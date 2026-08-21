// Navigate the CURRENT browser tab to an external URL (e.g. Stripe Checkout /
// Billing Portal), resolved per platform via a conditional import — the same
// approach as core/platform/file_download and core/storage/key_value_store:
//
// - Web builds get the real implementation (window.location.href) from
//   external_redirect_web.dart, so the Stripe-hosted page replaces this tab and
//   its return_url can bring the user straight back.
// - Everything else (the Dart VM under `flutter test`) gets a no-op stub, so
//   importing this never drags `dart:html` into a non-web target.
export 'external_redirect_stub.dart'
    if (dart.library.html) 'external_redirect_web.dart';
