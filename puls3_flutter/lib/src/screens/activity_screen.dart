import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/app_scope.dart';
import '../state/notification_center.dart';
import '../theme/puls3_theme.dart';
import '../ui/atoms/content_width.dart';
import '../ui/molecules/screen_header.dart';

/// `/activity`: deploys, hires, payments and ratings, newest first.
class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final center = AppScope.of(context).notifications;
    final compact = isCompactLayout(context);
    return ListenableBuilder(
      listenable: center,
      builder: (context, _) {
        final items = center.items;
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ContentWidth(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: compact ? Puls3Spacing.md : Puls3Spacing.xl,
                    bottom: Puls3Spacing.md,
                  ),
                  child: ScreenHeader(
                    title: 'Activity',
                    subtitle: center.unreadCount == 0
                        ? 'You are all caught up.'
                        : '${center.unreadCount} unread',
                    trailing: center.unreadCount == 0
                        ? null
                        : TextButton(
                            onPressed: center.markAllRead,
                            child: const Text('Mark all read'),
                          ),
                  ),
                ),
              ),
            ),
            if (items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyActivity(),
              )
            else
              SliverList.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const ContentWidth(
                  child: Divider(height: 1, color: Puls3Colors.hairline),
                ),
                itemBuilder: (context, i) {
                  final n = items[i];
                  return ContentWidth(
                    child: NotificationTile(
                      notification: n,
                      onTap: () {
                        center.markRead(n.id);
                        final route = n.route;
                        if (route != null) context.go(route);
                      },
                    ),
                  );
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: Puls3Spacing.lg)),
          ],
        );
      },
    );
  }
}

/// One notification: icon, title, one or two lines, relative time and an
/// unread dot.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
    this.now,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  /// For tests; defaults to the current time.
  final DateTime? now;

  static IconData iconFor(NotificationKind kind) => switch (kind) {
    NotificationKind.deploy => Icons.rocket_launch_outlined,
    NotificationKind.hire => Icons.handshake_outlined,
    NotificationKind.payment => Icons.payments_outlined,
    NotificationKind.rating => Icons.star_outline_rounded,
    NotificationKind.system => Icons.campaign_outlined,
  };

  static String relativeTime(DateTime time, DateTime now) {
    final d = now.difference(time);
    if (d.inMinutes < 1) return 'now';
    if (d.inHours < 1) return '${d.inMinutes}m';
    if (d.inDays < 1) return '${d.inHours}h';
    return '${d.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final n = notification;
    return InkWell(
      onTap: onTap,
      borderRadius: Puls3Radius.mdAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Puls3Spacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Puls3Colors.surface,
                border: Border.all(color: Puls3Colors.hairline),
              ),
              child: Icon(
                iconFor(n.kind),
                size: 20,
                color: n.read ? Puls3Colors.muted : Puls3Colors.lavender,
              ),
            ),
            const SizedBox(width: Puls3Spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Puls3Text.body.copyWith(
                            fontSize: 14,
                            fontWeight: n.read
                                ? FontWeight.w500
                                : FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: Puls3Spacing.xs),
                      Text(
                        relativeTime(n.time, now ?? DateTime.now()),
                        style: Puls3Text.bodyMuted.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    n.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Puls3Text.bodyMuted.copyWith(
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 20,
              child: n.read
                  ? null
                  : Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        key: const ValueKey('unread-dot'),
                        margin: const EdgeInsets.only(top: 6),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Puls3Colors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.notifications_none_rounded,
            size: 32,
            color: Puls3Colors.muted,
          ),
          const SizedBox(height: Puls3Spacing.sm),
          Text(
            'No activity yet',
            style: Puls3Text.title.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 2),
          Text(
            'Deploys, hires and payments will show up here.',
            style: Puls3Text.bodyMuted.copyWith(fontSize: 14),
          ),
        ],
      ),
    );
  }
}
