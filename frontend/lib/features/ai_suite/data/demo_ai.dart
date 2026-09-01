import '../domain/entities/best_time_slot.dart';

/// Sample "best times to post" shown to signed-out visitors so the AI
/// Assistant's recommendations look populated. Never shown once a session
/// exists.
const demoBestTimes = <BestTimeSlot>[
  BestTimeSlot(dayOfWeek: 2, hour: 13, averageEngagement: 8.4, sampleCount: 42),
  BestTimeSlot(dayOfWeek: 4, hour: 18, averageEngagement: 7.9, sampleCount: 38),
  BestTimeSlot(dayOfWeek: 6, hour: 11, averageEngagement: 7.1, sampleCount: 30),
  BestTimeSlot(dayOfWeek: 1, hour: 9, averageEngagement: 6.5, sampleCount: 27),
  BestTimeSlot(dayOfWeek: 5, hour: 20, averageEngagement: 6.2, sampleCount: 24),
];
