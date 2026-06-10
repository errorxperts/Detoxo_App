import 'package:flutter/animation.dart';

/// Motion durations. Pairs with flutter_animate's `.ms` ergonomics.
abstract final class AppDurations {
  static const Duration instant = Duration(milliseconds: 90); // button press
  static const Duration fast = Duration(milliseconds: 180); // toggles
  static const Duration normal = Duration(milliseconds: 300); // entrance fades
  static const Duration medium = Duration(milliseconds: 400); // page / sheet
  static const Duration slow = Duration(milliseconds: 700); // shimmer / reveal
  static const Duration pulse = Duration(milliseconds: 900); // status pulse
  static const Duration stagger = Duration(milliseconds: 80); // list interval
}

/// Curves tuned for a calm focus app — eased, never bouncy.
abstract final class AppCurves {
  static const Curve standard = Curves.easeOutCubic; // entrances
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
  static const Curve decelerate = Curves.easeOut;
  static const Curve gentle = Curves.easeInOut; // pulses, reversible
}
