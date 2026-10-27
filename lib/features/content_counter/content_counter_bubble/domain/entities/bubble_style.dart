import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_style_enums.dart';
import 'package:equatable/equatable.dart';

/// User-tunable appearance of the floating counter bubble: which of the six
/// styles, how big, how opaque.
///
/// Persisted natively in `ContentCounterStore` (as JSON) and pushed over the
/// command channel via [toWire]; the native bubble and the Flutter preview
/// both render from these fields. Ranges are enforced by the editing sliders
/// and re-clamped in [BubbleStyle.fromWire] so a malformed payload can never
/// produce an unusable bubble. Unknown (legacy) keys are ignored.
class BubbleStyle extends Equatable {
  const BubbleStyle({
    this.variant = BubbleVariant.ring,
    this.size = sizeDefault,
    this.opacity = opacityDefault,
  });

  const BubbleStyle.defaults() : this();

  factory BubbleStyle.fromWire(Map<String, dynamic>? m) {
    if (m == null) return const BubbleStyle.defaults();
    final v = m['variant'];
    return BubbleStyle(
      variant: BubbleVariant.fromWire(v is String ? v : null),
      size: _clamp(m['size'], sizeMin, sizeMax, sizeDefault),
      opacity: _clamp(m['opacity'], opacityMin, opacityMax, opacityDefault),
    );
  }

  /// Selected visual style.
  final BubbleVariant variant;

  /// Visible diameter in dp (the transparent glow margin is added natively).
  final double size;

  /// Fill alpha multiplier.
  final double opacity;

  // Field ranges (also drive the sliders).
  static const double sizeMin = 38.4;
  static const double sizeMax = 64;

  /// New installs start at the smallest bubble, the least in the way.
  static const double sizeDefault = sizeMin;
  static const double opacityMin = 0.5;
  static const double opacityMax = 1;
  static const double opacityDefault = 1;

  BubbleStyle copyWith({
    BubbleVariant? variant,
    double? size,
    double? opacity,
  }) {
    return BubbleStyle(
      variant: variant ?? this.variant,
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
    );
  }

  Map<String, dynamic> toWire() => {
    'variant': variant.wire,
    'size': size,
    'opacity': opacity,
  };

  @override
  List<Object?> get props => [variant, size, opacity];
}

double _clamp(Object? raw, double min, double max, double fallback) {
  final v = raw is num ? raw.toDouble() : fallback;
  return v.clamp(min, max);
}
