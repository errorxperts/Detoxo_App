import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_style_enums.dart';
import 'package:equatable/equatable.dart';

/// User-tunable appearance of the 2×2 home-screen widget.
///
/// Persisted natively in `ContentCounterStore` (as JSON) and pushed over the
/// command channel via [toWire]; the native `WidgetBitmapRenderer` and the
/// Flutter `WidgetPreview` both render from these fields. [WidgetStyle.fromWire]
/// coerces an all-lines-off payload back to showing today's count so the widget
/// is never rendered blank.
class WidgetStyle extends Equatable {
  const WidgetStyle({
    this.background = WidgetBackground.glassDark,
    this.theme = WidgetTheme.system,
    this.density = WidgetDensity.cozy,
    this.showToday = true,
    this.showLabel = true,
    this.showTotal = true,
    this.accentByUsage = false,
  });

  const WidgetStyle.defaults() : this();

  factory WidgetStyle.fromWire(Map<String, dynamic>? m) {
    if (m == null) return const WidgetStyle.defaults();
    final showToday = m['showToday'] as bool? ?? true;
    final showTotal = m['showTotal'] as bool? ?? true;
    // Never let both primary lines be off — the widget would be blank.
    final coerceToday = showToday || !showTotal;
    return WidgetStyle(
      background: WidgetBackground.fromWire(m['background'] as String?),
      theme: WidgetTheme.fromWire(m['theme'] as String?),
      density: WidgetDensity.fromWire(m['density'] as String?),
      showToday: coerceToday,
      showLabel: m['showLabel'] as bool? ?? true,
      showTotal: showTotal,
      accentByUsage: m['accentByUsage'] as bool? ?? false,
    );
  }

  /// Glass background treatment.
  final WidgetBackground background;

  /// Color scheme (system resolved natively at draw time).
  final WidgetTheme theme;

  /// Information density (font scale + padding).
  final WidgetDensity density;

  /// Show the large today count line.
  final bool showToday;

  /// Show the "reels today" caption.
  final bool showLabel;

  /// Show the "All time · N" line.
  final bool showTotal;

  /// Color the today count by today's usage band (green→brown).
  final bool accentByUsage;

  WidgetStyle copyWith({
    WidgetBackground? background,
    WidgetTheme? theme,
    WidgetDensity? density,
    bool? showToday,
    bool? showLabel,
    bool? showTotal,
    bool? accentByUsage,
  }) {
    return WidgetStyle(
      background: background ?? this.background,
      theme: theme ?? this.theme,
      density: density ?? this.density,
      showToday: showToday ?? this.showToday,
      showLabel: showLabel ?? this.showLabel,
      showTotal: showTotal ?? this.showTotal,
      accentByUsage: accentByUsage ?? this.accentByUsage,
    );
  }

  Map<String, dynamic> toWire() => {
    'background': background.wire,
    'theme': theme.wire,
    'density': density.wire,
    'showToday': showToday,
    'showLabel': showLabel,
    'showTotal': showTotal,
    'accentByUsage': accentByUsage,
  };

  @override
  List<Object?> get props => [
    background,
    theme,
    density,
    showToday,
    showLabel,
    showTotal,
    accentByUsage,
  ];
}
