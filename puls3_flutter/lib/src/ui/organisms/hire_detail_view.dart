import 'package:flutter/material.dart';

import '../../domain/stellar_format.dart';
import '../../hire/hire_gateway.dart';
import '../../theme/puls3_theme.dart';
import '../atoms/price_tag.dart';
import '../atoms/primary_button.dart';
import '../atoms/section_label.dart';
import '../molecules/key_value_row.dart';
import '../molecules/progress_step_row.dart';
import '../molecules/screen_header.dart';

/// S06 hire detail (flow F6): the hire's status, the agent run, the result
/// and the payment link. Presentational: the container polls the hire and
/// passes it with the callbacks.
class HireDetailView extends StatelessWidget {
  const HireDetailView({
    super.key,
    required this.hire,
    required this.onBackToMarketplace,
    this.onOpenPayment,
    this.onCopyResult,
    this.banner,
  });

  final HireProgress hire;
  final VoidCallback onBackToMarketplace;

  /// Opens the `fund` transaction on StellarExpert.
  final VoidCallback? onOpenPayment;

  /// Copies the result.
  final VoidCallback? onCopyResult;

  /// Shown above the steps, for example when a refresh failed.
  final Widget? banner;

  @override
  Widget build(BuildContext context) {
    final stage = hire.stage;
    final result = hire.result;
    final note = _note(stage);
    final payment = hire.paymentTransaction;
    final banner = this.banner;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Puls3Spacing.lg),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onBackToMarketplace,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Marketplace'),
          ),
        ),
        const SizedBox(height: Puls3Spacing.sm),
        ScreenHeader(
          title: 'Hire #${hire.hireId}',
          subtitle: hire.agentName,
          trailing: _StatusChip(label: statusLabel(hire), stage: stage),
        ),
        const SizedBox(height: Puls3Spacing.lg),
        if (banner != null) ...[
          banner,
          const SizedBox(height: Puls3Spacing.md),
        ],
        const SectionLabel('Progress'),
        const SizedBox(height: Puls3Spacing.xs),
        ..._steps(),
        if (note != null) ...[
          const SizedBox(height: Puls3Spacing.sm),
          Text(
            note,
            key: const ValueKey('hire-detail-note'),
            style: Puls3Text.bodyMuted,
          ),
        ],
        if (!stage.isFinal) ...[
          const SizedBox(height: Puls3Spacing.xs),
          Text(
            'Updates by itself every few seconds.',
            style: Puls3Text.caption.copyWith(color: Puls3Colors.muted),
          ),
        ],
        if (result != null) ...[
          const SizedBox(height: Puls3Spacing.lg),
          Row(
            children: [
              const Expanded(child: SectionLabel('Result')),
              if (onCopyResult != null)
                TextButton.icon(
                  key: const ValueKey('hire-detail-copy'),
                  onPressed: onCopyResult,
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy'),
                ),
            ],
          ),
          const SizedBox(height: Puls3Spacing.xs),
          Container(
            key: const ValueKey('hire-detail-result'),
            constraints: const BoxConstraints(maxHeight: 420),
            padding: const EdgeInsets.all(Puls3Spacing.md),
            decoration: BoxDecoration(
              color: Puls3Colors.surface,
              borderRadius: Puls3Radius.mdAll,
              border: Border.all(color: Puls3Colors.hairline),
            ),
            child: SingleChildScrollView(
              child: SelectableText(result, style: Puls3Text.body),
            ),
          ),
        ],
        const SizedBox(height: Puls3Spacing.lg),
        const SectionLabel('Task'),
        const SizedBox(height: Puls3Spacing.xs),
        Text(hire.input, style: Puls3Text.body),
        const SizedBox(height: Puls3Spacing.lg),
        Container(
          padding: const EdgeInsets.all(Puls3Spacing.md),
          decoration: BoxDecoration(
            color: Puls3Colors.background,
            borderRadius: Puls3Radius.mdAll,
            border: Border.all(color: Puls3Colors.hairline),
          ),
          child: Column(
            children: [
              KeyValueRow(label: 'Agent', value: hire.agentName),
              KeyValueRow(
                label: _holdsFunds(stage) ? 'Held in escrow' : 'Price',
                value: '',
                valueWidget: PriceTag(
                  stroops: hire.priceUsdcStroops,
                  suffix: null,
                ),
              ),
              const KeyValueRow(label: 'Network', value: 'Stellar Testnet'),
              if (payment != null)
                KeyValueRow(
                  label: 'Payment tx',
                  value: shortenAddress(payment, head: 8, tail: 8),
                  mono: true,
                ),
            ],
          ),
        ),
        if (payment != null && onOpenPayment != null) ...[
          const SizedBox(height: Puls3Spacing.md),
          PrimaryButton(
            label: 'View payment on StellarExpert',
            icon: Icons.open_in_new_rounded,
            variant: PrimaryButtonVariant.outline,
            expand: true,
            onPressed: onOpenPayment,
          ),
        ],
        const SizedBox(height: Puls3Spacing.xxl),
      ],
    );
  }

  /// The status as #10 names it, with the run while the hire is funded.
  static String statusLabel(HireProgress hire) => switch (hire.stage) {
    HireStage.awaitingPayment => 'Awaiting payment',
    HireStage.queued => 'Funded · Queued',
    HireStage.running => 'Funded · Running',
    HireStage.delivered => 'Funded · Result ready',
    HireStage.runFailed => 'Funded · Run failed',
    HireStage.submitted => 'Submitted',
    HireStage.completed => 'Completed',
    HireStage.rejected => hire.isCancelled ? 'Cancelled' : 'Rejected',
    HireStage.expired => 'Expired',
  };

  static bool _holdsFunds(HireStage stage) => switch (stage) {
    HireStage.queued ||
    HireStage.running ||
    HireStage.delivered ||
    HireStage.runFailed ||
    HireStage.submitted => true,
    _ => false,
  };

  List<Widget> _steps() {
    final stage = hire.stage;
    final paid = switch (stage) {
      HireStage.awaitingPayment => StepStatus.active,
      HireStage.rejected when hire.isCancelled => StepStatus.pending,
      _ => StepStatus.done,
    };
    final run = switch (stage) {
      HireStage.queued || HireStage.running => StepStatus.active,
      HireStage.runFailed => StepStatus.failed,
      HireStage.delivered ||
      HireStage.submitted ||
      HireStage.completed => StepStatus.done,
      _ => hire.result != null ? StepStatus.done : StepStatus.pending,
    };
    final submitted =
        stage == HireStage.submitted ||
            stage == HireStage.completed ||
            (stage == HireStage.rejected && hire.rejectedFrom == 'submitted')
        ? StepStatus.done
        : StepStatus.pending;
    final approved = stage == HireStage.completed
        ? StepStatus.done
        : StepStatus.pending;
    return [
      ProgressStepRow(
        label: 'Paid into the escrow',
        icon: Icons.shield_outlined,
        status: paid,
        description: 'Waiting for the payment to confirm on Stellar.',
      ),
      ProgressStepRow(
        label: 'Agent run',
        icon: Icons.smart_toy_outlined,
        status: run,
        description: switch (stage) {
          HireStage.queued => 'Queued: the agent starts shortly.',
          HireStage.running => 'The agent is working on your task.',
          _ => hire.failureReason ?? 'The agent could not finish this task.',
        },
      ),
      ProgressStepRow(
        label: 'Result recorded on Stellar',
        icon: Icons.link_rounded,
        status: submitted,
      ),
      ProgressStepRow(
        label: 'Approved, agent paid',
        icon: Icons.verified_outlined,
        status: approved,
      ),
    ];
  }

  String? _note(HireStage stage) => switch (stage) {
    HireStage.delivered =>
      'The agent finished. Your USDC stays in the escrow until the result '
          'is recorded on Stellar and approved.',
    HireStage.runFailed =>
      'The agent could not finish this task. Your USDC stays in the escrow '
          'and returns to you when the job expires.',
    HireStage.rejected when hire.isCancelled =>
      'This hire was cancelled before any payment.',
    HireStage.rejected =>
      'This hire was rejected. The escrow returned the USDC to you.',
    HireStage.expired =>
      'This hire expired. Any USDC held by the escrow returned to you.',
    _ => null,
  };
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.stage});

  final String label;
  final HireStage stage;

  @override
  Widget build(BuildContext context) {
    final color = switch (stage) {
      HireStage.completed || HireStage.delivered => Puls3Colors.success,
      HireStage.runFailed ||
      HireStage.rejected ||
      HireStage.expired => Puls3Colors.accent,
      _ => Puls3Colors.lavender,
    };
    return Container(
      key: const ValueKey('hire-detail-status'),
      padding: const EdgeInsets.symmetric(
        horizontal: Puls3Spacing.sm,
        vertical: Puls3Spacing.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: Puls3Radius.mdAll,
        border: Border.all(color: color),
      ),
      child: Text(label, style: Puls3Text.caption.copyWith(color: color)),
    );
  }
}
