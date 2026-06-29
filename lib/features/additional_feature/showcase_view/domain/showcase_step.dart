import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/widgets.dart';

/// Immutable description of one step in the feature showcase / walkthrough.
///
/// Each step binds a [key] (attached to the highlighted dashboard widget) to the
/// content shown in its glass tooltip: a small Lottie animation, a [title], a
/// [body], a semantic [tone] that colours the badge and progress dot, and a
/// Lucide [fallbackIcon] used when the Lottie asset can't be decoded.
@immutable
class ShowcaseStep {
  const ShowcaseStep({
    required this.key,
    required this.lottieAsset,
    required this.fallbackIcon,
    required this.tone,
    required this.title,
    required this.body,
  });

  /// The showcase target key — attach this to the widget being highlighted.
  final GlobalKey key;

  /// Path to the Lottie asset rendered as the feature icon
  /// (e.g. `Assets.lottie.nope`).
  final String lottieAsset;

  /// Animated-icon shown when [lottieAsset] fails to load.
  final AppIcon fallbackIcon;

  /// Semantic accent for the badge / active progress dot.
  final AppTone tone;

  /// Short feature name, e.g. "Block All".
  final String title;

  /// One- or two-sentence explanation of the feature.
  final String body;
}
