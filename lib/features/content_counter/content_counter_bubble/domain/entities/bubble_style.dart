import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_style_enums.dart';
import 'package:equatable/equatable.dart';

/// User-tunable appearance of the floating counter bubble.
///
/// Persisted natively in `ContentCounterStore` (as JSON) and pushed over the
/// command channel via [toWire]; the native `BubbleView` and the Flutter
/// `BubblePreview` both render from these fields. Ranges are enforced by the
/// editing sliders and re-clamped in [BubbleStyle.fromWire] so a malformed
/// payload can never produce an unusable bubble.
class BubbleStyle extends Equatable {
  const BubbleStyle({
    this.variant = BubbleVariant.glassOrb,
    this.size = sizeDefault,
    this.textScale = textScaleDefault,
    this.spacing = spacingDefault,
    this.opacity = opacityDefault,
    this.showLabel = false,
    this.showTime = true,
  });

  const BubbleStyle.defaults() : this();

  factory BubbleStyle.fromWire(Map<String, dynamic>? m) {
    if (m == null) return const BubbleStyle.defaults();
    return BubbleStyle(
      variant: BubbleVariant.fromWire(m['variant'] as String?),
      size: _clamp(m['size'], sizeMin, sizeMax, sizeDefault),
      textScale: _clamp(
        m['textScale'],
        textScaleMin,
        textScaleMax,
        textScaleDefault,
      ),
      spacing: _clamp(m['spacing'], spacingMin, spacingMax, spacingDefault),
      opacity: _clamp(m['opacity'], opacityMin, opacityMax, opacityDefault),
      showLabel: m['showLabel'] as bool? ?? false,
      showTime: m['showTime'] as bool? ?? true,
    );
  }

  /// Selected visual style.
  final BubbleVariant variant;

  /// Visible diameter in dp (the transparent glow margin is added natively).
  final double size;

  /// Multiplier over the per-digit base text size.
  final double textScale;

  /// Internal padding factor (used by the pill/label; ignored by the orb).
  final double spacing;

  /// Fill alpha multiplier.
  final double opacity;

  /// Whether to show a tiny "reels" caption under the count.
  final bool showLabel;

  /// Whether a single tap briefly reveals today's watch time on the bubble
  /// (double tap always opens the app). When off, a single tap opens the app.
  final bool showTime;

  // Field ranges (also drive the sliders).
  static const double sizeMin = 40;
  static const double sizeMax = 72;
  static const double sizeDefault = 48;
  static const double textScaleMin = 0.8;
  static const double textScaleMax = 1.4;
  static const double textScaleDefault = 1;
  static const double spacingMin = 0.8;
  static const double spacingMax = 1.3;
  static const double spacingDefault = 1;
  static const double opacityMin = 0.5;
  static const double opacityMax = 1;
  static const double opacityDefault = 0.95;

  BubbleStyle copyWith({
    BubbleVariant? variant,
    double? size,
    double? textScale,
    double? spacing,
    double? opacity,
    bool? showLabel,
    bool? showTime,
  }) {
    return BubbleStyle(
      variant: variant ?? this.variant,
      size: size ?? this.size,
      textScale: textScale ?? this.textScale,
      spacing: spacing ?? this.spacing,
      opacity: opacity ?? this.opacity,
      showLabel: showLabel ?? this.showLabel,
      showTime: showTime ?? this.showTime,
    );
  }

  Map<String, dynamic> toWire() => {
    'variant': variant.wire,
    'size': size,
    'textScale': textScale,
    'spacing': spacing,
    'opacity': opacity,
    'showLabel': showLabel,
    'showTime': showTime,
  };

  @override
  List<Object?> get props => [
    variant,
    size,
    textScale,
    spacing,
    opacity,
    showLabel,
    showTime,
  ];
}

double _clamp(Object? raw, double min, double max, double fallback) {
  final v = (raw as num?)?.toDouble() ?? fallback;
  return v.clamp(min, max);
}
