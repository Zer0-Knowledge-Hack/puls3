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

/**
 * The call signs a transaction and the SDK has no signer (ADR-0010 D5).
 * Nothing was sent.
 */
export class SignerRequired extends Error {
  override readonly name = 'SignerRequired';
  readonly code = 'SignerRequired';

  constructor(readonly operation: string) {
    super(`${operation} signs a transaction and needs a signer`);
  }
}

/**
 * The SDK refused to sign what the server prepared, because it broke one of
 * the rules of ADR-0010 D3. [rule] names it (`network`, `signer`, `call`,
 * `money`, `bounds`, `login`). Nothing was signed and nothing was submitted.
 */
export class SigningRefused extends Error {
  override readonly name = 'SigningRefused';
  readonly code = 'SigningRefused';

  constructor(
    readonly rule: 'network' | 'signer' | 'call' | 'money' | 'bounds' | 'login',
    message: string,
  ) {
    super(`Refused to sign (${rule}): ${message}`);
  }
}

/**
 * A step that waits on the chain did not finish in time. [step] names it.
 * The transaction may still land: read the hire or the deploy again.
 */
export class Puls3Timeout extends Error {
  override readonly name = 'Puls3Timeout';
  readonly code = 'Timeout';

  constructor(readonly step: string) {
    super(`Timed out waiting for ${step}`);
  }
}

/**
 * The chain refused a transaction the SDK signed and submitted. [errorCode]
 * is the server's code for it (`ChainSubmission` `errorCode`).
 */
export class ChainSubmissionFailed extends Error {
  override readonly name = 'ChainSubmissionFailed';
  readonly code = 'ChainSubmissionFailed';

  constructor(
    readonly purpose: string,
    readonly errorCode: string | null,
  ) {
    super(`The ${purpose} transaction failed on chain${errorCode === null ? '' : `: ${errorCode}`}`);
  }
}
