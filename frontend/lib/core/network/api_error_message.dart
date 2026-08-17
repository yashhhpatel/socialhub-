import 'package:dio/dio.dart';

/// Turns a thrown error into something worth showing a user.
///
/// The backend already returns a considered, human-readable `message` on
/// every failure (NestJS's standard error envelope — see
/// docs/SocialHub_REST_API_Design.md §0). Without this, that message is
/// discarded and Dio's own `toString()` is surfaced instead, which reads:
///
///   DioException [bad response]: This exception was thrown because the
///   response has a status code of 422 and RequestOptions.validateStatus
///   was configured to throw for this status code...
///
/// — three lines about Dio's internals and a link to MDN, in place of
/// "This asset has no rendered image yet." The user is told nothing about
/// what they did or what to do next.
///
/// Lives in core/network because every feature's error handling needs it,
/// and per docs/architecture §1 cross-cutting concerns belong in core/.
String describeApiError(Object error) {
  if (error is! DioException) return error.toString();

  // A 401 means "you need to be signed in" — the raw backend message
  // ("Unauthorized") reads like a failure the user caused. Say plainly what
  // to do instead, so every page that loads account data shows the same
  // friendly prompt when browsing signed out.
  if (error.response?.statusCode == 401) {
    return 'Please log in to view this.';
  }

  final data = error.response?.data;

  if (data is Map<String, dynamic>) {
    final message = data['message'];
    // class-validator returns an ARRAY of messages when several fields
    // fail at once (e.g. POST /content/assets/:id/variants with an empty
    // platforms list). Joining beats rendering "[Select at least one
    // platform.]" with the brackets showing.
    if (message is List) return message.join('\n');
    if (message is String) return message;
  }

  // No structured body — the request never reached the API (server down,
  // DNS, CORS, timeout). Say that, rather than leaking transport detail.
  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout =>
      'The server took too long to respond. Check your connection and try again.',
    DioExceptionType.connectionError =>
      'Could not reach the server. Is the backend running?',
    _ => error.message ?? 'Something went wrong. Please try again.',
  };
}
