import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/agent.dart';
import '../domain/stellar_format.dart';
import '../state/app_scope.dart';
import '../state/profile_controller.dart';
import '../theme/puls3_theme.dart';
import '../ui/atoms/content_width.dart';
import '../ui/atoms/primary_button.dart';
import '../ui/atoms/section_label.dart';
import '../ui/molecules/agent_list_card.dart';
import '../ui/molecules/copyable_value_row.dart';
import '../ui/molecules/screen_header.dart';

/// `/profile`: wallet-first account. Connect the wallet, create a profile
/// (name, handle, bio), then see your agents and settings. No passwords.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final compact = isCompactLayout(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        scope.wallet,
        scope.profile,
        scope.catalog,
      ]),
      builder: (context, _) {
        final wallet = scope.wallet.address;
        final profile = scope.profile.profileFor(wallet);
        final Widget body;
        if (wallet == null) {
          body = _ConnectWallet(
            connecting: scope.wallet.isConnecting,
            onConnect: scope.wallet.connect,
          );
        } else if (profile == null || _editing) {
          body = ProfileForm(
            key: ValueKey(profile?.handle ?? 'new'),
            initial: profile,
            onSubmit: (name, handle, bio) {
              scope.profile.save(
                wallet: wallet,
                displayName: name,
                handle: handle,
                bio: bio,
              );
              setState(() => _editing = false);
            },
            onCancel: profile == null
                ? null
                : () => setState(() => _editing = false),
          );
        } else {
          final agents = [
            for (final id in scope.profile.agentIds) ?scope.catalog.byId(id),
          ];
          body = _ProfileView(
            profile: profile,
            agents: agents,
            unread: scope.notifications.unreadCount,
            onEdit: () => setState(() => _editing = true),
            onOpenAgent: (a) => context.go('/agent/${a.id}'),
            onDeploy: () => context.go('/studio'),
            onActivity: () => context.go('/activity'),
            onDisconnect: () async {
              await scope.wallet.disconnect();
              scope.profile.clear();
            },
          );
        }
        return SingleChildScrollView(
          child: ContentWidth(
            maxWidth: 640,
            child: Padding(
              padding: EdgeInsets.only(
                top: compact ? Puls3Spacing.md : Puls3Spacing.xl,
                bottom: Puls3Spacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ScreenHeader(
                    title: 'Profile',
                    subtitle: wallet == null
                        ? 'Your wallet is your account.'
                        : profile == null
                        ? 'Create your public profile.'
                        : 'Your agents, activity and settings.',
                  ),
                  const SizedBox(height: Puls3Spacing.lg),
                  body,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ConnectWallet extends StatelessWidget {
  const _ConnectWallet({required this.connecting, required this.onConnect});

  final bool connecting;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            size: 32,
            color: Puls3Colors.lavender,
          ),
          const SizedBox(height: Puls3Spacing.sm),
          Text(
            'Connect your wallet',
            textAlign: TextAlign.center,
            style: Puls3Text.title.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 2),
          Text(
            'puls3 never asks for a password or your secret key.',
            textAlign: TextAlign.center,
            style: Puls3Text.bodyMuted.copyWith(fontSize: 14),
          ),
          const SizedBox(height: Puls3Spacing.md),
          PrimaryButton(
            label: 'Connect wallet',
            icon: Icons.account_balance_wallet_outlined,
            expand: true,
            isLoading: connecting,
            onPressed: onConnect,
          ),
        ],
      ),
    );
  }
}

/// Create or edit a profile: display name, handle and a short bio.
class ProfileForm extends StatefulWidget {
  const ProfileForm({
    super.key,
    required this.onSubmit,
    this.initial,
    this.onCancel,
  });

  final Profile? initial;
  final void Function(String name, String handle, String bio) onSubmit;
  final VoidCallback? onCancel;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  late final _name = TextEditingController(text: widget.initial?.displayName);
  late final _handle = TextEditingController(text: widget.initial?.handle);
  late final _bio = TextEditingController(text: widget.initial?.bio);
  Set<ProfileProblem> _problems = const {};

  @override
  void dispose() {
    _name.dispose();
    _handle.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _submit() {
    final problems = ProfileController.validate(
      displayName: _name.text,
      handle: _handle.text,
      bio: _bio.text,
    );
    setState(() => _problems = problems);
    if (problems.isEmpty) widget.onSubmit(_name.text, _handle.text, _bio.text);
  }

  @override
  Widget build(BuildContext context) {
    final creating = widget.initial == null;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            creating ? 'Create your profile' : 'Edit profile',
            style: Puls3Text.title.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 2),
          Text(
            'Shown on your agents and hires. Linked to your wallet.',
            style: Puls3Text.bodyMuted.copyWith(fontSize: 13),
          ),
          const SizedBox(height: Puls3Spacing.md),
          TextField(
            key: const Key('profile-name'),
            controller: _name,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Display name',
              errorText: _problems.contains(ProfileProblem.nameEmpty)
                  ? 'Enter a name'
                  : _problems.contains(ProfileProblem.nameTooLong)
                  ? 'Use 40 characters or fewer'
                  : null,
            ),
          ),
          const SizedBox(height: Puls3Spacing.sm),
          TextField(
            key: const Key('profile-handle'),
            controller: _handle,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Username',
              prefixText: '@',
              errorText: _problems.contains(ProfileProblem.handleInvalid)
                  ? '3–20 letters, numbers or _'
                  : null,
            ),
          ),
          const SizedBox(height: Puls3Spacing.sm),
          TextField(
            key: const Key('profile-bio'),
            controller: _bio,
            maxLines: 3,
            minLines: 2,
            decoration: InputDecoration(
              labelText: 'Bio (optional)',
              errorText: _problems.contains(ProfileProblem.bioTooLong)
                  ? 'Use 160 characters or fewer'
                  : null,
            ),
          ),
          const SizedBox(height: Puls3Spacing.md),
          PrimaryButton(
            label: creating ? 'Create profile' : 'Save changes',
            icon: Icons.check_rounded,
            expand: true,
            onPressed: _submit,
          ),
          if (widget.onCancel != null)
            TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
        ],
      ),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView({
    required this.profile,
    required this.agents,
    required this.unread,
    required this.onEdit,
    required this.onOpenAgent,
    required this.onDeploy,
    required this.onActivity,
    required this.onDisconnect,
  });

  final Profile profile;
  final List<Agent> agents;
  final int unread;
  final VoidCallback onEdit;
  final ValueChanged<Agent> onOpenAgent;
  final VoidCallback onDeploy;
  final VoidCallback onActivity;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Puls3Colors.accent,
                    child: Text(
                      profile.initials,
                      style: Puls3Text.title.copyWith(
                        color: Puls3Colors.onAccent,
                      ),
                    ),
                  ),
                  const SizedBox(width: Puls3Spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Puls3Text.title.copyWith(fontSize: 17),
                        ),
                        Text(
                          '@${profile.handle}',
                          style: Puls3Text.bodyMuted.copyWith(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit profile',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                ],
              ),
              if (profile.bio.isNotEmpty) ...[
                const SizedBox(height: Puls3Spacing.sm),
                Text(
                  profile.bio,
                  style: Puls3Text.body.copyWith(fontSize: 14, height: 1.45),
                ),
              ],
              const SizedBox(height: Puls3Spacing.xs),
              CopyableValueRow(
                label: 'Wallet',
                value: profile.wallet,
                display: shortenAddress(profile.wallet, head: 6, tail: 6),
                copyLabel: 'Copy wallet address',
              ),
              const Divider(height: Puls3Spacing.lg),
              Row(
                children: [
                  _Stat(value: '${agents.length}', label: 'Agents'),
                  const _Stat(value: '0', label: 'Hires'),
                  const _Stat(value: 'Testnet', label: 'Network'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: Puls3Spacing.lg),
        const SectionLabel('My agents'),
        const SizedBox(height: Puls3Spacing.sm),
        if (agents.isEmpty)
          _Panel(
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome_outlined,
                  color: Puls3Colors.lavender,
                ),
                const SizedBox(width: Puls3Spacing.sm),
                Expanded(
                  child: Text(
                    'You have not deployed an agent yet.',
                    style: Puls3Text.bodyMuted.copyWith(fontSize: 14),
                  ),
                ),
                TextButton(onPressed: onDeploy, child: const Text('Create')),
              ],
            ),
          )
        else
          for (final agent in agents)
            Padding(
              padding: const EdgeInsets.only(bottom: Puls3Spacing.xs),
              child: AgentListCard(
                agent: agent,
                onTap: () => onOpenAgent(agent),
              ),
            ),
        const SizedBox(height: Puls3Spacing.lg),
        const SectionLabel('Settings'),
        const SizedBox(height: Puls3Spacing.sm),
        _Panel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _SettingTile(
                icon: Icons.notifications_none_rounded,
                label: 'Notifications',
                trailing: unread == 0 ? null : _CountBadge(count: unread),
                onTap: onActivity,
              ),
              const Divider(height: 1),
              const _SettingTile(
                icon: Icons.public_rounded,
                label: 'Network',
                trailing: Text('Stellar Testnet'),
              ),
              const Divider(height: 1),
              _SettingTile(
                icon: Icons.logout_rounded,
                label: 'Disconnect wallet',
                onTap: onDisconnect,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Puls3Text.title.copyWith(fontSize: 15),
          ),
          Text(label, style: Puls3Text.bodyMuted.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 52,
      leading: Icon(icon, size: 20, color: Puls3Colors.lavender),
      title: Text(label, style: Puls3Text.body.copyWith(fontSize: 14)),
      trailing: DefaultTextStyle.merge(
        style: Puls3Text.bodyMuted.copyWith(fontSize: 13),
        child:
            trailing ??
            (onTap == null
                ? const SizedBox.shrink()
                : const Icon(Icons.chevron_right_rounded)),
      ),
      onTap: onTap,
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: const BoxDecoration(
        color: Puls3Colors.accent,
        borderRadius: Puls3Radius.pillAll,
      ),
      child: Text(
        '$count',
        style: Puls3Text.caption.copyWith(color: Puls3Colors.onAccent),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.padding = const EdgeInsets.all(Puls3Spacing.md),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    // Material, not a decorated box, so list tiles inside show their ink.
    return Material(
      color: Puls3Colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: Puls3Radius.mdAll,
        side: BorderSide(color: Puls3Colors.hairline),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
