import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/core/layout/widgets/notifications_icon.dart';
import 'package:socialhub/features/notifications/data/api_notifications_repository.dart';
import 'package:socialhub/features/notifications/domain/app_notification.dart';

/// Fake repo so the bell never touches the network.
class _FakeRepo implements ApiNotificationsRepository {
  _FakeRepo(this._items);
  final List<AppNotification> _items;
  bool markedAll = false;
  String? deletedId;

  @override
  Future<List<AppNotification>> list({int limit = 30}) async => _items;
  @override
  Future<int> unreadCount() async => _items.where((n) => !n.isRead).length;
  @override
  Future<void> markRead(String id) async {}
  @override
  Future<void> markAllRead() async => markedAll = true;
  @override
  Future<void> delete(String id) async => deletedId = id;
}

AppNotification _n({String id = 'n1', String title = 'Post published', bool read = false}) =>
    AppNotification(
      id: id,
      type: 'publish_succeeded',
      title: title,
      body: 'Your post was published to x.',
      linkPath: '/calendar',
      readAt: read ? DateTime(2026) : null,
      createdAt: DateTime(2026),
    );

Widget _host({required List<Override> overrides}) => ProviderScope(
      overrides: overrides,
      child: const MaterialApp(
        home: Scaffold(body: Center(child: NotificationsIcon())),
      ),
    );

void main() {
  test('AppNotification.fromJson parses fields + read state', () {
    final n = AppNotification.fromJson({
      'id': 'n1',
      'type': 'publish_failed',
      'title': 'Post failed',
      'body': 'oops',
      'linkPath': '/calendar',
      'readAt': null,
      'createdAt': '2026-08-21T00:00:00.000Z',
    });
    expect(n.type, 'publish_failed');
    expect(n.isRead, isFalse);
    expect(n.linkPath, '/calendar');
  });

  testWidgets('bell shows an unread badge', (tester) async {
    final overrides = <Override>[
      unreadNotificationsCountProvider.overrideWith((ref) async => 3),
    ];
    await tester.pumpWidget(_host(overrides: overrides));
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('caps the badge at 9+', (tester) async {
    final overrides = <Override>[
      unreadNotificationsCountProvider.overrideWith((ref) async => 42),
    ];
    await tester.pumpWidget(_host(overrides: overrides));
    await tester.pumpAndSettle();
    expect(find.text('9+'), findsOneWidget);
  });

  testWidgets('opening the bell lists notifications and marks all read',
      (tester) async {
    final repo = _FakeRepo([
      _n(title: 'Post published'),
      _n(id: 'n2', title: 'Invite accepted'),
    ]);
    final overrides = <Override>[
      notificationsRepositoryProvider.overrideWithValue(repo),
      unreadNotificationsCountProvider.overrideWith((ref) async => 2),
      notificationsListProvider.overrideWith((ref) async => repo.list()),
    ];
    await tester.pumpWidget(_host(overrides: overrides));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('Post published'), findsOneWidget);
    expect(find.text('Invite accepted'), findsOneWidget);
    expect(repo.markedAll, isTrue);
  });

  testWidgets('dismissing a notification deletes it via the repository',
      (tester) async {
    final repo = _FakeRepo([_n(title: 'Post failed')]);
    final overrides = <Override>[
      notificationsRepositoryProvider.overrideWithValue(repo),
      unreadNotificationsCountProvider.overrideWith((ref) async => 1),
      notificationsListProvider.overrideWith((ref) async => repo.list()),
    ];
    await tester.pumpWidget(_host(overrides: overrides));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();

    expect(repo.deletedId, 'n1');
  });

  testWidgets('shows the empty state when there are no notifications',
      (tester) async {
    final repo = _FakeRepo([]);
    final overrides = <Override>[
      notificationsRepositoryProvider.overrideWithValue(repo),
      unreadNotificationsCountProvider.overrideWith((ref) async => 0),
      notificationsListProvider.overrideWith((ref) async => <AppNotification>[]),
    ];
    await tester.pumpWidget(_host(overrides: overrides));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    expect(find.text("You're all caught up"), findsOneWidget);
  });
}
