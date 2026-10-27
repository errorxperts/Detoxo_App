import 'dart:math' as math;

import 'package:detoxo/core/design_system/foundations/glass_container.dart';
import 'package:detoxo/core/design_system/foundations/motion.dart';
import 'package:detoxo/core/design_system/tokens/app_motion.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:detoxo/core/design_system/tokens/app_tokens.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

/// Branded loading indicator (replaces bare `CircularProgressIndicator`): the
/// brand spinner, held still at three quarters under Reduce Motion.
class LoadingState extends StatelessWidget {
  const LoadingState({this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5, value: still ? 0.75 : null),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(message!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// The spec ring (TimeLeftRing): the groove, a track with a three-stop arc of
/// [palette] and its blurred copy, a knob at the arc's end, and the centre
/// disc holding [child]. Every measure is the spec's 300 px ring scaled to
/// [size]; the stroke is 24·size/300.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    required this.progress,
    this.size = 300,
    this.palette,
    this.child,
    super.key,
  });

  /// 0..1 arc, clockwise from 12 o'clock. Null draws the bare ring: no arc
  /// and no knob.
  final double? progress;
  final double size;

  /// Arc, halo and disc wash. Defaults to the static brand; Today passes the
  /// live accent.
  final AccentPalette? palette;
  final Widget? child;

  static List<DxShadow> _scale(List<DxShadow> shadows, double k) => [
    for (final s in shadows)
      DxShadow(
        color: s.color,
        offset: s.offset * k,
        blur: s.blur * k,
        spread: s.spread * k,
        inset: s.inset,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final p = palette ?? t.brand;
    final k = size / 300;
    final dark = t.brightness == Brightness.dark;
    final disc = 224 * k;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: DxSurfacePainter(
              radius: BorderRadius.circular(size / 2),
              gradient: [t.ringGrooveFrom, t.ringGrooveTo],
              angle: 145,
              shadows: _scale(t.shadowGroove, k),
            ),
          ),
          // Its own layer: a ticking arc never repaints the groove or disc.
          RepaintBoundary(
            child: CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(
                progress: progress,
                k: k,
                track: t.ringTrack,
                arc: dark
                    ? [p.light, p.main, p.deep]
                    : [p.main, Color.lerp(p.main, p.deep, AppTokens.arcMidMix)!, p.deep],
                glow: t.kArcGlow,
                halo: (dark ? p.light : p.main).withValues(alpha: t.kHalo),
                knobShadow: t.knobShadow,
              ),
            ),
          ),
          SizedBox.square(
            dimension: disc,
            child: CustomPaint(
              painter: DxSurfacePainter(
                radius: BorderRadius.circular(disc / 2),
                gradient: [t.ringDiscFrom, t.ringDiscTo],
                angle: 145,
                shadows: _scale(t.shadowDisc, k),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.main.withValues(alpha: AppTokens.discWash),
                ),
                child: Center(child: child),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.k,
    required this.track,
    required this.arc,
    required this.glow,
    required this.halo,
    required this.knobShadow,
  });

  final double? progress;
  final double k;
  final Color track;
  final List<Color> arc;
  final double glow;
  final Color halo;
  final Color knobShadow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = 131 * k;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24 * k;
    canvas.drawCircle(center, radius, Paint.from(stroke)..color = track);

    final p = progress;
    if (p == null) return;
    final sweep = math.pi * 2 * p.clamp(0, 1);
    if (sweep > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      // The SVG arc's bounding-box gradient runs top-left → bottom-right
      // before its −90° turn, so on screen it runs bottom-left → top-right.
      Shader shader(List<Color> colors) => LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: colors,
      ).createShader(rect);
      stroke.strokeCap = StrokeCap.round;
      canvas
        ..drawArc(
          rect,
          -math.pi / 2,
          sweep,
          false,
          Paint.from(stroke)
            ..shader = shader([for (final c in arc) c.withValues(alpha: c.a * glow)])
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 9 * k),
        )
        ..drawArc(rect, -math.pi / 2, sweep, false, Paint.from(stroke)..shader = shader(arc));
    }

    // The knob sits in the arc's rotated frame, so its shadow keeps the
    // spec offset (+1.5 along the travel, +2 toward the centre) all round.
    final top = Offset(0, -radius);
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(sweep)
      ..drawCircle(top, 17 * k, Paint()..color = halo)
      ..drawCircle(top + Offset(1.5 * k, 2 * k), 9.5 * k, Paint()..color = knobShadow)
      ..drawCircle(top, 9 * k, Paint()..color = Colors.white)
      ..restore();
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.k != k ||
      old.track != track ||
      !listEquals(old.arc, arc) ||
      old.glow != glow ||
      old.halo != halo ||
      old.knobShadow != knobShadow;
}

/// A linear progress bar (daily-limit usage, permissions completion, the
/// insights distraction share and per-app split): a solid brand fill on a
/// quiet track.
///
/// The **one** proportion bar in the app: private re-implementations kept
/// drifting apart (6 px here, 8 px there). Set [animate] for the growing fill;
/// it is opt-in so the existing static call sites are untouched.
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    required this.progress,
    this.height = 8,
    this.animate = false,
    this.semanticLabel,
    super.key,
  });

  final double progress;
  final double height;

  /// Grow the fill on change instead of snapping. Honours the OS "remove
  /// animations" setting.
  final bool animate;

  /// What a screen reader announces. A bare bar contributes no semantics node
  /// at all, so a caller whose value is not already in adjacent text must pass
  /// this or the information is silently unavailable.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final target = progress.clamp(0.0, 1.0);
    final fill = Container(
      height: height,
      decoration: BoxDecoration(
        color: context.tokens.brand.main,
        borderRadius: BorderRadius.circular(height),
      ),
    );
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(
        children: [
          Container(height: height, color: context.tokens.fillQuiet),
          if (animate && !reduce)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: target),
              duration: AppDurations.slow,
              curve: AppCurves.decelerate,
              // `child` is built once and handed back each frame — the fill is
              // not reallocated 30 times per animation.
              child: fill,
              builder: (context, v, child) => FractionallySizedBox(
                // A zero-width FractionallySizedBox lays out as unconstrained;
                // a hairline keeps it a no-op.
                widthFactor: v == 0 ? 0.001 : v,
                child: child,
              ),
            )
          else
            FractionallySizedBox(widthFactor: target == 0 ? 0.001 : target, child: fill),
        ],
      ),
    );
    return semanticLabel == null
        ? bar
        : Semantics(label: semanticLabel, container: true, child: bar);
  }
}

/// A calm empty / placeholder state: the icon in ink-2, the subtitle in body
/// ink-2.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// A flat button: `PrimaryButton(flat: true)` or a `SecondaryButton`.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ink2 = context.tokens.ink2;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: ink2),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: ink2),
              ),
            ],
            if (action != null) ...[const SizedBox(height: AppSpacing.lg), action!],
          ],
        ),
      ),
    );
  }
}

/// Grows an optional line in and out — size and fade together — so a hint or
/// a warning appearing under a control slides the layout instead of popping
/// it. A null [child] collapses to nothing; give a child whose text can
/// change while shown a key, so the change cross-fades.
class AppReveal extends StatelessWidget {
  const AppReveal({required this.child, super.key});

  final Widget? child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : AppDurations.fast,
    switchInCurve: AppCurves.standard,
    switchOutCurve: AppCurves.standard,
    transitionBuilder: (child, animation) => SizeTransition(
      sizeFactor: animation,
      alignment: Alignment.topCenter,
      child: FadeTransition(opacity: animation, child: child),
    ),
    child: child ?? const SizedBox.shrink(),
  );
}

/// A warning line for something switched on that cannot work yet — "Needs
/// “Display over other apps” — tap to allow": the tap is the fix. 48 dp tall
/// to tap, the line centred in it.
class NoticeLine extends StatelessWidget {
  const NoticeLine(this.text, {required this.onTap, super.key});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppPressable(
    onTap: onTap,
    semanticLabel: text,
    minTapTarget: const Size(0, AppSizes.minTapTarget),
    child: Row(
      children: [
        Icon(
          Icons.warning_amber_rounded,
          size: 14,
          color: context.tokens.statusText(context.tokens.statusSetup),
        ),
        const SizedBox(width: AppSpacing.xxs),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.tokens.statusText(context.tokens.statusSetup),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
