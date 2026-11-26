/**
 * TypeScript SDK for the puls3 API (#302): the agent catalog, hires and the
 * Agent Studio. With a signer it deploys agents and pays hires on testnet,
 * signing only what passes the checks of ADR-0010.
 */

export { Puls3Sdk, formatUsdc, type ConnectOptions, type Reviewed, type SdkOptions } from './sdk.js';
export { KeySession } from './key_session.js';
export { SorobanRpcReader, type ChainReader } from './chain_reader.js';
export { TESTNET, withNetwork, type Puls3Network } from './network.js';
export {
  keypairSigner,
  keypairSignerFromEnvironment,
  secretKeyVariable,
  type Puls3Signer,
} from './signer.js';
export {
  checkChallenge,
  checkPreparedAuthorization,
  checkPreparedTransaction,
  type Expectation,
  type WalletAuthorizationExpectation,
} from './guard.js';
export {
  CliSession,
  defaultSessionFile,
  refreshTokenVariable,
  sessionFileVariable,
  type RefreshCall,
  type RefreshedTokens,
} from './session.js';
export {
  HttpTransport,
  normalizeApiUrl,
  type AuthProvider,
  type HttpTransportOptions,
  type RefreshResult,
  type Transport,
} from './transport.js';
export {
  InvalidArgument,
  Puls3ApiError,
  Puls3HttpError,
  Puls3NetworkError,
  Puls3ProtocolError,
  SessionRequired,
  SignerRequired,
  SigningRefused,
  Puls3Timeout,
  ChainSubmissionFailed,
} from './errors.js';
export type {
  AgentHireStarted,
  AgentManifestDraft,
  AgentSummary,
  ChainSubmission,
  CreateHireResult,
  DeploySession,
  Hire,
  HireDetail,
  HireSummary,
  ManifestModel,
  ManifestPrice,
  ManifestSkill,
  Payment,
  PreparedTransaction,
  StudioDraft,
  TestRunResult,
  WalletChallenge,
} from './models.js';
