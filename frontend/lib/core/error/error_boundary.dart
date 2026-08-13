import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Global error handling for the app (Milestone 6.1).
///
/// Two failure surfaces, handled together here:
///
/// 1. WIDGET BUILD ERRORS — an exception thrown inside a widget's build().
///    Flutter's default replaces the widget with a grey box (release) or a
///    red "error" panel (debug). `ErrorWidget.builder` swaps that for the
///    friendly [_ErrorFallback] below.
///
/// 2. UNCAUGHT ERRORS — framework errors (`FlutterError.onError`) and
///    uncaught async/platform errors (`PlatformDispatcher.onError`). These
///    would otherwise print to the console and vanish; here they are routed
///    through a single logger so nothing fails silently.
///
/// Call [installGlobalErrorHandling] once, before runApp — see bootstrap.dart.
void installGlobalErrorHandling() {
  // The fallback is self-contained (its own Directionality + surface) on
  // purpose: ErrorWidget.builder can fire for a widget mounted ABOVE
  // MaterialApp, where there is no Directionality/Theme ancestor. A fallback
  // that assumed those would throw while rendering the error — turning one
  // failure into an infinite loop of them.
  ErrorWidget.builder = (FlutterErrorDetails details) => _ErrorFallback(details: details);

  // Framework-caught errors (build/layout/paint). In debug, still dump the
  // full details to the console so development keeps its normal diagnostics;
  // in release, record a concise line. Either way the UI has already been
  // handled by ErrorWidget.builder above.
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) {
      FlutterError.presentError(details);
    } else {
      debugPrint('[error] ${details.exceptionAsString()}');
    }
    previousOnError?.call(details);
  };

  // Uncaught errors from outside the framework: async gaps, platform
  // channels, unhandled Futures. Returning true marks them handled so the
  // engine doesn't tear the isolate down.
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('[error] uncaught: $error');
    return true;
  };
}

/// The graceful fallback shown in place of a widget that failed to build.
///
/// Deliberately dependency-free: no Riverpod, no theme lookup, no router —
/// anything it needed could itself be the thing that just broke. It shows
/// the concrete error text only in debug; in release it stays generic.
class _ErrorFallback extends StatelessWidget {
  const _ErrorFallback({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: const Color(0xFFF8F9FB),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 44, color: Color(0xFFB00020)),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2430),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This part of the page failed to load. Try again, and if it '
              'keeps happening, reload the app.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF5B6270)),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 16),
              Text(
                details.exceptionAsString(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF9AA0AC)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
