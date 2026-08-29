import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/templates/domain/entities/template.dart';

void main() {
  group('TemplateSummary.fromJson', () {
    test('parses card fields and tolerates a missing category/thumbnail', () {
      final t = TemplateSummary.fromJson({
        'id': 'tpl_1',
        'name': 'Promo square',
        'category': null,
        'thumbnailUrl': null,
      });
      expect(t.id, 'tpl_1');
      expect(t.name, 'Promo square');
      expect(t.category, isNull);
      expect(t.thumbnailUrl, isNull);
    });

    test('defaults isOwn to false when the flag is absent', () {
      final t = TemplateSummary.fromJson({'id': 'tpl_1', 'name': 'Promo'});
      expect(t.isOwn, isFalse);
    });

    test('parses isOwn when the backend marks the row as the caller\'s own', () {
      final t = TemplateSummary.fromJson({
        'id': 'tpl_1',
        'name': 'Promo',
        'isOwn': true,
      });
      expect(t.isOwn, isTrue);
    });
  });

  group('TemplateDetail.fromJson', () {
    test('carries the canvas payload for cloning into a new design', () {
      final t = TemplateDetail.fromJson({
        'id': 'tpl_1',
        'name': 'Promo square',
        'category': 'Promotions',
        'thumbnailUrl': 'https://cdn.test/thumb.png',
        'canvasJson': {'width': 1080, 'height': 1080, 'layers': <dynamic>[]},
      });
      expect(t.canvasJson['width'], 1080);
      expect(t.canvasJson['layers'], isEmpty);
      expect(t.category, 'Promotions');
    });
  });
}
