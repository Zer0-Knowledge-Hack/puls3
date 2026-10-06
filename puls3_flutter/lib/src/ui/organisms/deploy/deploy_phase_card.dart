import 'package:flutter/material.dart';

import '../../../deploy/deploy_flow_controller.dart';
import '../../../theme/puls3_theme.dart';
import 'deploy_copy.dart';

/// "Where am I, and do I have to do something?" for the step in progress:
/// an icon, a short title, one line and an indeterminate bar. The signature
/// step adds a waiting line so the user knows the wallet expects them.
class DeployPhaseCard extends StatelessWidget {
  const DeployPhaseCard({super.key, required this.step});

  final DeployStep step;

  @override
  Widget build(BuildContext context) {
    final copy = DeployStepCopy.of[step]!;
    final needsUser = step == DeployStep.awaitingSignature;
    return Semantics(
      liveRegion: true,
      label: '${copy.headline}. ${copy.message}',
      child: Container(
        key: ValueKey('deploy-phase-${step.name}'),
        decoration: BoxDecoration(
          color: Puls3Colors.surface,
          borderRadius: Puls3Radius.mdAll,
          border: Border.all(
            color: needsUser ? Puls3Colors.accent : Puls3Colors.hairline,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(Puls3Spacing.md),
              child: Row(
                children: [
                  _PhaseIcon(icon: copy.icon, highlight: needsUser),
                  const SizedBox(width: Puls3Spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(copy.headline, style: DeployText.subtitle),
                        const SizedBox(height: 2),
                        Text(copy.message, style: DeployText.bodyMuted),
                        if (copy.waitingLabel != null) ...[
                          const SizedBox(height: Puls3Spacing.xxs),
                          Text(
                            copy.waitingLabel!,
                            style: DeployText.caption.copyWith(
                              color: Puls3Colors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const LinearProgressIndicator(
              minHeight: 3,
              color: Puls3Colors.accent,
              backgroundColor: Puls3Colors.hairline,
            ),
          ],
        ),
      ),
    );
  }
}

class _PhaseIcon extends StatelessWidget {
  const _PhaseIcon({required this.icon, required this.highlight});

  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: highlight
            ? Puls3Colors.accent.withValues(alpha: 0.15)
            : Puls3Colors.background,
        border: Border.all(color: Puls3Colors.hairline),
      ),
      child: Icon(
        icon,
        size: 22,
        color: highlight ? Puls3Colors.accent : Puls3Colors.lavender,
      ),
    );
  }
}
