import 'dart:math' as math;

import 'package:detoxo/core/design_system/tokens/app_motion.dart';
import 'package:detoxo/core/design_system/tokens/app_tokens.dart';
import 'package:flutter/material.dart';

/// What picks the live accent: no mode (blocking off), a base mode, or a
/// session.
enum AccentMode { none, blockAll, conscious, pause, oneReel }

/// The live accent palette for [mode] in theme [t].
///
/// - No mode: `brand` up to 60 % of the daily limit [used], blending to
///   `pause` by 85 % and to `over` at 100 %.
/// - A base mode or One Reel: its own palette, warming toward that same
///   pause → over blend from 60 % used (at most an 80 % blend).
/// - Pause: the `pause` palette, blending to `over` over the last 2 minutes
///   ([pauseLeft]); an N-reel unblock passes no [pauseLeft] and stays `pause`.
///
/// Written literally: the Kotlin `AccentResolver` and the fixture's Python
/// model run the same double operations (test/fixtures/accent_cases.json).
AccentPalette resolveAccent(
  AppTokens t,
  AccentMode mode, {
  double used = 0,
  Duration? pauseLeft,
}) {
  final f = used.clamp(0.0, 1.0);
  final warm = f < 0.85
      ? t.pause
      : AccentPalette.lerp(t.pause, t.over, (f - 0.85) / 0.15);
  switch (mode) {
    case AccentMode.none:
      if (f < 0.6) return t.brand;
      return f < 0.85
          ? AccentPalette.lerp(t.brand, t.pause, (f - 0.6) / 0.25)
          : warm;
    case AccentMode.pause:
      if (pauseLeft == null) return t.pause;
      return AccentPalette.lerp(
        t.pause,
        t.over,
        (1 - pauseLeft.inMilliseconds / 120000).clamp(0.0, 1.0),
      );
    case AccentMode.blockAll || AccentMode.conscious || AccentMode.oneReel:
      final p = switch (mode) {
        AccentMode.blockAll => t.blockAll,
        AccentMode.conscious => t.conscious,
        _ => t.oneReel,
      };
      if (f <= 0.6) return p;
      return AccentPalette.lerp(p, warm, 0.8 * (f - 0.6) / 0.4);
  }
}

/// The CSS `hue-rotate(h) saturate(s)` filter chain the 3D mode icons wear,
/// as a 4×5 colour matrix with [opacity] on alpha (Filter Effects 1).
///
/// The icons are drawn blue (hue [AppTokens.iconBaseHue]); rotating by the
/// accent's hue minus that base turns them to the accent.
List<double> accentIconMatrix(
  AccentPalette accent, {
  double saturate = AppTokens.iconSaturateOn,
  double opacity = 1,
}) {
  final h =
      (HSVColor.fromColor(accent.main).hue - AppTokens.iconBaseHue) *
      math.pi /
      180;
  final c = math.cos(h);
  final s = math.sin(h);
  final hue = [
    0.213 + c * 0.787 - s * 0.213, 0.715 - c * 0.715 - s * 0.715, //
    0.072 - c * 0.072 + s * 0.928,
    0.213 - c * 0.213 + s * 0.143, 0.715 + c * 0.285 + s * 0.140, //
    0.072 - c * 0.072 - s * 0.283,
    0.213 - c * 0.213 - s * 0.787, 0.715 - c * 0.715 + s * 0.715, //
    0.072 + c * 0.928 + s * 0.072,
  ];
  final k = saturate;
  final sat = [
    0.213 + 0.787 * k, 0.715 - 0.715 * k, 0.072 - 0.072 * k, //
    0.213 - 0.213 * k, 0.715 + 0.285 * k, 0.072 - 0.072 * k, //
    0.213 - 0.213 * k, 0.715 - 0.715 * k, 0.072 + 0.928 * k,
  ];
  // Hue first, then saturate: sat · hue.
  double at(int r, int col) =>
      sat[r * 3] * hue[col] +
      sat[r * 3 + 1] * hue[3 + col] +
      sat[r * 3 + 2] * hue[6 + col];
  return [
    for (var r = 0; r < 3; r++) ...[at(r, 0), at(r, 1), at(r, 2), 0, 0],
    0,
    0,
    0,
    opacity,
    0,
  ];
}

/// [accentIconMatrix] as a [ColorFilter]: selected icons pass the defaults,
/// idle ones `saturate: AppTokens.iconSaturateOff, opacity:
/// AppTokens.iconOpacityOff` (see `Icon3d`).
ColorFilter accentIconFilter(
  AccentPalette accent, {
  double saturate = AppTokens.iconSaturateOn,
  double opacity = 1,
}) => ColorFilter.matrix(
  accentIconMatrix(accent, saturate: saturate, opacity: opacity),
);

/// Publishes the live accent for both themes, gliding a change over
/// [AppDurations.glide] (CSS `ease`). A theme switch picks the other palette,
/// so it snaps like every other token; Reduce Motion makes every change
/// instant.
///
/// A change glides only when [glideKey] changes with it (or [glideKey] is
/// null): a live Pause's per-second countdown passes the same key, so its
/// tick snaps instead of restarting a glide every second.
class AccentScope extends StatefulWidget {
  const AccentScope({
    required this.light,
    required this.dark,
    required this.child,
    this.glideKey,
    super.key,
  });

  final AccentPalette light;
  final AccentPalette dark;
  final Object? glideKey;
  final Widget child;

  @override
  State<AccentScope> createState() => _AccentScopeState();
}

class _AccentScopeState extends State<AccentScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glide = AnimationController(
    vsync: this,
    duration: AppDurations.glide,
    value: 1,
  );
  late (AccentPalette, AccentPalette) _from = (widget.light, widget.dark);

  (AccentPalette, AccentPalette) get _now {
    final t = AppCurves.glide.transform(_glide.value);
    return (
      AccentPalette.lerp(_from.$1, widget.light, t),
      AccentPalette.lerp(_from.$2, widget.dark, t),
    );
  }

  @override
  void didUpdateWidget(AccentScope old) {
    super.didUpdateWidget(old);
    if (old.light == widget.light && old.dark == widget.dark) return;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final glides =
        !still && (widget.glideKey == null || widget.glideKey != old.glideKey);
    if (glides) {
      // Start from the colour on screen, even mid-glide.
      final t = AppCurves.glide.transform(_glide.value);
      _from = (
        AccentPalette.lerp(_from.$1, old.light, t),
        AccentPalette.lerp(_from.$2, old.dark, t),
      );
      _glide.forward(from: 0);
    } else {
      _glide
        ..stop()
        ..value = 1;
      _from = (widget.light, widget.dark);
    }
  }

  @override
  void dispose() {
    _glide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _glide,
    builder: (context, child) {
      final (light, dark) = _now;
      return _AccentData(light: light, dark: dark, child: child!);
    },
    child: widget.child,
  );
}

class _AccentData extends InheritedWidget {
  const _AccentData({
    required this.light,
    required this.dark,
    required super.child,
  });

  final AccentPalette light;
  final AccentPalette dark;

  @override
  bool updateShouldNotify(_AccentData old) =>
      old.light != light || old.dark != dark;
}

extension AccentX on BuildContext {
  /// The live accent for the current theme: the nearest [AccentScope]'s, or
  /// the static `brand` without one.
  AccentPalette get accent {
    final data = dependOnInheritedWidgetOfExactType<_AccentData>();
    final dark = Theme.of(this).brightness == Brightness.dark;
    if (data == null) return tokens.brand;
    return dark ? data.dark : data.light;
  }
}
