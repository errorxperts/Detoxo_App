import 'dart:async';

import 'package:detoxo/core/constants/app_constants.dart';
import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/core/storage/local_store.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';
import 'package:detoxo/features/access_protection/domain/entities/pin_config.dart';
import 'package:detoxo/features/access_protection/presentation/pin_cubit.dart';
import 'package:detoxo/features/access_protection/presentation/pin_gate.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/app_settings.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/features/blocking/shared/presentation/settings_cubit.dart';
import 'package:detoxo/features/permissions/domain/entities/permission_status.dart';
import 'package:detoxo/features/permissions/presentation/permissions_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

/// The app's control hub: protection, feedback, usage, security & permissions,
/// appearance, about and reset — all in the glass design system. Plans, pause
/// and the platform blocklist live on the home screen, not here.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<PermissionsCubit>().refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user typically grants permissions from a system screen and returns.
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<PermissionsCubit>().refresh();
    }
  }

  /// Permissions live in a popup so the main screen stays short.
  Future<void> _openPermissions() async {
    await GlassBottomSheet.show<void>(
      context: context,
      title: 'Permissions',
      child: const _PermissionSheet(),
    );
  }

  /// Block-mode and appearance are chosen in popups too, so every choice on this
  /// screen opens the same kind of sheet (consistent with Permissions).
  Future<void> _openBlockMode() async {
    await GlassBottomSheet.show<void>(
      context: context,
      title: 'When a reel is detected',
      child: const _BlockModeSheet(),
    );
  }

  Future<void> _openTheme() async {
    await GlassBottomSheet.show<void>(
      context: context,
      title: 'Appearance',
      child: const _ThemeSheet(),
    );
  }

  /// Replays the one-time feature tour. The walkthrough lives on the dashboard
  /// (where its highlighted targets are), so we clear the "seen" flag and return
  /// home; the dashboard's coordinator restarts the showcase on the flag's
  /// true→false edge once it's front-most.
  void _replayShowcase() {
    unawaited(context.read<SettingsCubit>().setShowcaseSeen(value: false));
    context.go(Routes.home);
  }

  /// Disabling protection is a sensitive change, so it asks for the PIN (when
  /// the `settings` scope guards it); enabling proceeds directly. The switch is
  /// bound to `settings.masterEnabled`, so a cancelled PIN snaps it back.
  Future<void> _setMasterEnabled(BuildContext context, {required bool enabled}) async {
    if (!enabled) {
      final ok = await requirePin(context, PinScope.settings);
      if (!ok || !context.mounted) return;
    }
    if (!context.mounted) return;
    await context.read<SettingsCubit>().setMasterEnabled(enabled: enabled);
  }

  Future<void> _resetData() async {
    // Reset wipes the PIN itself, so it's a protected change: ask for the PIN
    // first (no-op when none is configured).
    if (!await requirePin(context, PinScope.settings) || !mounted) return;
    final ok = await AppDialog.confirm(
      context: context,
      title: 'Reset app data?',
      message:
          'This wipes your settings, blocklists, limits and PIN, then restarts '
          'onboarding. This cannot be undone.',
      confirmLabel: 'Reset everything',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await sl<LocalStore>().clearAll();
    if (!mounted) return;
    context.go(Routes.splash);
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: const GlassAppBar(title: Text('Settings')),
      body: BlocBuilder<SettingsCubit, AppSettings>(
        builder: (context, settings) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xxl),
            children: [
              // ── Protection: how Detoxo blocks & limits reels ────────────
              const SectionHeader('Protection'),
              _Spaced(
                AdaptiveSwitchTile(
                  leading: const Icon(Icons.shield_outlined, color: AppColors.accent),
                  title: 'Blocking active',
                  subtitle: 'Master switch for all detection',
                  value: settings.masterEnabled,
                  onChanged: (v) => unawaited(_setMasterEnabled(context, enabled: v)),
                ),
              ),
              FeatureTile(
                icon: Icons.touch_app_outlined,
                title: 'When a reel is detected',
                subtitle: _blockModeTitle(settings.defaultBlockMode),
                onTap: _openBlockMode,
              ),
              _Spaced(
                AdaptiveSwitchTile(
                  leading: const Icon(Icons.vibration, color: AppColors.accent),
                  title: 'Vibrate on block',
                  subtitle: 'Haptic buzz each time a reel is blocked',
                  value: settings.vibrationEnabled,
                  onChanged: (v) => context.read<SettingsCubit>().setVibration(enabled: v),
                ),
              ),
              FeatureTile(
                icon: Icons.hourglass_bottom,
                animatedIcon: AppIcon.dailyLimit,
                title: 'Daily limit',
                subtitle: 'Cap your reel time per day',
                onTap: () => context.push(Routes.dailyLimit),
              ),

              // ── Security: who can change things & system access ─────────
              const SectionHeader('Security'),
              _PinTile(),
              _PermissionsTile(onTap: _openPermissions),

              // ── General: appearance & app info ──────────────────────────
              const SectionHeader('General'),
              FeatureTile(
                icon: Icons.tips_and_updates_outlined,
                animatedIcon: AppIcon.info,
                title: 'Feature tour',
                subtitle: "Replay the walkthrough of Detoxo's features",
                onTap: _replayShowcase,
              ),
              FeatureTile(
                icon: _themeIcon(settings.themeMode),
                title: 'Appearance',
                subtitle: '${_themeLabel(settings.themeMode)} • ${_bgLabel(settings.backgroundId)}',
                onTap: _openTheme,
              ),
              _Spaced(
                GlassListTile(
                  leading: const Icon(Icons.info_outline, color: AppColors.accent),
                  title: AppConstants.appName,
                  subtitle: 'Reclaim your attention from short-form video',
                  trailing: Text(
                    'v${AppConstants.appVersion}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: context.glass.onGlassMuted),
                  ),
                ),
              ),

              // ── Reset ───────────────────────────────────────────────────
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: GhostButton(label: 'Reset app data', onPressed: _resetData),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Adds the standard inter-row gap below rows that don't bake it in themselves
/// ([FeatureTile] already includes a bottom gap), keeping list rhythm even.
class _Spaced extends StatelessWidget {
  const _Spaced(this.child);
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: child,
  );
}

// ── Block-mode + appearance option data ───────────────────────────────────────

const _blockModes = <(BlockingMode, String, String)>[
  (BlockingMode.pressBack, 'Press back', 'Gently exits the reel (recommended)'),
  (BlockingMode.killApp, 'Close the app', 'Force-closes (exit app) the offending app'),
  (BlockingMode.lockApp, 'Lock app', 'Locks the app behind your PIN, like an app locker'),
];

String _blockModeTitle(BlockingMode m) =>
    _blockModes.firstWhere((e) => e.$1 == m, orElse: () => _blockModes.first).$2;

String _themeLabel(AppThemeMode m) => switch (m) {
  AppThemeMode.system => 'System',
  AppThemeMode.light => 'Light',
  AppThemeMode.dark => 'Dark',
};

String _themeSubtitle(AppThemeMode m) => switch (m) {
  AppThemeMode.system => 'Match your device theme',
  AppThemeMode.light => 'Always light',
  AppThemeMode.dark => 'Always dark',
};

IconData _themeIcon(AppThemeMode m) => switch (m) {
  AppThemeMode.system => Icons.brightness_auto,
  AppThemeMode.light => Icons.light_mode,
  AppThemeMode.dark => Icons.dark_mode,
};

// ── Background option data ─────────────────────────────────────────────────────

const _backgrounds = <(AppBackground, String, String)>[
  (AppBackground.aurora, 'Aurora', 'Soft brand glow (default)'),
  (AppBackground.bg1, 'Sunset', 'Warm dusk gradient'),
  (AppBackground.bg2, 'Ocean', 'Cool blue gradient'),
  (AppBackground.bg3, 'Prism', 'Multi-colour gradient'),
];

String _bgLabel(AppBackground b) =>
    _backgrounds.firstWhere((e) => e.$1 == b, orElse: () => _backgrounds.first).$2;

/// SVG asset for a background's theme variant, or null for Aurora (which has no
/// asset). Mirrors `svgAssetFor` in the design system — the presentation layer
/// can't reach `main.dart`'s domain→style mapper, so a small local copy keeps
/// the picker self-contained.
String? _bgSvgAsset(AppBackground style, bool dark) => switch (style) {
  AppBackground.aurora => null,
  AppBackground.bg1 => dark ? 'assets/images/bg/dark_bg1.svg' : 'assets/images/bg/light_bg1.svg',
  AppBackground.bg2 => dark ? 'assets/images/bg/dark_bg2.svg' : 'assets/images/bg/light_bg2.svg',
  AppBackground.bg3 => dark ? 'assets/images/bg/dark_bg3.svg' : 'assets/images/bg/light_bg3.svg',
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

// ── Selectable option row (used in pickers) ───────────────────────────────────

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassListTile(
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? AppColors.accent : context.glass.onGlassMuted,
      ),
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    );
  }
}

// ── PIN lock: master switch + edit tile ───────────────────────────────────────

class _PinTile extends StatelessWidget {
  /// Master switch. Turning ON opens setup; turning OFF asks for the PIN and a
  /// confirmation, then disables. The switch is bound to `isConfigured`, so a
  /// cancelled turn-off (or a setup the user backs out of) snaps it back.
  Future<void> _toggle(BuildContext context, {required bool enable}) async {
    if (enable) {
      await context.push(Routes.pinSetup);
      return;
    }
    if (!await requirePin(context, PinScope.settings) || !context.mounted) {
      return;
    }
    final ok = await AppDialog.confirm(
      context: context,
      title: 'Turn off PIN lock?',
      message:
          'Detoxo and its protected sections will no longer ask for a PIN.',
      confirmLabel: 'Turn off',
      cancelLabel: 'Keep it on',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await context.read<PinCubit>().disable();
  }

  /// Edit the configured PIN (type, recovery email, biometrics). Gated by the
  /// settings scope like every protected change.
  Future<void> _openSettings(BuildContext context) async {
    if (await requirePin(context, PinScope.settings) && context.mounted) {
      unawaited(context.push(Routes.pinSetup));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PinCubit, PinConfig>(
      builder: (context, config) {
        final on = config.isConfigured;
        final typeLabel = switch (config.type) {
          PinType.custom => 'Custom',
          PinType.date => 'Date',
          PinType.time => 'Time',
          _ => '',
        };
        return Column(
          children: [
            _Spaced(
              AdaptiveSwitchTile(
                leading: const Icon(Icons.lock_outline, color: AppColors.accent),
                title: 'PIN lock',
                subtitle: on
                    ? 'On • $typeLabel PIN'
                    : 'Off — protect Detoxo with a PIN',
                value: on,
                onChanged: (v) => unawaited(_toggle(context, enable: v)),
              ),
            ),
            if (on)
              FeatureTile(
                icon: Icons.tune,
                animatedIcon: AppIcon.pinLock,
                title: 'PIN settings',
                subtitle: 'Type, recovery email & biometrics',
                onTap: () => _openSettings(context),
              ),
          ],
        );
      },
    );
  }
}

// ── Permissions: entry tile + popup ───────────────────────────────────────────

IconData _permissionIcon(AppPermission p) => switch (p) {
  AppPermission.accessibility => Icons.accessibility_new,
  AppPermission.overlay => Icons.layers,
  AppPermission.notifications => Icons.notifications,
  AppPermission.usageAccess => Icons.bar_chart,
  AppPermission.batteryOptimization => Icons.battery_charging_full,
  AppPermission.deviceAdmin => Icons.shield,
};

String _permissionWhy(AppPermission p) => switch (p) {
  AppPermission.accessibility => 'Detect and block reels & shorts',
  AppPermission.overlay => 'Show the block / PIN screen over apps',
  AppPermission.notifications => 'Alert you if protection stops',
  AppPermission.usageAccess => 'Power app usage limits',
  AppPermission.batteryOptimization => 'Keep the blocker alive',
  AppPermission.deviceAdmin => 'Uninstall protection',
};

/// Main-screen entry: a single tile summarising permission status; opens the
/// full list in a popup.
class _PermissionsTile extends StatelessWidget {
  const _PermissionsTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PermissionsCubit, List<PermissionStatus>>(
      builder: (context, statuses) {
        final granted = statuses.where((s) => s.granted).length;
        final total = statuses.length;
        final allOk = total > 0 && granted == total;
        return FeatureTile(
          icon: Icons.verified_user_outlined,
          animatedIcon: AppIcon.shieldCheck,
          title: 'Permissions',
          subtitle: 'Accessibility, overlay, notifications & more',
          trailing: total == 0
              ? const Icon(Icons.chevron_right)
              : Pill(
                  label: allOk ? 'All set' : '$granted/$total',
                  tone: allOk ? AppTone.success : AppTone.warning,
                ),
          onTap: onTap,
        );
      },
    );
  }
}

/// Popup body: the full permission list with grant actions. Updates live as the
/// user grants from system screens and returns.
class _PermissionSheet extends StatelessWidget {
  const _PermissionSheet();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PermissionsCubit, List<PermissionStatus>>(
      builder: (context, statuses) {
        if (statuses.isEmpty) {
          return const Text('No permissions to manage.');
        }
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final s in statuses)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: GlassListTile(
                    leading: Icon(_permissionIcon(s.kind), color: AppColors.accent),
                    title: s.kind.label,
                    subtitle: _permissionWhy(s.kind),
                    trailing: s.granted
                        ? const Pill(label: 'Granted', tone: AppTone.success, icon: Icons.check)
                        : TextButton(
                            onPressed: () => context.read<PermissionsCubit>().request(s.kind),
                            child: Text(s.kind.required ? 'Grant' : 'Enable'),
                          ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Block-mode picker (popup) ───────────────────────────────────────────────────

class _BlockModeSheet extends StatelessWidget {
  const _BlockModeSheet();

  /// Applies [mode] and closes the sheet. "Lock app" gates the reel behind the
  /// user's PIN, so picking it without a PIN configured can't enforce anything —
  /// we send the user to PIN setup instead of silently selecting a dead mode.
  Future<void> _select(BuildContext context, BlockingMode mode) async {
    final needsPin = mode == BlockingMode.lockApp && !context.read<PinCubit>().state.isConfigured;
    if (needsPin) {
      final router = GoRouter.of(context);
      final navigator = Navigator.of(context);
      final setUp = await AppDialog.confirm(
        context: context,
        title: 'Set a PIN first',
        message:
            'Lock app hides the reel behind your PIN, like an app locker. '
            'Set up a PIN to use this mode.',
        confirmLabel: 'Set up PIN',
      );
      if (!setUp) return;
      navigator.pop(); // close the sheet before leaving the screen
      unawaited(router.push(Routes.pinSetup));
      return;
    }
    unawaited(context.read<SettingsCubit>().setDefaultBlockMode(mode));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, AppSettings>(
      builder: (context, settings) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final e in _blockModes)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: _OptionTile(
                  title: e.$2,
                  subtitle: e.$3,
                  selected: settings.defaultBlockMode == e.$1,
                  onTap: () => unawaited(_select(context, e.$1)),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Appearance picker (popup) ───────────────────────────────────────────────────

class _ThemeSheet extends StatelessWidget {
  const _ThemeSheet();

  @override
  Widget build(BuildContext context) {
    // Reflects the active brightness (resolves System → device). bg4 is
    // light-only, so the picker disables it while dark.
    final dark = Theme.of(context).brightness == Brightness.dark;
    return BlocBuilder<SettingsCubit, AppSettings>(
      builder: (context, settings) {
        // Don't pop on selection: theme + background update live behind the
        // sheet (a free preview), and the user dismisses when happy.
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SectionHeader('Theme'),
              for (final m in AppThemeMode.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: _OptionTile(
                    title: _themeLabel(m),
                    subtitle: _themeSubtitle(m),
                    selected: settings.themeMode == m,
                    onTap: () => context.read<SettingsCubit>().setThemeMode(m),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              const SectionHeader('Background'),
              _BackgroundCarousel(selected: settings.backgroundId, dark: dark),
            ],
          ),
        );
      },
    );
  }
}

/// A compact, horizontally-scrolling carousel of image-only SVG background
/// previews. Tapping a card selects it; the selected card gets an accent ring +
/// check, and the chosen background's name + description show below (kept off
/// the cards to stay minimal).
class _BackgroundCarousel extends StatelessWidget {
  const _BackgroundCarousel({required this.selected, required this.dark});

  final AppBackground selected;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final current = _backgrounds.firstWhere(
      (e) => e.$1 == selected,
      orElse: () => _backgrounds.first,
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
            itemCount: _backgrounds.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, i) {
              final b = _backgrounds[i];
              return _BgCard(
                style: b.$1,
                dark: dark,
                selected: b.$1 == selected,
                onTap: () => context.read<SettingsCubit>().setBackground(b.$1),
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
        Text(current.$3, style: text.bodySmall?.copyWith(color: context.glass.onGlassMuted)),
      ],
    );
  }
}

/// One carousel card: the actual background preview (real SVG for bg1–bg3, a
/// gradient for the asset-less Aurora). The selected card animates to an accent
/// ring + glow with a check badge.
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
    final asset = _bgSvgAsset(style, dark);
    final borderWidth = selected ? 2.0 : 1.0;
    final preview = asset == null
        ? DecoratedBox(decoration: BoxDecoration(gradient: _auroraSwatchGradient(dark)))
        : SvgPicture.asset(asset, fit: BoxFit.cover);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        curve: AppCurves.standard,
        width: 116,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? AppColors.accent : context.glass.border,
            width: borderWidth,
          ),
          boxShadow: selected
              ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.35), blurRadius: 12)]
              : null,
        ),
        // Clip the preview to a radius concentric with the border so the
        // accent ring stays perfectly rounded around the tile when selected.
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
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, size: 14, color: AppColors.surfaceDark),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
