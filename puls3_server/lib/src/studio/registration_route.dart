import 'dart:convert';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:serverpod/serverpod.dart';

import 'registration_document.dart';
import 'serverpod_studio_agent_version_store.dart';
import 'serverpod_studio_deploy_store.dart';
import 'studio_model_policy.dart';

/// `GET /registry/<hash>` serves the public registration file.
///
/// The hash is the manifest hash in the on-chain URI. The prompt is not
/// in the document.
class RegistrationRoute extends WidgetRoute {
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
