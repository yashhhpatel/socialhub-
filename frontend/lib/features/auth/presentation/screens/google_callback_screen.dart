import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../state/auth_controller.dart';
import '../widgets/auth_scaffold.dart';

/// Landing screen for the Google redirect. The backend has already verified
/// the sign-in server-side and handed us a single-use ticket in the URL; here
/// we swap it for a real session, then let the router send the user on.
///
/// No ticket, or a rejected/expired one, bounces to /login with an error the
/// login screen surfaces — never a dead end.
class GoogleCallbackScreen extends ConsumerStatefulWidget {
  const GoogleCallbackScreen({super.key, required this.ticket});

  final String? ticket;

  @override
  ConsumerState<GoogleCallbackScreen> createState() =>
      _GoogleCallbackScreenState();
}

class _GoogleCallbackScreenState extends ConsumerState<GoogleCallbackScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _complete());
  }

  Future<void> _complete() async {
    final router = GoRouter.of(context);
    final ticket = widget.ticket;
    if (ticket == null || ticket.isEmpty) {
      router.go('/login?error=google');
      return;
    }

    final error =
        await ref.read(authControllerProvider.notifier).loginWithGoogleTicket(ticket);
    if (!mounted) return;

    if (error == null) {
      // Success — root redirects an authenticated user on to /dashboard.
      router.go('/');
    } else {
      router.go('/login?error=google');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const AuthScaffold(
      title: 'Signing you in…',
      subtitle: 'Completing your Google sign-in.',
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: SpacingTokens.lg),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
