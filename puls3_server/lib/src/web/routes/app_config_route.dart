import 'package:serverpod/serverpod.dart';

import '../../auth/wallet_auth_config.dart';
import '../../generated/protocol.dart';

/// Public SEP-10 values the web client reads from `config.json`.
///
/// [serverSigningKey] is the account address (`G…`). The `S…` secret never
/// enters this object.
class AppAuthPublication {
  AppAuthPublication({
    required this.serverSigningKey,
    required this.homeDomain,
    required this.webAuthDomain,
    required this.networkPassphrase,
  }) {
    if (!serverSigningKey.startsWith('G')) {
      throw ArgumentError(
        'auth.serverSigningKey must be a Stellar public address',
      );
    }
  }

  factory AppAuthPublication.fromConfig(WalletAuthConfig config) {
    return AppAuthPublication(
      serverSigningKey: config.serverAccount,
      homeDomain: config.homeDomain,
      webAuthDomain: config.webAuthDomain,
      networkPassphrase: config.networkPassphrase,
    );
  }

  final String serverSigningKey;
  final String homeDomain;
  final String webAuthDomain;
  final String networkPassphrase;

  Map<String, String> toJson() => {
    'serverSigningKey': serverSigningKey,
    'homeDomain': homeDomain,
    'webAuthDomain': webAuthDomain,
    'networkPassphrase': networkPassphrase,
  };
}

/// The auth block when wallet auth is configured, or null when this run mode
/// is allowed to boot without it. Production still fails closed in
/// [WalletAuthConfig.ensureProduction].
AppAuthPublication? publishedAuth({
  required Map<String, String> environment,
  required String? signingKey,
  required String runMode,
}) {
  try {
    return AppAuthPublication.fromConfig(
      WalletAuthConfig.fromEnvironment(
        environment,
        signingKey: signingKey,
        runMode: runMode,
      ),
    );
  } on Puls3ApiException {
    return null;
  }
}

class AppConfigWidget extends JsonWidget {
  AppConfigWidget({
    required String apiUrl,
    AppAuthPublication? auth,
  }) : super(
         object: {
           'apiUrl': apiUrl,
           if (auth != null) 'auth': auth.toJson(),
         },
       );
}

class AppConfigRoute extends WidgetRoute {
  AppConfigWidget widget;

  AppConfigRoute({
    required final ServerConfig apiConfig,
    AppAuthPublication? auth,
  }) : widget = AppConfigWidget(
         apiUrl: apiConfig.apiUrl.toString(),
         auth: auth,
       );

  @override
  Future<WebWidget> build(Session session, Request request) async {
    return widget;
  }
}

extension on ServerConfig {
  Uri get apiUrl => Uri(
    scheme: publicScheme,
    host: publicHost,
    port: publicPort,
  );
}
