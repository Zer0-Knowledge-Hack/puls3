import 'dart:convert';
import 'dart:io';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:serverpod/serverpod.dart';

import '../agent/hidden_agents.dart';
import 'registration_document.dart';
import 'serverpod_studio_agent_version_store.dart';
import 'serverpod_studio_deploy_store.dart';
import 'studio_model_policy.dart';

/// `GET /registry/<hash>` serves the public registration file.
///
/// The hash is the manifest hash in the on-chain URI. The prompt is not
/// in the document. An agent in `PULS3_HIDDEN_AGENT_IDS` is not served (404),
/// so a hidden agent's public file disappears with it from the catalog.
class RegistrationRoute extends WidgetRoute {
  /// Reads the hide list from [environment], the process environment when
  /// omitted. It is read per request, not here, so a malformed list fails
  /// this route instead of stopping the server at startup.
  RegistrationRoute({Map<String, String>? environment})
    : _environment = environment;

  final Map<String, String>? _environment;

  @override
  Future<WebWidget?> build(Session session, Request request) async {
    final segments = request.url.pathSegments;
    if (segments.length < 2 || segments[segments.length - 2] != 'registry') {
      return null;
    }
    final hash = segments.last;
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) return null;
    final row = await ServerpodStudioDeployStore(
      session,
    ).findByManifestHash(hash);
    if (row == null) return null;
    final hidden = HiddenAgents.fromEnvironment(
      _environment ?? Platform.environment,
    );
    if (hidden.contains(row.registryAgentId)) return null;
    final latest = row.registryAgentId == null
        ? null
        : await ServerpodStudioAgentVersionStore(
            session,
          ).latest(row.registryAgentId!);
    final raw =
        latest?.manifestJson ??
        (row.state == 'active' ? row.manifestJson : null);
    if (raw == null) return null;
    final AgentManifest manifest;
    try {
      manifest = AgentManifestDraft.fromJson(jsonDecode(raw)).validate(
        studioServerModelPolicy,
        ManifestVersion(latest?.version ?? ManifestVersion.first.value),
      );
    } on InvalidManifest {
      return null;
    } on FormatException {
      return null;
    }
    final document = registrationDocument(manifest);
    if (jsonEncode(document).contains(manifest.systemPrompt)) return null;
    return JsonWidget(object: document);
  }
}
