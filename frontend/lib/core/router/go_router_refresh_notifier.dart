import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/auth_token_store.dart';

/// Notifies GoRouter to re-run its `redirect` callback whenever the
/// token store changes, WITHOUT recreating the GoRouter instance itself.
///
/// Deliberately watches `authTokenStoreProvider` (core/network), not
/// `authControllerProvider` (features/auth) — per the architecture doc's
/// DI rule, core/ never depends on a feature. "Do we currently hold
/// tokens" is also the more correct signal for a route guard specifically
/// (gating on raw credential presence, not on higher-level UI state like
/// "is a login form currently submitting").
class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(Ref ref) {
    ref.listen<AuthTokens?>(authTokenStoreProvider, (previous, next) {
      final wasAuthenticated = previous != null;
      final isAuthenticated = next != null;
      if (wasAuthenticated != isAuthenticated) {
        notifyListeners();
      }
    });
  }
}
