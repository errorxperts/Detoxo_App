// Appearance enums for the reel-counter bubble and home-screen widget.
//
// Each enum carries its wire token (the string persisted natively in
// `ContentCounterStore` and sent over the command channel) so (de)serialization
// is explicit and order-independent — mirroring the pattern in `enums.dart`.

/// The visual style of the floating counter bubble. Every variant is drawn
/// natively (Canvas) and mirrored by a Flutter preview; two variants react to
/// today's count via the shared usage ladder.
enum BubbleVariant {
  /// Refined dark-glass circle: seed→accent gradient ring, mint glow, centered
  /// count. The default, brand-forward look.
  glassOrb('GLASS_ORB'),

  /// Glass bubble whose ring/fill color follows today's count (green→brown).
  usageRing('USAGE_RING'),

  /// Glass bubble showing an emoji that degrades happy→worst as the count grows,
  /// with a small count.
  emojiMood('EMOJI_MOOD'),

  /// Compact glass capsule: count text plus a small usage-colored dot.
  minimalPill('MINIMAL_PILL');

  const BubbleVariant(this.wire);
  final String wire;

  static BubbleVariant fromWire(String? v) =>
      values.firstWhere((e) => e.wire == v, orElse: () => BubbleVariant.glassOrb);
}

/// The glass background treatment of the home-screen widget bitmap.
enum WidgetBackground {
  /// Current dark glass: 0xFF171F33→0xFF0B1326 with a mint hairline.
  glassDark('GLASS_DARK'),

  /// Seed→accent tinted glass.
  glassBrand('GLASS_BRAND'),

  /// Flat opaque card fill (no gradient).
  solid('SOLID'),

  /// Background tinted by today's usage band (green→brown).
  usageTint('USAGE_TINT');

  const WidgetBackground(this.wire);
  final String wire;

  static WidgetBackground fromWire(String? v) => values.firstWhere(
    (e) => e.wire == v,
    orElse: () => WidgetBackground.glassDark,
  );
}

/// The widget's color scheme. [system] is resolved to the device's dark/light
/// mode natively at draw time (a widget has no Activity theme).
enum WidgetTheme {
  system('SYSTEM'),
  light('LIGHT'),
  dark('DARK');

  const WidgetTheme(this.wire);
  final String wire;

  static WidgetTheme fromWire(String? v) =>
      values.firstWhere((e) => e.wire == v, orElse: () => WidgetTheme.system);
}

/// The widget's information density (font scale + padding in the bitmap).
enum WidgetDensity {
  cozy('COZY'),
  compact('COMPACT');

  const WidgetDensity(this.wire);
  final String wire;

  static WidgetDensity fromWire(String? v) =>
      values.firstWhere((e) => e.wire == v, orElse: () => WidgetDensity.cozy);
}
