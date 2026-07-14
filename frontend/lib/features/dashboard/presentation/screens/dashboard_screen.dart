import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../../auth/presentation/state/auth_controller.dart';

/// Deliberately minimal. Built ahead of schedule (see route_guards.dart's
/// doc comment for why) purely so there's a real, authenticated
/// destination to land on and guard — not a stand-in for Phase 3's actual
/// dashboard/editor experience.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).session;

    return Scaffold(
      appBar: AppBar(title: const Text('SocialHub')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Welcome, ${session?.email ?? ''}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: SpacingTokens.sm),
            Text(
              'Role: ${session?.role ?? '—'}  ·  Org: ${session?.orgId ?? '—'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: SpacingTokens.xl),
            OutlinedButton(
              onPressed: () => ref.read(authControllerProvider.notifier).logout(),
              child: const Text('Log out'),
            ),
          ],
        ),
      ),
    );
  }
}
