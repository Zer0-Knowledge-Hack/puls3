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
/**
 * Longer than [staleLockMs] plus a heartbeat, so a program waiting on the
 * lock of one that just died lives to take it over (#438).
 */
const lockWaitMs = 90_000;

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

/** How the cross-process lock times out. Tests shorten it. */
export interface LockTiming {
  /** A lock whose owner has not shown a sign of life for this long is from a program that died. */
  staleMs: number;
  /** How often a live holder shows its sign of life. */
  heartbeatMs: number;
  /** How long to wait for the lock before giving up. */
  waitMs: number;
}

/** The timing of the lock unless a test shortens it. */
export const defaultLockTiming: Readonly<LockTiming> = Object.freeze({
  staleMs: staleLockMs,
  heartbeatMs: 15_000,
  waitMs: lockWaitMs,
});

/** The directory operations of the lock. Tests replace them to stage races. */
export interface LockFs {
  mkdir(path: string): Promise<unknown>;
  rename(from: string, to: string): Promise<void>;
}

const realLockFs: LockFs = {
  mkdir: (path) => fs.mkdir(path),
  rename: (from, to) => fs.rename(from, to),
};

/**
 * Runs [body] holding `<file>.lock.d` across processes (#424).
 *
 * - `mkdir` creates the lock atomically, and the holder writes a random
 *   owner token into it (`owner`). While [body] runs, the holder touches
 *   that file every [LockTiming.heartbeatMs], so a live holder never looks
 *   stale, however long it runs.
 * - A lock whose owner shows no sign of life for [LockTiming.staleMs] is from
 *   a program that died. Only the program holding `<file>.lock.d.takeover`
 *   may remove it, and only after reading again that it is still the same
 *   stale owner. Two programs that find it stale at once cannot both remove
 *   it, nor remove the lock the first one took next.
 * - On release, the holder removes the lock only while it is still its own.
 *
 * @internal Exported for the tests only; not part of the package API.
 */
export async function acrossProcesses<T>(
  file: string,
  body: () => Promise<T>,
  timing: LockTiming = defaultLockTiming,
  lockFs: LockFs = realLockFs,
): Promise<T> {
  await fs.mkdir(dirname(file), { recursive: true, mode: 0o700 });
  const lock = `${file}.lock.d`;
  const owner = join(lock, 'owner');
  const token = randomBytes(16).toString('hex');
  const deadline = Date.now() + timing.waitMs;
  let refused: string | null = null;
  for (;;) {
    try {
      await lockFs.mkdir(lock);
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== 'EEXIST') throw error;
      refused = (await removeIfStale(lock, timing.staleMs, lockFs)) ?? refused;
      if (Date.now() > deadline) {
        const cause = refused === null ? '' : `; the system refused to take over its stale lock (${refused})`;
        throw new Error(`Timed out waiting for the session lock ${lock}${cause}`);
      }
      await new Promise((resolve) => setTimeout(resolve, 25));
      continue;
    }
    try {
      await fs.writeFile(owner, token);
    } catch (error) {
      await removeDir(lock);
      throw error;
    }
    break;
  }
  const heartbeat = setInterval(() => {
    const now = new Date();
    void fs.utimes(owner, now, now).catch(() => undefined);
    // The directory too: 0.1.0 ages a lock by its directory alone.
    void fs.utimes(lock, now, now).catch(() => undefined);
  }, timing.heartbeatMs);
  heartbeat.unref();
  try {
    return await body();
  } finally {
    clearInterval(heartbeat);
    // A read Windows refuses for a moment must not leave our own lock behind.
    let current = await ownerOf(lock);
    for (let tries = 0; current?.unreadable && tries < 20; tries++) {
      await new Promise((resolve) => setTimeout(resolve, 25));
      current = await ownerOf(lock);
    }
    if (current?.token === token) await removeDir(lock);
  }
}

/**
 * The owner token of [lock] and how long ago it last showed a sign of life,
 * or null when there is no lock. A lock with no owner file yet (just
 * created, or left by an older version) is aged by its directory.
 */
async function ownerOf(
  lock: string,
): Promise<{ token: string | null; ageMs: number; unreadable?: true } | null> {
  const owner = join(lock, 'owner');
  try {
    const stat = await fs.stat(owner);
    const token = await fs.readFile(owner, 'utf8');
    return { token, ageMs: Date.now() - stat.mtimeMs };
  } catch (error) {
    // Unreadable for a moment (Windows, while another program writes it): alive.
    if ((error as NodeJS.ErrnoException).code !== 'ENOENT') return { token: null, ageMs: 0, unreadable: true };
    const stat = await fs.stat(lock).catch(() => null);
    return stat === null ? null : { token: null, ageMs: Date.now() - stat.mtimeMs };
  }
}

/**
 * Removes [lock] if its owner is stale, under the takeover lock (see
 * [acrossProcesses]). Returns the code of a refusal to create the takeover
 * lock, so a wait that ends can say why, or null.
 */
async function removeIfStale(lock: string, staleMs: number, lockFs: LockFs): Promise<string | null> {
  const seen = await ownerOf(lock);
  if (seen === null || seen.unreadable || seen.ageMs <= staleMs) return null;
  const takeover = `${lock}.takeover`;
  try {
    await lockFs.mkdir(takeover);
  } catch (error) {
    const code = (error as NodeJS.ErrnoException).code;
    // Windows refuses for a moment a name whose directory is being removed: try again later.
    if (code === 'EPERM' || code === 'EACCES') return code;
    if (code !== 'EEXIST') throw error;
    await removeStaleTakeover(takeover, staleMs, lockFs);
    return null;
  }
  try {
    const now = await ownerOf(lock);
    if (now !== null && !now.unreadable && now.token === seen.token && now.ageMs > staleMs) {
      await removeDir(lock);
    }
  } finally {
    await removeDir(takeover);
  }
  return null;
}

/**
 * Removes a takeover lock left by a program that died while taking over. It
 * is first renamed to a name of its own, and removed only if it is the same
 * directory that was found stale; a fresh one renamed by mistake is put back.
 * When it cannot be put back (a third program took the name in between), it
 * is left where it is: it may belong to a program still taking over (#438).
 */
async function removeStaleTakeover(takeover: string, staleMs: number, lockFs: LockFs): Promise<void> {
  const stat = await fs.stat(takeover).catch(() => null);
  if (stat === null || Date.now() - stat.mtimeMs <= staleMs) return;
  const claimed = `${takeover}.${randomBytes(8).toString('hex')}`;
  try {
    await lockFs.rename(takeover, claimed);
  } catch {
    return; // Another program removed or renamed it first.
  }
  const moved = await fs.stat(claimed).catch(() => null);
  if (moved !== null && moved.ino === stat.ino && moved.mtimeMs === stat.mtimeMs) {
    await removeDir(claimed);
  } else {
    await lockFs.rename(claimed, takeover).catch(() => undefined);
  }
}

/** Removes a lock directory, retrying while Windows briefly refuses (`EPERM`, `EBUSY`). */
async function removeDir(path: string): Promise<void> {
  await fs.rm(path, { recursive: true, force: true, maxRetries: 10, retryDelay: 20 });
}
