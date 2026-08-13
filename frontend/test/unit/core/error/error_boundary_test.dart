import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/core/error/error_boundary.dart';

void main() {
  group('installGlobalErrorHandling', () {
    /// Runs install, grabs the ErrorWidget.builder it registered, then puts
    /// the process-global handlers back immediately.
    ///
    /// flutter_test asserts ErrorWidget.builder is at its default when a test
    /// ends, so the global must not stay changed for the duration of a pump.
    /// Capturing the builder and restoring straight away lets us exercise the
    /// real installed fallback while keeping the framework's invariant.
    ErrorWidgetBuilder captureInstalledBuilder() {
      final savedBuilder = ErrorWidget.builder;
      final savedOnError = FlutterError.onError;

      installGlobalErrorHandling();
      final installed = ErrorWidget.builder;

      ErrorWidget.builder = savedBuilder;
      FlutterError.onError = savedOnError;
      return installed;
    }

    testWidgets('registers a fallback that renders friendly, actionable copy',
        (tester) async {
      final builder = captureInstalledBuilder();

      await tester.pumpWidget(
        builder(FlutterErrorDetails(exception: StateError('a layer blew up'))),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(
        find.textContaining('failed to load'),
        findsOneWidget,
        reason: 'the fallback should guide the user, not just say it broke',
      );
    });

    testWidgets('fallback is self-contained — renders with no MaterialApp ancestor',
        (tester) async {
      // ErrorWidget.builder can fire above MaterialApp, where there is no
      // Directionality/Theme. The fallback must still render rather than
      // throwing and looping.
      final builder = captureInstalledBuilder();

      await tester.pumpWidget(
        builder(FlutterErrorDetails(exception: Exception('bare'))),
      );

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('surfaces the concrete error only in debug builds', (tester) async {
      final builder = captureInstalledBuilder();

      await tester.pumpWidget(
        builder(FlutterErrorDetails(exception: StateError('SECRET_DETAIL_42'))),
      );

      // Tests run in debug, where surfacing the detail aids development; in a
      // release build the same fallback stays generic.
      if (kDebugMode) {
        expect(find.textContaining('SECRET_DETAIL_42'), findsOneWidget);
      } else {
        expect(find.textContaining('SECRET_DETAIL_42'), findsNothing);
      }
    });
  });
}
