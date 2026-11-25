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
      /** The highest job budget, in USDC stroops. */
      maxBudget: bigint;
    }
  | {
      purpose: 'fund';
      /** The highest budget `fund` may pull, in USDC stroops. */
      maxBudget: bigint;
      /** The highest subcontract reserve it may pull on top. 0 by default. */
      maxReserve: bigint;
    }
  | { purpose: 'complete' }
  | { purpose: 'reject' }
  | { purpose: 'registerFull' }
  | { purpose: 'giveFeedback' };

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
 */
export function checkPreparedAuthorization(
  prepared: PreparedTransaction,
  expectation: WalletAuthorizationExpectation,
  signer: string,
  network: Puls3Network,
  now: Date = new Date(),
): { entryXdr: string; validUntilLedger: number } {
  checkPreparation(prepared, 'setAgentWallet', signer, network, now);
  const entryXdr =
    prepared.authorizationEntryXdr ?? refuse('call', 'the preparation has no authorization entry');
  const validUntilLedger = prepared.signatureExpirationLedger;
  if (validUntilLedger === null || validUntilLedger <= 0) {
    refuse('bounds', 'the authorization has no expiration ledger');
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
 * Checks a SEP-10 login challenge (D3 rule 6) and returns its envelope. It
 * must be a challenge for the signer that no network accepts as a payment:
 * sequence 0, from another account, with `manage_data` operations only.
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
  if (tx.operations.length === 0) refuse('login', 'the challenge has no operations');
  tx.operations.forEach((operation, index) => {
    if (operation.type !== 'manageData') {
      refuse('login', `operation ${index} is ${operation.type}, not manage_data`);
    }
    if (index === 0) {
      if (operation.source !== signer) refuse('login', 'the first operation is not for the signer');
      const name = network.homeDomain === null ? null : `${network.homeDomain} auth`;
      if (name === null ? !operation.name.endsWith(' auth') : operation.name !== name) {
        refuse('login', `the first operation is "${operation.name}", not the home domain's auth`);
      }
    } else if (operation.source !== tx.source) {
      refuse('login', `operation ${index} acts for another account`);
    }
  });
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
      if (addressArg(call.args, 2) !== signer) {
        refuse('money', 'the job would be judged by another account than the signer');
      }
      if (addressArg(call.args, 7) !== network.usdc) refuse('money', 'the job is not paid in USDC');
      const budget = intArg(call.args, 8);
      if (budget <= 0n || budget > expectation.maxBudget) {
        refuse('money', `the budget ${budget} is above the allowed ${expectation.maxBudget}`);
      }
      return;
    }
    case 'fund': {
      expectCall(network.escrow, 'escrow', ['fund', 'fund_with_reserve']);
      const { budget, reserve } = fundAmounts(call);
      if (budget <= 0n || budget > expectation.maxBudget) {
        refuse('money', `fund pulls ${budget}, above the allowed ${expectation.maxBudget}`);
      }
      if (reserve < 0n || reserve > expectation.maxReserve) {
        refuse('money', `fund pulls a reserve of ${reserve}, above the allowed ${expectation.maxReserve}`);
      }
      return;
    }
    case 'complete':
    case 'reject':
      expectCall(network.escrow, 'escrow', [expectation.purpose]);
      return;
    case 'registerFull':
      expectCall(network.identityRegistry, 'Identity Registry', ['register_full']);
      return;
    case 'giveFeedback':
      expectCall(network.reputationRegistry, 'Reputation Registry', ['give_feedback']);
      return;
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
