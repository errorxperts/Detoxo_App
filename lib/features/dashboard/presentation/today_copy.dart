import 'package:detoxo/features/blocking/blocking.dart';

/// Which of the Today screen's four modes is lit: 0 Block All, 1 Conscious,
/// 2 Pause, 3 One Reel. The app's live accent reads the same index, so the
/// lit option and the accent can never disagree.
int modeIndex(AppSettings s, {required bool pauseLive}) {
  if (pauseLive) return 2;
  return switch (s.activePlan) {
    BlockingPlan.blockAll => 0,
    BlockingPlan.curious => 1,
    // An N-reel unblock is started from the Pause sheet, so it lights Pause.
    BlockingPlan.oneReel => s.reelAllowance <= 1 ? 3 : 2,
    BlockingPlan.paused => 2,
  };
}
