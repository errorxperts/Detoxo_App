import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/content_count.dart';

/// Controls the home-screen reel counter widget (pin + refresh). Live updates
/// while the UI is dead are pushed natively; this is the Dart control surface.
abstract interface class HomeWidgetRepository {
  /// Asks the launcher to pin the widget. Returns false if unsupported.
  Future<bool> pin();

  /// Pushes the latest snapshot so a freshly-pinned widget is immediately correct.
  Future<void> pushSnapshot(ContentCount count);

  /// Forces a re-render of any pinned widgets from the native store.
  Future<void> refresh();
}
