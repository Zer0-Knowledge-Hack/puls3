import 'package:puls3_domain/puls3_domain.dart' as domain;

import '../generated/protocol.dart';
import 'studio_draft_service.dart';

/// The domain wire document for [draft]. Null fields are omitted, matching
/// `AgentManifestDraft.toJson`.
Map<String, Object?> draftDocument(AgentManifestDraft draft) {
  final skills = draft.skills;
  final model = draft.model;
  final price = draft.price;
  return {
    'name': ?draft.name,
    'description': ?draft.description,
    if (skills != null)
      'skills': [
        for (final skill in skills)
          {
            'id': skill.id,
            'name': skill.name,
            'description': ?skill.description,
            if (skill.tags != null) 'tags': skill.tags,
          },
      ],
    if (model != null) 'model': {'provider': model.provider, 'id': model.id},
    'system_prompt': ?draft.systemPrompt,
    if (draft.inputType != null || draft.inputMaxChars != null)
      'input': {'type': ?draft.inputType, 'max_chars': ?draft.inputMaxChars},
    if (draft.outputType != null || draft.outputMaxChars != null)
      'output': {
        'type': ?draft.outputType,
        'max_chars': ?draft.outputMaxChars,
      },
    if (price != null) 'price': {'asset': price.asset, 'amount': price.amount},
  };
}

/// The transport draft for a domain manifest the caller is allowed to see.
AgentManifestDraft transportDraft(domain.AgentManifestDraft manifest) {
  final skills = manifest.skills;
  final model = manifest.model;
  final price = manifest.price;
  return AgentManifestDraft(
    name: manifest.name,
    description: manifest.description,
    skills: skills == null
        ? null
        : [
            for (final skill in skills)
              ManifestSkill(
                id: skill.id,
                name: skill.name,
                description: skill.description,
                tags: skill.tags,
              ),
          ],
    model: model == null
        ? null
        : ManifestModel(provider: model.provider, id: model.id),
    systemPrompt: manifest.systemPrompt,
    inputType: manifest.inputType?.name,
    inputMaxChars: manifest.inputMaxChars,
    outputType: manifest.outputType?.name,
    outputMaxChars: manifest.outputMaxChars,
    price: price == null
        ? null
        : ManifestPrice(asset: 'USDC', amount: price.stroops),
  );
}

StudioDraft transportStudioDraft(OwnedStudioDraft draft) => StudioDraft(
  draftId: draft.draftId,
  manifest: transportDraft(draft.manifest),
  revision: draft.revision,
  deployState: draft.deployState,
  liveVersion: draft.liveVersion,
  agentId: draft.agentId,
  retryFromStep: draft.retryFromStep,
);
