import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

/// Startup sequence for the app.
///
/// Kept separate from main.dart so future milestones (global error
/// handling in Phase 6, env-based DI composition in Phase 1+) have a single,
/// obvious place to hook in — main.dart itself should stay a one-line call
/// to bootstrap().
void bootstrap() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const ProviderScope(
      child: SocialHubApp(),
    ),
  );
}
