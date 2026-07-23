import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/app_settings.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/features/blocking/shared/presentation/settings_cubit.dart';
import 'package:detoxo/features/content_counter/content_counter_appearance/presentation/widgets/bubble_preview.dart';
import 'package:detoxo/features/content_counter/content_counter_appearance/presentation/widgets/widget_preview.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/domain/repositories/bubble_repository.dart';
import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_appearance.dart';
import 'package:detoxo/features/content_counter/content_counter_core/domain/repositories/content_counter_repository.dart';
import 'package:detoxo/features/content_counter/content_counter_core/domain/repositories/counter_appearance_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

/// One home for how Detoxo *looks*: the app theme (a Light / Dark segmented
/// control that auto-follows the device by default) and background, plus the
/// reel counter's two surfaces — the floating bubble and the home-screen widget,
/// each shown as a large live preview you tap to customise. The bubble carries
/// its own on/off; the widget and both editors are gated by the counting master.
class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  final ContentCounterRepository _counter = sl<ContentCounterRepository>();
  final BubbleRepository _bubble = sl<BubbleRepository>();
  final CounterAppearanceRepository _appearanceRepo =
      sl<CounterAppearanceRepository>();

  bool _counterOn = true;
  bool _bubbleOn = true;
  bool _loaded = false;

  // Live style + representative counts, so the previews read at a legible number
  // even before anything is counted today.
  CounterAppearance _appearance = const CounterAppearance.defaults();
  int _today = 137;
  int _total = 1240;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final count = await _counter.current();
    final appearance = await _appearanceRepo.current();
    if (!mounted) return;
    setState(() {
      _counterOn = count.enabled;
      _bubbleOn = count.bubbleEnabled;
      _appearance = appearance;
      if (count.today > 0) _today = count.today;
      if (count.total > 0) _total = count.total;
      _loaded = true;
    });
  }

  /// Re-pull the styles after returning from an editor so the previews reflect
  /// any change the user just made.
  Future<void> _reloadStyles() async {
    final appearance = await _appearanceRepo.current();
    if (!mounted) return;
    setState(() => _appearance = appearance);
  }

  void _toggleCounter(bool on) {
    setState(() => _counterOn = on);
    unawaited(_counter.setEnabled(enabled: on));
  }

  void _toggleBubble(bool on) {
    setState(() => _bubbleOn = on);
    unawaited(_applyBubble(on));
  }

  Future<void> _applyBubble(bool on) async {
    await _bubble.setEnabled(enabled: on);
    if (on && !await _bubble.canShow()) {
      await _bubble.requestPermission();
    }
  }

  Future<void> _openStyle(String route) async {
    await context.push(route);
    await _reloadStyles();
  }

  @override
  Widget build(BuildContext context) {
    final bubbleStyle = _appearance.bubble;
    final widgetStyle = _appearance.widget;
    final bubbleEditable = _counterOn && _bubbleOn;
    return GlassScaffold(
      appBar: const GlassAppBar(title: Text('Appearance')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.xxl + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          // ── App theme ───────────────────────────────────────────────────
          const SectionHeader('Theme'),
          const _ThemeControl(),

          // ── App background ──────────────────────────────────────────────
          const SectionHeader('Background'),
          const _BackgroundSection(),

          // ── Reel counter: master switch + the two surfaces as cards ─────
          const SectionHeader('Reel counter'),
          AdaptiveSwitchTile(
            leading: const IconBadge(icon: Icons.movie_filter_rounded),
            title: 'Count short videos',
            value: _counterOn,
            onChanged: _loaded ? _toggleCounter : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _SurfaceCard(
                    title: 'Bubble',
                    preview: BubblePreview(
                      style: bubbleStyle,
                      count: _today,
                      area: 88,
                    ),
                    editable: bubbleEditable,
                    onEdit: () => unawaited(_openStyle(Routes.bubbleStyle)),
                    trailing: AppToggle(
                      value: _bubbleOn,
                      enabled: _loaded && _counterOn,
                      onChanged: _toggleBubble,
                    ),
                    disabledHint: !_counterOn ? 'Counting off' : 'Bubble off',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _SurfaceCard(
                    title: 'Widget',
                    preview: WidgetPreview(
                      style: widgetStyle,
                      today: _today,
                      total: _total,
                      size: 88,
                    ),
                    editable: _counterOn,
                    onEdit: () => unawaited(_openStyle(Routes.homeWidget)),
                    disabledHint: 'Counting off',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Theme control (segmented + match-system, no glass card) ─────────────────────

/// The app-theme control, kept deliberately flat (no card): a custom sliding
/// **Light / Dark** segmented button plus a compact **Match system** row that
/// keeps the app auto-following the device (the default). Picking a segment
/// commits an explicit theme and turns matching off; while matching is on the
/// segment dims to show it's device-driven, not locked. The whole app re-themes
/// instantly.
class _ThemeControl extends StatelessWidget {
  const _ThemeControl();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, AppSettings>(
      buildWhen: (a, b) => a.themeMode != b.themeMode,
      builder: (context, settings) {
        final mode = settings.themeMode;
        final system = mode == AppThemeMode.system;
        final dark = Theme.of(context).brightness == Brightness.dark;
        final selectedIndex = switch (mode) {
          AppThemeMode.light => 0,
          AppThemeMode.dark => 1,
          AppThemeMode.system => dark ? 1 : 0,
        };
        final cubit = context.read<SettingsCubit>();
        final text = Theme.of(context).textTheme;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedOpacity(
              duration: AppDurations.fast,
              opacity: system ? 0.55 : 1,
              child: _ThemeSegmented(
                selectedIndex: selectedIndex,
                onChanged: (i) => cubit.setThemeMode(
                  i == 0 ? AppThemeMode.light : AppThemeMode.dark,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  Icons.brightness_auto_rounded,
                  size: 20,
                  color: context.glass.onGlassMuted,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Match system',
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                AppToggle(
                  value: system,
                  onChanged: (on) => cubit.setThemeMode(
                    on
                        ? AppThemeMode.system
                        : dark
                        ? AppThemeMode.dark
                        : AppThemeMode.light,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// A custom two-option segmented control with a sliding accent pill. Snappier and
/// more tactile than the plain Material segmented button — the pill glides
/// between segments and each tap fires a selection haptic.
class _ThemeSegmented extends StatelessWidget {
  const _ThemeSegmented({required this.selectedIndex, required this.onChanged});

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  static const List<(String, IconData)> _items = [
    ('Light', Icons.light_mode_rounded),
    ('Dark', Icons.dark_mode_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final accent = Theme.of(context).colorScheme.secondary;
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.glass.fillBottom,
        borderRadius: AppRadius.brPill,
        border: Border.all(color: context.glass.border),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The sliding selection pill.
          AnimatedAlign(
            duration: AppDurations.normal,
            curve: AppCurves.emphasized,
            alignment: selectedIndex == 0
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.22),
                  borderRadius: AppRadius.brPill,
                  border: Border.all(
                    color: accent.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      AppHaptics.selection();
                      onChanged(i);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _items[i].$2,
                          size: 18,
                          color: selectedIndex == i
                              ? accent
                              : context.glass.onGlassMuted,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          _items[i].$1,
                          style: text.labelLarge?.copyWith(
                            fontWeight: selectedIndex == i
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selectedIndex == i
                                ? accent
                                : context.glass.onGlassMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Surface card (bubble / home widget) ─────────────────────────────────────────

/// A card whose hero is a large live preview of the surface's current style.
/// Tapping the preview opens the editor — but only when [editable]; otherwise the
/// preview dims and a one-line hint explains what to switch on. [trailing] holds
/// the surface's own on/off switch (the bubble) or is null (the widget, gated by
/// the counting master).
class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.title,
    required this.preview,
    required this.editable,
    required this.onEdit,
    this.trailing,
    this.disabledHint,
  });

  final String title;
  final Widget preview;
  final bool editable;
  final VoidCallback onEdit;
  final Widget? trailing;
  final String? disabledHint;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fixed-height header so the previews line up across the two cards
          // even though only the bubble carries a switch.
          SizedBox(
            height: AppSizes.controlHeight,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: editable ? onEdit : null,
            child: AnimatedOpacity(
              duration: AppDurations.fast,
              opacity: editable ? 1 : 0.4,
              child: SizedBox(
                height: 96,
                child: Stack(
                  children: [
                    Center(child: preview),
                    if (editable)
                      const Positioned(top: 0, right: 0, child: _EditBadge()),
                  ],
                ),
              ),
            ),
          ),
          if (!editable && disabledHint != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Center(
              child: Text(
                disabledHint!,
                style: text.bodySmall?.copyWith(
                  color: context.glass.onGlassMuted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The little accent "edit" affordance pinned to a tappable preview.
class _EditBadge extends StatelessWidget {
  const _EditBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.tune_rounded,
        size: 16,
        color: Theme.of(context).colorScheme.onSecondary,
      ),
    );
  }
}

// ── Background carousel ─────────────────────────────────────────────────────────

/// The animated-background picker: a horizontally-scrolling row of real SVG
/// previews with the chosen background's name below. The options are
/// theme-specific — dark mode shows the `dark*` backgrounds, light mode shows
/// Aurora + the `light*` backgrounds — and each theme keeps its own pick.
/// Selecting a card updates the app background live behind this screen.
class _BackgroundSection extends StatelessWidget {
  const _BackgroundSection();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = Theme.of(context).textTheme;
    final options = dark ? _darkBackgrounds : _lightBackgrounds;
    return BlocBuilder<SettingsCubit, AppSettings>(
      buildWhen: (a, b) =>
          a.darkBackground != b.darkBackground ||
          a.lightBackground != b.lightBackground,
      builder: (context, settings) {
        final selected = dark
            ? settings.darkBackground
            : settings.lightBackground;
        final current = options.firstWhere(
          (e) => e.$1 == selected,
          orElse: () => options.first,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                itemCount: options.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final b = options[i];
                  return _BgCard(
                    style: b.$1,
                    dark: dark,
                    selected: b.$1 == selected,
                    onTap: () => context.read<SettingsCubit>().setBackground(
                      b.$1,
                      dark: dark,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              current.$2,
              style: text.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.glass.onGlass,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One background preview card (real SVG, or a gradient for the asset-less
/// Aurora). The SVG is blurred to mirror the full-screen ambient background —
/// which blurs its SVG heavily — so the swatch reads like what actually renders.
/// The selected card animates to an accent ring + glow with a check badge.
class _BgCard extends StatelessWidget {
  const _BgCard({
    required this.style,
    required this.dark,
    required this.selected,
    required this.onTap,
  });

  final AppBackground style;
  final bool dark;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final asset = _bgSvgAsset(style);
    final accent = Theme.of(context).colorScheme.secondary;
    final borderWidth = selected ? 2.0 : 1.0;
    final preview = asset == null
        ? DecoratedBox(
            decoration: BoxDecoration(gradient: _auroraSwatchGradient(dark)),
          )
        // Match the ambient background's heavy blur, scaled to the swatch.
        : ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: SvgPicture.asset(asset, fit: BoxFit.cover),
          );
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        curve: AppCurves.standard,
        width: 116,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? accent : context.glass.border,
            width: borderWidth,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md - borderWidth),
          child: Stack(
            fit: StackFit.expand,
            children: [
              preview,
              if (selected)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Background option data ──────────────────────────────────────────────────────

/// Dark-mode background options (default first). Dark has no Aurora — it's a
/// light-mode ambient.
const _darkBackgrounds = <(AppBackground, String)>[
  (AppBackground.dark1, 'Midnight'),
  (AppBackground.dark2, 'Twilight'),
  (AppBackground.dark3, 'Nebula'),
  (AppBackground.dark4, 'Magenta'),
  (AppBackground.dark5, 'Frost'),
  (AppBackground.dark6, 'Prism'),
];

/// Light-mode background options (Aurora, the theme-aware ambient, is default).
const _lightBackgrounds = <(AppBackground, String)>[
  (AppBackground.aurora, 'Aurora'),
  (AppBackground.light1, 'Sky'),
  (AppBackground.light2, 'Dawn'),
  (AppBackground.light3, 'Blossom'),
  (AppBackground.light4, 'Sunrise'),
  (AppBackground.light5, 'Pastel'),
];

/// SVG asset for a background, or null for Aurora (which has no asset). Mirrors
/// `svgAssetFor` in the design system — the presentation layer can't reach
/// `main.dart`'s domain→style mapper, so a small local copy keeps the picker
/// self-contained.
String? _bgSvgAsset(AppBackground style) => switch (style) {
  AppBackground.aurora => null,
  AppBackground.dark1 => 'assets/images/bg/dark_bg1.svg',
  AppBackground.dark2 => 'assets/images/bg/dark_bg2.svg',
  AppBackground.dark3 => 'assets/images/bg/dark_bg3.svg',
  AppBackground.dark4 => 'assets/images/bg/dark_bg4.svg',
  AppBackground.dark5 => 'assets/images/bg/dark_bg5.svg',
  AppBackground.dark6 => 'assets/images/bg/dark_bg6.svg',
  AppBackground.light1 => 'assets/images/bg/light_bg1.svg',
  AppBackground.light2 => 'assets/images/bg/light_bg2.svg',
  AppBackground.light3 => 'assets/images/bg/light_bg3.svg',
  AppBackground.light4 => 'assets/images/bg/light_bg4.svg',
  AppBackground.light5 => 'assets/images/bg/light_bg5.svg',
};

/// A small gradient standing in for the (asset-less) Aurora background in its
/// picker swatch.
Gradient _auroraSwatchGradient(bool dark) => LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: dark
      ? const [Color(0xFF1E2A52), Color(0xFF3A2A78), Color(0xFF0B1326)]
      : const [Color(0xFFF1ECFF), Color(0xFFE6FBF6), Color(0xFFEEF1FB)],
);
