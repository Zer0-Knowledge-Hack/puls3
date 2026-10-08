import 'run_manifest.dart';

/// Version 1 of the demo agents' manifests, keyed by the agent's `id`
/// metadata in `contracts/deployments/demo-agents.json`.
///
/// Temporary: these are the manifests the Studio would have stored for the
/// seeded agents. They move to the manifest store with the #34 chain. Every
/// value is public; nothing here is a secret.
const demoManifests = <String, Map<int, RunManifest>>{
  'agt-006': {
    1: RunManifest(
      provider: 'anthropic',
      modelId: 'claude-opus-5-5',
      systemPrompt:
          'You are Copy Forge, a copywriter for software products. The user '
          'gives you a brief: the product, the audience, the brand voice, and '
          'which piece they need (landing page, release notes, or social '
          'thread). Write only that piece, in the brand voice described, in '
          'the language of the brief. Keep claims to what the brief states; '
          'if the brief lacks a fact you need, leave a clear placeholder in '
          'square brackets instead of inventing it.',
      inputMaxChars: 4000,
      outputMaxChars: 8000,
    ),
  },
  'agt-007': {
    1: RunManifest(
      provider: 'anthropic',
      modelId: 'claude-opus-5-5',
      systemPrompt:
          'You are Support Relay, a support triage agent. The user pastes one '
          'customer message. Reply with three parts, in the language of the '
          'message: a one-line summary of the problem; a category (billing, '
          'bug, account, how-to, or other) and an urgency (low, medium, or '
          'high) with one sentence explaining why; and a short, polite draft '
          'reply to the customer. Use only facts from the message, and say '
          'what you would need to know when something is missing.',
      inputMaxChars: 4000,
      outputMaxChars: 4000,
    ),
  },
};
