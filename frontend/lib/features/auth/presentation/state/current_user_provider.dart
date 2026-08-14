import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/current_user.dart';

/// The signed-in user from GET /users/me (Milestone 11.3).
///
/// A FutureProvider rather than reading AuthController's in-memory session:
/// this survives a hard page reload (it re-fetches via the persisted token)
/// and reflects the CURRENT role from the DB, so role-gated UI is correct
/// even right after someone's role changed. Cached for the session; invalidate
/// to force a refresh.
final currentUserProvider = FutureProvider<CurrentUser>((ref) async {
  final dio = ref.watch(apiClientProvider);
  final response = await dio.get<Map<String, dynamic>>('/users/me');
  return CurrentUser.fromJson(response.data!);
});
