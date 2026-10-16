import 'dart:math' as math;

import 'package:detoxo/core/utils/duration_format.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart'
    show BlockingPlan, planLabel;
import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_style_enums.dart';
import 'package:detoxo/features/content_counter/home_content_counter/domain/entities/plan_state.dart';
import 'package:detoxo/features/content_counter/home_content_counter/domain/entities/widget_payload.dart';
import 'package:detoxo/features/content_counter/home_content_counter/domain/widget_rules.g.dart';

/// Everything a widget face shows, derived from one [WidgetPayload]: states,
/// values and copy (DS-08 / DS-09). Pure, and mirrored by Kotlin
/// `WidgetModel`; both are tested against `test/fixtures/home_widget_cases.json`,
/// written by `tool/home_widget/ref_model.py` (rules:
/// docs/code_docs/17-content-counter.md §5.2). Its `expected` keys name the
/// fields here (`final` is [isFinal]).
///
/// The tier is read from the payload, never derived from the count (IM-01).
/// A payload from another local day reads as Empty: count, time, hours and
/// tier are zero, while the limit, theme and flags are kept (IM-04).
///
/// `zoneOffsetMin` is the device's UTC offset now; `updatedZoneOffsetMin` the
/// offset at `updated_at` (default: the same), so across a DST change the
/// payload's day and "Updated" clock stay its own.
class WidgetModel {
  WidgetModel(
    this._payload, {
    required this._nowMs,
    required int zoneOffsetMin,
    required this._use24h,
    int? updatedZoneOffsetMin,
    this._plan = PlanState.demo,
  }) : _offsetMs = zoneOffsetMin * Duration.millisecondsPerMinute,
       _updatedOffsetMs =
           (updatedZoneOffsetMin ?? zoneOffsetMin) *
           Duration.millisecondsPerMinute;

  /// Lit segments out of this many on Time limit.
  static const segmentCount = WidgetRules.segmentCount;

  static const _stages = [
    'Blooming',
    'Happy',
    'Thirsty',
    'Wilting',
    'Withering',
    'Leafless',
  ];
  static const _health = [100, 90, 70, 50, 25, 0];

  final WidgetPayload _payload;
  final int _nowMs;
  final int _offsetMs;
  final int _updatedOffsetMs;
  final bool _use24h;

  /// The Plan face's source (EVO-073); the demo plan when not given.
  final PlanState _plan;

  late final bool _today =
      _localDay(_payload.updatedAt + _updatedOffsetMs) ==
      _localDay(_nowMs + _offsetMs);
  late final List<int> _hourly = _today
      ? _payload.hourlySeconds
      : WidgetPayload.empty.hourlySeconds;

  /// Clamped here too: a payload built in code skips [WidgetPayload.parse].
  late final int _limit =
      _payload.limitMinutes.clamp(0, WidgetRules.maxLimitMinutes) *
      Duration.secondsPerMinute;
  late final int _peakSeconds = _hourly.fold(0, math.max);
  late final String _updatedClock = _clock(
    _payload.updatedAt + _updatedOffsetMs,
  );

  /// Today's count after the day rule. Animate from this, not the payload's.
  late final int reelCount = _today ? _payload.reelCount : 0;

  /// Today's watch time in seconds, after the day rule.
  late final int watchSeconds = _today ? _payload.watchSeconds : 0;

  /// The DS-01 tier 0..5, as native wrote it.
  late final int tier = _today ? _payload.reelTier : 0;
  late final bool empty = reelCount == 0;
  late final bool isFinal = tier == WidgetRules.maxTier;
  late final bool hasLimit = _limit > 0;
  late final bool over = hasLimit && watchSeconds > _limit;

  /// Native could not refresh the data for over an hour (DS-08).
  late final bool stale =
      _payload.updatedAt > 0 &&
      _nowMs - _payload.updatedAt >
          WidgetRules.staleMinutes * Duration.millisecondsPerMinute;
  late final bool trackingOff = !_payload.trackingEnabled;

  /// The count as drawn, capped at `999+` (DS-09).
  late final String countText = _countText(reelCount);
  late final String time = _hm(watchSeconds);
  late final int toNext =
      (reelCount ~/ WidgetRules.tierStep + 1) * WidgetRules.tierStep -
      reelCount;
  late final int ringPct = empty
      ? 0
      : (isFinal ? 100 : reelCount % WidgetRules.tierStep);

  /// Any watch time lights a segment; the epsilon keeps an exact share of the
  /// limit (half of it lights 6) from rounding up into the next one.
  late final int segmentsOn = hasLimit
      ? (watchSeconds / _limit * segmentCount - 1e-6).ceil().clamp(
          0,
          segmentCount,
        )
      : 0;

  /// One bar per hour as a fraction of its box: full at 30 min, never below
  /// a 0.04 stub.
  late final List<double> bars = [
    for (final s in _hourly) (s / 1800).clamp(0.04, 1.0),
  ];

  /// The first hour holding the most watch time; -1 before any.
  late final int peakHour = _peakSeconds <= 0
      ? -1
      : _hourly.indexOf(_peakSeconds);
  late final String peakLabel = peakHour < 0
      ? 'No peak yet'
      : 'Peak ${_hourLabel(peakHour)}';
  late final String peakValue = peakHour < 0 ? '0m' : '${_peakSeconds ~/ 60}m';

  late final String tierChip = tier == 0 ? 'Empty' : 'Tier $tier';
  late final String reelsChip = _reelsText(reelCount);
  late final String todayShort = empty ? 'No reels' : 'Today';
  late final String todayLong = empty ? 'No reels yet' : 'Reels today';
  late final String nextShort = empty
      ? 'No reels yet'
      : isFinal
      ? 'Final colour'
      : '$toNext to next';
  late final String nextLong = empty
      ? 'No reels yet'
      : isFinal
      ? 'Final colour reached'
      : '${_reelsText(toNext)} to next colour';
  late final String nextLabel = empty
      ? 'First reel starts tier 1'
      : isFinal
      ? 'Final colour reached'
      : 'Next colour in';
  late final String nextValue = _reelsText(isFinal ? reelCount : toNext);

  /// Time left of the limit, the overrun after a `+`, or with no limit the
  /// time watched.
  late final String leftBig = !hasLimit
      ? time
      : over
      ? '+${_hm(watchSeconds - _limit)}'
      : _hm(_limit - watchSeconds);
  late final String limitLabel = !hasLimit
      ? 'No daily limit'
      : over
      ? 'Over ${_hm(_limit)}'
      : 'Left of ${_hm(_limit)}';
  late final String bonsaiStage = _stages[tier];
  late final int bonsaiHealth = _health[tier];
  late final String stageHealth = '$bonsaiStage · $bonsaiHealth%';
  late final String bentoNextLabel = empty
      ? 'Starts at'
      : isFinal
      ? 'Final colour'
      : 'Next colour';
  late final String bentoNextValue = empty
      ? '1 reel'
      : isFinal
      ? countText
      : _reelsText(toNext);

  /// Shown in place of the band label, muted (DS-08); tracking off beats
  /// stale. Null when the data is live.
  late final String? note = trackingOff
      ? 'Turn on tracking'
      : stale
      ? 'Updated $_updatedClock'
      : null;

  // ── Plan (EVO-073): the engine's plan, read live — not the payload ──────

  // Clamped here too: a state built in code skips ConfigStore's 1..20.
  late final int _allowance = _plan.reelAllowance.clamp(
    1,
    PlanState.maxAllowance,
  );
  late final int _reelsLeft =
      _allowance - _plan.reelsConsumed.clamp(0, _allowance);
  late final bool _reelsSpent = _reelsLeft == 0;
  late final _PlanKind _kind = !_plan.serviceOn
      ? _PlanKind.serviceOff
      : !_plan.blockingOn
      ? _PlanKind.blockingOff
      : _nowMs < _plan.pauseUntil
      ? _PlanKind.paused
      : switch (_plan.plan) {
          BlockingPlan.curious => _PlanKind.conscious,
          BlockingPlan.oneReel =>
            _allowance == 1 ? _PlanKind.oneReel : _PlanKind.unblock,
          // The legacy `paused` token blocks every reel, as natively.
          BlockingPlan.blockAll || BlockingPlan.paused => _PlanKind.blockAll,
        };

  /// Whole minutes of a live Pause left: floored, so they agree with
  /// "Back on at", and never 0.
  late final int _pauseMinutes = _kind == _PlanKind.paused
      ? math.max(
          1,
          (_plan.pauseUntil - _nowMs) ~/ Duration.millisecondsPerMinute,
        )
      : 0;
  late final String _pauseLeft = _hm(_pauseMinutes * Duration.secondsPerMinute);
  late final String _until = _clock(_plan.pauseUntil + _offsetMs);
  late final String _reelsLeftOf = '$_reelsLeft of $_allowance';
  late final bool _counting = _kind == _PlanKind.unblock && !_reelsSpent;

  /// The hero: the plan's name, "Paused" or "Off".
  late final String planTitle = switch (_kind) {
    _PlanKind.serviceOff || _PlanKind.blockingOff => 'Off',
    _PlanKind.paused => 'Paused',
    _PlanKind.blockAll => 'Block All',
    // The one wire → label mapping: `curious` reads "Conscious".
    _PlanKind.conscious ||
    _PlanKind.oneReel ||
    _PlanKind.unblock => planLabel(_plan.plan, allowance: _allowance),
  };

  /// The band label on Small.
  late final String planLabelShort = switch (_kind) {
    _PlanKind.serviceOff => 'Turn on blocking',
    _PlanKind.blockingOff => 'Blocking off',
    _PlanKind.paused => 'Reels allowed',
    _PlanKind.conscious => 'Earn reel time',
    _PlanKind.blockAll => 'Reels blocked',
    _PlanKind.oneReel => _reelsSpent ? 'Reels blocked' : '1 reel allowed',
    _PlanKind.unblock => _reelsSpent ? 'Reels blocked' : 'Reels left',
  };

  /// The band label on Medium and Large.
  late final String planLabelLong = switch (_kind) {
    _PlanKind.serviceOff => 'Turn on Accessibility to block',
    _PlanKind.blockingOff => 'Blocking is switched off',
    _PlanKind.paused => 'Back on at $_until',
    _PlanKind.conscious => 'Earn reel time by staying off',
    _PlanKind.blockAll => 'Every reel is blocked',
    _PlanKind.oneReel =>
      _reelsSpent
          ? 'Used, reels blocked again'
          : '1 reel allowed, then blocked',
    _PlanKind.unblock =>
      _reelsSpent ? 'Used, reels blocked again' : 'Reels left, then blocked',
  };

  /// The band value on Small: a Pause's minutes left, or Unblock's
  /// "3 of 5"; else none.
  late final String planValueShort = _kind == _PlanKind.paused
      ? _pauseLeft
      : (_counting ? _reelsLeftOf : '');

  /// The band value on Medium and Large: "4m left" after the clock, or
  /// "3 of 5".
  late final String planValueLong = _kind == _PlanKind.paused
      ? '$_pauseLeft left'
      : (_counting ? _reelsLeftOf : '');

  /// The value is a countdown: Medium and Large lead it with the clock.
  late final bool planClock = _kind == _PlanKind.paused;

  /// Protection in force, 0..100: full when on, filling as an allowance is
  /// spent, empty while paused or off.
  late final int planRingPct = switch (_kind) {
    _PlanKind.blockAll || _PlanKind.conscious => 100,
    _PlanKind.oneReel ||
    _PlanKind.unblock => (_allowance - _reelsLeft) * 100 ~/ _allowance,
    _PlanKind.paused || _PlanKind.serviceOff || _PlanKind.blockingOff => 0,
  };

  /// Large's ring hole.
  late final String planRingText = switch (_kind) {
    _PlanKind.blockAll || _PlanKind.conscious => 'On',
    _PlanKind.serviceOff || _PlanKind.blockingOff => 'Off',
    _PlanKind.paused => _pauseLeft,
    _PlanKind.oneReel || _PlanKind.unblock => '$_reelsLeft',
  };

  /// The Plan widget's TalkBack line, any size (DS-05).
  late final String planDescription = switch (_kind) {
    _PlanKind.serviceOff => 'Blocking is off, turn on Accessibility for Detoxo',
    _PlanKind.blockingOff => 'Blocking is switched off',
    _PlanKind.paused =>
      'Paused, reels allowed for ${_spokenMinutes(_pauseMinutes)}, '
          'blocking returns at $_until',
    _PlanKind.conscious => '$planTitle is on, earn reel time by staying off',
    _PlanKind.blockAll => '$planTitle is on, every reel is blocked',
    _PlanKind.oneReel || _PlanKind.unblock when _reelsSpent =>
      '$planTitle used, reels are blocked again',
    _PlanKind.oneReel => '$planTitle is on, 1 reel allowed, then blocked',
    _PlanKind.unblock => '$planTitle is on, $_reelsLeftOf reels left',
  };

  /// The TalkBack line for [family] drawn at [size] (DS-05), with the real
  /// count and the tracking-off / stale state. Bento speaks like Count when
  /// Small and like Next colour otherwise.
  String describe(WidgetFamily family, WidgetSize size) {
    final reels = '${_spokenReels(reelCount)} today';
    final count = '$reels, $time watched';
    final base = switch (family) {
      WidgetFamily.count => count,
      WidgetFamily.bento when size == WidgetSize.small => count,
      WidgetFamily.nextColour || WidgetFamily.bento =>
        isFinal
            ? '$reels, final colour reached'
            : '$reels, ${_spokenReels(toNext)} to the next colour',
      WidgetFamily.timeLimit when !hasLimit =>
        '$time watched today, no daily limit set',
      WidgetFamily.timeLimit when over =>
        '$time watched, ${_hm(watchSeconds - _limit)} over the '
            '${_hm(_limit)} limit',
      WidgetFamily.timeLimit =>
        '$time watched, ${_hm(_limit - watchSeconds)} left of the '
            '${_hm(_limit)} limit',
      WidgetFamily.rhythm when peakHour < 0 => '$time watched today',
      WidgetFamily.rhythm =>
        '$time watched today, peak at ${_hourLabel(peakHour)} with '
            '${_spokenMinutes(_peakSeconds ~/ 60)}',
      WidgetFamily.bonsai =>
        'Bonsai is $bonsaiStage, health $bonsaiHealth%, $reels',
      WidgetFamily.plan => planDescription,
    };
    // The plan is read live at every draw: no tracking or stale note (EVO-073).
    if (family == WidgetFamily.plan) return base;
    if (trackingOff) return '$base, tracking is off';
    return stale ? '$base, updated $_updatedClock' : base;
  }

  /// The day number of local epoch ms. Floor division, as the reference
  /// does: correct west of UTC too.
  int _localDay(int localMs) => _floorDiv(localMs, Duration.millisecondsPerDay);

  /// `9:40 PM`, or `21:40` with the device's 24-hour clock, of local epoch ms.
  String _clock(int localMs) {
    final minute =
        _floorDiv(localMs, Duration.millisecondsPerMinute) %
        Duration.minutesPerDay;
    final h = minute ~/ 60;
    final mm = '${minute % 60}'.padLeft(2, '0');
    return _use24h ? '${_two(h)}:$mm' : '${_h12(h)}:$mm ${_amPm(h)}';
  }

  /// `11 PM`, or `23:00` with the device's 24-hour clock.
  String _hourLabel(int h) =>
      _use24h ? '${_two(h)}:00' : '${_h12(h)} ${_amPm(h)}';
}

int _floorDiv(int a, int b) => (a - a % b) ~/ b;

String _hm(int seconds) => formatHm(Duration(seconds: seconds));

String _countText(int n) => n > 999 ? '999+' : '$n';

/// As drawn: the count capped like [_countText].
String _reelsText(int n) => n == 1 ? '1 reel' : '${_countText(n)} reels';

/// As spoken: the real count.
String _spokenReels(int n) => n == 1 ? '1 reel' : '$n reels';

String _spokenMinutes(int m) => m == 1 ? '1 minute' : '$m minutes';

String _two(int h) => '$h'.padLeft(2, '0');

int _h12(int h) => h % 12 == 0 ? 12 : h % 12;

String _amPm(int h) => h < 12 ? 'AM' : 'PM';

/// What the Plan face shows, highest first (EVO-073).
enum _PlanKind {
  serviceOff,
  blockingOff,
  paused,
  conscious,
  oneReel,
  unblock,
  blockAll,
}
