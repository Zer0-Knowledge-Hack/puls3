import 'package:flutter/material.dart';
import 'package:puls3_domain/puls3_domain.dart' show OutputType;

import '../../studio/studio_form_check.dart';
import '../../studio/studio_models.dart';
import '../../theme/puls3_theme.dart';
import '../atoms/section_label.dart';
import '../atoms/skill_chip.dart';

/// The Studio's agent builder form (S07): every manifest field of ADR-0004.
/// Presentational: the container owns the controllers and the state, and
/// passes the domain's problems in [errors].
class AgentForm extends StatelessWidget {
  const AgentForm({
    super.key,
    required this.nameController,
    required this.descriptionController,
    required this.promptController,
    required this.inputMaxController,
    required this.outputMaxController,
    required this.priceController,
    required this.skillController,
    required this.models,
    required this.selectedModel,
    required this.onModelChanged,
    required this.outputType,
    required this.onOutputTypeChanged,
    required this.skills,
    required this.suggestedSkills,
    required this.onAddSkill,
    required this.onRemoveSkill,
    this.errors = const {},
  });

  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController promptController;
  final TextEditingController inputMaxController;
  final TextEditingController outputMaxController;
  final TextEditingController priceController;
  final TextEditingController skillController;
  final List<StudioModelOption> models;
  final StudioModelOption? selectedModel;
  final ValueChanged<StudioModelOption> onModelChanged;
  final OutputType outputType;
  final ValueChanged<OutputType> onOutputTypeChanged;
  final List<String> skills;
  final List<String> suggestedSkills;
  final ValueChanged<String> onAddSkill;
  final ValueChanged<String> onRemoveSkill;

  /// The problem to show under each field.
  final Map<StudioField, String> errors;

  static String _count(TextEditingController c) =>
      '${c.text.runes.length} characters';

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: Puls3Spacing.md);
    final remainingSuggestions = suggestedSkills
        .where((s) => !skills.contains(s))
        .toList();
    final skillsError = errors[StudioField.skills];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Identity'),
        const SizedBox(height: Puls3Spacing.sm),
        TextField(
          key: const Key('agent-name-field'),
          controller: nameController,
          style: Puls3Text.body,
          decoration: InputDecoration(
            labelText: 'Agent name',
            hintText: 'For example, Brief Bot',
            helperText: _count(nameController),
            errorText: errors[StudioField.name],
          ),
        ),
        gap,
        TextField(
          key: const Key('agent-description-field'),
          controller: descriptionController,
          style: Puls3Text.body,
          minLines: 2,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Description',
            hintText: 'What the agent does, in one or two sentences',
            helperText: _count(descriptionController),
            errorText: errors[StudioField.description],
          ),
        ),
        gap,
        DropdownButtonFormField<StudioModelOption>(
          key: const Key('agent-model-field'),
          initialValue: selectedModel,
          isExpanded: true,
          dropdownColor: Puls3Colors.surface,
          style: Puls3Text.body,
          decoration: InputDecoration(
            labelText: 'Model',
            helperText: selectedModel == null
                ? 'Runs on your own provider account'
                : selectedModel!.isFree
                ? 'Free tier on your own Workers AI account'
                : 'Uses your own ${selectedModel!.provider} key',
            errorText: errors[StudioField.model],
          ),
          items: [
            for (final model in models)
              DropdownMenuItem(
                value: model,
                child: Text(
                  model.isFree ? '${model.label} · free' : model.label,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
          decoration: InputDecoration(
            labelText: 'System prompt',
            hintText: 'The instructions the agent follows on every hire',
            alignLabelWithHint: true,
            helperText: _count(promptController),
            errorText: errors[StudioField.systemPrompt],
          ),
        ),
        gap,
        TextField(
          key: const Key('agent-skill-field'),
          controller: skillController,
          style: Puls3Text.body,
          decoration: InputDecoration(
            labelText: 'Add a skill',
            hintText: 'Type and press Enter',
            errorText: skillsError,
            suffixIcon: IconButton(
              tooltip: 'Add skill',
              icon: const Icon(Icons.add_rounded),
              onPressed: () => onAddSkill(skillController.text),
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
            for (final skill in remainingSuggestions)
              SkillChip(label: '+ $skill', onTap: () => onAddSkill(skill)),
          ],
        ),
        const SizedBox(height: Puls3Spacing.lg),
        const SectionLabel('Input and output'),
        const SizedBox(height: Puls3Spacing.sm),
        TextField(
          key: const Key('agent-input-max-field'),
          controller: inputMaxController,
          style: Puls3Text.data,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Longest input (characters)',
            hintText: 'For example, 6000',
            helperText: 'Plain text from the person who hires the agent',
            errorText: errors[StudioField.input],
          ),
        ),
        gap,
        LayoutBuilder(
          builder: (context, constraints) {
            final format = DropdownButtonFormField<OutputType>(
              key: const Key('agent-output-type-field'),
              initialValue: outputType,
              isExpanded: true,
              dropdownColor: Puls3Colors.surface,
              style: Puls3Text.body,
              decoration: const InputDecoration(labelText: 'Answer format'),
              items: const [
                DropdownMenuItem(
                  value: OutputType.text,
                  child: Text('Plain text'),
                ),
                DropdownMenuItem(
                  value: OutputType.markdown,
                  child: Text('Markdown'),
                ),
              ],
              onChanged: (value) {
                if (value != null) onOutputTypeChanged(value);
              },
            );
            final limit = TextField(
              key: const Key('agent-output-max-field'),
              controller: outputMaxController,
              style: Puls3Text.data,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Longest answer',
                hintText: '2000',
                errorText: errors[StudioField.output],
                errorMaxLines: 3,
              ),
            );
            // Side by side when there is room; stacked on narrow phones.
            if (constraints.maxWidth < 360) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [format, gap, limit],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: format),
                const SizedBox(width: Puls3Spacing.sm),
                Expanded(child: limit),
              ],
            );
          },
        ),
        const SizedBox(height: Puls3Spacing.lg),
        const SectionLabel('Pricing'),
        const SizedBox(height: Puls3Spacing.sm),
        TextField(
          key: const Key('agent-price-field'),
          controller: priceController,
          style: Puls3Text.data,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Price per task',
            hintText: '0.50',
            suffixText: 'USDC',
            suffixStyle: Puls3Text.data,
            errorText: errors[StudioField.price],
          ),
        ),
      ],
    );
  }
}
