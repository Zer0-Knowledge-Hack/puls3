import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_flutter/src/studio/studio_gateway.dart';

/// A draft every deploy rule accepts, with a 100-character input limit.
AgentManifestDraft validManifest({String name = 'Brief Bot'}) =>
    AgentManifestDraft(
      name: name,
      description: 'Summarizes long text into a short brief.',
      skills: [Skill(id: 'summaries', name: 'Summaries')],
      model: ModelId(
        provider: 'workers-ai',
        id: '@cf/meta/llama-3.3-70b-instruct-fp8-fast',
      ),
      systemPrompt: 'You are Brief Bot. Reply with at most five bullet points.',
      inputType: InputType.text,
      inputMaxChars: 100,
      outputType: OutputType.text,
      outputMaxChars: 2000,
      price: UsdcAmount.stroops(1000000),
    );

const testOwner = 'GCDSVE4MGRNDOWEP7HX7HGMECBFAZPDI2J5PDGWDLOLLLIUIXFFSQFXZ';

StudioDraft savedDraft(
  int id, {
  String name = 'Brief Bot',
  DraftDeployState state = DraftDeployState.draft,
  int? liveVersion,
  String? agentId,
  int? retryFromStep,
}) => StudioDraft(
  draftId: id,
  manifest: validManifest(name: name),
  revision: 1,
  deployState: state,
  liveVersion: liveVersion,
  agentId: agentId,
  retryFromStep: retryFromStep,
);
