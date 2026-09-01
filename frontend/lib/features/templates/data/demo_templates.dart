import '../domain/entities/template.dart';

/// Sample template gallery shown to signed-out visitors. Thumbnails are left
/// null (the card shows its placeholder) so the demo needs no external images.
/// Never shown once a session exists.
const demoTemplates = <TemplateSummary>[
  TemplateSummary(
    id: 'demo-t1',
    name: 'Product Launch',
    category: 'Promotions',
    thumbnailUrl: 'https://picsum.photos/seed/tpl-launch/600/600',
  ),
  TemplateSummary(
    id: 'demo-t2',
    name: 'Weekend Sale',
    category: 'Promotions',
    thumbnailUrl: 'https://picsum.photos/seed/tpl-sale/600/600',
  ),
  TemplateSummary(
    id: 'demo-t3',
    name: 'Quote of the Day',
    category: 'Engagement',
    thumbnailUrl: 'https://picsum.photos/seed/tpl-quote/600/600',
  ),
  TemplateSummary(
    id: 'demo-t4',
    name: 'Meet the Team',
    category: 'Brand',
    thumbnailUrl: 'https://picsum.photos/seed/tpl-team/600/600',
  ),
  TemplateSummary(
    id: 'demo-t5',
    name: 'Customer Review',
    category: 'Social proof',
    thumbnailUrl: 'https://picsum.photos/seed/tpl-review/600/600',
  ),
  TemplateSummary(
    id: 'demo-t6',
    name: 'Event Countdown',
    category: 'Announcements',
    thumbnailUrl: 'https://picsum.photos/seed/tpl-event/600/600',
  ),
];
