import 'package:flutter/widgets.dart';

/// Design-system-neutral identity for the active app background. The
/// feature/domain layer (`AppBackground`) maps onto this so `design_system`
/// never imports the domain — mirroring how `main.dart` maps `AppThemeMode`
/// onto Flutter's `ThemeMode`.
///
/// [aurora] is the built-in ambient glow (no asset; painted by
/// `AmbientBackground` and made theme-aware). [bg1]–[bg3] are SVG gradient
/// backgrounds, each with a dark and light variant — see [svgAssetFor].
enum AppBackgroundStyle { aurora, bg1, bg2, bg3 }

/// Resolves the SVG asset path for [style] under [brightness], or `null` to
/// render the theme-aware Aurora ambient (the default).
String? svgAssetFor(AppBackgroundStyle style, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  switch (style) {
    case AppBackgroundStyle.aurora:
      return null;
    case AppBackgroundStyle.bg1:
      return dark ? 'assets/images/bg/dark_bg1.svg' : 'assets/images/bg/light_bg1.svg';
    case AppBackgroundStyle.bg2:
      return dark ? 'assets/images/bg/dark_bg2.svg' : 'assets/images/bg/light_bg2.svg';
    case AppBackgroundStyle.bg3:
      return dark ? 'assets/images/bg/dark_bg3.svg' : 'assets/images/bg/light_bg3.svg';
  }
}

/// Inherited selection of the active background, read by `AmbientBackground`
/// (via `GlassScaffold`) so screens needn't thread it through. Defaults to
/// [AppBackgroundStyle.aurora] when no scope is present, so any subtree (incl.
/// tests) renders a correct background.
class BackgroundScope extends InheritedWidget {
  const BackgroundScope({
    required this.style,
    required super.child,
    super.key,
  });

  final AppBackgroundStyle style;

  static AppBackgroundStyle of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<BackgroundScope>();
    return scope?.style ?? AppBackgroundStyle.aurora;
  }

  @override
  bool updateShouldNotify(BackgroundScope oldWidget) =>
      oldWidget.style != style;
}
