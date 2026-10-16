import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_style_enums.dart';
import 'package:equatable/equatable.dart';

/// Where a home-widget tap leads (IM-08). Native decides at tap time, from the
/// tracker's state then.
enum WidgetTapTarget {
  /// Tracking (or, for Plan, blocking) works: the screen behind the widget,
  /// picked per family in Dart (`WidgetTapListener`, EVO-072).
  activity('ACTIVITY'),

  /// The counter is off: the setting that turns it on.
  appearance('APPEARANCE'),

  /// The accessibility service is off: the grant that fixes it.
  permissions('PERMISSIONS'),

  /// Plan only (EVO-073): blocking is switched off — Settings, whose
  /// "Blocking active" switch turns it back on.
  settings('SETTINGS');

  const WidgetTapTarget(this.wire);
  final String wire;
}

/// A home-widget tap, delivered by `takePendingWidgetTap` as
/// `"FAMILY|SIZE|TARGET"` (wire tokens).
class WidgetTap extends Equatable {
  const WidgetTap(this.family, this.size, this.target);

  /// Null for anything unparseable: a malformed tap opens nothing rather than
  /// a screen the user did not ask for.
  static WidgetTap? parse(String? raw) {
    if (raw?.split('|') case [final f, final s, final t]) {
      final family = WidgetFamily.values.where((e) => e.wire == f).firstOrNull;
      final size = WidgetSize.values.where((e) => e.wire == s).firstOrNull;
      final target = WidgetTapTarget.values
          .where((e) => e.wire == t)
          .firstOrNull;
      if (family != null && size != null && target != null) {
        return WidgetTap(family, size, target);
      }
    }
    return null;
  }

  final WidgetFamily family;
  final WidgetSize size;
  final WidgetTapTarget target;

  @override
  List<Object?> get props => [family, size, target];
}
