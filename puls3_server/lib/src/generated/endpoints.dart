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
import 'package:serverpod/serverpod.dart' as _is;
import 'package:serverpod_auth_core_server/serverpod_auth_core_server.dart'
    as _iacs;
import 'package:serverpod_auth_idp_server/serverpod_auth_idp_server.dart'
    as _iais;
import '../agent/agent_endpoint.dart' as _i6aufbii;
import '../auth/jwt_refresh_endpoint.dart' as _inwq3ztq;
import '../auth/wallet_auth_endpoint.dart' as _i3i6b0lz;
import '../greetings/greeting_endpoint.dart' as _il624ik7;
import '../health/health_endpoint.dart' as _id9paj9q;
import '../hire/hire_endpoint.dart' as _icdhibuq;

class Endpoints extends _is.EndpointDispatch {
  @override
  void initializeEndpoints(_is.Server server) {
    var endpoints = <String, _is.Endpoint>{
      'agent': _i6aufbii.AgentEndpoint()
        ..initialize(
          server,
          'agent',
          null,
        ),
      'jwtRefresh': _inwq3ztq.JwtRefreshEndpoint()
        ..initialize(
          server,
          'jwtRefresh',
          null,
        ),
      'walletAuth': _i3i6b0lz.WalletAuthEndpoint()
        ..initialize(
          server,
          'walletAuth',
          null,
        ),
      'greeting': _il624ik7.GreetingEndpoint()
        ..initialize(
          server,
          'greeting',
          null,
        ),
      'health': _id9paj9q.HealthEndpoint()
        ..initialize(
          server,
          'health',
          null,
        ),
      'hire': _icdhibuq.HireEndpoint()
        ..initialize(
          server,
          'hire',
          null,
        ),
    };
    connectors['agent'] = _is.EndpointConnector(
      name: 'agent',
      endpoint: endpoints['agent']!,
      methodConnectors: {
        'list': _is.MethodConnector(
          name: 'list',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['agent'] as _i6aufbii.AgentEndpoint).list(session),
        ),
        'get': _is.MethodConnector(
          name: 'get',
          params: {
            'id': _is.ParameterDescription(
              name: 'id',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['agent'] as _i6aufbii.AgentEndpoint).get(
                session,
                params['id'],
              ),
        ),
      },
    );
    connectors['jwtRefresh'] = _is.EndpointConnector(
      name: 'jwtRefresh',
      endpoint: endpoints['jwtRefresh']!,
      methodConnectors: {
        'refreshAccessToken': _is.MethodConnector(
          name: 'refreshAccessToken',
          params: {
            'refreshToken': _is.ParameterDescription(
              name: 'refreshToken',
              type: _is.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['jwtRefresh'] as _inwq3ztq.JwtRefreshEndpoint)
                      .refreshAccessToken(
                        session,
                        refreshToken: params['refreshToken'],
                      ),
        ),
      },
    );
    connectors['walletAuth'] = _is.EndpointConnector(
      name: 'walletAuth',
      endpoint: endpoints['walletAuth']!,
      methodConnectors: {
        'createChallenge': _is.MethodConnector(
          name: 'createChallenge',
          params: {
            'wallet': _is.ParameterDescription(
              name: 'wallet',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['walletAuth'] as _i3i6b0lz.WalletAuthEndpoint)
                      .createChallenge(
                        session,
                        params['wallet'],
                      ),
        ),
        'verifyChallenge': _is.MethodConnector(
          name: 'verifyChallenge',
          params: {
            'challengeId': _is.ParameterDescription(
              name: 'challengeId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'wallet': _is.ParameterDescription(
              name: 'wallet',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'signedChallengeXdr': _is.ParameterDescription(
              name: 'signedChallengeXdr',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['walletAuth'] as _i3i6b0lz.WalletAuthEndpoint)
                      .verifyChallenge(
                        session,
                        params['challengeId'],
                        params['wallet'],
                        params['signedChallengeXdr'],
                      ),
        ),
      },
    );
    connectors['greeting'] = _is.EndpointConnector(
      name: 'greeting',
      endpoint: endpoints['greeting']!,
      methodConnectors: {
        'hello': _is.MethodConnector(
          name: 'hello',
          params: {
            'name': _is.ParameterDescription(
              name: 'name',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['greeting'] as _il624ik7.GreetingEndpoint).hello(
                    session,
                    params['name'],
                  ),
        ),
      },
    );
    connectors['health'] = _is.EndpointConnector(
      name: 'health',
      endpoint: endpoints['health']!,
      methodConnectors: {
        'check': _is.MethodConnector(
          name: 'check',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['health'] as _id9paj9q.HealthEndpoint)
                  .check(session),
        ),
      },
    );
    connectors['hire'] = _is.EndpointConnector(
      name: 'hire',
      endpoint: endpoints['hire']!,
      methodConnectors: {
        'createHire': _is.MethodConnector(
          name: 'createHire',
          params: {
            'agentId': _is.ParameterDescription(
              name: 'agentId',
              type: _is.getType<int>(),
              nullable: false,
            ),
            'consumer': _is.ParameterDescription(
              name: 'consumer',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'input': _is.ParameterDescription(
              name: 'input',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'requestId': _is.ParameterDescription(
              name: 'requestId',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['hire'] as _icdhibuq.HireEndpoint).createHire(
                    session,
                    params['agentId'],
                    params['consumer'],
                    params['input'],
                    params['requestId'],
                  ),
        ),
        'prepareCreateJob': _is.MethodConnector(
          name: 'prepareCreateJob',
          params: {
            'hireId': _is.ParameterDescription(
              name: 'hireId',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['hire'] as _icdhibuq.HireEndpoint)
                  .prepareCreateJob(
                    session,
                    params['hireId'],
                  ),
        ),
        'prepareFund': _is.MethodConnector(
          name: 'prepareFund',
          params: {
            'hireId': _is.ParameterDescription(
              name: 'hireId',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['hire'] as _icdhibuq.HireEndpoint).prepareFund(
                    session,
                    params['hireId'],
                  ),
        ),
        'prepareComplete': _is.MethodConnector(
          name: 'prepareComplete',
          params: {
            'hireId': _is.ParameterDescription(
              name: 'hireId',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['hire'] as _icdhibuq.HireEndpoint).prepareComplete(
                    session,
                    params['hireId'],
                  ),
        ),
        'prepareReject': _is.MethodConnector(
          name: 'prepareReject',
          params: {
            'hireId': _is.ParameterDescription(
              name: 'hireId',
              type: _is.getType<int>(),
              nullable: false,
            ),
            'reason': _is.ParameterDescription(
              name: 'reason',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['hire'] as _icdhibuq.HireEndpoint).prepareReject(
                    session,
                    params['hireId'],
                    params['reason'],
                  ),
        ),
        'submitEscrowCall': _is.MethodConnector(
          name: 'submitEscrowCall',
          params: {
            'hireId': _is.ParameterDescription(
              name: 'hireId',
              type: _is.getType<int>(),
              nullable: false,
            ),
            'preparationId': _is.ParameterDescription(
              name: 'preparationId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'signedTransactionXdr': _is.ParameterDescription(
              name: 'signedTransactionXdr',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['hire'] as _icdhibuq.HireEndpoint)
                  .submitEscrowCall(
                    session,
                    params['hireId'],
                    params['preparationId'],
                    params['signedTransactionXdr'],
                  ),
        ),
      },
    );
    modules['serverpod_auth_idp'] = _iais.Endpoints()
      ..initializeEndpoints(server);
    modules['serverpod_auth_core'] = _iacs.Endpoints()
      ..initializeEndpoints(server);
  }
}
