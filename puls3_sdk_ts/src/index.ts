/**
 * TypeScript SDK for the puls3 API (#302): the agent catalog, hires and the
 * Agent Studio. This version reads and prepares; it never signs or submits a
 * transaction.
 */

export { Puls3Sdk, formatUsdc, type ConnectOptions } from './sdk.js';
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
} from './errors.js';
export type {
  AgentHireStarted,
  AgentManifestDraft,
  AgentSummary,
  ChainSubmission,
  CreateHireResult,
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
} from './models.js';
