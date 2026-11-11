import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:puls3_client/puls3_client.dart' as api;

import '../theme/puls3_theme.dart';

/// Shows a new CLI session once (#259): [issue] creates it, the dialog shows
/// its refresh token with a copy button and a warning, and forgets it on
/// close. The token is never stored, logged or shown again.
Future<void> showCliSessionDialog(
  BuildContext context, {
  required Future<api.CliSessionGrant> Function() issue,
}) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (_) => CliSessionDialog(issue: issue),
  );
}

/// The dialog of [showCliSessionDialog].
class CliSessionDialog extends StatefulWidget {
  const CliSessionDialog({super.key, required this.issue});

  final Future<api.CliSessionGrant> Function() issue;

  @override
  State<CliSessionDialog> createState() => _CliSessionDialogState();
}

class _CliSessionDialogState extends State<CliSessionDialog> {
  late final Future<api.CliSessionGrant> _grant = widget.issue();
  var _copied = false;

  Future<void> _copy(String token) async {
    await Clipboard.setData(ClipboardData(text: token));
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Session for CLI'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: FutureBuilder<api.CliSessionGrant>(
          future: _grant,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text(
                key: ValueKey('cli-session-error'),
                'Could not create a CLI session. Your wallet stays signed in; '
                'try again.',
              );
            }
            final grant = snapshot.data;
            if (grant == null) {
              return const SizedBox(
                height: 64,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return _Grant(
              grant: grant,
              copied: _copied,
              onCopy: () => _copy(grant.refreshToken),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _Grant extends StatelessWidget {
  const _Grant({
    required this.grant,
    required this.copied,
    required this.onCopy,
  });

  final api.CliSessionGrant grant;
  final bool copied;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final expires = grant.expiresAt.toUtc().toIso8601String();
    return Column(
      key: const ValueKey('cli-session-grant'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Anyone with this token can act as your wallet in puls3 until '
          '$expires. Treat it like a password: do not share it, paste it '
          'in chat or commit it. It is shown only now.',
          style: Puls3Text.caption.copyWith(color: Puls3Colors.accent),
        ),
        const SizedBox(height: Puls3Spacing.sm),
        Container(
          padding: const EdgeInsets.all(Puls3Spacing.sm),
          decoration: BoxDecoration(
            color: Puls3Colors.surface,
            borderRadius: Puls3Radius.mdAll,
            border: Border.all(color: Puls3Colors.hairline),
          ),
          child: SelectableText(
            grant.refreshToken,
            key: const ValueKey('cli-session-token'),
            maxLines: 3,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        const SizedBox(height: Puls3Spacing.sm),
        OutlinedButton.icon(
          key: const ValueKey('cli-session-copy'),
          onPressed: onCopy,
          icon: Icon(copied ? Icons.check_rounded : Icons.copy_rounded),
          label: Text(copied ? 'Copied' : 'Copy token'),
        ),
        const SizedBox(height: Puls3Spacing.sm),
        const Text(
          'Then, in your terminal: export PULS3_REFRESH_TOKEN=<token>. Your '
          'app session is not affected.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
