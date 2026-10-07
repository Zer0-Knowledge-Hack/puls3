import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/agent_draft.dart';
import '../domain/usdc.dart';
import '../state/app_scope.dart';
import '../theme/puls3_theme.dart';
import '../ui/atoms/content_width.dart';
import '../ui/atoms/primary_button.dart';
import '../ui/atoms/section_label.dart';
import '../ui/molecules/agent_card.dart';
import '../ui/molecules/agent_list_card.dart';
import '../ui/molecules/screen_header.dart';
import '../ui/organisms/agent_form.dart';
import '../ui/organisms/publish_checklist.dart';
import '../ui/organisms/site_footer.dart';
import 'deploy_sheet.dart';

/// `/studio`: mock agent builder with a live marketplace preview.
/// Container: owns all form state.
class StudioScreen extends StatefulWidget {
  const StudioScreen({super.key});

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  static const _models = [
    'Claude Sonnet',
    'Claude Opus',
    'GPT-4.1',
    'Gemini 2.5 Pro',
    'Llama 3.3 70B',
  ];
  static const _suggestedSkills = [
    'Travel planning',
    'Payments',
    'Summaries',
    'Research',
    'Customer support',
  ];

  final _name = TextEditingController(text: 'Nomad Concierge');
  final _description = TextEditingController(
    text: 'Plans trips end to end, compares fares and pays vendors in USDC.',
  );
  final _prompt = TextEditingController(
    text:
        'You are a travel concierge. Find the best route and price, '
        'confirm with the user, then settle bookings in USDC on Stellar.',
  );
  final _price = TextEditingController(text: '0.50');
  final _skillInput = TextEditingController();

  String _model = _models.first;
  final List<String> _skills = ['Travel planning', 'Payments'];

  /// 0: create an agent, 1: the agents deployed from this device.
  int _tab = 0;

  late final Listenable _formChanges = Listenable.merge([
    _name,
    _description,
    _prompt,
    _price,
  ]);

  bool _policyAccepted = false;

  /// Set by the first deploy attempt: from then on errors show inline.
  bool _attempted = false;

  Map<AgentDraftField, String> get _errors => AgentDraftRules.validate(
    name: _name.text,
    description: _description.text,
    prompt: _prompt.text,
    skills: _skills,
    priceStroops: _priceStroops,
  );

  @override
  void dispose() {
    for (final c in [_name, _description, _prompt, _price, _skillInput]) {
      c.dispose();
    }
    super.dispose();
  }

  int? get _priceStroops => parseUsdcToStroops(_price.text);

  void _addSkill(String raw) {
    final skill = raw.trim();
    setState(() {
      if (skill.isNotEmpty &&
          !_skills.contains(skill) &&
          _skills.length < AgentDraftRules.skillsMax) {
        _skills.add(skill);
      }
      _skillInput.clear();
    });
  }

  void _removeSkill(String skill) => setState(() => _skills.remove(skill));

  Future<void> _deploy() async {
    final errors = _errors;
    final price = _priceStroops;
    if (errors.isNotEmpty || !_policyAccepted || price == null) {
      setState(() => _attempted = true);
      final missing = errors.length + (_policyAccepted ? 0 : 1);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              missing == 1
                  ? 'Complete 1 requirement to deploy.'
                  : 'Complete $missing requirements to deploy.',
            ),
          ),
        );
      return;
    }
    final draft = AgentDraft(
      name: _name.text.trim(),
      description: _description.text.trim(),
      model: _model,
      systemPrompt: _prompt.text,
      skills: List.unmodifiable(_skills),
      priceUsdcStroops: price,
    );
    await showDeploySheet(context, draft);
  }

  @override
  Widget build(BuildContext context) {
    final compact = isCompactLayout(context);
    final scroll = SingleChildScrollView(
      child: Column(
        children: [
          ContentWidth(
            child: ListenableBuilder(
              listenable: _formChanges,
              builder: (context, _) => _buildBody(context),
            ),
          ),
          const SiteFooter(),
        ],
      ),
    );
    if (!compact || _tab != 0) return scroll;
    // Phones: the primary action stays reachable under the thumb.
    return Column(
      children: [
        Expanded(child: scroll),
        ListenableBuilder(
          listenable: _formChanges,
          builder: (context, _) => _DeployBar(onDeploy: _deploy),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    final price = _priceStroops;
    final errors = _errors;
    final wide = MediaQuery.sizeOf(context).width >= 960;

    final form = AgentForm(
      nameController: _name,
      descriptionController: _description,
      promptController: _prompt,
      priceController: _price,
      skillController: _skillInput,
      models: _models,
      selectedModel: _model,
      onModelChanged: (m) => setState(() => _model = m),
      skills: _skills,
      suggestedSkills: _suggestedSkills,
      onAddSkill: _addSkill,
      onRemoveSkill: _removeSkill,
      errors: _attempted ? errors : const {},
    );

    final preview = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Marketplace preview'),
        const SizedBox(height: Puls3Spacing.sm),
        AgentCard(
          name: _name.text.trim(),
          topSkill: _skills.isEmpty ? 'Generalist' : _skills.first,
          priceUsdcStroops: price ?? 0,
          rating: 5.0,
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          model: _model,
          highlighted: true,
        ),
        const SizedBox(height: Puls3Spacing.md),
        PublishChecklist(
          errors: errors,
          policyAccepted: _policyAccepted,
          highlightMissing: _attempted,
          onPolicyChanged: (v) => setState(() => _policyAccepted = v),
          onReadPolicies: () => showAgentPolicies(context),
        ),
        const SizedBox(height: Puls3Spacing.sm),
        Text(
          'On deploy, puls3 creates a Stellar wallet for this agent and '
          'registers its identity on Soroban.',
          style: Puls3Text.bodyMuted.copyWith(fontSize: 13),
        ),
        if (!isCompactLayout(context)) ...[
          const SizedBox(height: Puls3Spacing.lg),
          PrimaryButton(
            label: 'Deploy to Stellar',
            icon: Icons.rocket_launch_outlined,
            expand: true,
            onPressed: _deploy,
          ),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: isCompactLayout(context) ? Puls3Spacing.md : Puls3Spacing.xl,
        ),
        const ScreenHeader(
          title: 'Agent Studio',
          subtitle:
              'Design an agent, give it a price, deploy it with its own wallet.',
        ),
        const SizedBox(height: Puls3Spacing.md),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: 0,
                icon: Icon(Icons.add_rounded, size: 18),
                label: Text('Create'),
              ),
              ButtonSegment(
                value: 1,
                icon: Icon(Icons.smart_toy_outlined, size: 18),
                label: Text('My agents'),
              ),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
        ),
        SizedBox(
          height: isCompactLayout(context) ? Puls3Spacing.lg : Puls3Spacing.xl,
        ),
        if (_tab == 1)
          _MyAgents(onCreate: () => setState(() => _tab = 0))
        else if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: form),
              const SizedBox(width: Puls3Spacing.xxl),
              Expanded(flex: 2, child: preview),
            ],
          )
        else ...[
          form,
          const SizedBox(height: Puls3Spacing.xl),
          preview,
        ],
        const SizedBox(height: Puls3Spacing.xxl),
      ],
    );
  }
}

/// Sticky bottom bar with the deploy action, for phones.
class _DeployBar extends StatelessWidget {
  const _DeployBar({required this.onDeploy});

  final VoidCallback? onDeploy;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Puls3Colors.background,
        border: Border(top: BorderSide(color: Puls3Colors.hairline)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Puls3Spacing.md,
          Puls3Spacing.sm,
          Puls3Spacing.md,
          Puls3Spacing.sm,
        ),
        child: PrimaryButton(
          label: 'Deploy to Stellar',
          icon: Icons.rocket_launch_outlined,
          expand: true,
          onPressed: onDeploy,
        ),
      ),
    );
  }
}

/// The agents deployed from this device, or a nudge to create the first.
class _MyAgents extends StatelessWidget {
  const _MyAgents({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.profile, scope.catalog]),
      builder: (context, _) {
        final agents = [
          for (final id in scope.profile.agentIds) ?scope.catalog.byId(id),
        ];
        if (agents.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: Puls3Spacing.xl),
            child: Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.smart_toy_outlined,
                    size: 32,
                    color: Puls3Colors.muted,
                  ),
                  const SizedBox(height: Puls3Spacing.sm),
                  Text(
                    'No agents yet',
                    style: Puls3Text.title.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Deploy your first agent to see it here.',
                    style: Puls3Text.bodyMuted.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: Puls3Spacing.sm),
                  TextButton(
                    onPressed: onCreate,
                    child: const Text('Create an agent'),
                  ),
                ],
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final agent in agents)
              Padding(
                padding: const EdgeInsets.only(bottom: Puls3Spacing.xs),
                child: AgentListCard(
                  agent: agent,
                  onTap: () => context.go('/agent/${agent.id}'),
                ),
              ),
          ],
        );
      },
    );
  }
}
