import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/widgets.dart';

/// Immutable description of one step in the feature showcase / walkthrough.
///
/// Each step binds a [key] (attached to the highlighted Today widget) to the
/// content shown in its tooltip: a feature badge ([image], a spec 3D icon, or
/// an [icon] glyph where no 3D icon exists), a [title] and a [body], all in
/// the step's own [palette] colour.
@immutable
class ShowcaseStep {
  const ShowcaseStep({
    required this.key,
    required this.title,
    required this.body,
    this.image,
    this.icon,
    this.accentTint = false,
    this.palette,
  }) : assert(image != null || icon != null, 'Provide an image or an icon');

  /// The showcase target key — attach this to the widget being highlighted.
  final GlobalKey key;

  /// Spec 3D icon shown in the badge — the same icon the highlighted widget
  /// uses (e.g. `Assets.images.icons.iconBlockAll`).
  final AssetGenImage? image;

  /// Glyph used when the step has no [image].
  final IconData? icon;

  /// Tints [image] to the step's colour, as the `ModeCard` draws its options.
  final bool accentTint;

  /// The step's colour in a theme: a mode's own palette (Block All, Conscious,
  /// One Reel, Pause), so each step reads in the colour that mode takes on
  /// Today. Null keeps the live accent.
  final AccentPalette Function(AppTokens t)? palette;

  /// Short feature name, e.g. "Block All".
  final String title;

  /// One- or two-sentence explanation of the feature.
  final String body;
}
