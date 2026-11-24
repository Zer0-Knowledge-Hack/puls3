import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puls3_domain/puls3_domain.dart'
    show AgentManifestDraft, OutputType;

import '../domain/usdc.dart';
import '../l10n/l10n.dart';
import '../state/app_scope.dart';
import '../studio/studio_brief.dart';
import '../studio/studio_form_check.dart';
import '../studio/studio_gateway.dart';
import '../studio/studio_models.dart';
import '../theme/breakpoints.dart';
import '../theme/puls3_theme.dart';
import '../ui/atoms/content_width.dart';
import '../ui/atoms/primary_button.dart';
import '../ui/atoms/section_label.dart';
import '../ui/molecules/agent_card.dart';
import '../ui/organisms/agent_form.dart';
import '../ui/organisms/site_footer.dart';
import 'playground.dart';
import 'studio_deploy.dart';
import 'wallet_sheet.dart';

/// `/studio` (S07, flows F4, F8, F9, F10): the agent builder with a live
/// Marketplace preview. The container: it owns the form state and checks it
/// with the domain manifest rules (#34) on every change, saves drafts and
/// opens the playground through the [StudioGateway]. Deploy and Test run
/// stay disabled until the manifest is valid.
class StudioScreen extends StatefulWidget {
  const StudioScreen({super.key, this.draftId, this.newVersion = false});

  /// A saved draft to open (`/studio?draft=n`, F8 "Continue editing").
  final int? draftId;

  /// Opens the live [draftId] as a new draft for version n+1 (F10).
  final bool newVersion;

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
  final _brief = TextEditingController();
  final _description = TextEditingController();
  final _prompt = TextEditingController();
  final _inputMax = TextEditingController();
  final _outputMax = TextEditingController();
  final _price = TextEditingController();
  final _subcontractChildren = TextEditingController();
  final _subcontractReserve = TextEditingController();
  final _skillInput = TextEditingController();

  StudioModelOption? _model;
  OutputType _outputType = OutputType.text;
  final List<String> _skills = [];

  /// Whether the agent may subcontract other agents (#334).
  bool _subcontract = false;

  /// Whether the builder has edited the generated description or prompt.
  /// While false, each follows the brief.
  bool _descriptionEdited = false;
  bool _promptEdited = false;

  /// Set while the brief regenerates the description and prompt, so their
  /// listeners do not mistake the generated text for a builder edit.
  bool _syncingFromBrief = false;

  /// Whether the explain-it-once field has been edited, so its problem is not
  /// shown before the builder touches it.
  bool _briefTouched = false;

  /// Whether the Advanced section is open.
  bool _advancedOpen = false;

  /// Fields the builder has edited: only their problems are shown, so an
  /// empty form does not open as a wall of errors.
  final Set<StudioField> _touched = {};

  /// The saved draft this form edits, and its latest known revision.
  int? _draftId;
  int? _revision;

  /// The wire document last saved, to tell unsaved changes apart.
  String? _savedJson;

  /// The live version an edit replaces (F10), for the banner.
  int? _replacesVersion;

  bool _loadingDraft = false;
  bool _saving = false;
  String? _saveError;

  /// The server's `InvalidManifest` problems, under their fields until the
  /// field is edited again (F8-3).
  final Map<StudioField, String> _serverErrors = {};
  bool _conflict = false;

  /// The draft the desktop playground runs, once opened.
  StudioDraft? _playground;

  late final Map<TextEditingController, StudioField> _fieldOf = {
    _name: StudioField.name,
    _description: StudioField.description,
    _prompt: StudioField.systemPrompt,
    _inputMax: StudioField.input,
    _outputMax: StudioField.output,
    _price: StudioField.price,
    _subcontractChildren: StudioField.subcontractChildren,
    _subcontractReserve: StudioField.subcontractReserve,
  };

  /// The default limits for a new agent: a non-technical builder never has to
  /// touch Advanced to deploy.
  static const _defaultInputMax = '8000';
  static const _defaultOutputMax = '2000';

  @override
  void initState() {
    super.initState();
    _inputMax.text = _defaultInputMax;
    _outputMax.text = _defaultOutputMax;
    _subcontractChildren.text = const StudioFormValues().subcontractMaxChildren;
    _outputType = OutputType.markdown;
    _model = studioModelOptions.first;
    for (final MapEntry(key: controller, value: field) in _fieldOf.entries) {
      controller.addListener(() => _onFieldChanged(controller, field));
    }
    _brief.addListener(_onBriefChanged);
    final draftId = widget.draftId;
    if (draftId != null) {
      _loadingDraft = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _open(draftId));
    }
  }

  @override
  void dispose() {
    for (final c in [..._fieldOf.keys, _brief, _skillInput]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onFieldChanged(TextEditingController controller, StudioField field) {
    if (_syncingFromBrief) return;
    setState(() {
      if (controller == _description) _descriptionEdited = true;
      if (controller == _prompt) _promptEdited = true;
      if (controller == _name && !_promptEdited) _syncPromptFromBrief();
      _touched.add(field);
      _serverErrors.remove(field);
    });
  }

  void _onBriefChanged() {
    if (_syncingFromBrief) return;
    setState(() {
      _briefTouched = true;
      _serverErrors.remove(StudioField.description);
      _serverErrors.remove(StudioField.systemPrompt);
      _syncFromBrief();
    });
  }

  /// Generates the description and prompt from the brief, unless the builder
  /// edited that field under Advanced.
  void _syncFromBrief() {
    _syncingFromBrief = true;
    try {
      if (!_descriptionEdited) {
        _description.text = descriptionFromBrief(_brief.text);
      }
      if (!_promptEdited) {
        _prompt.text = systemPromptFromBrief(_brief.text, name: _name.text);
      }
    } finally {
      _syncingFromBrief = false;
    }
  }

  void _syncPromptFromBrief() {
    if (_promptEdited) return;
    _syncingFromBrief = true;
    try {
      _prompt.text = systemPromptFromBrief(_brief.text, name: _name.text);
    } finally {
      _syncingFromBrief = false;
    }
  }

  String? get _owner => AppScope.of(context).wallet.address;

  StudioGateway get _gateway => AppScope.of(context).studioGateway;

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
    subcontract: _subcontract,
    subcontractMaxChildren: _subcontractChildren.text,
    subcontractReserve: _subcontractReserve.text,
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
  void _revealAll() => setState(() {
    _touched.addAll(StudioField.values);
    _briefTouched = true;
    _advancedOpen = true;
  });

  /// Loads a saved draft into the form (F8 "Continue editing", F10 "Edit").
  Future<void> _open(int draftId) async {
    if (!mounted) return;
    final l10n = context.l10n;
    final owner = _owner;
    if (owner == null) {
      setState(() {
        _loadingDraft = false;
        _saveError = l10n.studioConnectDraftOwner;
      });
      return;
    }
    try {
      final draft = await _gateway.getDraft(draftId, owner: owner);
      if (!mounted) return;
      setState(() {
        _fill(studioFormValuesFor(draft.manifest));
        if (widget.newVersion && draft.deployState == DraftDeployState.live) {
          // Version n stays live and immutable: the edit is a new draft.
          _replacesVersion = draft.liveVersion ?? 1;
        } else {
          _draftId = draft.draftId;
          _revision = draft.revision;
          _savedJson = _json(draft.manifest);
        }
        _loadingDraft = false;
      });
    } on StudioGatewayException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDraft = false;
        _saveError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingDraft = false;
        _saveError = l10n.studioDraftLoadError;
      });
    }
  }

  void _fill(StudioFormValues values) {
    _syncingFromBrief = true;
    try {
      _name.text = values.name;
      _brief.text = values.description;
      _description.text = values.description;
      _prompt.text = values.systemPrompt;
    } finally {
      _syncingFromBrief = false;
    }
    _descriptionEdited = true;
    _promptEdited = true;
    _briefTouched = true;
    _advancedOpen = false;
    _inputMax.text = values.inputMaxChars.isEmpty
        ? _defaultInputMax
        : values.inputMaxChars;
    _outputMax.text = values.outputMaxChars.isEmpty
        ? _defaultOutputMax
        : values.outputMaxChars;
    _price.text = values.price;
    _subcontract = values.subcontract;
    _subcontractChildren.text = values.subcontractMaxChildren;
    _subcontractReserve.text = values.subcontractReserve;
    _model = values.model ?? studioModelOptions.first;
    _outputType = values.outputType;
    _skills
      ..clear()
      ..addAll(values.skills);
    _touched.addAll(StudioField.values);
  }

  /// The domain draft has no value equality: compare wire documents.
  static String _json(AgentManifestDraft draft) => '${draft.toJson()}';

  bool _unsaved(AgentManifestDraft? current) =>
      _draftId == null || current == null || _json(current) != _savedJson;

  /// Saves the form as a draft (F8) and returns it, or null when it was not
  /// saved; the reason is shown under the buttons.
  Future<StudioDraft?> _save(
    AgentManifestDraft manifest, {
    bool overwrite = false,
  }) async {
    var owner = _owner;
    if (owner == null) {
      // F8: connect, then the save continues with the same form.
      await showWalletSheet(context);
      if (!mounted) return null;
      owner = _owner;
      if (owner == null) return null;
    }
    if (!mounted) return null;
    final l10n = context.l10n;
    setState(() {
      _saving = true;
      _saveError = null;
      _conflict = false;
      _serverErrors.clear();
    });
    String? error;
    final problems = <StudioField, String>{};
    var conflict = false;
    try {
      final draft = await _gateway.saveDraft(
        manifest,
        owner: owner,
        draftId: _draftId,
        revision: _revision,
        overwrite: overwrite,
      );
      if (!mounted) return null;
      setState(() {
        _draftId = draft.draftId;
        _revision = draft.revision;
        _savedJson = _json(manifest);
        _saving = false;
      });
      return draft;
    } on StudioDraftConflict catch (e) {
      conflict = true;
      error = e.message;
    } on StudioInvalidDraft catch (e) {
      error = e.message;
      for (final problem in e.problems) {
        final (field, message) = describeManifestProblem(problem, l10n);
        problems.putIfAbsent(field, () => message);
      }
    } on StudioGatewayException catch (e) {
      error = l10n.studioNotSaved(e.message);
    } catch (_) {
      error = l10n.studioServerNoAnswer;
    }
    if (!mounted) return null;
    setState(() {
      _saving = false;
      _conflict = conflict;
      _saveError = error;
      _serverErrors.addAll(problems);
      _touched.addAll(StudioField.values);
      _briefTouched = true;
      if (problems.keys.any(_isAdvancedField)) _advancedOpen = true;
    });
    return null;
  }

  static bool _isAdvancedField(StudioField field) => switch (field) {
    StudioField.description ||
    StudioField.model ||
    StudioField.systemPrompt ||
    StudioField.input ||
    StudioField.output ||
    StudioField.subcontractChildren ||
    StudioField.subcontractReserve => true,
    _ => false,
  };

  /// "Reload" after a conflict: the newer saved revision replaces the edits.
  Future<void> _reload() async {
    final draftId = _draftId;
    if (draftId == null) return;
    setState(() {
      _conflict = false;
      _saveError = null;
      _loadingDraft = true;
    });
    await _open(draftId);
  }

  /// Test run (F9): saves unsaved changes first, then opens the playground
  /// beside the preview, or as a sheet on phones.
  Future<void> _testRun(AgentManifestDraft manifest) async {
    if (_unsaved(manifest) && await _save(manifest) == null) return;
    if (!mounted) return;
    final owner = _owner;
    final draftId = _draftId;
    if (owner == null || draftId == null) return;
    final draft = StudioDraft(
      draftId: draftId,
      manifest: manifest,
      revision: _revision ?? 1,
    );
    final wide =
        MediaQuery.sizeOf(context).width >= Puls3Breakpoints.studioTwoColumn;
    if (wide) {
      setState(() => _playground = draft);
    } else {
      await showPlaygroundSheet(
        context,
        draft: draft,
        gateway: _gateway,
        owner: owner,
        onDeploy: () => _deploy(manifest),
      );
    }
  }

  /// Deploy (F4). With a wallet connected the draft is saved first, so My
  /// agents lists it as live once it is.
  Future<void> _deploy(AgentManifestDraft manifest) async {
    if (_owner != null && _unsaved(manifest)) {
      if (await _save(manifest) == null || !mounted) return;
    }
    if (!mounted) return;
    await deployStudioManifest(
      context,
      manifest,
      draftId: _draftId,
      owner: _owner,
    );
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
    final check = checkStudioForm(_values, l10n: context.l10n);
    // A draft needs at least a name to be listed in My agents.
    final saveable = _name.text.trim().isEmpty ? null : check.draft;
    final deployable = check.manifest != null ? saveable : null;
    final owner = AppScope.of(context).wallet.address;
    final playground = _playground;
    final shown = {
      for (final MapEntry(key: field, value: message) in check.errors.entries)
        if (_touched.contains(field)) field: message,
    };
    for (final MapEntry(key: field, value: message) in _serverErrors.entries) {
      shown.putIfAbsent(field, () => message);
    }
    // While a field is generated from the brief, its problem belongs under the
    // brief, not under a field the builder has not opened.
    final descriptionError =
        !_descriptionEdited &&
        check.errors.containsKey(StudioField.description);
    final promptError =
        !_promptEdited && check.errors.containsKey(StudioField.systemPrompt);
    final generatedError = descriptionError || promptError;
    final briefError = generatedError && _briefTouched
        ? (!_descriptionEdited
                  ? check.errors[StudioField.description]
                  : null) ??
              (!_promptEdited ? check.errors[StudioField.systemPrompt] : null)
        : null;
    final remaining =
        check.errors.length -
        (descriptionError ? 1 : 0) -
        (promptError ? 1 : 0) +
        (generatedError ? 1 : 0);
    final wide =
        MediaQuery.sizeOf(context).width >= Puls3Breakpoints.studioTwoColumn;

    final form = AgentForm(
      nameController: _name,
      briefController: _brief,
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
      advancedOpen: _advancedOpen,
      onToggleAdvanced: () => setState(() => _advancedOpen = !_advancedOpen),
      descriptionEdited: _descriptionEdited,
      promptEdited: _promptEdited,
      briefError: briefError,
      errors: shown,
      subcontract: _subcontract,
      onSubcontractChanged: (on) => setState(() {
        _subcontract = on;
        _serverErrors
          ..remove(StudioField.subcontractChildren)
          ..remove(StudioField.subcontractReserve);
      }),
      subcontractChildrenController: _subcontractChildren,
      subcontractReserveController: _subcontractReserve,
    );

    final name = _name.text.trim();
    final description = _description.text.trim();
    final busy = _saving || _loadingDraft;
    final preview = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(context.l10n.studioPreview),
        const SizedBox(height: Puls3Spacing.sm),
        // The same card the Marketplace shows (#26). A new agent has no
        // reviews: RatingBadge hides a 0.0 rating.
        AgentCard(
          key: const Key('studio-preview-card'),
          name: name.isEmpty ? context.l10n.studioYourAgent : name,
          topSkill: _skills.isEmpty
              ? context.l10n.studioGeneralist
              : localizedSkillName(context.l10n, _skills.first),
          priceUsdcStroops: parseUsdcToStroops(_price.text) ?? 0,
          rating: 0.0,
          description: description.isEmpty ? null : description,
          model: _model?.label,
          highlighted: true,
        ),
        const SizedBox(height: Puls3Spacing.md),
        _ReadyPanel(
          remaining: remaining,
          onShowMissing: _revealAll,
        ),
        const SizedBox(height: Puls3Spacing.md),
        Text(
          context.l10n.studioDeployHint,
          style: Puls3Text.bodyMuted,
        ),
        const SizedBox(height: Puls3Spacing.lg),
        PrimaryButton(
          key: const Key('studio-deploy'),
          label: context.l10n.studioDeploy,
          icon: Icons.rocket_launch_outlined,
          expand: true,
          onPressed: deployable == null || busy
              ? null
              : () => _deploy(deployable),
        ),
        const SizedBox(height: Puls3Spacing.sm),
        Row(
          children: [
            Expanded(
              child: PrimaryButton(
                key: const Key('studio-save'),
                label: _saving
                    ? context.l10n.studioSaving
                    : context.l10n.studioSaveDraft,
                icon: Icons.save_outlined,
                variant: PrimaryButtonVariant.outline,
                isLoading: _saving,
                expand: true,
                onPressed: saveable == null || busy
                    ? null
                    : () => _save(saveable),
              ),
            ),
            const SizedBox(width: Puls3Spacing.sm),
            Expanded(
              child: PrimaryButton(
                key: const Key('studio-test-run'),
                label: context.l10n.studioTestRun,
                icon: Icons.play_arrow_rounded,
                variant: PrimaryButtonVariant.outline,
                expand: true,
                onPressed: deployable == null || busy
                    ? null
                    : () => _testRun(deployable),
              ),
            ),
          ],
        ),
        const SizedBox(height: Puls3Spacing.xs),
        _SaveStatus(
          saving: _saving,
          revision: _draftId == null ? null : _revision,
          unsaved: _draftId != null && _unsaved(saveable),
          error: _saveError,
          conflict: _conflict,
          isDemo: _gateway.isDemo,
          walletConnected: owner != null,
          onReload: _reload,
          onKeepMine: saveable == null
              ? null
              : () => _save(saveable, overwrite: true),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('studio-my-agents'),
            onPressed: () => context.go('/studio/agents'),
            icon: const Icon(Icons.list_alt_rounded, size: 18),
            label: Text(context.l10n.studioMyAgents),
          ),
        ),
        if (wide && playground != null && owner != null) ...[
          const SizedBox(height: Puls3Spacing.md),
          Playground(
            // A fresh panel for each saved revision.
            key: ValueKey('playground-${playground.draftId}-$_revision'),
            draft: playground,
            gateway: _gateway,
            owner: owner,
            onClose: () => setState(() => _playground = null),
          ),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Puls3Spacing.xl),
        Text(
          context.l10n.studioTitle,
          style:
              MediaQuery.sizeOf(context).width <
                  Puls3Breakpoints.compactHeadline
              ? Puls3Text.h2Compact
              : Puls3Text.h1,
        ),
        const SizedBox(height: Puls3Spacing.xs),
        Text(
          context.l10n.studioLead,
          style: Puls3Text.lead,
        ),
        if (_loadingDraft) ...[
          const SizedBox(height: Puls3Spacing.md),
          const LinearProgressIndicator(key: Key('studio-loading-draft')),
        ],
        if (_replacesVersion case final version?) ...[
          const SizedBox(height: Puls3Spacing.md),
          _VersionBanner(version: version),
        ],
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

/// F10: editing a live agent makes a new version; hirers keep the old one.
class _VersionBanner extends StatelessWidget {
  const _VersionBanner({required this.version});

  final int version;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('studio-version-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(Puls3Spacing.sm),
      decoration: BoxDecoration(
        color: Puls3Colors.surface,
        borderRadius: Puls3Radius.mdAll,
        border: Border.all(color: Puls3Colors.lavender),
      ),
      child: Text(
        context.l10n.studioVersionBanner(version + 1, version),
        style: Puls3Text.body,
      ),
    );
  }
}

/// Saved, unsaved, or why a save failed (F8-3, F8-4).
class _SaveStatus extends StatelessWidget {
  const _SaveStatus({
    required this.saving,
    required this.revision,
    required this.unsaved,
    required this.error,
    required this.conflict,
    required this.isDemo,
    required this.walletConnected,
    required this.onReload,
    required this.onKeepMine,
  });

  final bool saving;
  final int? revision;
  final bool unsaved;
  final String? error;
  final bool conflict;
  final bool isDemo;
  final bool walletConnected;
  final VoidCallback onReload;
  final VoidCallback? onKeepMine;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    if (error != null) {
      return Column(
        key: const Key('studio-save-error'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            error,
            style: Puls3Text.bodyMuted.copyWith(color: Puls3Colors.accent),
          ),
          if (conflict)
            Wrap(
              spacing: Puls3Spacing.xs,
              children: [
                TextButton(
                  key: const Key('studio-conflict-reload'),
                  onPressed: onReload,
                  child: Text(context.l10n.studioReload),
                ),
                TextButton(
                  key: const Key('studio-conflict-keep'),
                  onPressed: onKeepMine,
                  child: Text(context.l10n.studioKeepMine),
                ),
              ],
            ),
        ],
      );
    }
    final revision = this.revision;
    final String? text;
    if (saving) {
      text = null;
    } else if (revision == null) {
      text = walletConnected ? null : context.l10n.studioConnectToSave;
    } else if (unsaved) {
      text = context.l10n.studioUnsavedRevision(revision);
    } else {
      text = isDemo
          ? context.l10n.studioSavedRevisionDemo(revision)
          : context.l10n.studioSavedRevision(revision);
    }
    if (text == null) return const SizedBox.shrink();
    return Text(
      text,
      key: const Key('studio-save-status'),
      style: Puls3Text.bodyMuted.copyWith(fontSize: 13),
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
                      ? context.l10n.studioReady
                      : context.l10n.studioFieldsToComplete(remaining),
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
                    child: Text(context.l10n.studioWhatIsMissing),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
