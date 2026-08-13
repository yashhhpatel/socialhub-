import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/error/error_boundary.dart';
import 'app.dart';

/// Startup sequence for the app.
///
/// Kept separate from main.dart so this milestone (global error handling,
/// Phase 6) has a single, obvious place to hook in — main.dart itself stays
/// a one-line call to bootstrap().
void bootstrap() {
  // runZonedGuarded is the outermost net: it catches errors thrown in async
  // callbacks that escape the widget tree entirely (a Future that rejects
  // with no await, a timer callback that throws). ensureInitialized and
  // runApp must both run INSIDE the same zone, or binding errors won't be
  // caught — hence the whole body sits in the guarded callback.
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();

      // Installs ErrorWidget.builder (graceful fallback for build failures)
      // and the FlutterError / PlatformDispatcher handlers. See
      // core/error/error_boundary.dart.
      installGlobalErrorHandling();

      runApp(
        const ProviderScope(
          child: SocialHubApp(),
        ),
      );
    },
    (Object error, StackTrace stack) {
      // Last resort — an async error no other handler caught. Logged rather
      // than swallowed silently; a real deployment wires this to Sentry in
      // Milestone 6.3.
      debugPrint('[error] uncaught (zone): $error');
    },
  );
}
