import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_style_enums.dart';
import 'package:detoxo/features/content_counter/home_content_counter/domain/entities/widget_payload.dart';
import 'package:detoxo/features/content_counter/home_content_counter/domain/entities/widget_tap.dart';

/// Why Dart asks native for a widget push (`ReelWidgetSync.push`); native
/// pushes on counts, midnight and setting changes by itself (IM-03).
enum WidgetPushReason {
  /// Cold start: repairs a widget that saw no push since midnight.
  refresh('refresh'),

  /// The app went to the background.
  background('background');

  const WidgetPushReason(this.wire);
  final String wire;
}

/// The Dart control surface of the home-screen widgets. Native
/// `ReelWidgetSync` is their one writer (IM-01): it builds and stores the
/// payload, and the widgets redraw only when what they show changed.
abstract interface class HomeWidgetRepository {
  /// Asks the launcher to pin a [family] widget. Returns false when the
  /// launcher can't pin programmatically (the caller tells the user to add it
  /// by hand), null when the call failed (the caller says to try again).
  Future<bool?> pin(WidgetFamily family);

  /// Has native rebuild and store the payload now.
  Future<void> push({WidgetPushReason reason = WidgetPushReason.refresh});

  /// A freshly built payload for the in-app previews; native does not store
  /// it, and shows the demo until the first reel is ever counted. Empty
  /// off-Android.
  Future<WidgetPayload> payload();

  /// The last widget tap, read and cleared natively so it answers once; null
  /// when there is none (or it is unparseable).
  Future<WidgetTap?> takePendingTap();
}
