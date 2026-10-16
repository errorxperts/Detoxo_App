import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_style_enums.dart';
import 'package:equatable/equatable.dart';

/// The home-screen widgets' one user setting: their colour scheme (DS-06).
///
/// Persisted natively in `ContentCounterStore` (as JSON) and pushed over the
/// command channel via [toWire]; native writes it into every widget payload.
class WidgetStyle extends Equatable {
  const WidgetStyle({this.theme = WidgetTheme.system});

  const WidgetStyle.defaults() : this();

  /// Tolerant: the old single widget's keys (background, density, line
  /// toggles) are ignored, and a wrong-typed theme takes the default.
  factory WidgetStyle.fromWire(Map<String, dynamic>? m) {
    final theme = m?['theme'];
    return WidgetStyle(
      theme: WidgetTheme.fromWire(theme is String ? theme : null),
    );
  }

  /// Colour scheme ([WidgetTheme.system] resolves on the device at draw time).
  final WidgetTheme theme;

  WidgetStyle copyWith({WidgetTheme? theme}) =>
      WidgetStyle(theme: theme ?? this.theme);

  Map<String, dynamic> toWire() => {'theme': theme.wire};

  @override
  List<Object?> get props => [theme];
}
