import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/publish/data/repositories/api_caption_repository.dart';
import 'package:socialhub/features/publish/domain/repositories/caption_repository.dart';
import 'package:socialhub/features/publish/presentation/state/caption_controller.dart';

/// Records what it was asked for, and answers however the test needs.
class _FakeCaptionRepository implements CaptionRepository {
  _FakeCaptionRepository(this._respond);

  final Future<String> Function(String assetId, String? tone) _respond;

  final calls = <({String assetId, String? tone})>[];

  @override
  Future<String> generate({required String assetId, String? tone}) {
    calls.add((assetId: assetId, tone: tone));
    return _respond(assetId, tone);
  }
}

/// Builds the DioException the backend's QuotaGuard produces on 429.
DioException _quotaException({String? resetAt, int status = 429}) {
  return DioException(
    requestOptions: RequestOptions(path: '/ai/caption'),
    response: Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: '/ai/caption'),
      statusCode: status,
      data: {
        'statusCode': status,
        'error': 'Too Many Requests',
        'message': 'Your organization has used all 25 AI generations.',
        if (resetAt != null) 'resetAt': resetAt,
      },
    ),
    type: DioExceptionType.badResponse,
  );
}

void main() {
  late _FakeCaptionRepository repository;

  ProviderContainer containerWith(_FakeCaptionRepository repo) {
    final container = ProviderContainer(
      overrides: [captionRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return container;
  }

  CaptionController controllerOf(ProviderContainer container) =>
      container.read(captionControllerProvider.notifier);

  CaptionState stateOf(ProviderContainer container) =>
      container.read(captionControllerProvider);

  group('CaptionController generation', () {
    test('starts idle with nothing generated', () {
      repository = _FakeCaptionRepository((_, __) async => 'unused');
      expect(stateOf(containerWith(repository)).phase, CaptionPhase.idle);
    });

    test('exposes the generated caption on success', () async {
      repository = _FakeCaptionRepository((_, __) async => 'Sunday reset');
      final container = containerWith(repository);

      await controllerOf(container).generate(assetId: 'ast_1');

      expect(stateOf(container).phase, CaptionPhase.ready);
      expect(stateOf(container).caption, 'Sunday reset');
      expect(stateOf(container).error, isNull);
    });

    test('omits tone entirely when none is chosen', () async {
      repository = _FakeCaptionRepository((_, __) async => 'x');
      final container = containerWith(repository);

      await controllerOf(container).generate(assetId: 'ast_1');

      expect(repository.calls.single.tone, isNull);
    });

    test('passes the chosen tone through to the repository', () async {
      repository = _FakeCaptionRepository((_, __) async => 'x');
      final container = containerWith(repository);

      await controllerOf(container).generate(assetId: 'ast_1', tone: 'playful');

      expect(repository.calls.single.tone, 'playful');
      expect(repository.calls.single.assetId, 'ast_1');
    });

    test('regenerating replaces the previous caption', () async {
      var call = 0;
      repository = _FakeCaptionRepository((_, __) async => 'caption ${++call}');
      final container = containerWith(repository);

      await controllerOf(container).generate(assetId: 'ast_1');
      expect(stateOf(container).caption, 'caption 1');

      await controllerOf(container).generate(assetId: 'ast_1');
      expect(stateOf(container).caption, 'caption 2');
      expect(repository.calls.length, 2);
    });

    test('keeps the previous caption visible while regenerating', () async {
      // Losing the current text mid-request would discard something the
      // user may still want if the regeneration is worse — or fails.
      final gate = Completer<String>();
      var first = true;
      repository = _FakeCaptionRepository((_, __) async {
        if (first) {
          first = false;
          return 'original';
        }
        return gate.future;
      });
      final container = containerWith(repository);

      await controllerOf(container).generate(assetId: 'ast_1');
      final pending = controllerOf(container).generate(assetId: 'ast_1');

      expect(stateOf(container).phase, CaptionPhase.generating);
      expect(stateOf(container).caption, 'original');

      gate.complete('replacement');
      await pending;
      expect(stateOf(container).caption, 'replacement');
    });
  });

  group('CaptionController failures', () {
    test('surfaces a plain failure with the backend message', () async {
      repository = _FakeCaptionRepository(
        (_, __) async => throw DioException(
          requestOptions: RequestOptions(path: '/ai/caption'),
          response: Response<Map<String, dynamic>>(
            requestOptions: RequestOptions(path: '/ai/caption'),
            statusCode: 422,
            data: {'message': 'This design is empty.'},
          ),
          type: DioExceptionType.badResponse,
        ),
      );
      final container = containerWith(repository);

      await controllerOf(container).generate(assetId: 'ast_1');

      expect(stateOf(container).phase, CaptionPhase.failed);
      expect(stateOf(container).error, 'This design is empty.');
      expect(stateOf(container).resetAt, isNull);
    });

    test('keeps the last good caption after a failed regeneration', () async {
      var first = true;
      repository = _FakeCaptionRepository((_, __) async {
        if (first) {
          first = false;
          return 'the good one';
        }
        throw DioException(
          requestOptions: RequestOptions(path: '/ai/caption'),
          type: DioExceptionType.connectionError,
        );
      });
      final container = containerWith(repository);

      await controllerOf(container).generate(assetId: 'ast_1');
      await controllerOf(container).generate(assetId: 'ast_1');

      expect(stateOf(container).phase, CaptionPhase.failed);
      expect(stateOf(container).caption, 'the good one');
    });
  });

  group('CaptionController quota (429)', () {
    test('distinguishes a quota rejection from an ordinary failure', () async {
      repository = _FakeCaptionRepository(
        (_, __) async => throw _quotaException(resetAt: '2026-09-11T09:00:00.000Z'),
      );
      final container = containerWith(repository);

      await controllerOf(container).generate(assetId: 'ast_1');

      expect(stateOf(container).phase, CaptionPhase.quotaExceeded);
      expect(stateOf(container).error, contains('25 AI generations'));
    });

    test('parses resetAt so the panel can say when generation resumes', () async {
      repository = _FakeCaptionRepository(
        (_, __) async => throw _quotaException(resetAt: '2026-09-11T09:00:00.000Z'),
      );
      final container = containerWith(repository);

      await controllerOf(container).generate(assetId: 'ast_1');

      expect(
        stateOf(container).resetAt,
        DateTime.parse('2026-09-11T09:00:00.000Z'),
      );
    });

    test('degrades to a plain failure if a 429 arrives without resetAt', () async {
      // Tolerant on purpose: a drifted body must not throw inside the
      // error handler and lose the message entirely.
      repository = _FakeCaptionRepository((_, __) async => throw _quotaException());
      final container = containerWith(repository);

      await controllerOf(container).generate(assetId: 'ast_1');

      expect(stateOf(container).phase, CaptionPhase.failed);
      expect(stateOf(container).error, contains('25 AI generations'));
    });

    test('does not treat a non-429 carrying resetAt as a quota rejection', () async {
      repository = _FakeCaptionRepository(
        (_, __) async =>
            throw _quotaException(resetAt: '2026-09-11T09:00:00.000Z', status: 500),
      );
      final container = containerWith(repository);

      await controllerOf(container).generate(assetId: 'ast_1');

      expect(stateOf(container).phase, CaptionPhase.failed);
      expect(stateOf(container).resetAt, isNull);
    });
  });

  group('CaptionController reset', () {
    test('clears generated text and error state', () async {
      repository = _FakeCaptionRepository((_, __) async => 'something');
      final container = containerWith(repository);

      await controllerOf(container).generate(assetId: 'ast_1');
      controllerOf(container).reset();

      expect(stateOf(container).phase, CaptionPhase.idle);
      expect(stateOf(container).caption, isNull);
      expect(stateOf(container).error, isNull);
    });
  });
}
