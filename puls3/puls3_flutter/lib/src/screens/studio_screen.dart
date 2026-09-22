import 'package:flutter/material.dart';

import '../domain/agent_draft.dart';
import '../domain/usdc.dart';
import '../theme/puls3_theme.dart';
import '../ui/atoms/content_width.dart';
import '../ui/atoms/primary_button.dart';
import '../ui/atoms/section_label.dart';
import '../ui/molecules/agent_card.dart';
import '../ui/organisms/agent_form.dart';
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

  late final Listenable _formChanges = Listenable.merge([
    _name,
    _description,
    _price,
  ]);

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
      if (skill.isNotEmpty && !_skills.contains(skill)) _skills.add(skill);
      _skillInput.clear();
    });
  }

  void _removeSkill(String skill) => setState(() => _skills.remove(skill));

  Future<void> _deploy() async {
    final price = _priceStroops;
    if (price == null) return;
    final draft = AgentDraft(
      name: _name.text.trim().isEmpty ? 'Untitled agent' : _name.text.trim(),
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
    return SingleChildScrollView(
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
  }

  Widget _buildBody(BuildContext context) {
    final price = _priceStroops;
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
      priceError: price == null ? 'Enter an amount like 0.50' : null,
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
        Text(
          'On deploy, puls3 creates a Stellar wallet for this agent and '
          'registers its identity on Soroban.',
          style: Puls3Text.bodyMuted,
        ),
        const SizedBox(height: Puls3Spacing.lg),
        PrimaryButton(
          label: 'Deploy to Stellar',
          icon: Icons.rocket_launch_outlined,
          expand: true,
          onPressed: price == null ? null : _deploy,
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Puls3Spacing.xl),
        Text('Agent Studio', style: Puls3Text.displayLg),
        const SizedBox(height: Puls3Spacing.xs),
        Text(
          'Design an agent, give it a price, deploy it with its own wallet.',
          style: Puls3Text.lead,
        ),
        const SizedBox(height: Puls3Spacing.xl),
        if (wide)
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
