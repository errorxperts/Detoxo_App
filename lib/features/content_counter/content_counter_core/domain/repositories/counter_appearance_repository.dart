import 'package:detoxo/features/content_counter/content_counter_bubble/domain/entities/bubble_style.dart';
import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_appearance.dart';
import 'package:detoxo/features/content_counter/home_content_counter/domain/entities/widget_style.dart';

/// Reads and writes the counter's appearance (bubble + home widget). A single
/// surface for both styles, kept separate from `BubbleRepository` /
/// `HomeWidgetRepository` so their tight control contracts stay clean.
///
/// Styles are persisted on the native side (so the bubble/widget stay correct
/// even when the Flutter UI is dead); writing a style also live-re-renders the
/// visible bubble and any pinned widget.
abstract interface class CounterAppearanceRepository {
  /// Hydrates the combined appearance from the native snapshot (defaults when
  /// unset or off-Android).
  Future<CounterAppearance> current();

  /// Persists + live-pushes the bubble style.
  Future<void> setBubbleStyle(BubbleStyle style);

  /// Persists + live-pushes the home-widget style.
  Future<void> setWidgetStyle(WidgetStyle style);
}
