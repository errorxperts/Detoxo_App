import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/utils/duration_format.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';
import 'package:detoxo/features/blocking/blocking.dart';
import 'package:detoxo/features/blocking/plans/domain/entities/conscious_state.dart';
import 'package:detoxo/features/blocking/plans/domain/entities/session_defaults.dart';

/// Which of the Today screen's five modes is lit: 0 Block All, 1 Conscious,
/// 2 Pause, 3 One Reel, 4 Unblock (an N-reel unblock). The app's live accent
/// reads the same index, so the lit option and the accent can never disagree.
int modeIndex(AppSettings s, {required bool pauseLive}) {
  if (pauseLive) return 2;
  return switch (s.activePlan) {
    BlockingPlan.blockAll => 0,
    BlockingPlan.curious => 1,
    BlockingPlan.oneReel => s.reelAllowance <= 1 ? 3 : 4,
    BlockingPlan.paused => 2,
  };
}

/// What the Today ring shows: [TimeLeftRing]'s face and its arc.
typedef RingFace = ({
  String eyebrow,
  bool live,
  int? value,
  String Function(int) format,
  String sub,
  double? progress,
});

String _hm(int minutes) => formatHm(Duration(minutes: minutes));
String _clock(int seconds) => formatCountdown(Duration(seconds: seconds));
String _plain(int n) => '$n';
String _reels(int n) => n == 1 ? '1 reel' : '$n reels';

/// The ring for a live [pause], an N-reel unblock ([reels] left of total),
/// or today's time against the daily [limit], first match wins. Before the
/// first counter read ([loaded] false) `measured` is a placeholder, so the
/// ring reads normally rather than "Counting is off".
RingFace ringFace({
  required bool loaded,
  required bool measured,
  required Duration spent,
  required Duration limit,
  required DateTime now,
  PauseSession? pause,
  ({int left, int total})? reels,
}) {
  if (pause != null) {
    final total = pause.pauseDuration;
    final left = pause.remainingIn(now);
    return (
      eyebrow: 'Reels allowed',
      live: true,
      value: left.inSeconds,
      format: _clock,
      sub: 'of a ${total.inMinutes} min break',
      progress: total > Duration.zero
          ? (left.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
          : 0.0,
    );
  }
  if (reels != null) {
    return (
      eyebrow: 'Reels allowed',
      live: true,
      value: reels.left,
      format: _plain,
      sub: 'of ${_reels(reels.total)}',
      progress: reels.total > 0
          ? (reels.left / reels.total).clamp(0.0, 1.0)
          : 0.0,
    );
  }
  RingFace time(String eyebrow, int? value, String sub, double? progress) => (
    eyebrow: eyebrow,
    live: false,
    value: value,
    format: _hm,
    sub: sub,
    progress: progress,
  );
  // "Count short videos" off also stops usage-time accrual: show it as
  // unmeasured, never as a reassuring "0m".
  if (loaded && !measured) {
    return time('Time left', null, 'Counting is off', null);
  }
  if (limit <= Duration.zero) {
    return time('Today', spent.inMinutes, 'No daily limit', null);
  }
  if (spent >= limit) {
    return time(
      'Time left',
      0,
      '${formatHm(spent - limit)} over your ${formatHm(limit)} limit',
      0,
    );
  }
  final left = limit - spent;
  return time(
    'Time left',
    left.inMinutes,
    '${formatHm(spent)} of ${formatHm(limit)} used',
    left.inSeconds / limit.inSeconds,
  );
}

/// The mode card's description row.
typedef ModeCopy = ({String title, String detail});

/// The description under lit mode [index] ([modeIndex]). With blocking off
/// it says so, so it never claims reels are blocked.
ModeCopy modeCopy({
  required int index,
  required bool masterOn,
  required DateTime now,
  PauseSession? pause,
  ({int left, int total})? reels,
  ConsciousState? conscious,
}) {
  if (!masterOn) {
    return (title: 'Blocking is off', detail: 'Turn it on in Settings');
  }
  return switch (index) {
    1 => (title: 'Conscious mode', detail: _consciousDetail(conscious)),
    2 when pause != null => (
      title: 'Reels allowed',
      detail: 'Blocking resumes in ${formatCountdown(pause.remainingIn(now))}',
    ),
    3 => (title: 'One reel left', detail: 'Blocked again once it ends'),
    4 when reels != null => (
      title: 'Reels allowed',
      detail: '${_reels(reels.left)} left, then blocked again',
    ),
    _ => (title: 'All reels blocked', detail: 'Across every app on your list'),
  };
}

String _consciousDetail(ConsciousState? c) {
  if (c != null && c.watching) {
    return 'Spending banked time, ${formatCountdown(c.banked)} left';
  }
  if (c != null && c.hasAllowance) {
    return '${formatCountdown(c.banked)} banked to spend';
  }
  return 'Earning 1 min for every ${SessionDefaults.consciousEarnDivisor} '
      'min away';
}

/// A blocker tile's status: nothing on its list is Not set up; the master
/// switch off, or every entry off, is Paused; anything else is On.
BlockerStatus blockerStatus({
  required int total,
  required int enabled,
  required bool masterOn,
}) {
  if (total == 0) return BlockerStatus.notSetUp;
  return masterOn && enabled > 0 ? BlockerStatus.on : BlockerStatus.paused;
}
