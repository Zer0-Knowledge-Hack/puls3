import { inspect } from 'node:util';

import { Puls3ApiError, Puls3HttpError } from './errors.js';
import { checkChallenge } from './guard.js';
import { decodeAuthTokens, decodeWalletChallenge } from './models.js';
import type { Puls3Network } from './network.js';
import type { Puls3Signer } from './signer.js';
import type { AuthProvider, RefreshResult, Transport } from './transport.js';

/**
 * A wallet session the SDK opens by itself with a [Puls3Signer] (ADR-0010
 * D5): it asks for a SEP-10 challenge, checks it (D3 rule 6), signs it and
 * exchanges it for tokens. No app and no copied CLI session are needed.
 *
 * Tokens stay in memory. Every refresh rotates the refresh token; when the
 * server refuses it (expired, revoked), the session signs in again with the
 * signer. No token appears in `toString`, `JSON.stringify` or
 * `util.inspect`.
 */
export class KeySession implements AuthProvider {
  /** An access token this close to its expiry is refreshed first. */
  static readonly #marginMs = 30_000;

  readonly #transport: Transport;
  readonly #signer: Puls3Signer;
  readonly #network: Puls3Network;
  readonly #now: () => Date;
  #accessToken: string | null = null;
  #accessExpiresAt: Date | null = null;
  #refreshToken: string | null = null;
  #pending: Promise<RefreshResult> | null = null;

  /**
   * [transport] makes the anonymous `walletAuth` and `jwtRefresh` calls; it
   * must not itself use this session.
   */
  constructor(
    transport: Transport,
    signer: Puls3Signer,
    network: Puls3Network,
    options: { now?: () => Date } = {},
  ) {
    this.#transport = transport;
    this.#signer = signer;
    this.#network = network;
    this.#now = options.now ?? (() => new Date());
  }

  /** The wallet this session acts for. */
  get wallet(): string {
    return this.#signer.publicKey();
  }

  async authorization(): Promise<string | null> {
    const result = await this.refresh(false);
    if (result === 'failedUnauthorized' || result === 'failedOther') return null;
    return this.#accessToken === null ? null : `Bearer ${this.#accessToken}`;
  }

  refresh(force: boolean): Promise<RefreshResult> {
    if (this.#pending !== null) return this.#pending;
    const next = this.#refreshOnce(force).finally(() => {
      this.#pending = null;
    });
    this.#pending = next;
    return next;
  }

  /** Signs in now, instead of on the first call that needs the session. */
  async login(): Promise<void> {
    await this.#login();
  }

  async #refreshOnce(force: boolean): Promise<RefreshResult> {
    if (!force && this.#accessValid) return 'skipped';
    if (this.#refreshToken !== null) {
      try {
        this.#store(
          await this.#transport.call(
            'jwtRefresh',
            'refreshAccessToken',
            { refreshToken: this.#refreshToken },
            { authenticated: false },
          ),
        );
        return 'success';
      } catch (error) {
        if (!(error instanceof Puls3ApiError)) return 'failedOther';
        // Refused: sign in again below.
        this.#refreshToken = null;
      }
    }
    try {
      await this.#login();
      return 'success';
    } catch (error) {
      if (error instanceof Puls3ApiError || error instanceof Puls3HttpError) {
        return 'failedUnauthorized';
      }
      // Anything else (a refused challenge, a signer that failed, an answer
      // this version cannot read, an unreachable server) must reach the
      // caller as it is, not as the 401 of a call sent without a session.
      throw error;
    }
  }

  async #login(): Promise<void> {
    const wallet = this.#signer.publicKey();
    const challenge = decodeWalletChallenge(
      await this.#transport.call('walletAuth', 'createChallenge', { wallet }, { authenticated: false }),
    );
    const payload = checkChallenge(challenge, wallet, this.#network, this.#now());
    const signed = await this.#signer.signTransaction(payload, this.#network.passphrase);
    this.#store(
      await this.#transport.call(
        'walletAuth',
        'verifyChallenge',
        { challengeId: challenge.challengeId, wallet, signedChallengeXdr: signed },
        { authenticated: false },
      ),
    );
  }

  #store(value: unknown): void {
    const tokens = decodeAuthTokens(value);
    this.#accessToken = tokens.token;
    this.#accessExpiresAt = tokens.tokenExpiresAt;
    this.#refreshToken = tokens.refreshToken;
  }

  get #accessValid(): boolean {
    return (
      this.#accessToken !== null &&
      this.#accessExpiresAt !== null &&
      this.#now().getTime() + KeySession.#marginMs < this.#accessExpiresAt.getTime()
    );
  }

  toString(): string {
    return `KeySession(${this.wallet})`;
  }

  toJSON(): unknown {
    return { wallet: this.wallet };
  }

  [inspect.custom](): string {
    return this.toString();
  }
}
