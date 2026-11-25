/**
 * The errors the SDK throws. None of them carries a token, a request body or
 * any other secret: a message is the server's own message or a fixed text.
 */

/**
 * A typed error from the server.
 *
 * For a `Puls3ApiException`, [code] is its code (`HireNotFound`,
 * `InvalidHireTransition`, ...) and [details] its details, exactly as the
 * Dart SDK sees them (ADR-0007 D3). For the server's other typed exceptions
 * (`AgentCatalogUnavailable`, `AgentUnavailable`, the refresh token ones of
 * the auth module, ...), [code] is the exception's class name without its
 * module, and [details] holds its fields as strings.
 */
export class Puls3ApiError extends Error {
  override readonly name = 'Puls3ApiError';

  constructor(
    readonly code: string,
    message: string | null,
    readonly details: Readonly<Record<string, string>> | null,
  ) {
    super(message ?? code);
  }
}

/**
 * The server answered with an HTTP error that is not a typed exception:
 * 401 (no valid session), 403, 404 (no such endpoint), a 400 for arguments it
 * could not read, or a 500.
 */
export class Puls3HttpError extends Error {
  override readonly name = 'Puls3HttpError';

  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
  }
}

/**
 * The server's answer does not have the shape this SDK version expects, for
 * example a field it needs is missing. Usually an SDK older than the server.
 */
export class Puls3ProtocolError extends Error {
  override readonly name = 'Puls3ProtocolError';
}

/** The server could not be reached, or did not answer in time. */
export class Puls3NetworkError extends Error {
  override readonly name = 'Puls3NetworkError';
}

/**
 * The call acts for a wallet and the SDK has no session for one. Nothing was
 * sent.
 */
export class SessionRequired extends Error {
  override readonly name = 'SessionRequired';
  readonly code = 'SessionRequired';

  constructor(readonly operation: string) {
    super(`${operation} needs a wallet session`);
  }
}

/** An argument the server would refuse. Nothing was sent. */
export class InvalidArgument extends Error {
  override readonly name = 'InvalidArgument';

  constructor(
    readonly argument: string,
    reason: string,
  ) {
    super(`${argument} ${reason}`);
  }
}
