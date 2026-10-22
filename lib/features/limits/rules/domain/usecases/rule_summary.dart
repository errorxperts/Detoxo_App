import 'package:detoxo/features/limits/rules/domain/entities/rule.dart';
import 'package:detoxo/features/limits/rules/domain/entities/rule_snapshot.dart';

/// Renders minutes-after-midnight as the user reads them. Defaults to the
/// 24-hour wire form; the UI passes a locale-aware one so a device set to
/// 12-hour does not pick "5:00 PM" and then read it back as "17:00".
typedef TimeFormat = String Function(int minutesAfterMidnight);

/// The one-line strings the rules list, its status pills and the Blocker
/// rules row render. Pure, so the copy is unit-testable and lives in one place.
abstract final class RuleSummary {
  static const List<String> _day = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  /// "Mon" … "Sun" for an ISO weekday (1–7) — the editor's day chips read from
  /// here rather than keeping their own copy.
  static String dayLabel(int isoWeekday) => _day[isoWeekday - 1];

  /// "Weekdays", "Weekends", "Every day" or "Mon, Wed, Fri".
  static String days(Set<int> days) {
    if (days.length == 7) return 'Every day';
    if (days.length == 5 && days.containsAll(RuleSchedule.weekdays)) {
      return 'Weekdays';
    }
    if (days.length == 2 && days.containsAll(const {6, 7})) return 'Weekends';
    final sorted = days.toList()..sort();
    return sorted.map((d) => _day[d - 1]).join(', ');
  }

  /// "Weekdays · 09:00–17:00 · 2 apps, 1 category".
  static String describe(Rule r, {TimeFormat time = RuleSchedule.formatHHmm}) {
    final when = switch (r.kind) {
      RuleKind.schedule =>
        r.schedule == null
            ? 'No time set'
            : '${days(r.schedule!.days)} · '
                  '${time(r.schedule!.startMin)}–'
                  '${time(r.schedule!.endMin)}'
                  '${r.schedule!.isOvernight ? ' (next day)' : ''}',
      RuleKind.timeLimit => '${r.thresholdMs ~/ 60000} min a day',
      RuleKind.openLimit => '${count(r.maxOpens, 'open', 'opens')} a day',
    };
    // Locked implies strict on the wire, so the chip is derived from the same
    // question native is asked — `isStrict` — and the two can never disagree.
    final commitment = r.locked
        ? (r.lockScope == LockScope.distracting
              ? ' · Locked · every distracting app'
              : ' · Locked')
        : r.strict
        ? ' · Strict'
        : '';
    return '$when · ${targets(r.selection)}$commitment';
  }

  /// "2 apps, 1 category, 3 sites, 1 reel feed" — counts, never labels: the
  /// list must not need the installed-apps scan to render.
  static String targets(RuleSelection s) {
    final parts = <String>[
      if (s.apps.isNotEmpty) count(s.apps.length, 'app', 'apps'),
      if (s.categories.isNotEmpty)
        count(s.categories.length, 'category', 'categories'),
      if (s.websites.isNotEmpty) count(s.websites.length, 'site', 'sites'),
      if (s.platforms.isNotEmpty)
        count(s.platforms.length, 'reel feed', 'reel feeds'),
    ];
    return parts.isEmpty ? 'No targets' : parts.join(', ');
  }

  /// The status pill: "Off", "Active now", "Limit reached", "22/30 min",
  /// "3 of 5 opens", "Needs usage access" or "Next Mon 09:00".
  static String status(
    Rule r,
    RuleStatus s,
    DateTime now, {
    TimeFormat time = RuleSchedule.formatHHmm,
  }) {
    if (!r.enabled) return 'Off';
    // An override is holding it open — say so rather than claiming it enforces.
    if (s.isLifted) {
      return 'Lifted to ${clock(s.liftedUntilMs, now, time: time)}';
    }
    if (s.spent) return 'Limit reached';
    if (s.activeNow) return 'Active now';
    switch (r.kind) {
      case RuleKind.schedule:
        return s.nextChangeMs > 0
            ? 'Next ${clock(s.nextChangeMs, now, time: time)}'
            : '';
      case RuleKind.timeLimit:
        if (!s.usageKnown) return 'Needs usage access';
        return '${s.usedMs ~/ 60000}/${r.thresholdMs ~/ 60000} min';
      case RuleKind.openLimit:
        if (!s.usageKnown) return 'Needs usage access';
        return '${s.opens} of ${r.maxOpens} opens';
    }
  }

  /// The Blocker rules row's summary, first match wins: the rule running now
  /// ("Bedtime on until 7 AM", plus " on Sat" when the end is a day or more
  /// away), a spent limit ("Insta budget limit reached"), the next start
  /// ("Next: Bedtime at 11 PM", " tomorrow", " on Sat"), then "All rules
  /// off", "Daily limit only" or "Nothing scheduled".
  static String nextEvent(
    List<Rule> rules,
    Map<String, RuleStatus> statuses,
    DateTime now, {
    TimeFormat time = RuleSchedule.formatHHmm,
  }) {
    if (rules.isEmpty) return 'Tap to set up';
    Rule? running;
    Rule? spent;
    Rule? next;
    var soonest = 0;
    for (final r in rules) {
      if (!r.enabled) continue;
      final s = statuses[r.id];
      if (s == null) continue;
      if (s.spent) {
        spent ??= r;
      } else if (s.activeNow) {
        running ??= r;
      } else if (s.nextChangeMs > 0 &&
          (next == null || s.nextChangeMs < soonest)) {
        next = r;
        soonest = s.nextChangeMs;
      }
    }
    String at(DateTime t) => time(t.hour * 60 + t.minute);
    String day(DateTime t) => _day[t.weekday - 1];
    if (running != null) {
      final endMs = statuses[running.id]!.nextChangeMs;
      if (endMs <= 0) return '${running.name} on';
      final end = DateTime.fromMillisecondsSinceEpoch(endMs);
      final far = end.difference(now) >= const Duration(days: 1);
      return '${running.name} on until ${at(end)}${far ? ' on ${day(end)}' : ''}';
    }
    if (spent != null) return '${spent.name} limit reached';
    if (next != null) {
      final start = DateTime.fromMillisecondsSinceEpoch(soonest);
      // Calendar days apart; UTC dates, so a DST night is still one day.
      final days = DateTime.utc(
        start.year,
        start.month,
        start.day,
      ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
      final when = switch (days) {
        <= 0 => '',
        1 => ' tomorrow',
        _ => ' on ${day(start)}',
      };
      return 'Next: ${next.name} at ${at(start)}$when';
    }
    final on = rules.where((r) => r.enabled);
    if (on.isEmpty) return 'All rules off';
    if (on.every((r) => r.kind != RuleKind.schedule)) return 'Daily limit only';
    return 'Nothing scheduled';
  }

  /// "09:00" today, "Mon 09:00" on another day.
  static String clock(
    int ms,
    DateTime now, {
    TimeFormat time = RuleSchedule.formatHHmm,
  }) {
    final t = DateTime.fromMillisecondsSinceEpoch(ms);
    final at = time(t.hour * 60 + t.minute);
    final sameDay =
        t.year == now.year && t.month == now.month && t.day == now.day;
    return sameDay ? at : '${_day[t.weekday - 1]} $at';
  }

  /// "1 app" / "3 apps" — the one pluraliser the list, the pills and the
  /// editor's tile subtitles and headline all read, so the copy cannot drift.
  static String count(int n, String one, String many) =>
      '$n ${n == 1 ? one : many}';
}
