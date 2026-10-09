import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/agent.dart';
import '../domain/stellar_explorer.dart';
import '../state/app_scope.dart';
import '../theme/puls3_theme.dart';
import '../ui/atoms/content_width.dart';
import '../ui/molecules/empty_state.dart';
import '../ui/molecules/error_banner.dart';
import '../ui/organisms/agent_detail_view.dart';
import '../ui/organisms/site_footer.dart';
import 'hire_sheet.dart';

/// Opens a URL outside the app; replaceable in tests.
typedef UrlOpener = Future<void> Function(Uri url);

Future<void> _launch(Uri url) async {
  await launchUrl(url, mode: LaunchMode.externalApplication);
}

enum _DetailStatus { loading, ready, notFound, error }

/// `/agent/:id` (S03, flow F3): the container. It reads the agent from the
/// server catalog (`agent.get`) and picks the state: loading, success, not
/// found, or an error with Retry. A cached copy is shown while it loads and,
/// with a warning, when the server cannot be reached; Hire stays disabled
/// until the agent is confirmed (docs/blueprints/flows.md, F3).
class AgentDetailScreen extends StatefulWidget {
  const AgentDetailScreen({
    super.key,
    required this.agentId,
    this.openUrl = _launch,
  });

  final String agentId;
  final UrlOpener openUrl;

  @override
  State<AgentDetailScreen> createState() => _AgentDetailScreenState();
}

class _AgentDetailScreenState extends State<AgentDetailScreen> {
  _DetailStatus _status = _DetailStatus.loading;
  Agent? _agent;
  bool _started = false;

  /// Bumped per request, so a stale answer never overwrites a newer one.
  int _request = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    unawaited(_load());
  }

  @override
  void didUpdateWidget(AgentDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.agentId != widget.agentId) {
      _agent = null;
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final catalog = AppScope.of(context).catalog;
    final id = widget.agentId;
    final request = ++_request;
    setState(() {
      _status = _DetailStatus.loading;
      _agent ??= catalog.byId(id);
    });
    try {
      final agent = await catalog.fetchAgent(id);
      if (!mounted || request != _request) return;
      setState(() {
        _agent = agent;
        _status = agent == null ? _DetailStatus.notFound : _DetailStatus.ready;
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      debugPrint('Agent detail: server load failed: $e');
      setState(() {
        _agent ??= catalog.byId(id);
        _status = _DetailStatus.error;
      });
    }
  }

  void _back() => context.go('/market');

  @override
  Widget build(BuildContext context) {
    final agent = _agent;
    final Widget body = switch (_status) {
      _DetailStatus.notFound => EmptyState(
        key: const ValueKey('detail-not-found'),
        icon: Icons.person_search_outlined,
        title: 'Agent not found',
        message:
            'No agent with this id is registered. It may have been '
            'removed, or the link is wrong.',
        actionLabel: 'Back to Marketplace',
        onAction: _back,
      ),
      _DetailStatus.loading when agent == null => AgentDetailSkeleton(
        key: const ValueKey('detail-loading'),
        onBack: _back,
      ),
      _DetailStatus.error when agent == null => Column(
        key: const ValueKey('detail-error'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: Puls3Spacing.xl),
          ErrorBanner(
            title: 'Could not load this agent',
            message:
                'The puls3 server did not answer. Check your '
                'connection and try again.',
            onRetry: () => unawaited(_load()),
          ),
          const SizedBox(height: Puls3Spacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _back,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Marketplace'),
            ),
          ),
          const SizedBox(height: Puls3Spacing.xxl),
        ],
      ),
      _ => _view(agent!),
    };
    return SingleChildScrollView(
      child: Column(
        children: [
          ContentWidth(child: body),
          const SiteFooter(),
        ],
      ),
    );
  }

  Widget _view(Agent agent) {
    final status = _status;
    return AgentDetailView(
      key: ValueKey('detail-$status'),
      agent: agent,
      onBack: _back,
      onHire: status == _DetailStatus.ready
          ? () => showHireSheet(context, agent)
          : null,
      hireNote: switch (status) {
        _DetailStatus.loading => 'Checking the agent on the server…',
        _DetailStatus.error => 'Hire is disabled until the agent loads.',
        _ => null,
      },
      onOpenExplorer: () => unawaited(
        widget.openUrl(
          Uri.parse(stellarExpertContractUrl(testnetIdentityRegistryAddress)),
        ),
      ),
      banner: status == _DetailStatus.error
          ? ErrorBanner(
              key: const ValueKey('detail-stale'),
              title: 'Showing the last known data',
              message:
                  'The puls3 server did not answer, so this agent '
                  'could not be confirmed.',
              onRetry: () => unawaited(_load()),
            )
          : null,
    );
  }
}
