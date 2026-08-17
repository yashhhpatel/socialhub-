import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the user's chosen theme mode.
///
/// Defaults to light — SocialHub's identity is the light-purple + white
/// premium design (soft lavender gradients, white surfaces). The dark
/// variant remains fully supported and toggleable from Settings; this only
/// sets the first-launch default.
///
/// NOTE: this is in-memory only for Milestone 0.2. Persisting the choice
/// across reloads requires `core/storage/local_store.dart`, which is
/// introduced in a later milestone (see docs/architecture — Flutter Web
/// Application Architecture, §5 and §9). Do not add persistence here yet.
class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.light);

  void toggle() {
    state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  }

  void setMode(ThemeMode mode) {
    state = mode;
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) => ThemeModeController(),
);
