import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/social_accounts/domain/entities/social_account.dart';
import 'package:socialhub/features/social_accounts/domain/entities/social_platform.dart';
import 'package:socialhub/features/social_accounts/presentation/widgets/platform_connection_card.dart';

SocialAccount _account() => SocialAccount(
      id: 'sa1',
      platform: SocialPlatform.instagram,
      externalAccountId: 'ig_123',
      status: 'connected',
      expiresAt: null,
      createdAt: DateTime(2026),
    );

Future<void> _pump(WidgetTester tester, Widget card) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: card)),
    );

void main() {
  testWidgets('connected account shows the Connected pill and Disconnect',
      (tester) async {
    await _pump(
      tester,
      PlatformConnectionCard(
        platform: SocialPlatform.instagram,
        account: _account(),
        isConnecting: false,
        isDisconnecting: false,
        onConnect: () {},
        onDisconnect: () {},
      ),
    );

    expect(find.text('Instagram'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('ig_123'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Disconnect'), findsOneWidget);
  });

  testWidgets('unconnected platform shows Not connected and Connect',
      (tester) async {
    await _pump(
      tester,
      PlatformConnectionCard(
        platform: SocialPlatform.linkedin,
        account: null,
        isConnecting: false,
        isDisconnecting: false,
        onConnect: () {},
        onDisconnect: () {},
      ),
    );

    expect(find.text('LinkedIn'), findsOneWidget);
    expect(find.text('Not connected'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Connect'), findsOneWidget);
  });
}
