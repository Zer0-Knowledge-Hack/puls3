import { randomBytes } from 'node:crypto';
import { promises as fs } from 'node:fs';
import { dirname, join } from 'node:path';
import { inspect } from 'node:util';

import { Puls3ApiError } from './errors.js';
import { decodeAuthTokens } from './models.js';
import { HttpTransport, type AuthProvider, type RefreshResult } from './transport.js';

/**
 * The environment variable a program seeds its session with: the refresh
 * token the app shows once ("Copy session for CLI", #259).
 */
export const refreshTokenVariable = 'PULS3_REFRESH_TOKEN';

/** The environment variable that moves this SDK's session file. */
export const sessionFileVariable = 'PULS3_NODE_SESSION_FILE';

/** What one refresh returns: a new access token and the rotated refresh token. */
export interface RefreshedTokens {
  accessToken: string;
  accessTokenExpiresAt: Date | null;
  refreshToken: string;
}

/**
 * Exchanges a refresh token for [RefreshedTokens]
 * (`jwtRefresh.refreshAccessToken`). A refused token (expired, revoked,
 * reused) rejects with a [Puls3ApiError]; anything else is treated as the
 * server being unreachable.
 */
export type RefreshCall = (refreshToken: string) => Promise<RefreshedTokens>;

/**
 * This SDK's session file: `$PULS3_NODE_SESSION_FILE`, else
 * `%APPDATA%\puls3\node-session.json` on Windows, else
 * `$XDG_CONFIG_HOME/puls3/node-session.json`, else
 * `$HOME/.config/puls3/node-session.json`. Null when none is set.
 *
 * It is not the Dart CLI's `session.json`: the CLI and the MCP server lock
 * that file in a way Node cannot share, so a Node program keeps its own
 * session, copied separately from the app.
 */
export function defaultSessionFile(
  environment: Readonly<Record<string, string | undefined>>,
  platform: NodeJS.Platform = process.platform,
): string | null {
  const set = (name: string): string | null => {
    const value = environment[name]?.trim() ?? '';
    return value === '' ? null : value;
  };
  const explicit = set(sessionFileVariable);
  if (explicit !== null) return explicit;
  if (platform === 'win32') {
    const appData = set('APPDATA');
    return appData === null ? null : join(appData, 'puls3', 'node-session.json');
  }
  const config = set('XDG_CONFIG_HOME');
  if (config !== null) return join(config, 'puls3', 'node-session.json');
  const home = set('HOME');
  return home === null ? null : join(home, '.config', 'puls3', 'node-session.json');
}

interface Stored {
  seed: string;
  refreshToken: string;
  accessToken: string | null;
  accessTokenExpiresAt: Date | null;
}

/**
 * A wallet session for a program without the app (#259, ADR-0007 A′,
 * ADR-0010 D5), the Node counterpart of the Dart SDK's `CliSession`.
 *
 * The app creates a CLI session for its wallet and shows the refresh token
 * once. The program seeds this session with it through
 * [refreshTokenVariable], never an argument. Every refresh rotates the
 * token, so the current one is kept in a file only the user can read (mode
 * 0600) and survives restarts. The session stops refreshing 72 hours after
 * the app created it; then copy a new one.
 *
 * Several Node programs can share one session file: a lock around each
 * refresh makes it read the newest token, so none of them presents a token
 * another already rotated, which the server treats as reuse and revokes.
 * Do not seed a Dart program (the `puls3` CLI, the MCP server) with the same
 * token: copy one session for each.
 *
 * No token appears in a `toString`, `JSON.stringify`, `util.inspect`, an
 * error or a log.
 */
export class CliSession implements AuthProvider {
  readonly #file: string;
  readonly #refresh: RefreshCall;
  readonly #now: () => Date;
  #state: Stored;
  #pending: Promise<RefreshResult> | null = null;

  /** An access token this close to its expiry is refreshed first. */
  static readonly #marginMs = 30_000;

  private constructor(file: string, refresh: RefreshCall, now: () => Date, state: Stored) {
    this.#file = file;
    this.#refresh = refresh;
    this.#now = now;
    this.#state = state;
  }

  /**
   * Opens the session for the server at [apiUrl]: the session file of
   * [environment] (see [defaultSessionFile]) seeded from
   * [refreshTokenVariable]. Null when there is neither a seed nor a saved
   * session.
   */
  static async open(
    apiUrl: string,
    options: {
      environment?: Readonly<Record<string, string | undefined>>;
      fetch?: typeof fetch;
    } = {},
  ): Promise<CliSession | null> {
    const environment = options.environment ?? process.env;
    const file = defaultSessionFile(environment);
    if (file === null) return null;
    const transport = new HttpTransport(
      apiUrl,
      options.fetch === undefined ? {} : { fetch: options.fetch },
    );
    return CliSession.load(file, {
      seed: environment[refreshTokenVariable],
      refresh: async (refreshToken) => {
        const tokens = decodeAuthTokens(
          await transport.call(
            'jwtRefresh',
            'refreshAccessToken',
            { refreshToken },
            { authenticated: false },
          ),
        );
        if (tokens.refreshToken === null) {
          throw new Error('The server returned no refresh token');
        }
        return {
          accessToken: tokens.token,
          accessTokenExpiresAt: tokens.tokenExpiresAt,
          refreshToken: tokens.refreshToken,
        };
      },
    });
  }

  /**
   * The session saved in [file], or a new one from [seed]. A seed that
   * differs from the one the file was last seeded with replaces the saved
   * session: that is how a program takes a newly copied session. Null when
   * there is neither.
   */
  static async load(
    file: string,
    options: { seed?: string | undefined; refresh: RefreshCall; now?: () => Date },
  ): Promise<CliSession | null> {
    const seed = options.seed?.trim() ?? '';
    const state = await locked(file, async () => {
      const saved = await read(file);
      if (seed !== '' && seed !== saved?.seed) {
        const fresh: Stored = {
          seed,
          refreshToken: seed,
          accessToken: null,
          accessTokenExpiresAt: null,
        };
        await write(file, fresh);
        return fresh;
      }
      return saved;
    });
    if (state === null) return null;
    return new CliSession(file, options.refresh, options.now ?? (() => new Date()), state);
  }

  /**
   * Whether the session can still refresh. False once the server refused
   * it: the file is removed and a new session must be copied from the app.
   */
  get isUsable(): boolean {
    return this.#state.refreshToken !== '';
  }

  async authorization(): Promise<string | null> {
    await this.refresh(false);
    const token = this.#state.accessToken;
    return token === null ? null : `Bearer ${token}`;
  }

  /**
   * Refreshes the access token, one refresh at a time. Without [force], a
   * token that is still valid is kept (`skipped`).
   */
  refresh(force: boolean): Promise<RefreshResult> {
    if (this.#pending !== null) return this.#pending;
    const next = this.#refreshOnce(force).finally(() => {
      this.#pending = null;
    });
    this.#pending = next;
    return next;
  }

  get #accessValid(): boolean {
    const { accessToken, accessTokenExpiresAt } = this.#state;
    return (
      accessToken !== null &&
      accessTokenExpiresAt !== null &&
      this.#now().getTime() + CliSession.#marginMs < accessTokenExpiresAt.getTime()
    );
  }

  async #refreshOnce(force: boolean): Promise<RefreshResult> {
    if (!this.isUsable) return 'failedUnauthorized';
    if (!force && this.#accessValid) return 'skipped';
    return locked(this.#file, async () => {
      const saved = await read(this.#file);
      if (saved === null) {
        // Another program found the session refused and removed the file.
        this.#state = { ...this.#state, refreshToken: '', accessToken: null };
        return 'failedUnauthorized';
      }
      if (saved.refreshToken !== this.#state.refreshToken) {
        // Rotated by another program: take its tokens.
        this.#state = saved;
        if (this.#accessValid) return 'success';
      } else if (!force && this.#accessValid) {
        return 'skipped';
      }
      let tokens: RefreshedTokens;
      try {
        tokens = await this.#refresh(this.#state.refreshToken);
      } catch (error) {
        if (error instanceof Puls3ApiError) {
          // Expired, revoked, reused or unknown: this session is over.
          this.#state = { ...this.#state, refreshToken: '', accessToken: null };
          await fs.rm(this.#file, { force: true });
          return 'failedUnauthorized';
        }
        return 'failedOther';
      }
      this.#state = {
        seed: this.#state.seed,
        refreshToken: tokens.refreshToken,
        accessToken: tokens.accessToken,
        accessTokenExpiresAt: tokens.accessTokenExpiresAt,
      };
      await write(this.#file, this.#state);
      return 'success';
    });
  }

  toString(): string {
    return `CliSession(${this.#file})`;
  }

  toJSON(): string {
    return this.toString();
  }

  [inspect.custom](): string {
    return this.toString();
  }
}

// --- The file -------------------------------------------------------------

async function read(file: string): Promise<Stored | null> {
  let text: string;
  try {
    text = await fs.readFile(file, 'utf8');
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') return null;
    throw error;
  }
  let json: unknown;
  try {
    json = JSON.parse(text);
  } catch {
    return null;
  }
  if (typeof json !== 'object' || json === null) return null;
  const { seed, refreshToken, accessToken, accessTokenExpiresAt } = json as Record<
    string,
    unknown
  >;
  if (typeof seed !== 'string' || typeof refreshToken !== 'string' || refreshToken === '') {
    return null;
  }
  const expiresAt =
    typeof accessTokenExpiresAt === 'string' ? new Date(accessTokenExpiresAt) : null;
  return {
    seed,
    refreshToken,
    accessToken: typeof accessToken === 'string' ? accessToken : null,
    accessTokenExpiresAt:
      expiresAt === null || Number.isNaN(expiresAt.getTime()) ? null : expiresAt,
  };
}

/**
 * Writes [state] with mode 0600: to a new temporary file in the same
 * directory, created user-only before any secret is written, then renamed
 * over [file]. Windows has no POSIX modes; the file is in the user's
 * profile.
 */
async function write(file: string, state: Stored): Promise<void> {
  await fs.mkdir(dirname(file), { recursive: true, mode: 0o700 });
  const temp = `${file}.${randomBytes(6).toString('hex')}.tmp`;
  const handle = await fs.open(temp, 'wx', 0o600);
  try {
    await handle.chmod(0o600);
    await handle.writeFile(
      JSON.stringify({
        seed: state.seed,
        refreshToken: state.refreshToken,
        accessToken: state.accessToken,
        accessTokenExpiresAt: state.accessTokenExpiresAt?.toISOString() ?? null,
      }),
    );
    await handle.sync();
  } finally {
    await handle.close();
  }
  await fs.rename(temp, file);
}

// --- The lock -------------------------------------------------------------

/** Queued bodies per file in this process. */
const inProcess = new Map<string, Promise<unknown>>();

/** A lock older than this is from a program that died holding it. */
const staleLockMs = 60_000;
const lockWaitMs = 30_000;

/**
 * Runs [body] holding the lock of [file]: in this process a queue per path,
 * across processes the directory `<file>.lock.d`, which `mkdir` creates
 * atomically. The lock holds no secret.
 */
async function locked<T>(file: string, body: () => Promise<T>): Promise<T> {
  const previous = inProcess.get(file) ?? Promise.resolve();
  const run = previous.catch(() => undefined).then(() => acrossProcesses(file, body));
  const tail = run.catch(() => undefined);
  inProcess.set(file, tail);
  try {
    return await run;
  } finally {
    if (inProcess.get(file) === tail) inProcess.delete(file);
  }
}

async function acrossProcesses<T>(file: string, body: () => Promise<T>): Promise<T> {
  await fs.mkdir(dirname(file), { recursive: true, mode: 0o700 });
  const lock = `${file}.lock.d`;
  const deadline = Date.now() + lockWaitMs;
  for (;;) {
    try {
      await fs.mkdir(lock);
      break;
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== 'EEXIST') throw error;
      const stat = await fs.stat(lock).catch(() => null);
      if (stat !== null && Date.now() - stat.mtimeMs > staleLockMs) {
        await fs.rm(lock, { recursive: true, force: true });
        continue;
      }
      if (Date.now() > deadline) {
        throw new Error(`Timed out waiting for the session lock ${lock}`);
      }
      await new Promise((resolve) => setTimeout(resolve, 25));
    }
  }
  try {
    return await body();
  } finally {
    await fs.rm(lock, { recursive: true, force: true });
  }
}
