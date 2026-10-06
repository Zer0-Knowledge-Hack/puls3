import 'package:flutter/material.dart';

import '../../../deploy/deploy_flow_controller.dart';
import '../../../theme/puls3_theme.dart';

/// Compact, mobile-first type for the deploy flow, built on the Puls3
/// fonts: 20 px title, 16 px subtitle, 14 px body, 12 px caption.
abstract final class DeployText {
  static TextStyle get title =>
      Puls3Text.h3.copyWith(fontSize: 20, fontWeight: FontWeight.w600);

  static TextStyle get subtitle => Puls3Text.title.copyWith(fontSize: 16);

  static TextStyle get body =>
      Puls3Text.body.copyWith(fontSize: 14, height: 1.45);

  static TextStyle get bodyMuted =>
      Puls3Text.bodyMuted.copyWith(fontSize: 14, height: 1.45);

  static TextStyle get caption =>
      Puls3Text.bodyMuted.copyWith(fontSize: 12, height: 1.4);
}

/// What each step shows: in the step list and in the current-step card.
class DeployStepCopy {
  const DeployStepCopy({
    required this.label,
    required this.description,
    required this.icon,
    required this.headline,
    required this.message,
    this.waitingLabel,
  });

  /// Name in the step list.
  final String label;

  /// One line under the active step.
  final String description;
  final IconData icon;

  /// Title of the current-step card.
  final String headline;

  /// One line in the current-step card.
  final String message;

  /// Extra status line while the step waits on the user.
  final String? waitingLabel;

  static const of = <DeployStep, DeployStepCopy>{
    DeployStep.preparing: DeployStepCopy(
      label: 'Preparing',
      description: 'Building the registration',
      icon: Icons.inventory_2_outlined,
      headline: 'Preparing deployment',
      message: 'Preparing your agent for Stellar.',
    ),
    DeployStep.awaitingSignature: DeployStepCopy(
      label: 'Waiting for signature',
      description: 'Approve it in your wallet',
      icon: Icons.account_balance_wallet_outlined,
      headline: 'Wallet signature',
      message: 'Confirm the transaction in your wallet.',
      waitingLabel: 'Waiting for confirmation…',
    ),
    DeployStep.registering: DeployStepCopy(
      label: 'Registering on-chain',
      description: 'Writing to Stellar testnet',
      icon: Icons.link_rounded,
      headline: 'Registering agent',
      message: 'Your agent is being registered on Stellar.',
    ),
    DeployStep.activating: DeployStepCopy(
      label: 'Activating',
      description: 'Binding its wallet and publishing',
      icon: Icons.bolt_rounded,
      headline: 'Activating agent',
      message: 'Almost there…',
    ),
    DeployStep.live: DeployStepCopy(
      label: 'Live',
      description: 'Ready to be hired',
      icon: Icons.rocket_launch_outlined,
      headline: 'Agent deployed',
      message: 'Your agent is now live on Stellar.',
    ),
  };
}

/// A human message and its recovery action for each error kind.
class DeployErrorCopy {
  const DeployErrorCopy({
    required this.title,
    required this.message,
    required this.action,
    required this.icon,
  });

  final String title;
  final String message;
  final String action;
  final IconData icon;

  static const of = <DeployErrorKind, DeployErrorCopy>{
    DeployErrorKind.signatureRejected: DeployErrorCopy(
      title: 'Signature rejected',
      message: 'The deployment was cancelled in your wallet.',
      action: 'Try again',
      icon: Icons.block_rounded,
    ),
    DeployErrorKind.walletUnavailable: DeployErrorCopy(
      title: 'Wallet not available',
      message: 'Open or unlock your wallet, then try again.',
      action: 'Try again',
      icon: Icons.account_balance_wallet_outlined,
    ),
    DeployErrorKind.wrongNetwork: DeployErrorCopy(
      title: 'Wrong network',
      message: 'Switch your wallet to Stellar Testnet, then try again.',
      action: 'Try again',
      icon: Icons.swap_horiz_rounded,
    ),
    DeployErrorKind.accountChanged: DeployErrorCopy(
      title: 'Wallet account changed',
      message: 'We will prepare a new transaction for the current account.',
      action: 'Use current account',
      icon: Icons.manage_accounts_outlined,
    ),
    DeployErrorKind.transactionFailed: DeployErrorCopy(
      title: 'Deployment failed',
      message: 'The transaction could not be completed. No agent was created.',
      action: 'Try again',
      icon: Icons.error_outline_rounded,
    ),
    DeployErrorKind.connection: DeployErrorCopy(
      title: 'Connection lost',
      message: 'Check your connection and try again. Finished steps are kept.',
      action: 'Retry',
      icon: Icons.wifi_off_rounded,
    ),
    DeployErrorKind.invalidResponse: DeployErrorCopy(
      title: 'Unexpected response',
      message: 'We could not verify the server answer, so we stopped here.',
      action: 'Retry',
      icon: Icons.gpp_maybe_outlined,
    ),
    DeployErrorKind.backendError: DeployErrorCopy(
      title: 'Something went wrong',
      message:
          "We couldn't complete the deployment. Check your connection and "
          'try again.',
      action: 'Retry',
      icon: Icons.cloud_off_rounded,
    ),
  };
}
