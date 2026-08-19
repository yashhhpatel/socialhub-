import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/auth_token_store.dart';
import '../../domain/entities/current_user.dart';

/// The signed-in user from GET /users/me (Milestone 11.3).
///
/// A FutureProvider rather than reading AuthController's in-memory session:
/// this survives a hard page reload (it re-fetches via the persisted token)
/// and reflects the CURRENT role from the DB, so role-gated UI is correct
/// even right after someone's role changed.
///
/// Re-evaluates whenever the user signs in or out: it watches only whether a
/// token EXISTS (not its value, so a silent token refresh doesn't refetch).
/// Without this, browsing a page like Team while signed out cached a 401 here
/// for the whole session, so the content stayed hidden even after logging in.
final currentUserProvider = FutureProvider<CurrentUser>((ref) async {
  // Rebuild on login/logout — not on token rotation.
  ref.watch(authTokenStoreProvider.select((tokens) => tokens != null));
  final dio = ref.watch(apiClientProvider);
  final response = await dio.get<Map<String, dynamic>>('/users/me');
  return CurrentUser.fromJson(response.data!);
});
