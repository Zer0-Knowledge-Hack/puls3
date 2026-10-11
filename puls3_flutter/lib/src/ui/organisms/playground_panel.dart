import 'package:flutter/material.dart';

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
              const Expanded(child: SectionLabel('Test run')),
              if (onClose != null)
                IconButton(
                  key: const Key('playground-close'),
                  tooltip: 'Close',
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
            ],
          ),
          const SizedBox(height: Puls3Spacing.xs),
          Text(
            isDemo
                ? 'Demo test runner: no model answers yet.'
                : 'Test runs are free and limited per day.',
            style: Puls3Text.bodyMuted,
          ),
          const SizedBox(height: Puls3Spacing.sm),
          ListenableBuilder(
            listenable: inputController,
            builder: (context, _) => _InputAndRun(
              controller: inputController,
              maxChars: inputMaxChars,
              locked: running,
              canRun: status != PlaygroundStatus.quotaExceeded,
              running: running,
              onRun: onRun,
            ),
          ),
          if (running) ...[
            const SizedBox(height: Puls3Spacing.sm),
            Text(
              'Running… It stops at the runtime timeout.',
              key: const Key('playground-running'),
              style: Puls3Text.bodyMuted,
            ),
          ],
          if (status == PlaygroundStatus.failed) ...[
            const SizedBox(height: Puls3Spacing.md),
            ErrorBanner(
              key: const Key('playground-error'),
              title: 'The test run failed',
              message: errorMessage ?? 'Try again in a moment.',
              onRetry: onRetry,
            ),
          ],
          if (status == PlaygroundStatus.quotaExceeded) ...[
            const SizedBox(height: Puls3Spacing.md),
            Text(
              errorMessage ?? 'You used today\'s test runs.',
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
              label: 'Deploy to Stellar',
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
            hintText: 'A sample task for your agent',
            counterText: '$length / $maxChars',
            errorText: tooLong
                ? 'This agent accepts up to $maxChars characters.'
                : null,
          ),
        ),
        const SizedBox(height: Puls3Spacing.sm),
        PrimaryButton(
          key: const Key('playground-run'),
          label: running ? 'Running…' : 'Run',
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
                  'Test run: not paid, nothing on chain',
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
                  label: const Text('Copy'),
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
              runs == 1 ? '1 run left today' : '$runs runs left today',
              style: Puls3Text.bodyMuted.copyWith(fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
