import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/app_scope.dart';
import '../state/wallet_controller.dart';
import '../studio/studio_gateway.dart';
import '../theme/puls3_theme.dart';
import '../ui/atoms/content_width.dart';
import '../ui/atoms/primary_button.dart';
import '../ui/molecules/empty_state.dart';
import '../ui/molecules/screen_header.dart';
import '../ui/organisms/my_agents_list.dart';
import '../ui/organisms/site_footer.dart';
import 'studio_deploy.dart';
import 'wallet_sheet.dart';

/// `/studio/agents` (S12, flow F11): the connected wallet's drafts and
/// deployed agents. The container: it loads them from the [StudioGateway]
/// and turns the row actions into navigation.
class MyAgentsScreen extends StatefulWidget {
  const MyAgentsScreen({super.key});

  @override
  State<MyAgentsScreen> createState() => _MyAgentsScreenState();
}

class _MyAgentsScreenState extends State<MyAgentsScreen> {
  WalletController? _wallet;
  String? _owner;
  List<StudioDraft>? _drafts;
  String? _error;
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wallet = AppScope.of(context).wallet;
    if (wallet != _wallet) {
      _wallet?.removeListener(_onWallet);
      _wallet = wallet..addListener(_onWallet);
      _syncOwner();
    }
  }

  @override
  void dispose() {
    _wallet?.removeListener(_onWallet);
    super.dispose();
  }

  void _onWallet() => setState(_syncOwner);

  /// Reloads for the connected wallet: another account has other agents.
  void _syncOwner() {
    final owner = _wallet?.address;
    if (owner == _owner) return;
    _owner = owner;
    _drafts = null;
    _error = null;
    _loading = owner != null;
    if (owner != null) _fetch(owner);
  }

  void _retry() {
    final owner = _owner;
    if (owner == null) return;
    setState(() => _loading = true);
    _fetch(owner);
  }

  Future<void> _fetch(String owner) async {
    final gateway = AppScope.of(context).studioGateway;
    List<StudioDraft>? drafts;
    String? error;
    try {
      drafts = await gateway.listDrafts(owner: owner);
    } on StudioGatewayException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'The server did not answer. Try again.';
    }
    if (!mounted || owner != _owner) return;
    setState(() {
      _loading = false;
      _error = error;
      if (drafts != null) _drafts = drafts;
    });
  }

  Future<void> _resume(StudioDraft draft) async {
    await deployStudioManifest(
      context,
      draft.manifest,
      draftId: draft.draftId,
      owner: _owner,
    );
    if (mounted) _retry();
  }

  @override
  Widget build(BuildContext context) {
    final owner = _owner;
    final gateway = AppScope.of(context).studioGateway;
    return SingleChildScrollView(
      child: Column(
        children: [
          ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: Puls3Spacing.xl),
                ScreenHeader(
                  title: 'My agents',
                  subtitle: gateway.isDemo
                      ? 'Your drafts and deployed agents. Demo: kept in '
                            'this browser tab only.'
                      : 'Your drafts and deployed agents.',
                  trailing: PrimaryButton(
                    key: const Key('my-agents-new'),
                    label: 'New agent',
                    icon: Icons.add_rounded,
                    variant: PrimaryButtonVariant.outline,
                    onPressed: () => context.go('/studio'),
                  ),
                ),
                const SizedBox(height: Puls3Spacing.xl),
                if (owner == null)
                  EmptyState(
                    key: const Key('my-agents-no-wallet'),
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Connect your wallet',
                    message: 'Your drafts and agents belong to your wallet.',
                    actionLabel: 'Connect wallet',
                    onAction: () => showWalletSheet(context),
                  )
                else
                  MyAgentsList(
                    drafts: _drafts,
                    loading: _loading,
                    error: _error,
                    onRetry: _retry,
                    onNewAgent: () => context.go('/studio'),
                    onContinue: (d) => context.go('/studio?draft=${d.draftId}'),
                    onResume: _resume,
                    onView: (d) => context.go('/agent/${d.agentId}'),
                    onEdit: (d) =>
                        context.go('/studio?draft=${d.draftId}&edit=1'),
                  ),
                const SizedBox(height: Puls3Spacing.xxl),
              ],
            ),
          ),
          const SiteFooter(),
        ],
      ),
    );
  }
}
