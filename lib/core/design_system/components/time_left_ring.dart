import 'dart:math' as math;

import 'package:detoxo/core/design_system/components/dx_icons.dart';
import 'package:detoxo/core/design_system/components/feedback.dart';
import 'package:detoxo/core/design_system/foundations/accent.dart';
import 'package:detoxo/core/design_system/tokens/app_motion.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:detoxo/core/design_system/tokens/app_tokens.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';

/// Today's hero (spec TimeLeftRing): a [ProgressRing] in the live accent
/// whose face holds the [eyebrow], the [value] through [format] and the
/// [sub] line, with the reels and streak line 22 below. During a [live]
/// Pause or reel session the ring is the countdown gauge instead: the
/// pre-migration hero's read-only `SleekCircularSlider` (240° open at the
/// bottom, an 8 track, a 12 bar in the accent, no handle) draining as the
/// time or the reels run out.
///
/// The value, the counts and the arc count up from zero once per mount over
/// [AppDurations.glide]; every later change (the 1 Hz Pause tick, a new
/// count) snaps. Reduce Motion skips the count-up. The ring is [_size] px,
/// narrower only when its box is.
class TimeLeftRing extends StatelessWidget {
  const TimeLeftRing({
    required this.eyebrow,
    required this.value,
    required this.format,
    required this.sub,
    required this.progress,
    this.live = false,
    this.reels,
    this.streak,
    super.key,
  });

  /// "Time left" or "Reels allowed"; shown uppercase, read as given.
  final String eyebrow;

  /// A live Pause or reel session: the eyebrow in accent text instead of
  /// ink-2, and the countdown gauge instead of the [ProgressRing].
  final bool live;

  /// Minutes or seconds left, shown through [format]; null shows "—".
  final int? value;
  final String Function(int) format;
  final String sub;

  /// 0..1 of the time left; null draws no arc and no knob.
  final double? progress;

  /// Reels today and the streak in days; null shows "—".
  final int? reels;
  final int? streak;

  /// 30 % under the spec's 300, so the mode card sits higher on Today.
  static const double _size = 210;

  static String _count(int? n, [double k = 1]) =>
      n == null ? '—' : '${(n * k).round()}';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final accent = context.accent;
    final ink2 = AppTypography.body.copyWith(color: t.ink2);

    Widget stat(Widget glyph, String n, String words) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        glyph,
        const SizedBox(width: 7),
        Text(n, style: AppTypography.labelStrong.copyWith(color: t.ink)),
        const SizedBox(width: 7),
        Text(words, style: ink2),
      ],
    );

    return LayoutBuilder(
      builder: (context, box) {
        final size = math.min(_size, box.maxWidth);
        // A fixed 0 → 1 tween runs once per mount; rebuilds land at 1, so
        // ticks snap.
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: context.motion(AppDurations.glide),
          curve: AppCurves.standard,
          builder: (context, k, _) {
            final face = SizedBox.square(
              dimension: (224 - 20) * size / 300,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Semantics(
                  container: true,
                  excludeSemantics: true,
                  label: [
                    eyebrow,
                    if (value != null) format(value!),
                    sub,
                  ].join(', '),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        eyebrow.toUpperCase(),
                        style: AppTypography.eyebrow.copyWith(
                          color: live ? t.accentText(accent) : t.ink2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        value == null ? '—' : format((value! * k).round()),
                        style: AppTypography.number.copyWith(color: t.ink),
                      ),
                      const SizedBox(height: 6),
                      Text(sub, style: ink2),
                    ],
                  ),
                ),
              ),
            );
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The face ticks every second; keep that off the screen's layer.
                RepaintBoundary(
                  child: live
                      ? _Countdown(
                          progress: progress ?? 0,
                          size: size,
                          palette: accent,
                          child: face,
                        )
                      : ProgressRing(
                          progress: progress == null ? null : progress! * k,
                          size: size,
                          palette: accent,
                          child: face,
                        ),
                ),
                const SizedBox(height: 22),
                Semantics(
                  container: true,
                  excludeSemantics: true,
                  label:
                      '${_count(reels)} reels today, '
                      '${_count(streak)} day streak',
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        stat(
                          Glyph(
                            Assets.svg.playCircle,
                            size: 18,
                            color: t.accentText(accent),
                          ),
                          _count(reels, k),
                          'reels today',
                        ),
                        const SizedBox(width: AppSpacing.md),
                        SizedBox(
                          width: 1,
                          height: 18,
                          child: ColoredBox(color: t.hairline),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        stat(
                          Glyph(Assets.svg.flame, size: 18, color: t.streak),
                          _count(streak, k),
                          'day streak',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Today's two ambient lights (V02 artboards): the accent's main stop at
/// `kAmb`, 380 px at (5, 45) (V02's 90, raised with the 210 px ring's
/// centre), and its deep stop at `kAmbDeep`, 400 px at (120, 560), each
/// fading to clear at its edge. They read
/// `context.accent`, so they glide with it.
///
/// Mount it with `Positioned.fill` behind the screen's scroll content: it
/// fills and clips to its box and ignores touches.
class AmbientLights extends StatelessWidget {
  const AmbientLights({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final a = context.accent;
    Widget light(Rect r, Color c, double k) => Positioned.fromRect(
      rect: r,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              c.withValues(alpha: k),
              c.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
    return IgnorePointer(
      child: Stack(
        children: [
          light(const Rect.fromLTWH(5, 45, 380, 380), a.main, t.kAmb),
          light(const Rect.fromLTWH(120, 560, 400, 400), a.deep, t.kAmbDeep),
        ],
      ),
    );
  }
}

/// The live-session gauge: the pre-migration countdown ring
/// (`SleekCircularSlider`, package-default 150° start and 240° sweep), read
/// only, in the live accent. It eases between the 1 Hz ticks unless Reduce
/// Motion is on.
class _Countdown extends StatelessWidget {
  const _Countdown({
    required this.progress,
    required this.size,
    required this.palette,
    required this.child,
  });

  final double progress;
  final double size;
  final AccentPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return IgnorePointer(
      child: SleekCircularSlider(
        max: 1,
        initialValue: progress.clamp(0.0, 1.0),
        appearance: CircularSliderAppearance(
          size: size,
          animationEnabled:
              !(MediaQuery.maybeDisableAnimationsOf(context) ?? false),
          customWidths: CustomSliderWidths(
            trackWidth: 8,
            progressBarWidth: 12,
            handlerSize: 0,
          ),
          customColors: CustomSliderColors(
            trackColor: t.control,
            progressBarColors: [palette.main, palette.deep, palette.main],
            dotColor: Colors.transparent,
            hideShadow: true,
          ),
        ),
        innerWidget: (_) => Center(child: child),
      ),
    );
  }
}
