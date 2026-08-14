import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/brand_kit/domain/entities/brand_kit.dart';

void main() {
  group('BrandKit.fromJson', () {
    test('parses colours, fonts and logo', () {
      final kit = BrandKit.fromJson({
        'id': 'bk_1',
        'colors': ['#112233', '#445566'],
        'fonts': ['Inter', 'Roboto'],
        'logoUrl': 'https://cdn.test/logo.png',
        'logoPublicId': 'socialhub/logo',
      });

      expect(kit.colors, ['#112233', '#445566']);
      expect(kit.fonts, ['Inter', 'Roboto']);
      expect(kit.logoUrl, 'https://cdn.test/logo.png');
    });

    test('defaults missing arrays to empty and logo to null', () {
      final kit = BrandKit.fromJson({'id': 'bk_1'});
      expect(kit.colors, isEmpty);
      expect(kit.fonts, isEmpty);
      expect(kit.logoUrl, isNull);
      expect(kit.isEmpty, isTrue);
    });
  });

  group('BrandKit derived accessors', () {
    test('primary/accent pick the first and second colours', () {
      const kit = BrandKit(id: 'x', colors: ['#111111', '#222222']);
      expect(kit.primaryColor, '#111111');
      expect(kit.accentColor, '#222222');
    });

    test('accent falls back to the primary when only one colour is set', () {
      const kit = BrandKit(id: 'x', colors: ['#111111']);
      expect(kit.accentColor, '#111111');
    });

    test('accessors are null on an empty kit', () {
      const kit = BrandKit(id: 'x');
      expect(kit.primaryColor, isNull);
      expect(kit.accentColor, isNull);
      expect(kit.primaryFont, isNull);
    });
  });
}
