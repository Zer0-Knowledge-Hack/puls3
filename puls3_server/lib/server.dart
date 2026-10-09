import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';

import 'src/auth/wallet_auth_config.dart';
import 'src/chain/chain_tracker_wiring.dart';
import 'src/cors/allowed_origins.dart';
import 'src/generated/endpoints.dart';
import 'src/generated/protocol.dart';
import 'src/health/health_endpoint.dart';
import 'src/runtime/agent_runtime_wiring.dart';
import 'src/web/routes/app_config_route.dart';
import 'src/web/routes/root.dart';

/// The starting point of the Serverpod server.
void run(List<String> args) async {
  // Initialize Serverpod and connect it with your generated code.
  final pod = Serverpod(args, Protocol(), Endpoints());

  // Resolve the reported version now, so an invalid PULS3_GIT_SHA stops the
  // server at startup instead of failing the first health call.
  stdout.writeln('puls3 server version ${HealthEndpoint.appVersion}');

  // Only the origins in PULS3_ALLOWED_ORIGINS (plus loopback in development)
  // may call the API server from a browser (see README). An invalid list
  // stops startup.
  pod.server.addMiddleware(
    originGateFromEnvironment(
      Platform.environment,
      runMode: pod.runMode,
      log: stdout.writeln,
    ),
  );

  // JWT sessions. Wallet sign-in issues them; there is no email identity provider.
  pod.initializeAuthServices(
    tokenManagerBuilders: [
      // Use JWT for authentication keys towards the server.
      JwtConfigFromPasswords(),
    ],
  );

  // Setup a default page at the web root.
  // These are used by the default page.
  pod.webServer.addRoute(RootRoute(), '/');
  pod.webServer.addRoute(RootRoute(), '/index.html');

  // Serve all files in the web/static relative directory under /.
  // These are used by the default web page.
  final root = Directory(Uri(path: 'web/static').toFilePath());
  pod.webServer.addRoute(StaticRoute.directory(root));

  // Setup the app config route.
  // We build this configuration based on the servers api url and serve it to
  // the flutter app.
  pod.webServer.addRoute(
    AppConfigRoute(
      apiConfig: pod.config.apiServer,
      auth: publishedAuth(
        environment: Platform.environment,
        signingKey: pod.getPassword('walletAuthSigningKey'),
        runMode: pod.runMode,
      ),
    ),
    '/app/assets/assets/config.json',
  );

  // Checks if the flutter web app has been built and serves it if it has.
  final appDir = Directory(Uri(path: 'web/app').toFilePath());
  if (appDir.existsSync()) {
    // Serve the flutter web app under the /app path.
    pod.webServer.addRoute(
      FlutterRoute(
        Directory(
          Uri(path: 'web/app').toFilePath(),
        ),
      ),
      '/app',
    );
  } else {
    // If the flutter web app has not been built, serve the build app page.
    pod.webServer.addRoute(
      StaticRoute.file(
        File(
          Uri(path: 'web/pages/build_flutter_app.html').toFilePath(),
        ),
      ),
      '/app/**',
    );
  }

  // Start the server.
  // A missing SEP-10 signing key or auth domain stops production before any
  // endpoint is served. Other run modes stay up and fail the challenge call.
  WalletAuthConfig.ensureProduction(
    Platform.environment,
    signingKey: pod.getPassword('walletAuthSigningKey'),
    runMode: pod.runMode,
  );
  await pod.start();

  // Track relay submissions until they are final, when
  // PULS3_TRACKER_ENABLED=true (see README). Serverpod runs shutdown tasks on
  // SIGINT/SIGTERM after it stops taking requests and before it closes the
  // database, so the pass in flight can finish.
  final tracker = startChainTracker(pod, Platform.environment);
  if (tracker != null) {
    pod.experimental.shutdownTasks.addTask('chain-tracker', tracker.stop);
  }

  // Run the agent of every funded hire, when PULS3_RUNTIME_ENABLED=true and
  // at least one model provider has credentials (#20, see README).
  final runtime = startAgentRuntime(pod, Platform.environment);
  if (runtime != null) {
    pod.experimental.shutdownTasks.addTask('agent-runtime', runtime.stop);
  }
}
