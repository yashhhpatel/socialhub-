import 'dart:html' as html;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/api_social_accounts_repository.dart';
import '../../domain/entities/social_account.dart';
import '../../domain/entities/social_platform.dart';
import '../../domain/repositories/social_accounts_repository.dart';

/// `dart:html` is used directly (not `url_launcher`) specifically for
/// the full-page navigation in `connect()` below — see that method's
/// comment for why. Direct use is acceptable here without a conditional/
/// web-only import guard because this entire project targets Flutter
/// Web only (see docs/architecture — no mobile target exists).
class SocialAccountsController extends StateNotifier<AsyncValue<List<SocialAccount>>> {
  SocialAccountsController(this._repository) : super(const AsyncValue.loading()) {
    refresh();
  }

  final SocialAccountsRepository _repository;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.list());
  }

  Future<void> connect(SocialPlatform platform) async {
    final url = await _repository.getConnectUrl(platform);

    // Full-page navigation (NOT a new tab) to the OAuth provider's
    // consent screen, deliberately via window.location.href rather than
    // url_launcher (which defaults to opening a new tab/window on Flutter
    // Web). The backend's callback redirects this SAME tab back to
    // /settings once the OAuth flow completes — see
    // social_accounts_screen.dart's handling of the resulting query
    // params.
    html.window.location.href = url;
  }

  Future<void> disconnect(String accountId) async {
    await _repository.disconnect(accountId);
    await refresh();
  }
}

final socialAccountsControllerProvider = StateNotifierProvider<
    SocialAccountsController, AsyncValue<List<SocialAccount>>>((ref) {
  return SocialAccountsController(ref.watch(socialAccountsRepositoryProvider));
});
