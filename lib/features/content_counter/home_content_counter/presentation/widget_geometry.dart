import 'dart:ui';

import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_style_enums.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/widget_tokens.g.dart';

/// The DS-04 box of each size class, in design units (Kotlin mirror:
/// `WidgetSize.designWidth/Height` + `WidgetTokens`).
extension WidgetSizeGeometry on WidgetSize {
  Size get box => switch (this) {
    WidgetSize.small => const Size(
      WidgetTokens.widgetSW,
      WidgetTokens.widgetSH,
    ),
    WidgetSize.medium => const Size(
      WidgetTokens.widgetMW,
      WidgetTokens.widgetMH,
    ),
    WidgetSize.large => const Size(
      WidgetTokens.widgetLW,
      WidgetTokens.widgetLH,
    ),
  };
}
