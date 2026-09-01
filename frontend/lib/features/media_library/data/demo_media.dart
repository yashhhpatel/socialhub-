import '../domain/media_item.dart';

/// Sample media library shown to signed-out visitors. Thumbnails use a public
/// seeded placeholder-image service so the grid looks like a real library;
/// each falls back to the card's icon if it can't load (e.g. offline). Never
/// shown once a session exists.
const demoMediaItems = <MediaItem>[
  MediaItem(
    id: 'demo-m1',
    url: 'https://picsum.photos/seed/socialhub-launch/600/600',
    publicId: 'demo/launch',
    type: 'image',
    name: 'product-launch.jpg',
  ),
  MediaItem(
    id: 'demo-m2',
    url: 'https://picsum.photos/seed/socialhub-team/600/600',
    publicId: 'demo/team',
    type: 'image',
    name: 'team-photo.jpg',
  ),
  MediaItem(
    id: 'demo-m3',
    url: 'https://picsum.photos/seed/socialhub-sale/600/600',
    publicId: 'demo/sale',
    type: 'image',
    name: 'weekend-sale.png',
  ),
  MediaItem(
    id: 'demo-m4',
    url: 'https://picsum.photos/seed/socialhub-promo/600/600',
    publicId: 'demo/promo-reel',
    type: 'video',
    name: 'promo-reel.mp4',
    posterUrl: 'https://picsum.photos/seed/socialhub-promo/600/600',
  ),
  MediaItem(
    id: 'demo-m5',
    url: 'https://picsum.photos/seed/socialhub-quote/600/600',
    publicId: 'demo/quote',
    type: 'image',
    name: 'quote-card.png',
  ),
  MediaItem(
    id: 'demo-m6',
    url: 'https://picsum.photos/seed/socialhub-event/600/600',
    publicId: 'demo/event',
    type: 'image',
    name: 'event-banner.jpg',
  ),
  MediaItem(
    id: 'demo-m7',
    url: 'https://picsum.photos/seed/socialhub-bts/600/600',
    publicId: 'demo/bts',
    type: 'video',
    name: 'behind-the-scenes.mp4',
    posterUrl: 'https://picsum.photos/seed/socialhub-bts/600/600',
  ),
  MediaItem(
    id: 'demo-m8',
    url: 'https://picsum.photos/seed/socialhub-testimonial/600/600',
    publicId: 'demo/testimonial',
    type: 'image',
    name: 'testimonial.jpg',
  ),
];
