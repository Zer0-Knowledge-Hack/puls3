import 'package:puls3_domain/puls3_domain.dart';

/// A model the Studio offers (ADR-0004: the builder picks one model, once,
/// on their own provider account).
class StudioModelOption {
  const StudioModelOption({
    required this.provider,
    required this.id,
    required this.label,
  });

  final String provider;
  final String id;

  /// What the builder sees, for example "Claude Sonnet 5.5".
  final String label;

  ModelId get modelId => ModelId(provider: provider, id: id);

  /// The free tier runs on the builder's own Workers AI account; a paid
  /// provider needs the builder's own key (BYOK).
  bool get isFree => provider == ModelPolicy.freeProvider;

  /// Whether the model can call tools, which subcontracting needs (ADR-0011
  /// D8): every Claude model, and the free models in
  /// [studioWorkersAiToolModels].
  bool get supportsTools => !isFree || studioWorkersAiToolModels.contains(id);
}

/// The Workers AI models that call tools. The server is the authority
/// (`workersAiToolModels`); the Studio mirrors it to enable the subcontract
/// opt-in only where a hire can use it.
const studioWorkersAiToolModels = {
  '@cf/mistralai/mistral-small-3.1-24b-instruct',
};

/// The models the Studio offers: Workers AI ids from the ADR-0004 examples
/// and the models the Anthropic runtime adapter serves (#20).
///
/// The server is the authority: the Studio endpoints (#35) validate the
/// manifest again with the server's policy. Until they serve the policy,
/// the app keeps this mirror of it.
const studioModelOptions = [
  StudioModelOption(
    provider: 'workers-ai',
    id: '@cf/meta/llama-3.3-70b-instruct-fp8-fast',
    label: 'Llama 3.3 70B',
  ),
  StudioModelOption(
    provider: 'workers-ai',
    id: '@cf/mistralai/mistral-small-3.1-24b-instruct',
    label: 'Mistral Small 3.1 24B',
  ),
  StudioModelOption(
    provider: 'anthropic',
    id: 'claude-sonnet-5-5',
    label: 'Claude Sonnet 5.5',
  ),
  StudioModelOption(
    provider: 'anthropic',
    id: 'claude-opus-5-5',
    label: 'Claude Opus 5.5',
  ),
  StudioModelOption(
    provider: 'anthropic',
    id: 'claude-fable-5-1',
    label: 'Claude Fable 5.1',
  ),
];

/// The [ModelPolicy] the Studio validates with: the options above.
final studioModelPolicy = ModelPolicy(
  workersAiModels: {
    for (final option in studioModelOptions)
      if (option.isFree) option.id,
  },
  paidProviders: {
    for (final option in studioModelOptions)
      if (!option.isFree) option.provider,
  },
);

/// The most agents one hire may subcontract (ADR-0011 D8). The server is the
/// authority (`subcontractMaxChildrenCap`); the Studio mirrors it so the
/// builder is never offered more than a hire can open.
const studioSubcontractMaxChildren = 2;
