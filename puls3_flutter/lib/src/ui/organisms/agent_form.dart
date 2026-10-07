import 'package:flutter/material.dart';

import '../../domain/agent_draft.dart';
import '../../theme/puls3_theme.dart';
import '../atoms/section_label.dart';
import '../atoms/skill_chip.dart';

/// The Studio's agent builder form. Presentational: the container owns the
/// text controllers and all form state and passes them in.
class AgentForm extends StatelessWidget {
  const AgentForm({
    super.key,
    required this.nameController,
    required this.descriptionController,
    required this.promptController,
    required this.priceController,
    required this.skillController,
    required this.models,
    required this.selectedModel,
    required this.onModelChanged,
    required this.skills,
    required this.suggestedSkills,
    required this.onAddSkill,
    required this.onRemoveSkill,
    this.errors = const {},
  });

  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController promptController;
  final TextEditingController priceController;
  final TextEditingController skillController;
  final List<String> models;
  final String selectedModel;
  final ValueChanged<String> onModelChanged;
  final List<String> skills;
  final List<String> suggestedSkills;
  final ValueChanged<String> onAddSkill;
  final ValueChanged<String> onRemoveSkill;

  /// Messages for the fields that break a manifest rule; shown under them.
  final Map<AgentDraftField, String> errors;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: Puls3Spacing.md);
    final full = skills.length >= AgentDraftRules.skillsMax;
    final remainingSuggestions = suggestedSkills
        .where((s) => !skills.contains(s))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Identity'),
        const SizedBox(height: Puls3Spacing.sm),
        TextField(
          key: const Key('agent-name-field'),
          controller: nameController,
          style: Puls3Text.body,
          maxLength: AgentDraftRules.nameMax,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Agent name',
            errorText: errors[AgentDraftField.name],
          ),
        ),
        gap,
        TextField(
          key: const Key('agent-description-field'),
          controller: descriptionController,
          style: Puls3Text.body,
          minLines: 2,
          maxLines: 4,
          maxLength: AgentDraftRules.descriptionMax,
          decoration: InputDecoration(
            labelText: 'Description',
            helperText: 'Public. What the agent does, in one or two lines.',
            errorText: errors[AgentDraftField.description],
          ),
        ),
        gap,
        DropdownButtonFormField<String>(
          initialValue: selectedModel,
          dropdownColor: Puls3Colors.surface,
          style: Puls3Text.body,
          decoration: const InputDecoration(labelText: 'Model'),
          items: [
            for (final model in models)
              DropdownMenuItem(value: model, child: Text(model)),
          ],
          onChanged: (value) {
            if (value != null) onModelChanged(value);
          },
        ),
        const SizedBox(height: Puls3Spacing.lg),
        const SectionLabel('Behavior'),
        const SizedBox(height: Puls3Spacing.sm),
        TextField(
          key: const Key('agent-prompt-field'),
          controller: promptController,
          style: Puls3Text.data,
          minLines: 4,
          maxLines: 8,
          maxLength: AgentDraftRules.promptMax,
          decoration: InputDecoration(
            labelText: 'System prompt',
            helperText: 'Private. Only you can see it.',
            alignLabelWithHint: true,
            errorText: errors[AgentDraftField.prompt],
          ),
        ),
        gap,
        TextField(
          controller: skillController,
          style: Puls3Text.body,
          enabled: !full,
          maxLength: 32,
          decoration: InputDecoration(
            labelText: 'Add a skill',
            hintText: 'Type and press Enter',
            counterText: '',
            helperText:
                '${skills.length} of ${AgentDraftRules.skillsMax} skills',
            errorText: errors[AgentDraftField.skills],
            suffixIcon: IconButton(
              tooltip: 'Add skill',
              icon: const Icon(Icons.add_rounded),
              onPressed: full ? null : () => onAddSkill(skillController.text),
            ),
          ),
          onSubmitted: onAddSkill,
        ),
        const SizedBox(height: Puls3Spacing.sm),
        Wrap(
          spacing: Puls3Spacing.xs,
          runSpacing: Puls3Spacing.xs,
          children: [
            for (final skill in skills)
              SkillChip(
                label: skill,
                selected: true,
                onDelete: () => onRemoveSkill(skill),
              ),
            if (!full)
              for (final skill in remainingSuggestions)
                SkillChip(label: '+ $skill', onTap: () => onAddSkill(skill)),
          ],
        ),
        const SizedBox(height: Puls3Spacing.lg),
        const SectionLabel('Pricing'),
        const SizedBox(height: Puls3Spacing.sm),
        TextField(
          controller: priceController,
          style: Puls3Text.data,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Price per task',
            suffixText: 'USDC',
            suffixStyle: Puls3Text.data,
            helperText: 'Paid per task in USDC. You receive it on approval.',
            errorText: errors[AgentDraftField.price],
          ),
        ),
      ],
    );
  }
}
