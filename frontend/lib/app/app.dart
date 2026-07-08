import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/router/app_router.dart';
import '../core/theme/dark_theme.dart';
import '../core/theme/light_theme.dart';
import '../core/theme/theme_mode_controller.dart';

/// Root widget of the application. Composes theme + router. No feature
/// knowledge lives here — this file should not need to change as features
/// are added in later milestones.
class SocialHubApp extends ConsumerWidget {
  const SocialHubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'SocialHub',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
