import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/api_brand_kit_repository.dart';
import '../../domain/entities/brand_kit.dart';

/// The org's brand kit (Milestone 9.3). A plain FutureProvider — the kit
/// changes rarely (it's edited by hand in the settings screen), so it's
/// fetched on demand and invalidated after an edit rather than kept in a
/// live subscription.
final brandKitProvider = FutureProvider<BrandKit>((ref) async {
  return ref.watch(brandKitRepositoryProvider).get();
});
