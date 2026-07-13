import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_interceptor.dart';

/// Base URL is compile-time configurable via `--dart-define=API_BASE_URL=...`
/// (standard Flutter Web practice for per-environment builds — staging vs.
/// production point at different API hosts without a code change). Defaults
/// to local dev.
const _defaultBaseUrl = 'http://localhost:3000';
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: _defaultBaseUrl,
);

/// Single shared HTTP client for all REST calls, per docs/architecture —
/// Flutter Web Application Architecture, §10: one place for base URL and
/// default headers, so no feature independently reinvents its own HTTP
/// setup.
final apiClientProvider = Provider<Dio>((ref) {
  // A second, interceptor-free instance used only by AuthInterceptor
  // itself for the refresh call — see auth_interceptor.dart for why.
  final refreshDio = Dio(BaseOptions(baseUrl: apiBaseUrl));

  final dio = Dio(BaseOptions(baseUrl: apiBaseUrl));
  dio.interceptors.add(AuthInterceptor(ref, refreshDio));

  return dio;
});
