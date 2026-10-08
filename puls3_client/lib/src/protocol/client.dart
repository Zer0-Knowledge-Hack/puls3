/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _ida;
import 'package:http/http.dart' as _i85jenna;
import 'package:puls3_client/src/protocol/agent/agent_summary.dart'
    as _i78wn19p;
import 'package:puls3_client/src/protocol/create_hire_result.dart' as _iyigzt6l;
import 'package:puls3_client/src/protocol/greetings/greeting.dart' as _igee0kk1;
import 'package:puls3_client/src/protocol/health/backend_health.dart'
    as _iur07860;
import 'package:puls3_client/src/protocol/hire_detail.dart' as _iytku71p;
import 'package:puls3_client/src/protocol/prepared_transaction.dart'
    as _iy6q6dct;
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    as _iacc;
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart'
    as _iaic;
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import 'protocol.dart' as _il2as5qe;

/// Serves the agent catalog read from the on-chain identity registry.
///
/// It only delegates to [AgentCatalogService], which owns caching and the
/// outage policy. When the chain cannot be read and nothing is cached, `list`
/// and `get` throw [AgentCatalogUnavailable] instead of answering with an
/// empty catalog or `null`.
/// {@category Endpoint}
class EndpointAgent extends _isc.EndpointRef {
  EndpointAgent(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'agent';

  /// Every agent registered on chain with valid metadata, oldest first.
  _ida.Future<List<_i78wn19p.AgentSummary>> list() =>
      caller.callServerEndpoint<List<_i78wn19p.AgentSummary>>(
        'agent',
        'list',
        {},
      );

  /// The agent with the metadata id [id], or `null` when there is none.
  _ida.Future<_i78wn19p.AgentSummary?> get(String id) =>
      caller.callServerEndpoint<_i78wn19p.AgentSummary?>(
        'agent',
        'get',
        {'id': id},
      );
}

/// By extending [EmailIdpBaseEndpoint], the email identity provider endpoints
/// are made available on the server and enable the corresponding sign-in widget
/// on the client.
/// {@category Endpoint}
class EndpointEmailIdp extends _iaic.EndpointEmailIdpBase {
  EndpointEmailIdp(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'emailIdp';

  /// Logs in the user and returns a new session.
  ///
  /// Throws an [EmailAccountLoginException] in case of errors, with reason:
  /// - [EmailAccountLoginExceptionReason.invalidCredentials] if the email or
  ///   password is incorrect.
  /// - [EmailAccountLoginExceptionReason.tooManyAttempts] if there have been
  ///   too many failed login attempts.
  ///
  /// Throws an [AuthUserBlockedException] if the auth user is blocked.
  @override
  _ida.Future<_iacc.AuthSuccess> login({
    required String email,
    required String password,
  }) => caller.callServerEndpoint<_iacc.AuthSuccess>(
    'emailIdp',
    'login',
    {
      'email': email,
      'password': password,
    },
  );

  /// Starts the registration for a new user account with an email-based login
  /// associated to it.
  ///
  /// Upon successful completion of this method, an email will have been
  /// sent to [email] with a verification link, which the user must open to
  /// complete the registration.
  ///
  /// Always returns a account request ID, which can be used to complete the
  /// registration. If the email is already registered, the returned ID will not
  /// be valid.
  @override
  _ida.Future<_isc.UuidValue> startRegistration({required String email}) =>
      caller.callServerEndpoint<_isc.UuidValue>(
        'emailIdp',
        'startRegistration',
        {'email': email},
      );

  /// Verifies an account request code and returns a token
  /// that can be used to complete the account creation.
  ///
  /// Throws an [EmailAccountRequestException] in case of errors, with reason:
  /// - [EmailAccountRequestExceptionReason.expired] if the account request has
  ///   already expired.
  /// - [EmailAccountRequestExceptionReason.policyViolation] if the password
  ///   does not comply with the password policy.
  /// - [EmailAccountRequestExceptionReason.invalid] if no request exists
  ///   for the given [accountRequestId] or [verificationCode] is invalid.
  @override
  _ida.Future<String> verifyRegistrationCode({
    required _isc.UuidValue accountRequestId,
    required String verificationCode,
  }) => caller.callServerEndpoint<String>(
    'emailIdp',
    'verifyRegistrationCode',
    {
      'accountRequestId': accountRequestId,
      'verificationCode': verificationCode,
    },
  );

  /// Completes a new account registration, creating a new auth user with a
  /// profile and attaching the given email account to it.
  ///
  /// Throws an [EmailAccountRequestException] in case of errors, with reason:
  /// - [EmailAccountRequestExceptionReason.expired] if the account request has
  ///   already expired.
  /// - [EmailAccountRequestExceptionReason.policyViolation] if the password
  ///   does not comply with the password policy.
  /// - [EmailAccountRequestExceptionReason.invalid] if the [registrationToken]
  ///   is invalid.
  ///
  /// Throws an [AuthUserBlockedException] if the auth user is blocked.
  ///
  /// Returns a session for the newly created user.
  @override
  _ida.Future<_iacc.AuthSuccess> finishRegistration({
    required String registrationToken,
    required String password,
  }) => caller.callServerEndpoint<_iacc.AuthSuccess>(
    'emailIdp',
    'finishRegistration',
    {
      'registrationToken': registrationToken,
      'password': password,
    },
  );

  /// Requests a password reset for [email].
  ///
  /// If the email address is registered, an email with reset instructions will
  /// be send out. If the email is unknown, this method will have no effect.
  ///
  /// Always returns a password reset request ID, which can be used to complete
  /// the reset. If the email is not registered, the returned ID will not be
  /// valid.
  ///
  /// Throws an [EmailAccountPasswordResetException] in case of errors, with reason:
  /// - [EmailAccountPasswordResetExceptionReason.tooManyAttempts] if the user has
  ///   made too many attempts trying to request a password reset.
  ///
  @override
  _ida.Future<_isc.UuidValue> startPasswordReset({required String email}) =>
      caller.callServerEndpoint<_isc.UuidValue>(
        'emailIdp',
        'startPasswordReset',
        {'email': email},
      );

  /// Verifies a password reset code and returns a finishPasswordResetToken
  /// that can be used to finish the password reset.
  ///
  /// Throws an [EmailAccountPasswordResetException] in case of errors, with reason:
  /// - [EmailAccountPasswordResetExceptionReason.expired] if the password reset
  ///   request has already expired.
  /// - [EmailAccountPasswordResetExceptionReason.tooManyAttempts] if the user has
  ///   made too many attempts trying to verify the password reset.
  /// - [EmailAccountPasswordResetExceptionReason.invalid] if no request exists
  ///   for the given [passwordResetRequestId] or [verificationCode] is invalid.
  ///
  /// If multiple steps are required to complete the password reset, this endpoint
  /// should be overridden to return credentials for the next step instead
  /// of the credentials for setting the password.
  @override
  _ida.Future<String> verifyPasswordResetCode({
    required _isc.UuidValue passwordResetRequestId,
    required String verificationCode,
  }) => caller.callServerEndpoint<String>(
    'emailIdp',
    'verifyPasswordResetCode',
    {
      'passwordResetRequestId': passwordResetRequestId,
      'verificationCode': verificationCode,
    },
  );

  /// Completes a password reset request by setting a new password.
  ///
  /// The [verificationCode] returned from [verifyPasswordResetCode] is used to
  /// validate the password reset request.
  ///
  /// Throws an [EmailAccountPasswordResetException] in case of errors, with reason:
  /// - [EmailAccountPasswordResetExceptionReason.expired] if the password reset
  ///   request has already expired.
  /// - [EmailAccountPasswordResetExceptionReason.policyViolation] if the new
  ///   password does not comply with the password policy.
  /// - [EmailAccountPasswordResetExceptionReason.invalid] if no request exists
  ///   for the given [passwordResetRequestId] or [verificationCode] is invalid.
  ///
  /// Throws an [AuthUserBlockedException] if the auth user is blocked.
  @override
  _ida.Future<void> finishPasswordReset({
    required String finishPasswordResetToken,
    required String newPassword,
  }) => caller.callServerEndpoint<void>(
    'emailIdp',
    'finishPasswordReset',
    {
      'finishPasswordResetToken': finishPasswordResetToken,
      'newPassword': newPassword,
    },
  );

  @override
  _ida.Future<bool> hasAccount() => caller.callServerEndpoint<bool>(
    'emailIdp',
    'hasAccount',
    {},
  );
}

/// By extending [RefreshJwtTokensEndpoint], the JWT token refresh endpoint
/// is made available on the server and enables automatic token refresh on the client.
/// {@category Endpoint}
class EndpointJwtRefresh extends _iacc.EndpointRefreshJwtTokens {
  EndpointJwtRefresh(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'jwtRefresh';

  /// Creates a new token pair for the given [refreshToken].
  ///
  /// If [refreshToken] is omitted, cookie-mode web clients fall back to the
  /// configured HttpOnly refresh cookie. When neither source is present this
  /// throws [RefreshTokenNotFoundException], the same public "no usable refresh
  /// credential" exception used for unknown refresh tokens.
  ///
  /// Can throw the following exceptions:
  /// -[RefreshTokenMalformedException]: refresh token is malformed and could
  ///   not be parsed. Not expected to happen for tokens issued by the server.
  /// -[RefreshTokenNotFoundException]: refresh token is unknown to the server.
  ///   Either the token was deleted or generated by a different server.
  /// -[RefreshTokenExpiredException]: refresh token has expired. Will happen
  ///   only if it has not been used within configured `refreshTokenLifetime`.
  /// -[RefreshTokenInvalidSecretException]: refresh token is incorrect, meaning
  ///   it does not refer to the current secret refresh token. This indicates
  ///   either a malfunctioning client or a malicious attempt by someone who has
  ///   obtained the refresh token. In this case the underlying refresh token
  ///   will be deleted, and access to it will expire fully when the last access
  ///   token is elapsed.
  ///
  /// This endpoint is unauthenticated, meaning the client won't include any
  /// authentication information with the call.
  @override
  _ida.Future<_iacc.AuthSuccess> refreshAccessToken({String? refreshToken}) =>
      caller.callServerEndpoint<_iacc.AuthSuccess>(
        'jwtRefresh',
        'refreshAccessToken',
        {'refreshToken': refreshToken},
        authenticated: false,
      );
}

/// This is an example endpoint that returns a greeting message through
/// its [hello] method.
/// {@category Endpoint}
class EndpointGreeting extends _isc.EndpointRef {
  EndpointGreeting(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'greeting';

  /// Returns a personalized greeting message: "Hello {name}".
  _ida.Future<_igee0kk1.Greeting> hello(String name) =>
      caller.callServerEndpoint<_igee0kk1.Greeting>(
        'greeting',
        'hello',
        {'name': name},
      );
}

/// Reports whether the backend is reachable and which app version it runs.
/// {@category Endpoint}
class EndpointHealth extends _isc.EndpointRef {
  EndpointHealth(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'health';

  /// Returns basic health information without requiring authentication.
  _ida.Future<_iur07860.BackendHealth> check() =>
      caller.callServerEndpoint<_iur07860.BackendHealth>(
        'health',
        'check',
        {},
      );
}

/// Creates hires and relays their escrow calls (api.md, `HireEndpoint`).
///
/// Every method first resolves the caller through [SessionWallet.requireLogin]
/// and only then builds the services, so a caller without a session reaches no
/// store and no chain. Wallet parameters must equal the session wallet
/// (`WalletMismatch`), and ownership of a hire is checked against the session
/// wallet by the services.
///
/// `listHires` is not part of this endpoint yet.
///
/// Follow-ups: `InputTooLong` has no documented limit, so the input length is
/// not checked here; `PersistenceUnavailable` is not mapped, so a database
/// failure surfaces as Serverpod's own internal error.
/// {@category Endpoint}
class EndpointHire extends _isc.EndpointRef {
  EndpointHire(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'hire';

  /// Creates the hire of [requestId] for [consumer] and prepares its
  /// `create_job`; repeating the request returns the same hire.
  _ida.Future<_iyigzt6l.CreateHireResult> createHire(
    int agentId,
    String consumer,
    String input,
    String requestId,
  ) => caller.callServerEndpoint<_iyigzt6l.CreateHireResult>(
    'hire',
    'createHire',
    {
      'agentId': agentId,
      'consumer': consumer,
      'input': input,
      'requestId': requestId,
    },
  );

  /// A fresh unsigned `create_job` for a hire that has no job yet.
  _ida.Future<_iy6q6dct.PreparedTransaction> prepareCreateJob(int hireId) =>
      caller.callServerEndpoint<_iy6q6dct.PreparedTransaction>(
        'hire',
        'prepareCreateJob',
        {'hireId': hireId},
      );

  /// The unsigned `fund` of an open hire.
  _ida.Future<_iy6q6dct.PreparedTransaction> prepareFund(int hireId) =>
      caller.callServerEndpoint<_iy6q6dct.PreparedTransaction>(
        'hire',
        'prepareFund',
        {'hireId': hireId},
      );

  /// The unsigned `complete` of a submitted hire.
  _ida.Future<_iy6q6dct.PreparedTransaction> prepareComplete(int hireId) =>
      caller.callServerEndpoint<_iy6q6dct.PreparedTransaction>(
        'hire',
        'prepareComplete',
        {'hireId': hireId},
      );

  /// The unsigned `reject` of a hire, with the consumer's [reason].
  _ida.Future<_iy6q6dct.PreparedTransaction> prepareReject(
    int hireId,
    String reason,
  ) => caller.callServerEndpoint<_iy6q6dct.PreparedTransaction>(
    'hire',
    'prepareReject',
    {
      'hireId': hireId,
      'reason': reason,
    },
  );

  /// The hire [hireId] as its [consumer] sees it: escrow status, run
  /// progress and result (F6). Read-only, so the app polls it.
  _ida.Future<_iytku71p.HireDetail> getHire(
    int hireId,
    String consumer,
  ) => caller.callServerEndpoint<_iytku71p.HireDetail>(
    'hire',
    'getHire',
    {
      'hireId': hireId,
      'consumer': consumer,
    },
  );

  /// Verifies the wallet-signed envelope of [preparationId] and relays it.
  _ida.Future<_iytku71p.HireDetail> submitEscrowCall(
    int hireId,
    String preparationId,
    String signedTransactionXdr,
  ) => caller.callServerEndpoint<_iytku71p.HireDetail>(
    'hire',
    'submitEscrowCall',
    {
      'hireId': hireId,
      'preparationId': preparationId,
      'signedTransactionXdr': signedTransactionXdr,
    },
  );
}

class Modules {
  Modules(Client client) {
    serverpod_auth_idp = _iaic.Caller(client);
    serverpod_auth_core = _iacc.Caller(client);
  }

  late final _iaic.Caller serverpod_auth_idp;

  late final _iacc.Caller serverpod_auth_core;
}

class Client extends _isc.ServerpodClientShared {
  Client(
    String host, {
    dynamic securityContext,
    Duration? streamingConnectionTimeout,
    Duration? connectionTimeout,
    Function(
      _isc.MethodCallContext,
      Object,
      StackTrace,
    )?
    onFailedCall,
    Function(_isc.MethodCallContext)? onSucceededCall,
    bool? disconnectStreamsOnLostInternetConnection,
    _i85jenna.Client? httpClientOverride,
  }) : super(
         host,
         _il2as5qe.Protocol(),
         securityContext: securityContext,
         streamingConnectionTimeout: streamingConnectionTimeout,
         connectionTimeout: connectionTimeout,
         onFailedCall: onFailedCall,
         onSucceededCall: onSucceededCall,
         disconnectStreamsOnLostInternetConnection:
             disconnectStreamsOnLostInternetConnection,
         httpClientOverride: httpClientOverride,
       ) {
    agent = EndpointAgent(this);
    emailIdp = EndpointEmailIdp(this);
    jwtRefresh = EndpointJwtRefresh(this);
    greeting = EndpointGreeting(this);
    health = EndpointHealth(this);
    hire = EndpointHire(this);
    modules = Modules(this);
  }

  late final EndpointAgent agent;

  late final EndpointEmailIdp emailIdp;

  late final EndpointJwtRefresh jwtRefresh;

  late final EndpointGreeting greeting;

  late final EndpointHealth health;

  late final EndpointHire hire;

  late final Modules modules;

  @override
  Map<String, _isc.EndpointRef> get endpointRefLookup => {
    'agent': agent,
    'emailIdp': emailIdp,
    'jwtRefresh': jwtRefresh,
    'greeting': greeting,
    'health': health,
    'hire': hire,
  };

  @override
  Map<String, _isc.ModuleEndpointCaller> get moduleLookup => {
    'serverpod_auth_idp': modules.serverpod_auth_idp,
    'serverpod_auth_core': modules.serverpod_auth_core,
  };
}
