import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/additional_feature/showcase_view/domain/showcase_step.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/widgets.dart';

/// Long-lived [GlobalKey]s for the five showcase targets.
///
/// They are `static final` (one instance for the app's lifetime) because only a
/// single `DashboardTab` is ever mounted at a time — recreating them per build,
/// or having two live simultaneously, would trip Flutter's duplicate-GlobalKey
/// assertion.
abstract final class FeatureShowcaseKeys {
  static final blockAll = GlobalKey(debugLabel: 'showcase.blockAll');
  static final conscious = GlobalKey(debugLabel: 'showcase.conscious');
  static final pause = GlobalKey(debugLabel: 'showcase.pause');
  static final appBlocker = GlobalKey(debugLabel: 'showcase.appBlocker');
  static final webBlocker = GlobalKey(debugLabel: 'showcase.webBlocker');

  /// Tour order — passed verbatim to `startShowCase`.
  static List<GlobalKey> get ordered => [
    blockAll,
    conscious,
    pause,
    appBlocker,
    webBlocker,
  ];
}

/// Total number of steps (used for the tooltip's "N of M" progress dots).
const int featureShowcaseStepCount = 5;

/// The ordered content for the five steps.
///
/// Index 0–2 (the three mode cells) MUST stay aligned with the dashboard's
/// `_modeOptions` order — Block All, Conscious, Pause — since the dashboard wraps
/// mode cell `i` with `featureShowcaseSteps[i]`.
final List<ShowcaseStep> featureShowcaseSteps = [
  ShowcaseStep(
    key: FeatureShowcaseKeys.blockAll,
    lottieAsset: Assets.lottie.nope,
    fallbackIcon: AppIcon.ban,
    tone: AppTone.danger,
    title: 'Block All',
    body:
        'Total focus. Every distracting app and reel is blocked the moment you '
        'open it — no exceptions.',
  ),
  ShowcaseStep(
    key: FeatureShowcaseKeys.conscious,
    lottieAsset: Assets.lottie.thinking,
    fallbackIcon: AppIcon.shieldCheck,
    tone: AppTone.accent,
    title: 'Conscious',
    body:
        'Earn your scroll. Stay off reels to bank time, then spend it mindfully '
        'whenever you choose.',
  ),
  ShowcaseStep(
    key: FeatureShowcaseKeys.pause,
    lottieAsset: Assets.lottie.plsWait,
    fallbackIcon: AppIcon.pause,
    tone: AppTone.warning,
    title: 'Pause',
    body:
        'Need a breather? Pause protection for a set window — everything is '
        'allowed, then blocking resumes automatically.',
  ),
  ShowcaseStep(
    key: FeatureShowcaseKeys.appBlocker,
    lottieAsset: Assets.lottie.handUp,
    fallbackIcon: AppIcon.appBlocker,
    tone: AppTone.accent,
    title: 'App Blocker',
    body:
        'Choose exactly which apps Detoxo guards. Tap any time to manage your '
        'blocked apps.',
  ),
  ShowcaseStep(
    key: FeatureShowcaseKeys.webBlocker,
    lottieAsset: Assets.lottie.glasses,
    fallbackIcon: AppIcon.websiteBlocker,
    tone: AppTone.success,
    title: 'Web Blocker',
    body:
        'Block distracting and adult websites right in your browser — no VPN '
        'required.',
  ),
];
