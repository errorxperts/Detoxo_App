import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/widgets.dart';

/// Immutable description of one step in the feature showcase / walkthrough.
///
/// Each step binds a [key] (attached to the highlighted dashboard widget) to the
/// content shown in its glass tooltip: a feature badge ([image] artwork, or an
/// [icon] glyph where no artwork exists), a [title], a [body], and a semantic
/// [tone] that colours the badge and progress dot.
@immutable
class ShowcaseStep {
  const ShowcaseStep({
    required this.key,
    required this.tone,
    required this.title,
    required this.body,
    this.image,
    this.icon,
  }) : assert(image != null || icon != null, 'Provide an image or an icon');

  /// The showcase target key — attach this to the widget being highlighted.
  final GlobalKey key;

  /// Illustration asset shown in the badge — the same artwork the highlighted
  /// widget uses (e.g. `Assets.images.illustration.block.path`).
  final String? image;

  /// Animated glyph used when the step has no [image].
  final AppIcon? icon;

  /// Semantic accent for the badge / active progress dot.
  final AppTone tone;

  /// Short feature name, e.g. "Block All".
  final String title;

  /// One- or two-sentence explanation of the feature.
  final String body;
}
