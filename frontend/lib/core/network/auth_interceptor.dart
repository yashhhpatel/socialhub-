import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_token_store.dart';

/// Attaches the current access token to every outgoing request, and
/// transparently refreshes-and-retries on a 401 — per docs/architecture —
/// Flutter Web Application Architecture, §10: "a feature's repository code
/// never has to know tokens exist."
///
/// Two things worth knowing about this implementation:
///
/// 1. It uses a SEPARATE Dio instance (`_refreshDio`, with no interceptors
///    attached) to make the actual POST /auth/refresh call. Using the same
///    Dio instance this interceptor is attached to would risk this
///    interceptor intercepting its own refresh call's 401 (if the refresh
///    token itself is invalid/expired) and recursing.
///
/// 2. Concurrent requests that all 401 at once (e.g. several widgets
///    fetching data right as the access token expires) must not each
///    trigger their own independent refresh call — that would race to
///    rotate the same refresh token multiple times, and per the backend's
///    reuse-detection (see docs/api/SocialHub_REST_API_Design.md, POST
///    /auth/refresh), a second rotation of an already-rotated token
///    revokes the ENTIRE session. `_refreshing` ensures only one refresh
///    is ever in flight; concurrent callers await the same Future.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._ref, this._refreshDio);

  final Ref _ref;
  final Dio _refreshDio;
  Future<bool>? _refreshing;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final tokens = _ref.read(authTokenStoreProvider);
    if (tokens != null) {
      options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final isRefreshCallItself = err.requestOptions.path.contains('/auth/refresh');

    if (!isUnauthorized || isRefreshCallItself) {
      handler.next(err);
      return;
    }

    final refreshed = await _refreshTokens();
    if (!refreshed) {
      // Refresh token is itself invalid/expired/revoked — the session is
      // genuinely over. Clear it so the rest of the app (once route
      // guards exist) can react, rather than holding onto dead tokens.
      _ref.read(authTokenStoreProvider.notifier).state = null;
      handler.next(err);
      return;
    }

    try {
      final tokens = _ref.read(authTokenStoreProvider)!;
      final retryOptions = err.requestOptions
        ..headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      final response = await _refreshDio.fetch(retryOptions);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  Future<bool> _refreshTokens() {
    return _refreshing ??= _performRefresh().whenComplete(() {
      _refreshing = null;
    });
  }

  Future<bool> _performRefresh() async {
    final currentTokens = _ref.read(authTokenStoreProvider);
    if (currentTokens == null) return false;

    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': currentTokens.refreshToken},
      );

      final data = response.data!;
      _ref.read(authTokenStoreProvider.notifier).state = AuthTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
      return true;
    } on DioException {
      return false;
    }
  }
}
