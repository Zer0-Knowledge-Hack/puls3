import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:puls3_domain/puls3_domain.dart' show ModelPolicy, OutputType;

import '../studio/studio_gateway.dart';
import '../theme/breakpoints.dart';
import '../theme/puls3_theme.dart';
import '../ui/organisms/playground_panel.dart';

/// Container of the S11 playground (flow F9): runs a saved draft through the
/// [StudioGateway] and maps its answers and errors to [PlaygroundPanel].
class Playground extends StatefulWidget {
  const Playground({
    super.key,
    required this.draft,
    required this.gateway,
    required this.owner,
    this.onDeploy,
    this.onClose,
  });

  final StudioDraft draft;
  final StudioGateway gateway;

  /// The connected wallet that owns [draft].
  final String owner;
  final VoidCallback? onDeploy;
  final VoidCallback? onClose;

  @override
  State<Playground> createState() => _PlaygroundState();
}

class _PlaygroundState extends State<Playground> {
  final _input = TextEditingController();
  final _secret = TextEditingController();
  final _accountId = TextEditingController();
  PlaygroundStatus _status = PlaygroundStatus.idle;
  TestRunResult? _result;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    _secret.dispose();
    _accountId.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _status = PlaygroundStatus.running;
      _error = null;
    });
    try {
      if (!widget.gateway.isDemo) {
        final provider = widget.draft.manifest.model?.provider;
        if (provider == null) {
          throw const StudioUnavailable('The test runner is unavailable.');
        }
        await widget.gateway.saveProviderCredential(
          provider: provider,
          secret: _secret.text,
          accountId: provider == ModelPolicy.freeProvider
              ? _accountId.text.trim()
              : null,
          owner: widget.owner,
        );
      }
      final result = await widget.gateway.testRun(
        widget.draft.draftId,
        _input.text,
        owner: widget.owner,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _status = PlaygroundStatus.result;
      });
    } on StudioTestQuotaExceeded catch (e) {
      if (!mounted) return;
      setState(() {
        _status = PlaygroundStatus.quotaExceeded;
        _error = _quotaMessage(e.resetsAt);
      });
    } on StudioGatewayException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = PlaygroundStatus.failed;
        _error = switch (e) {
          StudioUnavailable() => 'The test runner is unavailable.',
          _ => e.message,
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = PlaygroundStatus.failed;
        _error = 'The test runner is unavailable.';
      });
    }
  }

  String _quotaMessage(DateTime? resetsAt) {
    if (resetsAt == null) return 'You used today\'s test runs.';
    final local = resetsAt.toLocal();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    return 'You used today\'s test runs. They reset at $time.';
  }

  Future<void> _copy() async {
    final output = _result?.output;
    if (output == null) return;
    await Clipboard.setData(ClipboardData(text: output));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(const SnackBar(content: Text('Output copied')));
  }

  @override
  Widget build(BuildContext context) {
    final manifest = widget.draft.manifest;
    return PlaygroundPanel(
      inputController: _input,
      inputMaxChars: manifest.inputMaxChars ?? 0,
      status: _status,
      onRun: _run,
      onRetry: _run,
      output: _result?.output,
      markdown: manifest.outputType == OutputType.markdown,
      remainingDailyRuns: _result?.remainingDailyRuns,
      errorMessage: _error,
      isDemo: widget.gateway.isDemo,
      credentialSecret: widget.gateway.isDemo ? null : _secret,
      credentialAccountId:
          widget.gateway.isDemo ||
              widget.draft.manifest.model?.provider != ModelPolicy.freeProvider
          ? null
          : _accountId,
      onCopy: _copy,
      onClose: widget.onClose,
      onDeploy: widget.onDeploy,
    );
  }
}

/// Opens the playground as a bottom sheet (phones, F9-1).
Future<void> showPlaygroundSheet(
  BuildContext context, {
  required StudioDraft draft,
  required StudioGateway gateway,
  required String owner,
  VoidCallback? onDeploy,
}) {
  return showModalBottomSheet<void>(
    context: context,
    // Above the whole app, so the phone's bottom navigation bar does not
    // cover the end of the sheet.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Puls3Colors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(Puls3Radius.lg),
      ),
    ),
    builder: (sheetContext) {
      final narrow =
          MediaQuery.sizeOf(sheetContext).width < Puls3Breakpoints.narrowGutter;
      final gutter = narrow ? Puls3Spacing.md : Puls3Spacing.lg;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          gutter,
          gutter,
          gutter,
          gutter + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Playground(
          draft: draft,
          gateway: gateway,
          owner: owner,
          onClose: () => Navigator.of(sheetContext).pop(),
          onDeploy: onDeploy == null
              ? null
              : () {
                  Navigator.of(sheetContext).pop();
                  onDeploy();
                },
        ),
      );
    },
  );
}
