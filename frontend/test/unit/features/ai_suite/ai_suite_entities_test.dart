import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/ai_suite/domain/entities/best_time_slot.dart';
import 'package:socialhub/features/ai_suite/domain/entities/viral_score.dart';

void main() {
  group('ViralScore.fromJson', () {
    test('parses score and rationale', () {
      final v = ViralScore.fromJson({'score': 82, 'rationale': 'Strong hook.'});
      expect(v.score, 82);
      expect(v.rationale, 'Strong hook.');
    });

    test('defaults a missing rationale to empty', () {
      expect(ViralScore.fromJson({'score': 10}).rationale, '');
    });
  });

  group('BestTimeSlot', () {
    test('parses all fields', () {
      final s = BestTimeSlot.fromJson({
        'dayOfWeek': 1,
        'hour': 9,
        'averageEngagement': 13.5,
        'sampleCount': 4,
      });
      expect(s.dayOfWeek, 1);
      expect(s.hour, 9);
      expect(s.averageEngagement, 13.5);
      expect(s.sampleCount, 4);
    });

    test('localLabel produces a weekday + time string', () {
      const s = BestTimeSlot(dayOfWeek: 1, hour: 9, averageEngagement: 1, sampleCount: 1);
      // Exact value depends on the runner's timezone, so assert the shape.
      expect(s.localLabel, matches(r'^(Sun|Mon|Tue|Wed|Thu|Fri|Sat) \d{1,2}:\d{2}$'));
    });
  });
}
