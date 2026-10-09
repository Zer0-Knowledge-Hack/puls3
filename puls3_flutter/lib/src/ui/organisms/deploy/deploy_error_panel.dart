import 'package:flutter/material.dart';

import '../../../deploy/deploy_flow_controller.dart';
import '../../../domain/stellar_format.dart';
import '../../../theme/puls3_theme.dart';
import '../../atoms/primary_button.dart';
import '../../molecules/copyable_value_row.dart';
import 'deploy_copy.dart';

/// A stopped deploy: what happened in one or two lines, the action that
/// recovers from it, and technical details only on request.
class DeployErrorPanel extends StatefulWidget {
  const DeployErrorPanel({
    super.key,
    required this.error,
    required this.onRetry,
    required this.onCancel,
  });

  final DeployError error;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  State<DeployErrorPanel> createState() => _DeployErrorPanelState();
}

class _DeployErrorPanelState extends State<DeployErrorPanel> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final error = widget.error;
    final copy = DeployErrorCopy.of[error.kind]!;
    final hasDetails = error.detail != null || error.transactionHash != null;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        key: ValueKey('deploy-error-${error.kind.name}'),
        padding: const EdgeInsets.all(Puls3Spacing.md),
        decoration: BoxDecoration(
          color: Puls3Colors.surface,
          borderRadius: Puls3Radius.mdAll,
          border: Border.all(color: Puls3Colors.accent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(copy.icon, color: Puls3Colors.accent, size: 24),
                const SizedBox(width: Puls3Spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(copy.title, style: DeployText.subtitle),
                      const SizedBox(height: 2),
                      Text(copy.message, style: DeployText.bodyMuted),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Puls3Spacing.md),
            PrimaryButton(
              label: copy.action,
              icon: Icons.refresh_rounded,
              expand: true,
              onPressed: widget.onRetry,
            ),
            const SizedBox(height: Puls3Spacing.xxs),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('Cancel'),
                ),
                if (hasDetails)
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _showDetails = !_showDetails),
                    iconAlignment: IconAlignment.end,
                    icon: Icon(
                      _showDetails
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18,
                    ),
                    label: Text(_showDetails ? 'Hide details' : 'Show details'),
                  ),
              ],
            ),
            if (_showDetails) _Details(error: error),
          ],
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.error});

  final DeployError error;

  @override
  Widget build(BuildContext context) {
    final hash = error.transactionHash;
    return Container(
      key: const ValueKey('deploy-error-details'),
      padding: const EdgeInsets.all(Puls3Spacing.sm),
      decoration: const BoxDecoration(
        color: Puls3Colors.background,
        borderRadius: Puls3Radius.smAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Code: ${error.kind.name} · step: ${error.step.name}',
            style: Puls3Text.data.copyWith(fontSize: 12),
          ),
          if (error.detail != null) ...[
            const SizedBox(height: Puls3Spacing.xxs),
            SelectableText(error.detail!, style: DeployText.caption),
          ],
          if (hash != null)
            CopyableValueRow(
              label: 'Transaction',
              value: hash,
              display: shortenAddress(hash, head: 8, tail: 8),
            ),
        ],
      ),
    );
  }
}
