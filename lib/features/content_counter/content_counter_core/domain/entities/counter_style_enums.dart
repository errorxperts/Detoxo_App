// Appearance enums for the reel-counter bubble and home-screen widgets.
//
// Each enum carries its wire token (the string persisted natively in
// `ContentCounterStore` or sent over the command channel) so (de)serialization
// is explicit and order-independent — mirroring the pattern in `enums.dart`.

/// The visual style of the floating counter bubble: one of six board designs.
/// Each is a shell (the circle's chrome) plus a face (what it shows), drawn
/// natively and mirrored by a Flutter preview; the colour always follows
/// today's DS-01 tier (`BubbleModel.tier`). A stored style that is no longer
/// offered (NEON, STEPS, WEATHER, OUTLINE) reads back as [mascot].
enum BubbleVariant {
  mascot('MASCOT', 'Mascot'),
  ring('RING', 'Ring'),
  liquid('LIQUID', 'Liquid'),
  hourglass('HOURGLASS', 'Hourglass'),
  bezel('BEZEL', 'Bezel'),
  drop('DROP', 'Drop');

  const BubbleVariant(this.wire, this.label);
  final String wire;

  /// Display name in the app.
  final String label;

  static BubbleVariant fromWire(String? v) =>
      values.firstWhere((e) => e.wire == v, orElse: () => BubbleVariant.mascot);
}

/// The glass background treatment of the block screen (`BlockScreenStyle`).
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

/// The seven home-screen widget families (Widget Rules DS-10). Each is one
/// native provider plus one face per language; [wire] names it on the channel,
/// in the widget tap and in analytics.
enum WidgetFamily {
  count('COUNT', 'Count', 'Today at a glance. The tile colour is the tier.'),
  nextColour(
    'NEXT_COLOUR',
    'Next colour',
    'The ring fills over each block of 100 reels, then the tile changes colour.',
  ),
  timeLimit(
    'TIME_LIMIT',
    'Time limit',
    "Watch time left in today's limit, in twelve segments.",
  ),
  rhythm(
    'RHYTHM',
    'Rhythm',
    "When today's scrolling happened, hour by hour, with the peak hour called out.",
  ),
  bonsai(
    'BONSAI',
    'Bonsai',
    'A living tree on a neutral tile. It loses a stage every 100 reels, from Blooming to Leafless.',
  ),
  bento(
    'BENTO',
    'Bento',
    'A neutral shell with modules. The count module carries the tier colour; the rest stay calm.',
  ),
  plan(
    'PLAN',
    'Plan',
    'Whether blocking is on right now, and which plan is running. A pause counts down.',
  );

  const WidgetFamily(this.wire, this.label, this.blurb);
  final String wire;

  /// Display name in the app (the rail). The Android picker's names are
  /// native, `res/values/strings.xml` `widget_label_*`.
  final String label;

  /// The one muted line describing the family in the app.
  final String blurb;

  static WidgetFamily fromWire(String? v) =>
      values.firstWhere((e) => e.wire == v, orElse: () => WidgetFamily.count);
}

/// A home-widget size class (DS-04). Native picks it per instance from the
/// launcher cell; in the app it is the preview's size switch. Its design box
/// lives with the drawing code (`WidgetSizeGeometry`).
enum WidgetSize {
  small('SMALL', 'Small'),
  medium('MEDIUM', 'Medium'),
  large('LARGE', 'Large');

  const WidgetSize(this.wire, this.label);
  final String wire;
  final String label;

  static WidgetSize fromWire(String? v) =>
      values.firstWhere((e) => e.wire == v, orElse: () => WidgetSize.small);
}
