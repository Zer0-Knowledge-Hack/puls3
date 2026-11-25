import { Networks, StrKey } from '@stellar/stellar-base';

/**
 * The chain the SDK signs for, and the contracts it accepts to sign calls to
 * (ADR-0010 D3). These come from the SDK, never from the server's answer: a
 * server that asks for a call to another contract is refused.
 */
export interface Puls3Network {
  /** The network passphrase every signature covers. */
  readonly passphrase: string;
  /** The ERC-8183 escrow: `create_job`, `fund`, `complete`, `reject`. */
  readonly escrow: string;
  /** The Identity Registry: `register_full`, `set_agent_wallet`. */
  readonly identityRegistry: string;
  /** The Reputation Registry: `give_feedback`. */
  readonly reputationRegistry: string;
  /** The USDC Stellar Asset Contract, the only token `fund` may move. */
  readonly usdc: string;
  /** The highest total fee, in stroops, the SDK signs. */
  readonly maxFeeStroops: number;
  /**
   * The server's SEP-10 signing key (`G…`). When set, a login challenge must
   * come from it and carry its signature. The app reads the same value from
   * `PULS3_AUTH_SERVER_SIGNING_KEY`.
   */
  readonly serverSigningKey: string | null;
  /** The SEP-10 home domain. When set, the challenge must name it. */
  readonly homeDomain: string | null;
}

/**
 * puls3 on Stellar testnet, from `contracts/deployments/testnet.json` and
 * `docs/verification/live-hire.md`. A new escrow (the 0.2.0 rotation) needs
 * a new release of this package, or an override in [withNetwork].
 */
export const TESTNET: Puls3Network = Object.freeze({
  passphrase: Networks.TESTNET,
  escrow: 'CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2',
  identityRegistry: 'CD5QZOKGRBV35C5SDT6PG7S72XGG4BHQAC2L56YLNBJDUL4LDMTXFIJJ',
  reputationRegistry: 'CBJZYEJ5DS7TDLA2ECRAW3ICQIYAOMTCQ5QSY7PYJ5PJ2W5EAHPBP5Q4',
  usdc: 'CBIELTK6YBZJU5UP2WWQEUCYKLPU6AUNZ2BQ4WWFEIE3USCIHMXQDAMA',
  maxFeeStroops: 50_000_000,
  serverSigningKey: null,
  homeDomain: null,
});

/**
 * [base] with some values replaced, for example the contracts of a local
 * sandbox or the server's signing key. Refuses the public network: week 3
 * signs on testnet only (ADR-0010, open decision 2).
 */
export function withNetwork(
  overrides: Partial<Puls3Network>,
  base: Puls3Network = TESTNET,
): Puls3Network {
  const network = { ...base, ...overrides };
  if (network.passphrase === Networks.PUBLIC) {
    throw new TypeError('This SDK does not sign on the public network');
  }
  for (const key of ['escrow', 'identityRegistry', 'reputationRegistry', 'usdc'] as const) {
    if (!StrKey.isValidContract(network[key])) {
      throw new TypeError(`${key} is not a contract address`);
    }
  }
  if (network.serverSigningKey !== null && !StrKey.isValidEd25519PublicKey(network.serverSigningKey)) {
    throw new TypeError('serverSigningKey is not a G… address');
  }
  if (!Number.isSafeInteger(network.maxFeeStroops) || network.maxFeeStroops <= 0) {
    throw new TypeError('maxFeeStroops must be a positive integer');
  }
  return Object.freeze(network);
}
