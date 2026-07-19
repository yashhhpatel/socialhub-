import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Owned by CanvasSurface's State (created in initState, disposed in
/// dispose) — NOT a Riverpod provider, since its lifecycle should be
/// tied exactly to one CanvasSurface widget instance, not shared or
/// externally managed.
///
/// `ensureLoaded` is safe to call every paint pass for the same URL —
/// already-cached or already-in-flight URLs are no-ops, so
/// CanvasPainter can simply call it unconditionally for every image
/// layer it encounters without needing its own bookkeeping.
class CanvasImageCache extends ChangeNotifier {
  final Map<String, ui.Image> _cache = {};
  final Set<String> _loading = {};
  bool _disposed = false;

  ui.Image? get(String url) => _cache[url];

  void ensureLoaded(String url) {
    if (_cache.containsKey(url) || _loading.contains(url)) return;
    _loading.add(url);

    final stream = NetworkImage(url).resolve(const ImageConfiguration());
    late ImageStreamListener listener;

    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        _loading.remove(url);
        stream.removeListener(listener);
        if (_disposed) return; // widget gone before the load finished
        _cache[url] = info.image;
        notifyListeners();
      },
      onError: (Object error, StackTrace? stackTrace) {
        _loading.remove(url);
        stream.removeListener(listener);
        // Left uncached — CanvasPainter falls back to a placeholder
        // rect for this layer rather than crashing the whole paint pass
        // over one bad image URL.
      },
    );

    stream.addListener(listener);
  }

  @override
  void dispose() {
    _disposed = true;
    _cache.clear();
    super.dispose();
  }
}
