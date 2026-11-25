import { createHash } from 'node:crypto';
import {
  Account,
  Address,
  Asset,
  Keypair,
  Operation,
  TransactionBuilder,
  nativeToScVal,
  xdr,
} from '@stellar/stellar-base';

import type { PreparedTransaction, WalletChallenge } from '../src/models.js';
import { TESTNET } from '../src/network.js';

/**
 * Envelopes built here the way the server prepares them, so the checks of
 * ADR-0010 D3 are tested on real XDR, not on mocks.
 */

export const builder = Keypair.random();
export const stranger = Keypair.random();
export const server = Keypair.random();
export const agentWallet = Keypair.random().publicKey();
export const provider = Keypair.random().publicKey();
export const otherContract = 'CDLZFC3SYJYDZT7K67VZ75HPJVIEUVNIXF47ZG2FB2RMQQVU2HHGCYSC';

export const addr = (address: string) => new Address(address).toScVal();
export const i128 = (v: bigint) => nativeToScVal(v, { type: 'i128' });
export const u32 = (v: number) => nativeToScVal(v, { type: 'u32' });
export const u64 = (v: bigint) => nativeToScVal(v, { type: 'u64' });
export const str = (v: string) => nativeToScVal(v, { type: 'string' });
export const bytes32 = () => xdr.ScVal.scvBytes(Buffer.alloc(32, 7));

export interface Call {
  contract: string;
  fn: string;
  args: xdr.ScVal[];
}

export function invocation(call: Call, subs: xdr.SorobanAuthorizedInvocation[] = []) {
  return new xdr.SorobanAuthorizedInvocation({
    function: xdr.SorobanAuthorizedFunction.sorobanAuthorizedFunctionTypeContractFn(
      new xdr.InvokeContractArgs({
        contractAddress: new Address(call.contract).toScAddress(),
        functionName: call.fn,
        args: call.args,
      }),
    ),
    subInvocations: subs,
  });
}

/** The source account's own authorization of [call]. */
export function sourceAuth(call: Call, subs: xdr.SorobanAuthorizedInvocation[] = []) {
  return new xdr.SorobanAuthorizationEntry({
    credentials: xdr.SorobanCredentials.sorobanCredentialsSourceAccount(),
    rootInvocation: invocation(call, subs),
  });
}

/** An authorization of [call] that [address] has to sign separately. */
export function addressAuth(address: string, call: Call, subs: xdr.SorobanAuthorizedInvocation[] = []) {
  return new xdr.SorobanAuthorizationEntry({
    credentials: xdr.SorobanCredentials.sorobanCredentialsAddress(
      new xdr.SorobanAddressCredentials({
        address: new Address(address).toScAddress(),
        nonce: xdr.Int64.fromString('42'),
        signatureExpirationLedger: 0,
        signature: xdr.ScVal.scvVoid(),
      }),
    ),
    rootInvocation: invocation(call, subs),
  });
}

export interface EnvelopeOptions {
  source?: string;
  fee?: number;
  timeoutSeconds?: number;
  auth?: xdr.SorobanAuthorizationEntry[];
  extraOperation?: boolean;
  passphrase?: string;
}

/** A one-call envelope, unsigned, as `prepare…` returns it. */
export function envelope(call: Call, options: EnvelopeOptions = {}): string {
  const source = options.source ?? builder.publicKey();
  const tx = new TransactionBuilder(new Account(source, '100'), {
    fee: String(options.fee ?? 100_000),
    networkPassphrase: options.passphrase ?? TESTNET.passphrase,
  }).addOperation(
    Operation.invokeContractFunction({
      contract: call.contract,
      function: call.fn,
      args: call.args,
      auth: options.auth ?? [sourceAuth(call)],
    }),
  );
  if (options.extraOperation) {
    tx.addOperation(Operation.manageData({ name: 'x', value: 'y' }));
  }
  return tx.setTimeout(options.timeoutSeconds ?? 300).build().toXDR();
}

export const createJobCall = (
  overrides: Partial<Record<'caller' | 'evaluator' | 'token' | 'provider', string>> & {
    budget?: bigint;
    hook?: xdr.ScVal;
    agentId?: number;
  } = {},
): Call => ({
  contract: TESTNET.escrow,
  fn: 'create_job',
  args: [
    addr(overrides.caller ?? builder.publicKey()),
    addr(overrides.provider ?? provider),
    addr(overrides.evaluator ?? builder.publicKey()),
    u64(1_900_000_000n),
    str('Summarize this transaction.'),
    overrides.hook ?? xdr.ScVal.scvVoid(),
    u32(overrides.agentId ?? 30),
    addr(overrides.token ?? TESTNET.usdc),
    i128(overrides.budget ?? 5_000_000n),
  ],
});

export const fundCall = (budget = 5_000_000n, jobId = 35n): Call => ({
  contract: TESTNET.escrow,
  fn: 'fund',
  args: [addr(builder.publicKey()), u64(jobId), i128(budget), u32(500)],
});

export const fundWithReserveCall = (budget: bigint, reserve: bigint): Call => ({
  contract: TESTNET.escrow,
  fn: 'fund_with_reserve',
  args: [addr(builder.publicKey()), u64(35n), i128(budget), i128(reserve), u32(500)],
});

export const transferCall = (
  amount: bigint,
  overrides: { from?: string; to?: string; token?: string } = {},
): Call => ({
  contract: overrides.token ?? TESTNET.usdc,
  fn: 'transfer',
  args: [
    addr(overrides.from ?? builder.publicKey()),
    addr(overrides.to ?? TESTNET.escrow),
    i128(amount),
  ],
});

/** The reason the tests reject with. */
export const rejectReason = 'Not usable.';

/** complete carries 32 zero bytes, reject the SHA-256 of the reason (as the server). */
export const reasonBytes = (fn: 'complete' | 'reject', reason = rejectReason) =>
  xdr.ScVal.scvBytes(fn === 'complete' ? Buffer.alloc(32) : createHash('sha256').update(reason, 'utf8').digest());

export const escrowCall = (
  fn: 'complete' | 'reject',
  caller = builder.publicKey(),
  jobId = 35n,
  reason: xdr.ScVal = reasonBytes(fn),
): Call => ({
  contract: TESTNET.escrow,
  fn,
  args: [addr(caller), u64(jobId), reason],
});

/** Draft 7, as the deploy tests serve it from `getDraft`. */
export const draft7 = {
  draftId: 7,
  manifest: {
    name: 'Summarizer',
    description: 'Summarizes a text in five bullets.',
    skills: [{ id: 'summarize', name: 'Summarize', description: null, tags: ['text'] }],
    model: { provider: 'workers-ai', id: '@cf/meta/llama-3.3-70b-instruct-fp8-fast' },
    systemPrompt: 'Summarize the text in five short bullet points.',
    inputType: 'text',
    inputMaxChars: 4000,
    outputType: 'text',
    outputMaxChars: 2000,
    price: { asset: 'USDC', amount: 1_000_000 },
  },
  revision: 3,
  deployState: 'draft',
  liveVersion: null,
  agentId: null,
  retryFromStep: null,
};

/** What draft 7 must register. */
export const registration = {
  catalogId: 'studio-7',
  name: 'Summarizer',
  description: 'Summarizes a text in five bullets.',
  skills: ['summarize'],
  priceUsdcStroops: '1000000',
  model: '@cf/meta/llama-3.3-70b-instruct-fp8-fast',
};

const manifestHashBytes = createHash('sha256').update('draft 7 manifest', 'utf8').digest();

const metadataEntry = (key: string, value: Buffer) =>
  xdr.ScVal.scvMap([
    new xdr.ScMapEntry({ key: xdr.ScVal.scvSymbol('key'), val: xdr.ScVal.scvString(key) }),
    new xdr.ScMapEntry({ key: xdr.ScVal.scvSymbol('value'), val: xdr.ScVal.scvBytes(value) }),
  ]);

/** register_full as `registerFullArgs` builds it, with [overrides] for the refusals. */
export const registerFullCall = (
  options: {
    caller?: string;
    uri?: string;
    fields?: Partial<Record<string, string>>;
    extra?: [string, string];
    drop?: string;
  } = {},
): Call => {
  const fields: Record<string, string> = {
    id: registration.catalogId,
    name: registration.name,
    description: registration.description,
    skills: JSON.stringify(registration.skills),
    priceUsdcStroops: registration.priceUsdcStroops,
    model: registration.model,
    'puls3.manifestVersion': '1',
  };
  for (const [key, value] of Object.entries(options.fields ?? {})) {
    if (value !== undefined) fields[key] = value;
  }
  const entries = Object.entries(fields)
    .filter(([key]) => key !== options.drop)
    .map(([key, value]) => metadataEntry(key, Buffer.from(value, 'utf8')));
  if (options.drop !== 'manifestHash') entries.push(metadataEntry('manifestHash', manifestHashBytes));
  if (options.extra) entries.push(metadataEntry(options.extra[0], Buffer.from(options.extra[1], 'utf8')));
  return {
    contract: TESTNET.identityRegistry,
    fn: 'register_full',
    args: [
      addr(options.caller ?? builder.publicKey()),
      str(options.uri ?? `https://puls3.example/registry/${manifestHashBytes.toString('hex')}`),
      xdr.ScVal.scvVec(entries),
    ],
  };
};

export const giveFeedbackCall = (agentId = 30): Call => ({
  contract: TESTNET.reputationRegistry,
  fn: 'give_feedback',
  args: [
    addr(builder.publicKey()),
    u32(agentId),
    i128(5n),
    u32(0),
    str('puls3'),
    str('puls3:job:v1:x:35'),
    str(''),
    str(''),
    bytes32(),
  ],
});

export const setAgentWalletCall = (agentId = 31, wallet = agentWallet): Call => ({
  contract: TESTNET.identityRegistry,
  fn: 'set_agent_wallet',
  args: [addr(builder.publicKey()), u32(agentId), addr(wallet)],
});

export function prepared(
  purpose: string,
  overrides: Partial<PreparedTransaction> = {},
): PreparedTransaction {
  return {
    preparationId: `prep-${purpose}`,
    purpose,
    signer: builder.publicKey(),
    networkPassphrase: TESTNET.passphrase,
    unsignedTransactionXdr: null,
    authorizationEntryXdr: null,
    transaction: null,
    signatureExpirationLedger: null,
    expiresAt: new Date(Date.now() + 600_000),
    ...overrides,
  };
}

export function preparedTx(purpose: string, call: Call, options: EnvelopeOptions = {}) {
  return prepared(purpose, { unsignedTransactionXdr: envelope(call, options) });
}

export interface ChallengeOptions {
  wallet?: string;
  from?: Keypair;
  sequence?: string;
  firstSource?: string;
  name?: string;
  payment?: boolean;
  sign?: boolean;
  timeoutSeconds?: number;
  /** The `web_auth_domain` value. Defaults to `puls3.example`. */
  webAuthDomain?: string;
  /** Adds a third `manage_data` operation, which no real challenge has. */
  extraOperation?: boolean;
}

/** A SEP-10 challenge like `StellarSep10Codec.build`. */
export function challenge(options: ChallengeOptions = {}): WalletChallenge {
  const from = options.from ?? server;
  const wallet = options.wallet ?? builder.publicKey();
  // TransactionBuilder adds one to the account's sequence.
  const sequence = options.sequence === undefined ? '-1' : String(BigInt(options.sequence) - 1n);
  const builderTx = new TransactionBuilder(new Account(from.publicKey(), sequence), {
    fee: '100',
    networkPassphrase: TESTNET.passphrase,
  })
    .addOperation(
      options.payment
        ? Operation.payment({
            destination: stranger.publicKey(),
            asset: Asset.native(),
            amount: '1',
            source: options.firstSource ?? wallet,
          })
        : Operation.manageData({
            name: options.name ?? 'puls3.example auth',
            value: 'bm9uY2U=',
            source: options.firstSource ?? wallet,
          }),
    )
    .addOperation(
      Operation.manageData({
        name: 'web_auth_domain',
        value: options.webAuthDomain ?? 'puls3.example',
        source: from.publicKey(),
      }),
    );
  if (options.extraOperation) {
    builderTx.addOperation(Operation.manageData({ name: 'extra', value: 'x', source: from.publicKey() }));
  }
  const tx = builderTx
    .setTimeout(options.timeoutSeconds ?? 900)
    .build();
  if (options.sign !== false) tx.sign(from);
  return {
    challengeId: 'challenge-1',
    wallet,
    payload: tx.toXDR(),
    networkPassphrase: TESTNET.passphrase,
    expiresAt: new Date(Date.now() + 900_000),
  };
}
