import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../state/app_scope.dart';
import '../theme/puls3_theme.dart';
import '../ui/atoms/content_width.dart';
import 'agent_hire_tracker.dart';

/// `/hires/:id?as=<agentId>`: a hire the user's live Studio agent [agentId]
/// made and paid from its own wallet. `/hires/:id` reads hires as their
/// consumer wallet, so these are read through `getAgentHire` instead.
class AgentHireDetailScreen extends StatelessWidget {
  const AgentHireDetailScreen({
    super.key,
    required this.hireId,
    required this.agentId,
  });

  final int hireId;

  /// The registry id of the hiring agent.
  final int agentId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final wallet = AppScope.of(context).wallet;
    return SingleChildScrollView(
      child: ContentWidth(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Puls3Spacing.xl),
          child: ListenableBuilder(
            listenable: wallet,
            builder: (context, _) {
              final owner = wallet.address;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.agentHireDetailTitle, style: Puls3Text.h3),
                  const SizedBox(height: Puls3Spacing.lg),
                  if (owner == null)
                    Text(
                      l10n.agentHireDetailConnect,
                      key: const Key('agent-hire-connect'),
                      style: Puls3Text.bodyMuted,
                    )
                  else
                    AgentHireTracker(
                      key: ValueKey('$agentId-$hireId-$owner'),
                      hiringAgentId: agentId,
                      hireId: hireId,
                      owner: owner,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
