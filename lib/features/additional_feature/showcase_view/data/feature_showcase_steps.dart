import 'package:detoxo/features/additional_feature/showcase_view/domain/showcase_step.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/widgets.dart';

/// Long-lived [GlobalKey]s for the seven showcase targets.
///
/// They are `static final` (one instance for the app's lifetime) because only a
/// single `DashboardTab` is ever mounted at a time — recreating them per build,
/// or having two live simultaneously, would trip Flutter's duplicate-GlobalKey
/// assertion.
abstract final class FeatureShowcaseKeys {
  static final blockAll = GlobalKey(debugLabel: 'showcase.blockAll');
  static final conscious = GlobalKey(debugLabel: 'showcase.conscious');
  static final pause = GlobalKey(debugLabel: 'showcase.pause');
  static final oneReel = GlobalKey(debugLabel: 'showcase.oneReel');
  static final unblock = GlobalKey(debugLabel: 'showcase.unblock');
  static final appBlocker = GlobalKey(debugLabel: 'showcase.appBlocker');
  static final webBlocker = GlobalKey(debugLabel: 'showcase.webBlocker');

  /// Tour order — passed verbatim to `startShowCase`.
  static List<GlobalKey> get ordered => [
    blockAll,
    conscious,
    pause,
    oneReel,
    unblock,
    appBlocker,
    webBlocker,
  ];
}

/// Total number of steps (used for the tooltip's "N of M" progress dots).
const int featureShowcaseStepCount = 7;

/// The ordered content for the seven steps.
///
/// Index 0–4 (the five modes) MUST stay aligned with the Today mode card's
/// option order — Block All, Conscious, Pause, One Reel, Unblock — since
/// `ModeCard.decorateOption` wraps option `i` with `featureShowcaseSteps[i]`.
/// Index 5–6 are the App Blocker / Web Blocker tiles. The five mode steps tint
/// their badge to the live accent, as the mode card tints its options.
final List<ShowcaseStep> featureShowcaseSteps = [
  ShowcaseStep(
    key: FeatureShowcaseKeys.blockAll,
    image: Assets.images.icons.iconBlockAll,
    accentTint: true,
    title: 'Block All',
    body:
        'Total focus. Every distracting app and reel is blocked the moment you '
        'open it — no exceptions.',
  ),
  ShowcaseStep(
    key: FeatureShowcaseKeys.conscious,
    image: Assets.images.icons.iconConscious,
    accentTint: true,
    title: 'Conscious',
    body:
        'Earn your scroll. Stay off reels to bank time, then spend it mindfully '
        'whenever you choose.',
  ),
  ShowcaseStep(
    key: FeatureShowcaseKeys.pause,
    image: Assets.images.icons.iconPause,
    accentTint: true,
    title: 'Pause',
    body:
        'Need a breather? Unblock reels for a few minutes, then blocking '
        'returns to your base mode on its own.',
  ),
  ShowcaseStep(
    key: FeatureShowcaseKeys.oneReel,
    image: Assets.images.icons.iconOneReel,
    accentTint: true,
    title: 'One Reel',
    body:
        'Watch a single reel, then Detoxo locks straight back to your base '
        'mode. Quick scrolls don’t use it up: a reel counts after a couple of '
        'seconds.',
  ),
  ShowcaseStep(
    key: FeatureShowcaseKeys.unblock,
    image: Assets.images.icons.iconReelCount,
    accentTint: true,
    title: 'Unblock',
    body:
        'Pick how many reels to watch, from 1 to 20. Blocking comes back '
        'after the last one.',
  ),
  ShowcaseStep(
    key: FeatureShowcaseKeys.appBlocker,
    image: Assets.images.icons.iconAppBlocker,
    title: 'App Blocker',
    body:
        'Choose exactly which apps Detoxo guards. Tap any time to manage your '
        'blocked apps.',
  ),
  ShowcaseStep(
    key: FeatureShowcaseKeys.webBlocker,
    image: Assets.images.icons.iconWebBlocker,
    title: 'Web Blocker',
    body:
        'Block distracting and adult websites right in your browser — no VPN '
        'required.',
  ),
];
