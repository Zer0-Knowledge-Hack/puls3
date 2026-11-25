import { createHash } from 'node:crypto';

import {
  Address,
  FeeBumpTransaction,
  Keypair,
  Networks,
  Transaction,
  TransactionBuilder,
  scValToNative,
  xdr,
} from '@stellar/stellar-base';

import { SigningRefused } from './errors.js';
import type { PreparedTransaction, WalletChallenge } from './models.js';
import type { Puls3Network } from './network.js';

/**
 * The checks the SDK runs before it signs anything (ADR-0010 D3). Each
 * function decodes what the server prepared and throws [SigningRefused]
 * unless it is exactly the call the SDK asked for, for the signer, on the
 * configured network and contracts, moving no more money than the caller
 * allowed. Contract ids come from [Puls3Network], never from the server.
 */

/** What the caller allowed for one wallet-signed transaction. */
export type Expectation =
  | {
      purpose: 'createJob';
      /** The highest job budget the caller allowed, in USDC stroops. */
      maxBudget: bigint;
      /** The agent's price: the job's budget must be exactly this. */
      price: bigint;
      /** The registry id of the agent being hired. */
      agentId: number;
      /** The agent's wallet, read from the Identity Registry, not the server. */
      provider: string;
    }
  | {
      purpose: 'fund';
      /** The highest budget `fund` may pull, in USDC stroops. */
      maxBudget: bigint;
      /** The agent's price: `expected_budget` must be exactly this. */
      price: bigint;
      /** The highest subcontract reserve it may pull on top. 0 by default. */
      maxReserve: bigint;
      /** The escrow job this hire's `create_job` produced. */
      jobId: bigint;
    }
  | { purpose: 'complete'; jobId: bigint }
  | {
      purpose: 'reject';
      jobId: bigint;
      /** The reason the SDK sent to the server; the call carries its SHA-256. */
      reason: string;
    }
  | { purpose: 'registerFull'; registration: RegistrationExpectation }
  | {
      purpose: 'giveFeedback';
      agentId: number;
      /** The score the caller passed to `rate`: the call's `value`, with 0 decimals. */
      score: number;
    };

/**
 * What `register_full` must register, from the draft the SDK read itself
 * (`getDraft`). The server builds the same values in `registerFullArgs`.
 */
export interface RegistrationExpectation {
  /** `studio-<draftId>`. */
  catalogId: string;
  name: string;
  description: string;
  /** The skill ids, in the draft's order. */
  skills: string[];
  /** The price in USDC stroops, as a decimal string. */
  priceUsdcStroops: string;
  /** The model id. */
  model: string;
}

/** What the caller expects the builder's `set_agent_wallet` entry to bind. */
export interface WalletAuthorizationExpectation {
  /** The Identity Registry id `register_full` returned. */
  agentId: number;
  /** The custodied agent wallet the deploy created. */
  agentWallet: string;
}

interface ContractCall {
  contract: string;
  fn: string;
  args: xdr.ScVal[];
}

function refuse(rule: SigningRefused['rule'], message: string): never {
  throw new SigningRefused(rule, message);
}

/**
 * Checks a wallet-signed transaction the server prepared, and returns its
 * unsigned envelope, ready for the signer.
 */
export function checkPreparedTransaction(
  prepared: PreparedTransaction,
  expectation: Expectation,
  signer: string,
  network: Puls3Network,
  now: Date = new Date(),
): string {
  checkPreparation(prepared, expectation.purpose, signer, network, now);
  const envelope =
    prepared.unsignedTransactionXdr ?? refuse('call', 'the preparation has no transaction');
  const tx = readTransaction(envelope, network.passphrase, 'call');

  if (tx.source !== signer) {
    refuse('signer', `the transaction's source is ${tx.source}, not the signer`);
  }
  if (BigInt(tx.fee) > BigInt(network.maxFeeStroops)) {
    refuse('bounds', `the fee ${tx.fee} is above the cap of ${network.maxFeeStroops} stroops`);
  }
  const bounds = tx.timeBounds;
  if (bounds === undefined || bounds.maxTime === '0') {
    refuse('bounds', 'the transaction has no time bounds');
  }
  if (Number(bounds.maxTime) * 1000 < now.getTime()) {
    refuse('bounds', 'the transaction has expired');
  }
  if (Number(bounds.maxTime) * 1000 > now.getTime() + network.maxTimeHorizonSeconds * 1000) {
    refuse('bounds', `the transaction stays valid more than ${network.maxTimeHorizonSeconds} s ahead`);
  }
  if (tx.operations.length !== 1) {
    refuse('call', `the transaction has ${tx.operations.length} operations, not 1`);
  }
  const operation = tx.operations[0]!;
  if (operation.type !== 'invokeHostFunction') {
    refuse('call', `the operation is ${operation.type}, not a contract call`);
  }
  if (operation.source !== undefined && operation.source !== signer) {
    refuse('signer', 'the operation acts for another account');
  }
  const call = invokedCall(operation.func) ?? refuse('call', 'the operation does not call a contract');
  checkCall(call, expectation, signer, network);

  for (const entry of operation.auth ?? []) {
    const credentials = entry.credentials();
    if (credentials.switch().name === 'sorobanCredentialsAddress') {
      const address = Address.fromScAddress(credentials.address().address()).toString();
      if (address !== signer) {
        refuse('signer', `the transaction asks ${address} to authorize a call`);
      }
    }
    const root = entry.rootInvocation();
    const rootCall =
      authorizedCall(root.function()) ?? refuse('call', 'an authorization is not a contract call');
    if (rootCall.contract !== call.contract || rootCall.fn !== call.fn || !sameArgs(rootCall.args, call.args)) {
      refuse('call', 'an authorization covers another call than the transaction makes');
    }
    checkSubInvocations(root.subInvocations(), call, expectation, signer, network);
  }
  return envelope;
}

/**
 * Checks the builder's `set_agent_wallet` authorization entry (deploy step
 * F4-7) and returns it with the ledger it must stay valid until.
 * [latestLedger] is read from the chain by the SDK, not from the server: the
 * entry must expire after it and within [Puls3Network.maxAuthLedgers].
 */
export function checkPreparedAuthorization(
  prepared: PreparedTransaction,
  expectation: WalletAuthorizationExpectation,
  signer: string,
  network: Puls3Network,
  latestLedger: number,
  now: Date = new Date(),
): { entryXdr: string; validUntilLedger: number } {
  checkPreparation(prepared, 'setAgentWallet', signer, network, now);
  const entryXdr =
    prepared.authorizationEntryXdr ?? refuse('call', 'the preparation has no authorization entry');
  const validUntilLedger = prepared.signatureExpirationLedger;
  if (validUntilLedger === null || validUntilLedger <= 0) {
    refuse('bounds', 'the authorization has no expiration ledger');
  }
  if (validUntilLedger <= latestLedger) {
    refuse('bounds', `the authorization expired at ledger ${validUntilLedger}`);
  }
  if (validUntilLedger > latestLedger + network.maxAuthLedgers) {
    refuse(
      'bounds',
      `the authorization stays valid until ledger ${validUntilLedger}, more than ${network.maxAuthLedgers} ahead`,
    );
  }
  let entry: xdr.SorobanAuthorizationEntry;
  try {
    entry = xdr.SorobanAuthorizationEntry.fromXDR(entryXdr, 'base64');
  } catch {
    refuse('call', 'the authorization entry cannot be read');
  }
  const credentials = entry.credentials();
  if (credentials.switch().name !== 'sorobanCredentialsAddress') {
    refuse('signer', 'the authorization entry has no address credentials');
  }
  const address = Address.fromScAddress(credentials.address().address()).toString();
  if (address !== signer) {
    refuse('signer', `the authorization entry is for ${address}, not the signer`);
  }
  const root = entry.rootInvocation();
  const call = authorizedCall(root.function()) ?? refuse('call', 'the authorization is not a contract call');
  if (call.contract !== network.identityRegistry || call.fn !== 'set_agent_wallet') {
    refuse('call', `the authorization is for ${call.fn} on ${call.contract}, not set_agent_wallet on the Identity Registry`);
  }
  if (call.args.length !== 3) refuse('call', 'set_agent_wallet does not have 3 arguments');
  if (addressArg(call.args, 0) !== signer) refuse('signer', 'set_agent_wallet is not called by the signer');
  if (intArg(call.args, 1) !== BigInt(expectation.agentId)) {
    refuse('call', `set_agent_wallet is for agent ${intArg(call.args, 1)}, not ${expectation.agentId}`);
  }
  if (addressArg(call.args, 2) !== expectation.agentWallet) {
    refuse('call', 'set_agent_wallet binds another wallet than the deploy created');
  }
  if (root.subInvocations().length !== 0) {
    refuse('money', 'the authorization covers further calls');
  }
  return { entryXdr, validUntilLedger };
}

/**
 * Checks a SEP-10 login challenge (D3 rule 7) and returns its envelope. It
 * must be a challenge for the signer that no network accepts as a payment:
 * sequence 0, from the server's key and signed by it, with exactly the two
 * `manage_data` operations `<home domain> auth` and `web_auth_domain`.
 */
export function checkChallenge(
  challenge: WalletChallenge,
  signer: string,
  network: Puls3Network,
  now: Date = new Date(),
): string {
  checkNetwork(challenge.networkPassphrase, network);
  if (challenge.wallet !== signer) refuse('login', 'the challenge is for another wallet');
  const tx = readTransaction(challenge.payload, network.passphrase, 'login');
  if (tx.sequence !== '0') refuse('login', 'the challenge has a sequence number');
  if (tx.source === signer) refuse('login', 'the challenge comes from the signer itself');
  if (network.serverSigningKey !== null) {
    if (tx.source !== network.serverSigningKey) {
      refuse('login', "the challenge does not come from the server's signing key");
    }
    const server = Keypair.fromPublicKey(network.serverSigningKey);
    const hash = tx.hash();
    if (!tx.signatures.some((s) => safeVerify(server, hash, s.signature()))) {
      refuse('login', 'the challenge is not signed by the server');
    }
  }
  const bounds = tx.timeBounds;
  if (bounds === undefined || bounds.maxTime === '0') refuse('login', 'the challenge has no time bounds');
  const seconds = now.getTime() / 1000;
  if (Number(bounds.maxTime) < seconds) refuse('login', 'the challenge has expired');
  if (tx.operations.length !== 2) {
    refuse('login', `the challenge has ${tx.operations.length} operations, not 2`);
  }
  const [auth, domain] = tx.operations;
  if (auth!.type !== 'manageData') refuse('login', `operation 0 is ${auth!.type}, not manage_data`);
  if (domain!.type !== 'manageData') refuse('login', `operation 1 is ${domain!.type}, not manage_data`);
  if (auth.source !== signer) refuse('login', 'the first operation is not for the signer');
  const name = network.homeDomain === null ? null : `${network.homeDomain} auth`;
  if (name === null ? !auth.name.endsWith(' auth') : auth.name !== name) {
    refuse('login', `the first operation is "${auth.name}", not the home domain's auth`);
  }
  if (domain.name !== 'web_auth_domain') {
    refuse('login', `the second operation is "${domain.name}", not web_auth_domain`);
  }
  if (domain.source !== tx.source) refuse('login', 'web_auth_domain acts for another account');
  if (
    network.webAuthDomain !== null &&
    (domain.value === undefined || domain.value.toString() !== network.webAuthDomain)
  ) {
    refuse('login', `the challenge's web_auth_domain is not ${network.webAuthDomain}`);
  }
  return challenge.payload;
}

// --- Internals --------------------------------------------------------------

function checkNetwork(passphrase: string, network: Puls3Network): void {
  if (network.passphrase === Networks.PUBLIC) {
    refuse('network', 'this SDK does not sign on the public network');
  }
  if (passphrase !== network.passphrase) {
    refuse('network', `the server prepared it for "${passphrase}", not "${network.passphrase}"`);
  }
}

function checkPreparation(
  prepared: PreparedTransaction,
  purpose: string,
  signer: string,
  network: Puls3Network,
  now: Date,
): void {
  if (prepared.purpose !== purpose) {
    refuse('call', `the server prepared ${prepared.purpose}, not ${purpose}`);
  }
  checkNetwork(prepared.networkPassphrase, network);
  if (prepared.signer !== signer) {
    refuse('signer', `the server prepared it for ${prepared.signer}, not the signer`);
  }
  if (prepared.expiresAt.getTime() <= now.getTime()) {
    refuse('bounds', 'the preparation has expired');
  }
}

function checkCall(
  call: ContractCall,
  expectation: Expectation,
  signer: string,
  network: Puls3Network,
): void {
  const expectCall = (contract: string, label: string, fns: readonly string[]) => {
    if (call.contract !== contract) {
      refuse('call', `the transaction calls ${call.contract}, not the ${label}`);
    }
    if (!fns.includes(call.fn)) {
      refuse('call', `the transaction calls ${call.fn}, not ${fns.join(' or ')}`);
    }
    if (addressArg(call.args, 0) !== signer) {
      refuse('signer', `${call.fn} is not called by the signer`);
    }
  };
  switch (expectation.purpose) {
    case 'createJob': {
      expectCall(network.escrow, 'escrow', ['create_job']);
      // create_job(caller, provider, evaluator, expired_at, description, hook, agent_id, token, budget)
      if (call.args.length !== 9) refuse('call', 'create_job does not have 9 arguments');
      if (addressArg(call.args, 1) !== expectation.provider) {
        refuse('money', "the job would pay another account than the agent's registered wallet");
      }
      if (addressArg(call.args, 2) !== signer) {
        refuse('money', 'the job would be judged by another account than the signer');
      }
      if (call.args[5]!.switch().name !== 'scvVoid') refuse('call', 'the job has a hook');
      if (intArg(call.args, 6) !== BigInt(expectation.agentId)) {
        refuse('call', `the job is for agent ${intArg(call.args, 6)}, not ${expectation.agentId}`);
      }
      if (addressArg(call.args, 7) !== network.usdc) refuse('money', 'the job is not paid in USDC');
      const budget = intArg(call.args, 8);
      if (budget <= 0n || budget > expectation.maxBudget) {
        refuse('money', `the budget ${budget} is above the allowed ${expectation.maxBudget}`);
      }
      if (budget !== expectation.price) {
        refuse('money', `the budget ${budget} is not the agent's price ${expectation.price}`);
      }
      return;
    }
    case 'fund': {
      expectCall(network.escrow, 'escrow', ['fund', 'fund_with_reserve']);
      const { budget, reserve } = fundAmounts(call);
      expectJob(call, expectation.jobId);
      if (budget <= 0n || budget > expectation.maxBudget) {
        refuse('money', `fund pulls ${budget}, above the allowed ${expectation.maxBudget}`);
      }
      if (budget !== expectation.price) {
        refuse('money', `fund pulls ${budget}, not the agent's price ${expectation.price}`);
      }
      if (reserve < 0n || reserve > expectation.maxReserve) {
        refuse('money', `fund pulls a reserve of ${reserve}, above the allowed ${expectation.maxReserve}`);
      }
      // `max_fee_bps` is the last argument of both calls.
      const feeBps = intArg(call.args, call.args.length - 1);
      if (feeBps < 0n || feeBps > BigInt(network.maxFeeBps)) {
        refuse('money', `fund accepts a platform fee of ${feeBps} bps, above the allowed ${network.maxFeeBps}`);
      }
      return;
    }
    case 'complete':
    case 'reject': {
      expectCall(network.escrow, 'escrow', [expectation.purpose]);
      // complete(caller, job_id, reason) / reject(caller, job_id, reason)
      if (call.args.length !== 3) refuse('call', `${call.fn} does not have 3 arguments`);
      expectJob(call, expectation.jobId);
      // The server sends 32 zero bytes for complete and the SHA-256 of the
      // reason for reject (escrow_relay_service.dart, _jobArgs).
      const reason =
        expectation.purpose === 'complete'
          ? Buffer.alloc(32)
          : createHash('sha256').update(expectation.reason, 'utf8').digest();
      if (!bytesArg(call.args, 2).equals(reason)) {
        refuse(
          'call',
          expectation.purpose === 'complete'
            ? 'complete carries a reason, where it must carry none'
            : 'reject carries another reason than the one you gave',
        );
      }
      return;
    }
    case 'registerFull':
      expectCall(network.identityRegistry, 'Identity Registry', ['register_full']);
      checkRegistration(call, expectation.registration, network.registrationOrigin);
      return;
    case 'giveFeedback':
      expectCall(network.reputationRegistry, 'Reputation Registry', ['give_feedback']);
      if (intArg(call.args, 1) !== BigInt(expectation.agentId)) {
        refuse('call', `the feedback is for agent ${intArg(call.args, 1)}, not ${expectation.agentId}`);
      }
      // give_feedback(caller, agent_id, value, value_decimals, …): the score
      // is `value` with 0 decimals, as `reputation_calls.dart` sends it.
      if (intArg(call.args, 2) !== BigInt(expectation.score) || intArg(call.args, 3) !== 0n) {
        refuse(
          'call',
          `the feedback scores ${intArg(call.args, 2)} with ${intArg(call.args, 3)} decimals, not ${expectation.score}`,
        );
      }
      return;
  }
}

/** The metadata keys `register_full` carries, and nothing else. */
const registrationKeys = [
  'id',
  'name',
  'description',
  'skills',
  'priceUsdcStroops',
  'model',
  'puls3.manifestVersion',
  'manifestHash',
] as const;

/**
 * `register_full(caller, agent_uri, metadata)`: the metadata is the draft's,
 * and the URI is the registration file of the manifest hash it carries
 * (`<origin>/registry/<hex>`). The hash itself is not recomputed: that
 * would mean reproducing the server's JSON encoding of the manifest, so it
 * is tied to the URI instead, and every field it covers is compared.
 */
function checkRegistration(
  call: ContractCall,
  expected: RegistrationExpectation,
  origin: string | null,
): void {
  if (call.args.length !== 3) refuse('call', 'register_full does not have 3 arguments');
  const uri = stringArg(call.args, 1);
  const metadata = call.args[2]!;
  if (metadata.switch().name !== 'scvVec') refuse('call', 'register_full has no metadata list');
  const entries = new Map<string, Buffer>();
  for (const item of metadata.vec() ?? []) {
    if (item.switch().name !== 'scvMap') refuse('call', 'a metadata entry is not a map');
    const fields = new Map(
      (item.map() ?? []).map((e) => [e.key().switch().name === 'scvSymbol' ? e.key().sym().toString() : '', e.val()]),
    );
    const key = fields.get('key');
    const value = fields.get('value');
    if (key?.switch().name !== 'scvString' || value?.switch().name !== 'scvBytes') {
      refuse('call', 'a metadata entry is not a key and its bytes');
    }
    const name = key.str().toString();
    if (entries.has(name)) refuse('call', `the metadata repeats "${name}"`);
    entries.set(name, Buffer.from(value.bytes()));
  }
  const keys = [...entries.keys()].sort();
  if (keys.join('\n') !== [...registrationKeys].sort().join('\n')) {
    refuse('call', `the metadata has the keys ${keys.join(', ')}, not the draft's`);
  }
  const text = (key: string) => entries.get(key)!.toString('utf8');
  const same = (key: string, value: string) => {
    if (text(key).trim() !== value.trim()) {
      refuse('call', `the registered ${key} is not the draft's`);
    }
  };
  same('id', expected.catalogId);
  same('name', expected.name);
  same('description', expected.description);
  same('priceUsdcStroops', expected.priceUsdcStroops);
  same('model', expected.model);
  let skills: unknown;
  try {
    skills = JSON.parse(text('skills'));
  } catch {
    refuse('call', 'the registered skills are not a list');
  }
  if (!Array.isArray(skills) || skills.join('\n') !== expected.skills.join('\n')) {
    refuse('call', "the registered skills are not the draft's");
  }
  if (!/^[1-9][0-9]*$/.test(text('puls3.manifestVersion'))) {
    refuse('call', 'the registered manifest version is not a version number');
  }
  const hash = entries.get('manifestHash')!;
  if (hash.length !== 32) refuse('call', 'the manifest hash is not 32 bytes');
  const path = /\/registry\/([0-9a-f]{64})$/.exec(uri);
  if (path === null || path[1] !== hash.toString('hex')) {
    refuse('call', "the agent URI is not the registration file of the manifest it registers");
  }
  if (origin !== null && uri !== `${origin}/registry/${path[1]}`) {
    refuse('call', `the agent URI is not on the registration origin ${origin}`);
  }
}

/** `job_id` (argument 1) is the job of the hire the flow works on. */
function expectJob(call: ContractCall, jobId: bigint): void {
  if (intArg(call.args, 1) !== jobId) {
    refuse('call', `${call.fn} is for job ${intArg(call.args, 1)}, not ${jobId}`);
  }
}

/** `fund(caller, job_id, expected_budget, max_fee_bps)` or `fund_with_reserve(caller, job_id, expected_budget, reserve, max_fee_bps)`. */
function fundAmounts(call: ContractCall): { budget: bigint; reserve: bigint } {
  if (call.fn === 'fund') {
    if (call.args.length !== 4) refuse('call', 'fund does not have 4 arguments');
    return { budget: intArg(call.args, 2), reserve: 0n };
  }
  if (call.args.length !== 5) refuse('call', 'fund_with_reserve does not have 5 arguments');
  return { budget: intArg(call.args, 2), reserve: intArg(call.args, 3) };
}

/**
 * Only `fund` may authorize a nested call, and only the USDC transfer of
 * exactly the budget and reserve from the signer to the escrow.
 */
function checkSubInvocations(
  subs: xdr.SorobanAuthorizedInvocation[],
  call: ContractCall,
  expectation: Expectation,
  signer: string,
  network: Puls3Network,
): void {
  if (subs.length === 0) return;
  if (expectation.purpose !== 'fund' || subs.length !== 1) {
    refuse('money', `${call.fn} authorizes a further call`);
  }
  const sub = subs[0]!;
  const transfer = authorizedCall(sub.function()) ?? refuse('money', 'fund authorizes a non-contract call');
  if (transfer.contract !== network.usdc || transfer.fn !== 'transfer') {
    refuse('money', `fund authorizes ${transfer.fn} on ${transfer.contract}, not a USDC transfer`);
  }
  if (transfer.args.length !== 3) refuse('money', 'the transfer does not have 3 arguments');
  const { budget, reserve } = fundAmounts(call);
  if (addressArg(transfer.args, 0) !== signer) refuse('money', 'the transfer is not from the signer');
  if (addressArg(transfer.args, 1) !== network.escrow) refuse('money', 'the transfer is not to the escrow');
  if (intArg(transfer.args, 2) !== budget + reserve) {
    refuse('money', `the transfer moves ${intArg(transfer.args, 2)}, not the budget and reserve ${budget + reserve}`);
  }
  if (sub.subInvocations().length !== 0) refuse('money', 'the transfer authorizes a further call');
}

function readTransaction(
  envelope: string,
  passphrase: string,
  rule: 'call' | 'login',
): Transaction {
  let tx: Transaction | FeeBumpTransaction;
  try {
    tx = TransactionBuilder.fromXDR(envelope, passphrase);
  } catch {
    refuse(rule, 'the transaction cannot be read');
  }
  if (tx instanceof FeeBumpTransaction) refuse(rule, 'a fee-bump transaction');
  return tx;
}

function invokedCall(fn: xdr.HostFunction): ContractCall | null {
  if (fn.switch().name !== 'hostFunctionTypeInvokeContract') return null;
  return contractArgs(fn.invokeContract());
}

function authorizedCall(fn: xdr.SorobanAuthorizedFunction): ContractCall | null {
  if (fn.switch().name !== 'sorobanAuthorizedFunctionTypeContractFn') return null;
  return contractArgs(fn.contractFn());
}

function contractArgs(call: xdr.InvokeContractArgs): ContractCall {
  return {
    contract: Address.fromScAddress(call.contractAddress()).toString(),
    fn: call.functionName().toString(),
    args: call.args(),
  };
}

function sameArgs(a: xdr.ScVal[], b: xdr.ScVal[]): boolean {
  return a.length === b.length && a.every((v, i) => v.toXDR('base64') === b[i]!.toXDR('base64'));
}

function bytesArg(args: xdr.ScVal[], index: number): Buffer {
  const value = args[index];
  if (value === undefined || value.switch().name !== 'scvBytes') {
    refuse('call', `argument ${index} is not bytes`);
  }
  return Buffer.from(value.bytes());
}

function stringArg(args: xdr.ScVal[], index: number): string {
  const value = args[index];
  if (value === undefined || value.switch().name !== 'scvString') {
    refuse('call', `argument ${index} is not a string`);
  }
  return value.str().toString();
}

function addressArg(args: xdr.ScVal[], index: number): string {
  const value = args[index];
  if (value === undefined || value.switch().name !== 'scvAddress') {
    refuse('call', `argument ${index} is not an address`);
  }
  return Address.fromScVal(value).toString();
}

const integerTypes = new Set(['scvU32', 'scvI32', 'scvU64', 'scvI64', 'scvU128', 'scvI128']);

function intArg(args: xdr.ScVal[], index: number): bigint {
  const value = args[index];
  if (value === undefined || !integerTypes.has(value.switch().name)) {
    refuse('call', `argument ${index} is not an integer`);
  }
  return BigInt(scValToNative(value) as number | bigint);
}

function safeVerify(key: Keypair, hash: Buffer, signature: Buffer): boolean {
  try {
    return key.verify(hash, signature);
  } catch {
    return false;
  }
}
