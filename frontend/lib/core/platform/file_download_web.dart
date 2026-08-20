// Web implementation of [downloadTextFile]: hands the browser a text file to
// save via a Blob + temporary object URL and a synthetic anchor click.
// ignore: avoid_web_libraries_in_flutter
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void downloadTextFile({
  required String filename,
  required String content,
  String mimeType = 'application/json',
}) {
  final bytes = utf8.encode(content);
  final blob = html.Blob(<Object>[bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
