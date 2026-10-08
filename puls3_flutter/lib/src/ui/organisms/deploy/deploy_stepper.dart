import 'package:flutter/material.dart';

import '../../../deploy/deploy_flow_controller.dart';
import '../../molecules/progress_step_row.dart';
import 'deploy_copy.dart';

/// The five deploy steps with their state: completed, in progress, failed
/// or pending. Presentational and reusable on any screen.
class DeployStepper extends StatelessWidget {
  const DeployStepper({super.key, required this.current, this.failed = false});

  /// The step in progress, or the one that failed.
  final DeployStep current;

  /// Whether [current] stopped with an error.
  final bool failed;

  StepStatus _statusOf(DeployStep step) {
    if (current == DeployStep.live) return StepStatus.done;
    if (step.index < current.index) return StepStatus.done;
    if (step.index > current.index) return StepStatus.pending;
    return failed ? StepStatus.failed : StepStatus.active;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final step in DeployStep.values)
          ProgressStepRow(
            key: ValueKey('deploy-step-${step.name}'),
            label: DeployStepCopy.of[step]!.label,
            description: DeployStepCopy.of[step]!.description,
            icon: DeployStepCopy.of[step]!.icon,
            status: _statusOf(step),
          ),
      ],
    );
  }
}
