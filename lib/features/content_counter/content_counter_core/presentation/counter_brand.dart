import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/widgets.dart';

/// The app theme's primary in [brightness], ARGB: the brand of the background
/// picked for that brightness. Native tints the bubble and the widgets with
/// the same value (pushed by `_BrandSync`), so a preview shows what will be
/// drawn, even in the brightness the app isn't showing.
int counterBrand(BuildContext context, Brightness brightness) => brandFor(
  BackgroundScope.of(context, brightness),
  brightness,
).primary.toARGB32();
