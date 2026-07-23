import 'package:flutter/widgets.dart';

/// Design-system-neutral identity for the active app background. The
/// feature/domain layer (`AppBackground`) maps onto this so `design_system`
/// never imports the domain — mirroring how `main.dart` maps `AppThemeMode`
/// onto Flutter's `ThemeMode`.
///
/// [aurora] is the built-in ambient glow (no asset; painted by
/// `AmbientBackground` and made theme-aware). The rest are single SVG assets:
/// [dark1]–[dark6] for dark mode, [light1]–[light5] for light mode — see
/// [svgAssetFor].
enum AppBackgroundStyle {
  aurora,
  dark1,
  dark2,
  dark3,
  dark4,
  dark5,
  dark6,
  light1,
  light2,
  light3,
  light4,
  light5,
}

/// Resolves the SVG asset path for [style], or `null` to render the theme-aware
/// Aurora ambient. Each style is theme-specific, so there is one asset per style.
String? svgAssetFor(AppBackgroundStyle style) => switch (style) {
  AppBackgroundStyle.aurora => null,
  AppBackgroundStyle.dark1 => 'assets/images/bg/dark_bg1.svg',
  AppBackgroundStyle.dark2 => 'assets/images/bg/dark_bg2.svg',
  AppBackgroundStyle.dark3 => 'assets/images/bg/dark_bg3.svg',
  AppBackgroundStyle.dark4 => 'assets/images/bg/dark_bg4.svg',
  AppBackgroundStyle.dark5 => 'assets/images/bg/dark_bg5.svg',
  AppBackgroundStyle.dark6 => 'assets/images/bg/dark_bg6.svg',
  AppBackgroundStyle.light1 => 'assets/images/bg/light_bg1.svg',
  AppBackgroundStyle.light2 => 'assets/images/bg/light_bg2.svg',
  AppBackgroundStyle.light3 => 'assets/images/bg/light_bg3.svg',
  AppBackgroundStyle.light4 => 'assets/images/bg/light_bg4.svg',
  AppBackgroundStyle.light5 => 'assets/images/bg/light_bg5.svg',
};

/// Inherited selection of the active background, read by `AmbientBackground`
/// (via `GlassScaffold`) so screens needn't thread it through. Carries a [dark]
/// and a [light] choice; [of] returns the one matching the active brightness.
/// Defaults to [AppBackgroundStyle.aurora] when no scope is present, so any
/// subtree (incl. tests) renders a correct background.
class BackgroundScope extends InheritedWidget {
  const BackgroundScope({
    required this.dark,
    required this.light,
    required super.child,
    super.key,
  });

  final AppBackgroundStyle dark;
  final AppBackgroundStyle light;

  static AppBackgroundStyle of(BuildContext context, Brightness brightness) {
    final scope = context.dependOnInheritedWidgetOfExactType<BackgroundScope>();
    if (scope == null) return AppBackgroundStyle.aurora;
    return brightness == Brightness.dark ? scope.dark : scope.light;
  }

  @override
  bool updateShouldNotify(BackgroundScope oldWidget) =>
      oldWidget.dark != dark || oldWidget.light != light;
}
