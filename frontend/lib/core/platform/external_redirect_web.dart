// Web implementation of [redirectToExternal]: navigates the SAME tab to the
// given URL via window.location.href — the Stripe-hosted Checkout/Portal page
// then replaces the app, and its return_url brings the user back. Deliberately
// not url_launcher, which opens a new tab on Flutter Web (matching how the
// OAuth connect flow already redirects).
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void redirectToExternal(String url) {
  html.window.location.href = url;
}
