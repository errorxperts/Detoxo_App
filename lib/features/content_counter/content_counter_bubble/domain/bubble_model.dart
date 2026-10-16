import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_style_enums.dart';
import 'package:detoxo/features/content_counter/home_content_counter/domain/widget_rules.g.dart';

/// How the tier moved between two reel counts.
enum TierChange { none, down, up }

/// Colour-free text and numbers of the floating bubble.
///
/// MIRROR CONTRACT: Kotlin `overlay/bubble/BubbleModel.kt` computes the same
/// values; both are pinned by `test/fixtures/bubble_cases.json`. Change one,
/// change the other and the fixture.
abstract final class BubbleModel {
  static int _n(int v) => v < 0 ? 0 : v;

  static String _reels(int n) => n == 1 ? 'reel' : 'reels';

  /// 0 for no reels, then one tier per hundred, capped at the final tier.
  static int tier(int count) {
    final n = _n(count);
    if (n == 0) return 0;
    final t = n ~/ WidgetRules.tierStep + 1;
    return t > WidgetRules.maxTier ? WidgetRules.maxTier : t;
  }

  static String countText(int count) {
    final n = _n(count);
    if (n <= 999) return '$n';
    if (n >= 10000) return '${n ~/ 1000}k';
    final tenths = n ~/ 100;
    return tenths % 10 == 0
        ? '${tenths ~/ 10}k'
        : '${tenths ~/ 10}.${tenths % 10}k';
  }

  /// `21m`, `1h 12m`, `2h`.
  static String shortTime(int seconds) {
    final s = _n(seconds);
    if (s < 3600) return '${s ~/ 60}m';
    final m = s % 3600 ~/ 60;
    return m == 0 ? '${s ~/ 3600}h' : '${s ~/ 3600}h ${m}m';
  }

  /// `21:56`, `1:12:08`.
  static String clock(int seconds) {
    final s = _n(seconds);
    String two(int v) => v.toString().padLeft(2, '0');
    final h = s ~/ 3600;
    final ms = '${two(s % 3600 ~/ 60)}:${two(s % 60)}';
    return h > 0 ? '$h:$ms' : ms;
  }

  /// Progress to the next colour, 0..100 (100 once the final tier is hit).
  static int pct(int count) {
    final n = _n(count);
    if (n == 0) return 0;
    return tier(n) == WidgetRules.maxTier ? 100 : n % WidgetRules.tierStep;
  }

  static int toNext(int count) {
    final n = _n(count);
    return (n ~/ WidgetRules.tierStep + 1) * WidgetRules.tierStep - n;
  }

  static String nextLine(int count) {
    final n = _n(count);
    if (n == 0) return 'First reel turns it green.';
    if (tier(n) == WidgetRules.maxTier) return 'Final colour reached.';
    return '${toNext(n)} ${_reels(toNext(n))} to the next colour.';
  }

  static bool isDial(BubbleVariant v) => switch (v) {
    BubbleVariant.ring ||
    BubbleVariant.liquid ||
    BubbleVariant.hourglass ||
    BubbleVariant.bezel => true,
    _ => false,
  };

  /// Width of the open timer pill in dp.
  static double timerWidth(int seconds, BubbleVariant v) {
    if (v == BubbleVariant.ring ||
        v == BubbleVariant.hourglass ||
        v == BubbleVariant.bezel) {
      return 176;
    }
    return _n(seconds) >= 3600 ? 156 : 136;
  }

  /// Spoken label of the collapsed bubble; [tapHint] false drops the closing
  /// "Tap to show the timer." for a bubble that cannot be tapped.
  static String collapsedLabel(
    int count,
    int seconds,
    BubbleVariant v, {
    bool tapHint = true,
  }) {
    final String tail;
    if (isDial(v)) {
      tail = tier(count) == WidgetRules.maxTier
          ? 'final colour'
          : '${toNext(count)} to the next colour';
    } else {
      tail = '${shortTime(seconds)} watched';
    }
    final label = '${countText(count)} ${_reels(count)} today, $tail.';
    return tapHint ? '$label Tap to show the timer.' : label;
  }

  static String openLabel(int seconds) =>
      'Watch time today ${clock(seconds)}. Tap to show the reel count.';

  static int bezelLit(int count) =>
      tier(count) == WidgetRules.maxTier ? 10 : pct(count) ~/ 10;

  static double sandTop(int pct) => 13 + pct * 0.20;

  static double sandBottom(int pct) => 53 - pct * 0.22;

  static String mascotLine(int tier) => const [
    'Glass · happy to see you',
    'Green · big smile',
    'Lime · surprised, that many already?',
    'Amber · worried',
    'Orange-red · upset',
    'Deep red · palm up: stop',
  ][tier.clamp(0, WidgetRules.maxTier)];

  static TierChange transition(int oldTier, int newTier) => newTier > oldTier
      ? TierChange.up
      : newTier < oldTier
      ? TierChange.down
      : TierChange.none;
}
