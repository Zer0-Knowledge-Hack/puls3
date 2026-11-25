import {
  Puls3ApiError,
  Puls3HttpError,
  Puls3NetworkError,
} from './errors.js';

/**
 * Supplies the `Authorization` header of a wallet session, and refreshes it.
 * [CliSession] is one; a program can bring its own.
 */
export interface AuthProvider {
  /** The header value (`Bearer <token>`), or null when there is none. */
  authorization(): Promise<string | null>;

  /**
   * Gets a new access token. The transport calls it with `force` after the
   * server answered 401, and retries the call once if it returns `success`.
   */
  refresh(force: boolean): Promise<RefreshResult>;
}

export type RefreshResult =
  | 'success'
  | 'skipped'
  | 'failedUnauthorized'
  | 'failedOther';

/** One endpoint call, as the generated Serverpod client makes it. */
export interface Transport {
  call(
    endpoint: string,
    method: string,
    args: Readonly<Record<string, unknown>>,
    options?: { authenticated?: boolean },
  ): Promise<unknown>;
}

export interface HttpTransportOptions {
  /** Signs the calls in as a wallet. Without it every call is anonymous. */
  auth?: AuthProvider;
  /** For tests and other runtimes. Defaults to the global `fetch`. */
  fetch?: typeof fetch;
  /** Per request. Defaults to 20 seconds, as the Dart client. */
  timeoutMs?: number;
}

/**
 * Calls the puls3 server over HTTP, with the wire format of the generated
 * Dart client (`docs/sdk/protocol.md`):
 *
 * - `POST <apiUrl><endpoint>/<method>`, a JSON object of the named arguments
 *   (a left-out optional argument is `null`), and the session's
 *   `Authorization: Bearer <token>` unless the call is anonymous;
 * - 200 with the JSON of the result;
 * - 400 with `{"className": ..., "data": {...}}` for a typed exception,
 *   which becomes a [Puls3ApiError]; any other status is a [Puls3HttpError].
 */
export class HttpTransport implements Transport {
  readonly #base: string;
  readonly #auth: AuthProvider | undefined;
  readonly #fetch: typeof fetch;
  readonly #timeoutMs: number;

  constructor(apiUrl: string, options: HttpTransportOptions = {}) {
    this.#base = normalizeApiUrl(apiUrl);
    this.#auth = options.auth;
    this.#fetch = options.fetch ?? globalThis.fetch;
    this.#timeoutMs = options.timeoutMs ?? 20_000;
  }

  async call(
    endpoint: string,
    method: string,
    args: Readonly<Record<string, unknown>>,
    options: { authenticated?: boolean } = {},
  ): Promise<unknown> {
    const auth = options.authenticated === false ? undefined : this.#auth;
    const body = JSON.stringify(args, (_key, value: unknown) =>
      value === undefined ? null : value,
    );
    const url = `${this.#base}${endpoint}/${method}`;

    let response = await this.#post(url, body, await auth?.authorization());
    if (response.status === 401 && auth !== undefined) {
      // The access token was refused although it looked valid: refresh once
      // and retry, as the Dart client does.
      if ((await auth.refresh(true)) === 'success') {
        response = await this.#post(url, body, await auth.authorization());
      }
    }
    const text = await this.#read(response);
    if (response.status !== 200) throw errorFrom(response.status, text);
    return text.length === 0 ? null : (JSON.parse(text) as unknown);
  }

  async #post(
    url: string,
    body: string,
    authorization: string | null | undefined,
  ): Promise<Response> {
    const headers: Record<string, string> = {
      'content-type': 'application/json; charset=utf-8',
    };
    if (authorization) headers['authorization'] = authorization;
    try {
      return await this.#fetch(url, {
        method: 'POST',
        headers,
        body,
        signal: AbortSignal.timeout(this.#timeoutMs),
      });
    } catch (error) {
      throw new Puls3NetworkError(networkMessage(error), { cause: error });
    }
  }

  async #read(response: Response): Promise<string> {
    try {
      return await response.text();
    } catch (error) {
      throw new Puls3NetworkError(networkMessage(error), { cause: error });
    }
  }
}

/**
 * [apiUrl] as the calls need it: absolute, `http` or `https`, with a path
 * ending in `/` and no query or fragment, since endpoint paths are appended
 * to it.
 */
export function normalizeApiUrl(apiUrl: string): string {
  let url: URL;
  try {
    url = new URL(apiUrl);
  } catch {
    throw new TypeError('apiUrl must be an absolute http or https URL');
  }
  if (
    (url.protocol !== 'http:' && url.protocol !== 'https:') ||
    url.hostname === '' ||
    url.search !== '' ||
    url.hash !== '' ||
    apiUrl.includes('?') ||
    apiUrl.includes('#')
  ) {
    throw new TypeError(
      'apiUrl must be an absolute http or https URL with no query or fragment',
    );
  }
  if (!url.pathname.endsWith('/')) url.pathname = `${url.pathname}/`;
  return url.toString();
}

/** The error for a non-200 answer. */
export function errorFrom(status: number, body: string): Error {
  if (status === 400) {
    const typed = typedException(body);
    if (typed !== null) return typed;
  }
  const message =
    status === 400 && body.length > 0 && body.length <= 500
      ? body
      : `The server answered HTTP ${status}`;
  return new Puls3HttpError(status, message);
}

function typedException(body: string): Puls3ApiError | null {
  let parsed: unknown;
  try {
    parsed = JSON.parse(body);
  } catch {
    return null;
  }
  if (!isObject(parsed)) return null;
  const { className, data } = parsed;
  if (typeof className !== 'string' || !isObject(data)) return null;
  const name = className.slice(className.lastIndexOf('.') + 1);

  if (name === 'Puls3ApiException') {
    if (typeof data['code'] !== 'string') return null;
    const message = typeof data['message'] === 'string' ? data['message'] : null;
    return new Puls3ApiError(data['code'], message, stringMap(data['details']));
  }
  const details: Record<string, string> = {};
  for (const [key, value] of Object.entries(data)) {
    if (value === null || value === undefined) continue;
    details[key] = typeof value === 'string' ? value : JSON.stringify(value);
  }
  const message = typeof data['message'] === 'string' ? data['message'] : null;
  return new Puls3ApiError(
    name,
    message,
    Object.keys(details).length === 0 ? null : details,
  );
}

function stringMap(value: unknown): Record<string, string> | null {
  if (!isObject(value)) return null;
  const out: Record<string, string> = {};
  for (const [key, entry] of Object.entries(value)) {
    if (typeof entry === 'string') out[key] = entry;
  }
  return out;
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function networkMessage(error: unknown): string {
  if (error instanceof Error && error.name === 'TimeoutError') {
    return 'The puls3 server did not answer in time';
  }
  return 'Could not reach the puls3 server';
}
