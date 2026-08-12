import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/core/network/api_error_message.dart';

DioException _withBody(Object? body, {int status = 422}) {
  final options = RequestOptions(path: '/content/assets/x/variants');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<Object?>(
      requestOptions: options,
      statusCode: status,
      data: body,
    ),
  );
}

void main() {
  group('describeApiError', () {
    test("surfaces the backend's message instead of Dio's internals", () {
      // The exact 422 a user hit by pressing "Generate variants" on a
      // design that had never been exported.
      final error = _withBody({
        'message': 'This asset has no rendered image yet. Save the design '
            'from the editor before generating platform variants.',
        'error': 'Unprocessable Entity',
        'statusCode': 422,
      });

      final result = describeApiError(error);

      expect(result, startsWith('This asset has no rendered image yet.'));
      expect(result, isNot(contains('DioException')));
      expect(result, isNot(contains('validateStatus')));
      expect(result, isNot(contains('developer.mozilla.org')));
    });

    test('joins the array class-validator returns for multi-field failures', () {
      final error = _withBody(
        {
          'message': ['Select at least one platform.', 'Unknown platform.'],
          'statusCode': 400,
        },
        status: 400,
      );

      final result = describeApiError(error);

      expect(result, 'Select at least one platform.\nUnknown platform.');
      // Not the raw list, brackets and all.
      expect(result, isNot(contains('[')));
    });

    test('explains a dead backend in plain language', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/health'),
        type: DioExceptionType.connectionError,
      );

      expect(describeApiError(error), contains('Could not reach the server'));
    });

    test('explains a timeout without leaking transport detail', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/health'),
        type: DioExceptionType.receiveTimeout,
      );

      expect(describeApiError(error), contains('took too long'));
    });

    test('falls back gracefully when the body is not the standard envelope', () {
      final error = _withBody('<html>502 Bad Gateway</html>', status: 502);
      expect(describeApiError(error), isNotEmpty);
    });

    test('passes non-Dio errors straight through', () {
      expect(describeApiError(StateError('boom')), contains('boom'));
    });
  });
}
