import 'package:flutter/foundation.dart';

/// What a notification is about; drives its icon.
enum NotificationKind { deploy, hire, payment, rating, system }

/// One entry in the Activity feed.
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.time,
    this.route,
    this.read = false,
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime time;

  /// Where tapping it navigates, e.g. `/agent/42`.
  final String? route;
  final bool read;

  AppNotification markRead() => AppNotification(
    id: id,
    kind: kind,
    title: title,
    body: body,
    time: time,
    route: route,
    read: true,
  );
}

/// In-memory Activity feed. The demo seeds it with sample events; the app
/// adds real ones (a deploy going live). A server feed replaces it later.
class NotificationCenter extends ChangeNotifier {
  NotificationCenter({List<AppNotification>? seed, DateTime Function()? now})
    : _now = now ?? DateTime.now,
      _items = seed ?? _demoSeed((now ?? DateTime.now)());

  final DateTime Function() _now;
  List<AppNotification> _items;
  var _next = 0;

  /// Newest first.
  List<AppNotification> get items => List.unmodifiable(_items);

  int get unreadCount => _items.where((n) => !n.read).length;

  void push({
    required NotificationKind kind,
    required String title,
    required String body,
    String? route,
  }) {
    _items = [
      AppNotification(
        id: 'local-${_next++}',
        kind: kind,
        title: title,
        body: body,
        time: _now(),
        route: route,
      ),
      ..._items,
    ];
    notifyListeners();
  }

  void markRead(String id) {
    _items = [for (final n in _items) n.id == id ? n.markRead() : n];
    notifyListeners();
  }

  void markAllRead() {
    if (unreadCount == 0) return;
    _items = [for (final n in _items) n.markRead()];
    notifyListeners();
  }

  static List<AppNotification> _demoSeed(DateTime now) => [
    AppNotification(
      id: 'demo-1',
      kind: NotificationKind.payment,
      title: 'Payment received',
      body: 'Ledger Scout earned 0.50 USDC for a completed task.',
      time: now.subtract(const Duration(minutes: 12)),
      route: '/agent/agt-001',
    ),
    AppNotification(
      id: 'demo-2',
      kind: NotificationKind.rating,
      title: 'New 5-star rating',
      body: 'A client rated Soroban Auditor: "Clear, fast audit."',
      time: now.subtract(const Duration(hours: 3)),
      route: '/agent/agt-003',
    ),
    AppNotification(
      id: 'demo-3',
      kind: NotificationKind.system,
      title: 'Welcome to puls3',
      body: 'Build an agent in Studio or hire one in the Marketplace.',
      time: now.subtract(const Duration(days: 1)),
      read: true,
    ),
  ];
}
