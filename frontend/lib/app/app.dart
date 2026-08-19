import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/auth_interceptor.dart';
import '../core/router/app_router.dart';
import '../core/theme/dark_theme.dart';
import '../core/theme/light_theme.dart';
import '../core/theme/theme_mode_controller.dart';
import '../features/settings/data/api_white_label_repository.dart';

/// Root widget of the application. Composes theme + router.
///
/// White-labeling (Milestone 15.4): if the signed-in org has a brand colour,
/// it overrides the theme's primary across the whole app shell. Applied here
/// so it reaches every screen at once. Absent/loading/error branding falls
/// back to the default theme — branding is strictly additive.
class SocialHubApp extends ConsumerWidget {
  const SocialHubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final brandColor =
        ref.watch(whiteLabelProvider).valueOrNull?.primaryColor;

    // When a signed-out (or expired) user tries to use a feature that needs
    // an account, the AuthInterceptor bumps this signal — send them to log
    // in, remembering where they were so we can return them afterwards. Done
    // here, at the composition root, so the interceptor itself stays free of
    // any router dependency.
    ref.listen<int>(loginRequiredSignalProvider, (_, __) {
      final loc = router.routeInformationProvider.value.uri.toString();
      final onAuthScreen =
          loc.startsWith('/login') || loc.startsWith('/register');
      router.go(
        onAuthScreen ? '/login' : '/login?from=${Uri.encodeComponent(loc)}',
      );
    });

    return MaterialApp.router(
      title: 'SocialHub',
      debugShowCheckedModeBanner: false,
      theme: _branded(lightTheme, brandColor),
      darkTheme: _branded(darkTheme, brandColor),
      themeMode: themeMode,
      routerConfig: router,
    );
  }

  ThemeData _branded(ThemeData base, Color? primary) {
    if (primary == null) return base;
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(primary: primary),
    );
  }
}
