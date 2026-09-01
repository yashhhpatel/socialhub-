import '../domain/entities/brand_kit.dart';

/// Sample brand kit shown to signed-out visitors so the colours, fonts and
/// logo sections look filled in. Never shown once a session exists.
const demoBrandKit = BrandKit(
  id: 'demo-brand-kit',
  colors: ['#6C5CE7', '#A29BFE', '#26D07C', '#FFB020'],
  fonts: ['Lato', 'Inter', 'Playfair Display'],
  logoUrl: 'https://picsum.photos/seed/socialhub-brand-logo/240/240',
);
