import 'package:puls3_domain/puls3_domain.dart';

/// Public ERC-8004 registration file. The system prompt is not a field.
Map<String, Object?> registrationDocument(AgentManifest manifest) => {
  'type': 'https://eips.ethereum.org/EIPS/eip-8004#registration-v1',
  'name': manifest.name,
  'description': manifest.description,
  'services': const [
    {'name': 'puls3', 'endpoint': 'https://puls3-4lw.pages.dev'},
  ],
  'x402Support': false,
  'active': true,
  'puls3': {
    'skills': [
      for (final skill in manifest.skills)
        {
          'id': skill.id,
          'name': skill.name,
          'description': skill.description,
        },
    ],
    'price': {'asset': 'USDC', 'amount': manifest.price.stroops},
    'model': {'provider': manifest.model.provider, 'id': manifest.model.id},
    'manifestVersion': manifest.version.value,
  },
};
