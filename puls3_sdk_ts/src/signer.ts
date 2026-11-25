import { inspect } from 'node:util';

import {
  Keypair,
  StrKey,
  TransactionBuilder,
  authorizeEntry,
  xdr,
} from '@stellar/stellar-base';

/**
 * Signs for one Stellar account (ADR-0010 D2). The SDK asks it to sign only
 * what passed the checks of D3, and never sends the secret anywhere.
 *
 * [keypairSigner] holds a secret in this process. A program can bring its
 * own implementation (a KMS, a hardware key) so the SDK never sees one.
 */
export interface Puls3Signer {
  /** The account's `G…` address. */
  publicKey(): string;
  /** Signs a base64 transaction envelope and returns it signed. */
  signTransaction(envelopeXdr: string, networkPassphrase: string): Promise<string>;
  /**
   * Signs a base64 `SorobanAuthorizationEntry` with address credentials,
   * valid until [validUntilLedger], and returns it signed.
   */
  signAuthEntry(
    entryXdr: string,
    validUntilLedger: number,
    networkPassphrase: string,
  ): Promise<string>;
}

/** The environment variable [keypairSignerFromEnvironment] reads. */
export const secretKeyVariable = 'PULS3_SECRET_KEY';

/**
 * A signer over an `S…` secret. Use a key made for the SDK on testnet, not
 * the wallet you use in the app.
 *
 * The secret stays inside the returned object: it is not a property, so
 * `JSON.stringify`, `util.inspect` and a thrown error never show it.
 */
export function keypairSigner(secret: string): Puls3Signer {
  if (typeof secret !== 'string' || !StrKey.isValidEd25519SecretSeed(secret.trim())) {
    // Never echo the value: it may be a real secret with a typo.
    throw new TypeError('The secret key is not a valid S… key');
  }
  const keypair = Keypair.fromSecret(secret.trim());
  const address = keypair.publicKey();
  const signer: Puls3Signer = {
    publicKey: () => address,
    async signTransaction(envelopeXdr, networkPassphrase) {
      const tx = TransactionBuilder.fromXDR(envelopeXdr, networkPassphrase);
      tx.sign(keypair);
      return tx.toXDR();
    },
    async signAuthEntry(entryXdr, validUntilLedger, networkPassphrase) {
      const entry = xdr.SorobanAuthorizationEntry.fromXDR(entryXdr, 'base64');
      const signed = await authorizeEntry(entry, keypair, validUntilLedger, networkPassphrase);
      return signed.toXDR('base64');
    },
  };
  Object.defineProperties(signer, {
    toJSON: { value: () => ({ publicKey: address }) },
    toString: { value: () => `Puls3Signer(${address})` },
    [inspect.custom]: { value: () => `Puls3Signer(${address})` },
  });
  return Object.freeze(signer);
}

/**
 * [keypairSigner] over the secret in `PULS3_SECRET_KEY`, or null when it is
 * not set. The secret is read from the environment, never an argument on a
 * command line.
 */
export function keypairSignerFromEnvironment(
  environment: Readonly<Record<string, string | undefined>> = process.env,
): Puls3Signer | null {
  const secret = environment[secretKeyVariable]?.trim();
  return secret === undefined || secret === '' ? null : keypairSigner(secret);
}
