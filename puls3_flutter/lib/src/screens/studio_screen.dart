import 'package:flutter/material.dart';
import 'package:puls3_domain/puls3_domain.dart' show AgentManifest, OutputType;

import '../domain/agent_draft.dart';
import '../domain/usdc.dart';
import '../studio/studio_form_check.dart';
import '../studio/studio_models.dart';
import '../theme/breakpoints.dart';
import '../theme/puls3_theme.dart';
import '../ui/atoms/content_width.dart';
import '../ui/atoms/primary_button.dart';
import '../ui/atoms/section_label.dart';
import '../ui/molecules/agent_card.dart';
import '../ui/organisms/agent_form.dart';
import '../ui/organisms/site_footer.dart';
import 'deploy_sheet.dart';

/// `/studio` (S07, flow F4): the agent builder with a live Marketplace
/// preview. The container: it owns the form state and checks it with the
/// domain manifest rules (#34) on every change. Deploy stays disabled until
/// the manifest is valid.
class StudioScreen extends StatefulWidget {
  const StudioScreen({super.key});

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  static const _suggestedSkills = [
    'Summaries',
    'Research',
    'Payments',
    'Customer support',
    'Smart contracts',
  ];

  final _name = TextEditingController();
  final _description = TextEditingController();
  final _prompt = TextEditingController();
  final _inputMax = TextEditingController();
  final _outputMax = TextEditingController();
  final _price = TextEditingController();
  final _skillInput = TextEditingController();

  StudioModelOption? _model;
  OutputType _outputType = OutputType.text;
  final List<String> _skills = [];

  /// Fields the builder has edited: only their problems are shown, so an
  /// empty form does not open as a wall of errors.
  final Set<StudioField> _touched = {};

  late final Map<TextEditingController, StudioField> _fieldOf = {
    _name: StudioField.name,
    _description: StudioField.description,
    _prompt: StudioField.systemPrompt,
    _inputMax: StudioField.input,
    _outputMax: StudioField.output,
    _price: StudioField.price,
  };

  @override
  void initState() {
    super.initState();
    for (final MapEntry(key: controller, value: field) in _fieldOf.entries) {
      controller.addListener(() => _touch(field));
    }
  }

  @override
  void dispose() {
    for (final c in [..._fieldOf.keys, _skillInput]) {
      c.dispose();
    }
    super.dispose();
  }

  void _touch(StudioField field) => setState(() => _touched.add(field));

  StudioFormValues get _values => StudioFormValues(
    name: _name.text,
    description: _description.text,
    skills: List.unmodifiable(_skills),
    model: _model,
    systemPrompt: _prompt.text,
    inputMaxChars: _inputMax.text,
    outputType: _outputType,
    outputMaxChars: _outputMax.text,
    price: _price.text,
  );

  void _addSkill(String raw) {
    final skill = raw.trim();
    setState(() {
      if (skill.isNotEmpty && !_skills.contains(skill)) _skills.add(skill);
      _skillInput.clear();
      _touched.add(StudioField.skills);
    });
  }

  void _removeSkill(String skill) => setState(() {
    _skills.remove(skill);
    _touched.add(StudioField.skills);
  });

  /// Shows every remaining problem, for "What is missing?".
  void _revealAll() => setState(() => _touched.addAll(StudioField.values));

  Future<void> _deploy(AgentManifest manifest) async {
    final draft = AgentDraft(
      name: manifest.name,
      description: manifest.description,
      model: _model!.label,
      systemPrompt: manifest.systemPrompt,
      skills: [for (final s in manifest.skills) s.name],
      priceUsdcStroops: manifest.price.stroops,
    );
    await showDeploySheet(context, draft);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          ContentWidth(child: _buildBody(context)),
          const SiteFooter(),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final check = checkStudioForm(_values);
    final manifest = check.manifest;
    final shown = {
      for (final MapEntry(key: field, value: message) in check.errors.entries)
        if (_touched.contains(field)) field: message,
    };
    final wide =
        MediaQuery.sizeOf(context).width >= Puls3Breakpoints.studioTwoColumn;

    final form = AgentForm(
      nameController: _name,
      descriptionController: _description,
      promptController: _prompt,
      inputMaxController: _inputMax,
      outputMaxController: _outputMax,
      priceController: _price,
      skillController: _skillInput,
      models: studioModelOptions,
      selectedModel: _model,
      onModelChanged: (m) => setState(() {
        _model = m;
        _touched.add(StudioField.model);
      }),
      outputType: _outputType,
      onOutputTypeChanged: (t) => setState(() => _outputType = t),
      skills: _skills,
      suggestedSkills: _suggestedSkills,
      onAddSkill: _addSkill,
      onRemoveSkill: _removeSkill,
      errors: shown,
    );

    final name = _name.text.trim();
    final description = _description.text.trim();
    final preview = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Marketplace preview'),
        const SizedBox(height: Puls3Spacing.sm),
        // The same card the Marketplace shows (#26). A new agent has no
        // reviews: RatingBadge hides a 0.0 rating.
        AgentCard(
          key: const Key('studio-preview-card'),
          name: name.isEmpty ? 'Your agent' : name,
          topSkill: _skills.isEmpty ? 'Generalist' : _skills.first,
          priceUsdcStroops: parseUsdcToStroops(_price.text) ?? 0,
          rating: 0.0,
          description: description.isEmpty ? null : description,
          model: _model?.label,
          highlighted: true,
        ),
        const SizedBox(height: Puls3Spacing.md),
        _ReadyPanel(
          remaining: check.errors.length,
          onShowMissing: _revealAll,
        ),
        const SizedBox(height: Puls3Spacing.md),
        Text(
          'On deploy, puls3 creates a Stellar wallet for this agent and '
          'registers its identity on Soroban.',
          style: Puls3Text.bodyMuted,
        ),
        const SizedBox(height: Puls3Spacing.lg),
        PrimaryButton(
          key: const Key('studio-deploy'),
          label: 'Deploy to Stellar',
          icon: Icons.rocket_launch_outlined,
          expand: true,
          onPressed: manifest == null ? null : () => _deploy(manifest),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Puls3Spacing.xl),
        Text(
          'Agent Studio',
          style:
              MediaQuery.sizeOf(context).width <
                  Puls3Breakpoints.compactHeadline
              ? Puls3Text.h2Compact
              : Puls3Text.h1,
        ),
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

/// Whether the manifest is ready to deploy, and a way to see what is
/// missing.
class _ReadyPanel extends StatelessWidget {
  const _ReadyPanel({required this.remaining, required this.onShowMissing});

  final int remaining;
  final VoidCallback onShowMissing;

  @override
  Widget build(BuildContext context) {
    final ready = remaining == 0;
    return Container(
      key: const Key('studio-ready-panel'),
      padding: const EdgeInsets.all(Puls3Spacing.sm),
      decoration: BoxDecoration(
        color: Puls3Colors.surface,
        borderRadius: Puls3Radius.mdAll,
        border: Border.all(
          color: ready ? Puls3Colors.success : Puls3Colors.hairline,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              ready ? Icons.check_circle_rounded : Icons.pending_outlined,
              size: 20,
              color: ready ? Puls3Colors.success : Puls3Colors.muted,
            ),
          ),
          const SizedBox(width: Puls3Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ready
                      ? 'Ready to deploy'
                      : remaining == 1
                      ? '1 field to complete'
                      : '$remaining fields to complete',
                  style: Puls3Text.body,
                ),
                // Under the text, so it fits on the narrowest phones.
                if (!ready)
                  TextButton(
                    onPressed: onShowMissing,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 36),
                    ),
                    child: const Text('What is missing?'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
