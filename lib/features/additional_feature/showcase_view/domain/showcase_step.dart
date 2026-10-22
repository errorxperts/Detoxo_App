import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/widgets.dart';

/// Immutable description of one step in the feature showcase / walkthrough.
///
/// Each step binds a [key] (attached to the highlighted Today widget) to the
/// content shown in its glass tooltip: a feature badge ([image], a spec 3D
/// icon, or an [icon] glyph where no 3D icon exists), a [title], a [body], and
/// a semantic [tone] that colours the badge and progress dot.
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

  /// Spec 3D icon shown in the badge — the same icon the highlighted widget
  /// uses (e.g. `Assets.images.icons.iconBlockAll`).
  final AssetGenImage? image;

  /// Animated glyph used when the step has no [image].
  final AppIcon? icon;

  /// Semantic accent for the badge / active progress dot.
  final AppTone tone;

  /// Short feature name, e.g. "Block All".
  final String title;

  /// One- or two-sentence explanation of the feature.
  final String body;
}
