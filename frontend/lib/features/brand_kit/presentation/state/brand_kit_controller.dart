import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/auth_token_store.dart';
import '../../data/repositories/api_brand_kit_repository.dart';
import '../../domain/entities/brand_kit.dart';

/// The org's brand kit (Milestone 9.3). A plain FutureProvider — the kit
/// changes rarely (it's edited by hand in the settings screen), so it's
/// fetched on demand and invalidated after an edit rather than kept in a
/// live subscription.
///
/// Re-evaluates on login/logout (watching only whether a token exists) so
/// browsing this page signed out doesn't cache a 401 that then hides the
/// content after the user logs in.
final brandKitProvider = FutureProvider<BrandKit>((ref) async {
  ref.watch(authTokenStoreProvider.select((tokens) => tokens != null));
  return ref.watch(brandKitRepositoryProvider).get();
});
