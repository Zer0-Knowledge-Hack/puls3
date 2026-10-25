import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/puls3_theme.dart';
import '../atoms/primary_button.dart';
import '../atoms/section_label.dart';
import '../molecules/error_banner.dart';

/// What the playground shows (S11).
enum PlaygroundStatus {
  /// Waiting for input (Empty).
  idle,

  /// A test run is in progress (Loading).
  running,

  /// The last run answered (Success).
  result,

  /// The last run failed and can be tried again (Error).
  failed,

  /// Today's free runs are used: Run stays disabled (Error).
  quotaExceeded,
}

/// The S11 playground: a sample input, **Run**, and the answer. Purely
/// presentational: the container owns the input and calls the backend.
class PlaygroundPanel extends StatelessWidget {
  const PlaygroundPanel({
    super.key,
    required this.inputController,
    required this.inputMaxChars,
    required this.status,
    required this.onRun,
    required this.onRetry,
    this.output,
    this.markdown = false,
    this.remainingDailyRuns,
    this.errorMessage,
    this.isDemo = false,
    this.onCopy,
    this.onClose,
    this.onDeploy,
    this.credentialSecret,
    this.credentialAccountId,
  });

  final TextEditingController inputController;
  final int inputMaxChars;
  final PlaygroundStatus status;
  final VoidCallback onRun;
  final VoidCallback onRetry;

  /// The last answer, shown in [PlaygroundStatus.result].
  final String? output;

  /// The draft's `outputType` is Markdown: shown as source, monospaced.
  final bool markdown;
  final int? remainingDailyRuns;

  /// The safe reason of a failed run, or when the quota resets.
  final String? errorMessage;

  /// Runs come from a demo backend: no model answers.
  final bool isDemo;
  final VoidCallback? onCopy;

  /// Closes the panel (the phone sheet); null hides the action.
  final VoidCallback? onClose;

  /// Opens the deploy sheet (F4); null hides the action.
  final VoidCallback? onDeploy;

  /// The builder's provider token. Null hides the field (the demo).
  final TextEditingController? credentialSecret;

  /// Cloudflare account id. Null hides the field.
  final TextEditingController? credentialAccountId;

  @override
  Widget build(BuildContext context) {
    final running = status == PlaygroundStatus.running;
    return Container(
      key: const Key('playground-panel'),
      padding: const EdgeInsets.all(Puls3Spacing.md),
      decoration: BoxDecoration(
        color: Puls3Colors.surface,
        borderRadius: Puls3Radius.mdAll,
        border: Border.all(color: Puls3Colors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: SectionLabel(context.l10n.studioTestRun)),
              if (onClose != null)
                IconButton(
                  key: const Key('playground-close'),
                  tooltip: context.l10n.commonClose,
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
            ],
          ),
          const SizedBox(height: Puls3Spacing.xs),
          Text(
            isDemo
                ? context.l10n.playgroundDemoLead
                : context.l10n.playgroundLiveLead,
            style: Puls3Text.bodyMuted,
          ),
          const SizedBox(height: Puls3Spacing.sm),
          if (credentialSecret != null) ...[
            TextField(
              key: const Key('playground-credential'),
              controller: credentialSecret,
              enabled: !running,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: context.l10n.playgroundProviderToken,
                hintText: context.l10n.playgroundProviderTokenHint,
              ),
            ),
            const SizedBox(height: Puls3Spacing.sm),
          ],
          if (credentialAccountId != null) ...[
            TextField(
              key: const Key('playground-account'),
              controller: credentialAccountId,
              enabled: !running,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: context.l10n.playgroundAccountId,
              ),
            ),
            const SizedBox(height: Puls3Spacing.sm),
          ],
          ListenableBuilder(
            listenable: Listenable.merge([
              inputController,
              credentialSecret,
              credentialAccountId,
            ]),
            builder: (context, _) {
              final secret = credentialSecret;
              final account = credentialAccountId;
              final credentialsReady =
                  secret == null ||
                  (secret.text.trim().isNotEmpty &&
                      (account == null || account.text.trim().isNotEmpty));
              return _InputAndRun(
                controller: inputController,
                maxChars: inputMaxChars,
                locked: running,
                canRun:
                    status != PlaygroundStatus.quotaExceeded &&
                    credentialsReady,
                running: running,
                onRun: onRun,
              );
            },
          ),
          if (running) ...[
            const SizedBox(height: Puls3Spacing.sm),
            Text(
              context.l10n.playgroundRunning,
              key: const Key('playground-running'),
              style: Puls3Text.bodyMuted,
            ),
          ],
          if (status == PlaygroundStatus.failed) ...[
            const SizedBox(height: Puls3Spacing.md),
            ErrorBanner(
              key: const Key('playground-error'),
              title: context.l10n.playgroundFailed,
              message: errorMessage ?? context.l10n.playgroundTryLater,
              onRetry: onRetry,
            ),
          ],
          if (status == PlaygroundStatus.quotaExceeded) ...[
            const SizedBox(height: Puls3Spacing.md),
            Text(
              errorMessage ?? context.l10n.playgroundQuota,
              key: const Key('playground-quota'),
              style: Puls3Text.body.copyWith(color: Puls3Colors.accent),
            ),
          ],
          if (status == PlaygroundStatus.result && output != null) ...[
            const SizedBox(height: Puls3Spacing.md),
            TestRunResultCard(
              output: output!,
              markdown: markdown,
              remainingDailyRuns: remainingDailyRuns,
              onCopy: onCopy,
            ),
          ],
          if (onDeploy != null) ...[
            const SizedBox(height: Puls3Spacing.md),
            PrimaryButton(
              key: const Key('playground-deploy'),
              label: context.l10n.studioDeploy,
              icon: Icons.rocket_launch_outlined,
              variant: PrimaryButtonVariant.outline,
              expand: true,
              onPressed: running ? null : onDeploy,
            ),
          ],
        ],
      ),
    );
  }
}

class _InputAndRun extends StatelessWidget {
  const _InputAndRun({
    required this.controller,
    required this.maxChars,
    required this.locked,
    required this.canRun,
    required this.running,
    required this.onRun,
  });

  final TextEditingController controller;
  final int maxChars;
  final bool locked;
  final bool canRun;
  final bool running;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final length = controller.text.length;
    final tooLong = length > maxChars;
    final empty = controller.text.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('playground-input'),
          controller: controller,
          enabled: !locked,
          minLines: 3,
          maxLines: 8,
          decoration: InputDecoration(
            hintText: context.l10n.playgroundSampleTask,
            counterText: '$length / $maxChars',
            errorText: tooLong
                ? context.l10n.playgroundTooLong(maxChars)
                : null,
          ),
        ),
        const SizedBox(height: Puls3Spacing.sm),
        PrimaryButton(
          key: const Key('playground-run'),
          label: running
              ? context.l10n.playgroundRunningButton
              : context.l10n.playgroundRun,
          icon: Icons.play_arrow_rounded,
          isLoading: running,
          expand: true,
          onPressed: running || !canRun || empty || tooLong ? null : onRun,
        ),
      ],
    );
  }
}

/// The answer of a test run, labelled so it is never mistaken for a paid
/// hire. Purely presentational.
class TestRunResultCard extends StatelessWidget {
  const TestRunResultCard({
    super.key,
    required this.output,
    this.markdown = false,
    this.remainingDailyRuns,
    this.onCopy,
  });

  final String output;
  final bool markdown;
  final int? remainingDailyRuns;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final runs = remainingDailyRuns;
    return Container(
      key: const Key('playground-result'),
      padding: const EdgeInsets.all(Puls3Spacing.sm),
      decoration: BoxDecoration(
        color: Puls3Colors.background,
        borderRadius: Puls3Radius.mdAll,
        border: Border.all(color: Puls3Colors.success),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.playgroundResultLabel,
                  style: Puls3Text.caption.copyWith(
                    color: Puls3Colors.success,
                  ),
                ),
              ),
              if (onCopy != null)
                TextButton.icon(
                  key: const Key('playground-copy'),
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: Text(context.l10n.commonCopy),
                ),
            ],
          ),
          const SizedBox(height: Puls3Spacing.xs),
          SelectableText(
            output,
            style: markdown ? Puls3Text.data : Puls3Text.body,
          ),
          if (runs != null) ...[
            const SizedBox(height: Puls3Spacing.sm),
            Text(
              context.l10n.playgroundRunsLeft(runs),
              style: Puls3Text.bodyMuted.copyWith(fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
