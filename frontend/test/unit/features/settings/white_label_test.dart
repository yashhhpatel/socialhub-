import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/settings/domain/white_label.dart';

void main() {
  group('WhiteLabel.fromJson', () {
    test('parses logo and colour', () {
      final wl = WhiteLabel.fromJson({'logoUrl': 'https://cdn/x.png', 'primaryColor': '#1A2B3C'});
      expect(wl.logoUrl, 'https://cdn/x.png');
      expect(wl.primaryColorHex, '#1A2B3C');
      expect(wl.primaryColor, const Color(0xFF1A2B3C));
      expect(wl.isEmpty, isFalse);
    });

    test('is empty when the org set no branding', () {
      final wl = WhiteLabel.fromJson({'logoUrl': null, 'primaryColor': null});
      expect(wl.isEmpty, isTrue);
      expect(wl.primaryColor, isNull);
    });
  });

  group('parseHexColor', () {
    test('parses #RRGGBB and shorthand #RGB', () {
      expect(parseHexColor('#FF0000'), const Color(0xFFFF0000));
      expect(parseHexColor('#f00'), const Color(0xFFFF0000));
    });

    test('moves CSS RRGGBBAA alpha to the front', () {
      expect(parseHexColor('#00FF0080'), const Color(0x8000FF00));
    });

    test('returns null on null or malformed input', () {
      expect(parseHexColor(null), isNull);
      expect(parseHexColor('not-a-color'), isNull);
      expect(parseHexColor('#12'), isNull);
    });
  });
}
