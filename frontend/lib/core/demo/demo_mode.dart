import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../network/auth_token_store.dart';

/// True when nobody is signed in.
///
/// In demo mode the app is a fully explorable product tour: every data
/// provider serves realistic sample content (so no page looks empty), and
/// every protected action routes to the login page instead of running.
/// The instant a real session exists this flips to false and the providers
/// swap back to live backend data — demo and real data are never mixed.
final demoModeProvider = Provider<bool>(
  (ref) => ref.watch(authTokenStoreProvider.select((t) => t == null)),
);

/// Gate for a protected action while browsing the demo. When signed out this
/// sends the user to login (preserving where they were) and returns true, so
/// the caller should stop; when signed in it returns false and the caller
/// proceeds with the real action.
bool redirectToLoginIfDemo(BuildContext context, WidgetRef ref) {
  if (!ref.read(demoModeProvider)) return false;
  final from = GoRouterState.of(context).uri.toString();
  context.go('/login?from=${Uri.encodeComponent(from)}');
  return true;
}
