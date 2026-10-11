import 'package:flutter/material.dart';
import 'package:puls3_domain/puls3_domain.dart' show AgentManifestDraft;

import '../domain/agent_draft.dart';
import '../state/app_scope.dart';
import '../studio/studio_gateway.dart';
import '../studio/studio_models.dart';
import 'deploy_sheet.dart';

/// Opens the deploy sheet (S08) for a deployable [manifest], from the
/// Studio or from "Resume deploy" in My agents. When it was saved as
/// [draftId] by [owner], the draft is recorded as live once the agent is.
Future<void> deployStudioManifest(
  BuildContext context,
  AgentManifestDraft manifest, {
  int? draftId,
  String? owner,
}) {
  final gateway = AppScope.of(context).studioGateway;
  return showDeploySheet(
    context,
    agentDraftFor(manifest),
    onLive: draftId == null || owner == null
        ? null
        : (result) => gateway.recordDeploy(
            draftId,
            owner: owner,
            state: DraftDeployState.live,
            // A demo deploy is not in the catalog: nothing to view.
            agentId: result.isDemo ? null : '${result.agentId}',
          ),
  );
}

/// The deploy flow's snapshot of a deployable [manifest].
AgentDraft agentDraftFor(AgentManifestDraft manifest) {
  final model = manifest.model;
  final option = model == null
      ? null
      : studioModelOptions
            .where((o) => o.provider == model.provider && o.id == model.id)
            .firstOrNull;
  return AgentDraft(
    name: manifest.name ?? '',
    description: manifest.description ?? '',
    model: option?.label ?? model?.id ?? '',
    systemPrompt: manifest.systemPrompt ?? '',
    skills: [for (final s in manifest.skills ?? const []) s.name],
    priceUsdcStroops: manifest.price?.stroops ?? 0,
  );
}
