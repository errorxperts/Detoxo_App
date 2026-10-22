import 'dart:async';

import 'package:detoxo/core/constants/app_constants.dart';
import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/core/navigation/app_gate.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/core/storage/local_store.dart';
import 'package:detoxo/core/utils/duration_format.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';
import 'package:detoxo/features/access_protection/domain/entities/pin_config.dart';
import 'package:detoxo/features/access_protection/presentation/pin_cubit.dart';
import 'package:detoxo/features/access_protection/presentation/pin_gate.dart';
import 'package:detoxo/features/additional_feature/app_upgrader/app_upgrader.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/app_settings.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/features/blocking/shared/presentation/settings_cubit.dart';
import 'package:detoxo/features/limits/limits.dart';
import 'package:detoxo/features/permissions/domain/entities/permission_status.dart';
import 'package:detoxo/features/permissions/presentation/permission_actions.dart';
import 'package:detoxo/features/permissions/presentation/permissions_cubit.dart';
import 'package:detoxo/features/settings/presentation/widgets/block_mode_picker.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The app's control hub: protection, feedback, usage, security & permissions,
/// appearance, about and reset — all in the glass design system. Plans, pause
/// and the platform blocklist live on the home screen, not here.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
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

  Future<void> _openNudgeThreshold() async {
    await GlassBottomSheet.show<void>(
      context: context,
      title: 'Nudge me every',
      child: const _NudgeThresholdSheet(),
    );
  }

  /// Disabling protection is a sensitive change: the PIN first (when the
  /// `settings` scope guards it), then a critical [ConfirmSheet]; enabling
  /// proceeds directly. The switch is bound to `settings.masterEnabled`, so a
  /// cancelled PIN or sheet snaps it back.
  Future<void> _setMasterEnabled(
    BuildContext context, {
    required bool enabled,
  }) async {
    final cubit = context.read<SettingsCubit>();
    if (enabled) {
      await cubit.setMasterEnabled(enabled: true);
      return;
    }
    if (!await requirePin(context, PinScope.settings) || !context.mounted) {
      return;
    }
    final ok = await ConfirmSheet.show(
      context,
      icon: Icon3d(
        Assets.images.icons.iconBlockAll,
        size: ConfirmSheet.iconSize,
        accentTint: true,
      ),
      title: 'Turn off blocking?',
      message:
          'Reels, apps and sites stay unblocked until you turn it back on.',
      action: 'Slide to turn off',
      cancel: 'Keep blocking',
      tone: ConfirmTone.critical,
    );
    if (!ok) return;
    await cubit.setMasterEnabled(enabled: false);
    if (context.mounted && !cubit.state.masterEnabled) {
      GlassToast.show(context, 'Blocking is off');
    }
  }

  /// Turning suppression on without Android's notification-access grant would
  /// silently do nothing, so the grant is funnelled first — through the same
  /// [requestPermission] entry point as everywhere else, which carries the
  /// prominent disclosure and the restricted-settings recovery.
  ///
  /// A **declined disclosure is a refusal**, and the setting is not committed:
  /// recording the feature as on right after the user read what it does and
  /// said no would be the app overriding an explicit consent decision.
  ///
  /// Proceeding past the disclosure does commit, because the system grant
  /// screen returns no result — the user is still standing on Android's list
  /// when this resolves, so "not granted yet" is not "not wanted". The tile
  /// renders that gap truthfully instead of pretending (see [_GrantedSwitch]).
  Future<void> _setSuppressNotifications(
    BuildContext context, {
    required bool enabled,
  }) async {
    final permissions = context.read<PermissionsCubit>();
    if (enabled) {
      final status = permissions.statusFor(AppPermission.notificationListener);
      if (!permissions.effectivelyGranted(status)) {
        final proceeded = await requestPermission(
          context,
          AppPermission.notificationListener,
        );
        if (!proceeded || !context.mounted) return;
      }
    }
    await context.read<SettingsCubit>().setSuppressNotifications(
      enabled: enabled,
    );
  }

  Future<void> _resetData() async {
    // Reset wipes the PIN itself, so it's a protected change: ask for the PIN
    // first (no-op when none is configured), then the critical confirm. No
    // toast: the splash is the feedback.
    if (!await requirePin(context, PinScope.settings) || !mounted) return;
    final ok = await ConfirmSheet.show(
      context,
      icon: const DetoxoLogo(height: ConfirmSheet.iconSize),
      title: 'Reset app data?',
      message:
          'Settings, blocklists, limits and your PIN are erased, and setup '
          'starts again.',
      action: 'Slide to reset',
      cancel: 'Keep my data',
      tone: ConfirmTone.critical,
    );
    if (!ok || !mounted) return;
    await sl<LocalStore>().clearAll();
    if (!mounted) return;
    // Slam the router's gate shut BEFORE navigating. This path re-enters the
    // splash without restarting the process, so the gate still holds the flags
    // from before the wipe — leaving them set would wave the user straight
    // through to home and the bootstrap would never run.
    sl<AppGate>().reset();
    context.go(Routes.splash);
  }

  @override
  Widget build(BuildContext context) {
    // The Settings screen is a separate route (not under HomeShell's
    // UpgradeGate), so it hosts its own UpgradeCubit. It auto-checks on open so
    // the version row can reveal an "Update" button when a newer build is
    // available.
    return BlocProvider(
      create: (_) => UpgradeCubit(sl<AppUpgradeService>())..check(),
      child: GlassScaffold(
        appBar: const GlassAppBar(title: Text('Settings')),
        body: BlocBuilder<SettingsCubit, AppSettings>(
          builder: (context, settings) {
            final pinOn = context.select<PinCubit, bool>(
              (c) => c.state.isConfigured,
            );
            final cubit = context.read<SettingsCubit>();
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                0,
                AppSpacing.gutter,
                AppSpacing.xxl,
              ),
              // One SectionHeader and one panel of flat rows per section.
              children: [
                // ── Protection: how Detoxo blocks & limits reels ────────────
                const SectionHeader('Protection'),
                PanelGroup(
                  children: [
                    FeatureTile(
                      icon: Icons.hourglass_bottom,
                      title: 'Daily limit',
                      subtitle: 'Cap your reel time per day',
                      onTap: () => context.push(Routes.dailyLimit),
                    ),
                    _BlockModeTile(
                      mode: settings.defaultBlockMode,
                      onTap: _openBlockMode,
                    ),
                    AppToggleTile(
                      leading: _glyph(context, Icons.shield_outlined),
                      title: 'Blocking active',
                      subtitle: 'Master switch for all detection',
                      value: settings.masterEnabled,
                      onChanged: (v) =>
                          unawaited(_setMasterEnabled(context, enabled: v)),
                    ),
                    AppToggleTile(
                      leading: _glyph(context, Icons.vibration),
                      title: 'Vibrate on block',
                      subtitle: 'Haptic buzz each time a reel is blocked',
                      value: settings.vibrationEnabled,
                      onChanged: (v) => cubit.setVibration(enabled: v),
                    ),
                    const _AllowanceTile(),
                    // The nudge draws in an overlay window, so without
                    // "Display over other apps" `NudgeOverlay.show` returns
                    // false and not one card could appear.
                    _GrantedSwitch(
                      icon: Icons.timer_outlined,
                      title: 'Soft nudge',
                      subtitle:
                          'A card that says how long you’ve been in a '
                          'distracting app. Nothing is blocked.',
                      value: settings.nudgeEnabled,
                      onChanged: (v) => cubit.setNudgeEnabled(enabled: v),
                      permission: AppPermission.overlay,
                      missing: 'No cards can appear until you allow it',
                    ),
                    if (settings.nudgeEnabled)
                      FeatureTile(
                        icon: Icons.tune,
                        title: 'Nudge me every',
                        subtitle: _nudgeTitle(settings),
                        onTap: _openNudgeThreshold,
                      ),
                  ],
                ),

                // ── Privacy: apps Detoxo must never touch ───────────────────
                const SectionHeader('Privacy'),
                PanelGroup(
                  children: [
                    FeatureTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Protected apps',
                      subtitle:
                          'Banking & sensitive apps Detoxo completely ignores',
                      onTap: () => context.push(Routes.protectedApps),
                    ),
                    _GrantedSwitch(
                      icon: Icons.notifications_off,
                      title: 'Notification silence',
                      subtitle: 'Mute apps while they’re blocked',
                      value: settings.suppressNotifications,
                      onChanged: (v) => unawaited(
                        _setSuppressNotifications(context, enabled: v),
                      ),
                      permission: AppPermission.notificationListener,
                      missing: 'Nothing is muted until you allow it',
                    ),
                  ],
                ),

                // ── Security: who can change things & system access ─────────
                const SectionHeader('Security'),
                PanelGroup(
                  children: [
                    const _PinTile(),
                    // Edit the configured PIN (type, auto-lock, biometrics).
                    // The `/pin/setup` route itself is wrapped in
                    // `PinGuard(scope: settings)`, so no gate here.
                    if (pinOn)
                      FeatureTile(
                        icon: Icons.tune,
                        title: 'PIN settings',
                        subtitle: 'Type, auto-lock & biometrics',
                        onTap: () => context.push(Routes.pinSetup),
                      ),
                    _PermissionsTile(onTap: _openPermissions),
                  ],
                ),

                // ── General: appearance & app info ──────────────────────────
                const SectionHeader('General'),
                PanelGroup(
                  children: [
                    FeatureTile(
                      icon: _themeIcon(settings.themeMode),
                      title: 'Appearance',
                      subtitle: 'Theme and reel counter',
                      onTap: () => context.push(Routes.appearance),
                    ),
                    AppToggleTile(
                      leading: _glyph(context, Icons.feedback_outlined),
                      title: 'Feedback button',
                      subtitle: 'Show a feedback button in every top bar',
                      value: settings.showFeedbackButton,
                      onChanged: (v) => cubit.setShowFeedbackButton(enabled: v),
                    ),
                    const _VersionRow(),
                  ],
                ),

                // ── Reset ───────────────────────────────────────────────────
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: SecondaryButton(
                    label: 'Reset app data',
                    destructive: true,
                    onPressed: _resetData,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A row's leading glyph: 24 px in ink-2, like [FeatureTile]'s.
Widget _glyph(BuildContext context, IconData icon) =>
    Icon(icon, size: 24, color: context.tokens.ink2);

/// EVO-053 — how many per-target allowances ("Allow Instagram for 15 minutes")
/// may be spent per day.
///
/// Ships as **Unlimited**, so nothing changes for anyone who does not opt in.
/// It lives here rather than on a blocklist screen because it governs every
/// grant surface at once — a row, the wall, the website list — and because
/// Settings is what the PIN already guards.
class _AllowanceTile extends StatelessWidget {
  const _AllowanceTile();

  static const List<int> _options = [0, 1, 2, 3, 5];

  static String _label(int limit) => limit == 0 ? 'Unlimited' : '$limit a day';

  @override
  Widget build(BuildContext context) {
    final limit = context.select<UnblockCubit, int>(
      (c) => c.state.config.grantLimit,
    );
    return FeatureTile(
      icon: Icons.timer_outlined,
      title: 'Allowances',
      subtitle: _label(limit),
      onTap: () => _pick(context, limit),
    );
  }

  Future<void> _pick(BuildContext context, int current) async {
    final cubit = context.read<UnblockCubit>();
    final picked = await GlassBottomSheet.show<int>(
      context: context,
      title: 'Allowances a day',
      child: Builder(
        builder: (sheetContext) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            PanelGroup(
              children: [
                for (final o in _options)
                  GlassListTile(
                    title: _label(o),
                    selected: o == current,
                    onTap: () => Navigator.of(sheetContext).pop(o),
                  ),
              ],
            ),
            const _SheetNote(
              'How often you can free one app, feed or site for a few '
              'minutes before tomorrow.',
            ),
          ],
        ),
      ),
    );
    if (picked == null || picked == current) return;
    await cubit.setGrantLimit(picked);
  }
}

/// Block-mode entry, rendered truthfully like [_GrantedSwitch]: "Block screen"
/// draws in an overlay window, so without "Display over other apps" the mode
/// still bounces the reel but no wall can ever appear — say so and offer the
/// fix. Only a *definite* missing grant counts (EVO-014).
class _BlockModeTile extends StatelessWidget {
  const _BlockModeTile({required this.mode, required this.onTap});

  final BlockingMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PermissionsCubit, List<PermissionStatus>>(
      builder: (context, _) {
        final cubit = context.read<PermissionsCubit>();
        return BlockModeTile(
          mode: mode,
          needsOverlay:
              mode == BlockingMode.blockScreen &&
              !cubit.effectivelyGranted(cubit.statusFor(AppPermission.overlay)),
          onTap: onTap,
          onGrant: () =>
              unawaited(requestPermission(context, AppPermission.overlay)),
        );
      },
    );
  }
}

/// A switch whose feature needs an Android grant, rendered truthfully
/// (EVO-036 / EVO-042): "on" and "working" are two different things. The
/// grant can still be pending on Android's own screen, or revoked from system
/// settings while the switch stayed on, and a plain ON would be the app
/// claiming to do something it cannot — the shape `ContentCount.bubbleBlocked`
/// solves for the counter bubble (EVO-022). So while the switch is on and the
/// grant is missing, a [PermissionNeededRow] says what is not happening and a
/// tap asks for the grant; the permission state refreshes on every resume, so
/// returning from Android's list clears it.
class _GrantedSwitch extends StatelessWidget {
  const _GrantedSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.permission,
    required this.missing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final AppPermission permission;

  /// What does not happen without the grant.
  final String missing;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PermissionsCubit, List<PermissionStatus>>(
      builder: (context, _) {
        final cubit = context.read<PermissionsCubit>();
        // Only a *definite* missing grant is a problem — an unknown read falls
        // back to lastKnownGranted (EVO-014), so a flaky channel call never
        // accuses a working setup of being broken.
        final blocked =
            value && !cubit.effectivelyGranted(cubit.statusFor(permission));
        return Column(
          children: [
            AppToggleTile(
              leading: _glyph(context, icon),
              title: title,
              subtitle: subtitle,
              value: value,
              onChanged: onChanged,
            ),
            if (blocked)
              PermissionNeededRow(
                title: permission.label,
                subtitle: missing,
                onTap: () => unawaited(requestPermission(context, permission)),
              ),
          ],
        );
      },
    );
  }
}

/// A subhead ink-2 line under a sheet's options.
class _SheetNote extends StatelessWidget {
  const _SheetNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, AppSpacing.sm, 4, 0),
    child: Text(
      text,
      style: AppTypography.subhead.copyWith(color: context.tokens.ink2),
    ),
  );
}

// ── App version + update check ────────────────────────────────────────────────

/// The app-version row, which doubles as the "check for updates" surface.
/// Tapping it runs a manual check (toasting when already current); when a newer
/// build is available it says so and offers an "Update" button that opens the
/// store. Backed by the screen-local `UpgradeCubit` (see `build`).
class _VersionRow extends StatelessWidget {
  const _VersionRow();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UpgradeCubit, UpgradeState>(
      listenWhen: (prev, next) => prev.view != next.view,
      listener: (context, state) {
        // Confirm "up to date" only for a user-initiated tap, not the auto-check.
        if (state.view == UpgradeView.upToDate && state.manual) {
          GlassToast.show(context, "You're on the latest version");
        }
      },
      builder: (context, state) {
        final update = state.view == UpgradeView.updateAvailable
            ? state.status
            : null;
        final version = update?.storeVersion;
        final upgrade = context.read<UpgradeCubit>();
        return GlassListTile(
          leading: _glyph(context, Icons.info_outline),
          title: '${AppConstants.appName} v${AppConstants.appVersion}',
          subtitle: update == null
              ? 'Tap to check for updates'
              : version != null
              ? 'Version $version is available'
              : 'A new version is available',
          // With an update known, the button is the one action.
          onTap: update == null ? () => upgrade.check(manual: true) : null,
          trailing: update == null
              ? null
              : SecondaryButton(label: 'Update', onPressed: upgrade.openStore),
        );
      },
    );
  }
}

// ── Nudge + appearance option data ────────────────────────────────────────────

/// Minutes offered for the soft nudge. Deliberately no value under 5: a card
/// every couple of minutes stops being information and becomes nagging.
/// Both lists sit inside the native clamps (1–60 min, 1–50 cards).
const _nudgeMinutes = <int>[5, 10, 15, 30];
const _nudgeCaps = <int>[2, 4, 6, 10];

String _nudgeTitle(AppSettings s) =>
    '${formatHm(Duration(minutes: s.nudgeThresholdMinutes))} · up to '
    '${s.nudgeDailyCap} per app a day';

IconData _themeIcon(AppThemeMode m) => switch (m) {
  AppThemeMode.system => Icons.brightness_auto,
  AppThemeMode.light => Icons.light_mode,
  AppThemeMode.dark => Icons.dark_mode,
};

// ── PIN lock: master switch ─────────────────────────────────────────────────────

class _PinTile extends StatelessWidget {
  const _PinTile();

  /// Master switch. Turning ON opens setup; turning OFF asks for the PIN, then
  /// [confirmPinOff] disables. The switch is bound to `isConfigured`, so a
  /// cancelled turn-off (or a setup the user backs out of) snaps it back.
  Future<void> _toggle(BuildContext context, {required bool enable}) async {
    if (enable) {
      await context.push(Routes.pinSetup);
      return;
    }
    if (!await requirePin(context, PinScope.settings) || !context.mounted) {
      return;
    }
    await confirmPinOff(context);
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
          _ => 'Unknown', // wire-compat types; never render a dangling bullet
        };
        return AppToggleTile(
          leading: _glyph(context, Icons.lock_outline),
          title: 'PIN lock',
          subtitle: on ? 'On · $typeLabel PIN' : 'Off',
          value: on,
          onChanged: (v) => unawaited(_toggle(context, enable: v)),
        );
      },
    );
  }
}

// ── Permissions: entry tile + popup ───────────────────────────────────────────

/// Main-screen entry: a single tile summarising permission status; opens the
/// full list in a popup.
class _PermissionsTile extends StatelessWidget {
  const _PermissionsTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PermissionsCubit, List<PermissionStatus>>(
      builder: (context, statuses) {
        // Required only, via effectivelyGranted — the same predicate the
        // funnel's "n of m on" note and Continue button use, so the two can
        // never contradict each other. Counting all of AppPermission.values made
        // "All set" unreachable: it demanded uninstall protection and
        // notification access, both of which ship off by design.
        final cubit = context.read<PermissionsCubit>();
        final required = statuses.where((s) => s.kind.required).toList();
        final granted = required.where(cubit.effectivelyGranted).length;
        final total = required.length;
        final allOk = total > 0 && granted == total;
        return FeatureTile(
          icon: Icons.verified_user_outlined,
          title: 'Permissions',
          subtitle: 'Accessibility, overlay, notifications & more',
          trailing: total == 0
              ? null
              : Pill(
                  label: allOk ? 'All set' : '$granted of $total on',
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
          return Text(
            'No permissions to manage.',
            style: AppTypography.body.copyWith(color: context.tokens.ink2),
          );
        }
        // The funnel's rows, so the two can never disagree.
        return SingleChildScrollView(
          child: PanelGroup(
            children: [for (final s in statuses) PermissionRow(s)],
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
  /// "Block screen" needs the overlay grant the same way. Overlay has no
  /// in-app disclosure (`permission_actions.dart`), so [requestPermission]
  /// opens Android's own screen directly and returns false only for the
  /// restricted-settings recovery sheet. The mode still commits while the
  /// user is on that screen — "not granted yet" is not "not wanted" — and
  /// [_BlockModeTile] renders the gap truthfully. The mode carries its own
  /// wall (native `WallPolicy` bypasses the Appearance switch for it), so
  /// nothing on the Appearance screen is touched here.
  Future<void> _select(BuildContext context, BlockingMode mode) async {
    if (mode == BlockingMode.blockScreen) {
      final permissions = context.read<PermissionsCubit>();
      if (!permissions.effectivelyGranted(
        permissions.statusFor(AppPermission.overlay),
      )) {
        final proceeded = await requestPermission(
          context,
          AppPermission.overlay,
        );
        if (!proceeded || !context.mounted) return;
      }
    }
    final needsPin =
        mode == BlockingMode.lockApp &&
        !context.read<PinCubit>().state.isConfigured;
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
        return BlockModeOptions(
          selected: settings.defaultBlockMode,
          onSelect: (m) => unawaited(_select(context, m)),
        );
      },
    );
  }
}

/// Picks how often the soft nudge speaks, and how many times a day it may.
/// It stays open until both have been picked, so one visit sets both.
///
/// The copy is explicit that the threshold is per visit, because "nudge me
/// every 5 minutes" and "nudge me after 30 minutes today" are different
/// features and the second one is the Daily limit, one row up this screen.
class _NudgeThresholdSheet extends StatefulWidget {
  const _NudgeThresholdSheet();

  @override
  State<_NudgeThresholdSheet> createState() => _NudgeThresholdSheetState();
}

class _NudgeThresholdSheetState extends State<_NudgeThresholdSheet> {
  bool _minutesPicked = false;
  bool _capPicked = false;

  void _picked({bool minutes = false, bool cap = false}) {
    _minutesPicked |= minutes;
    _capPicked |= cap;
    if (_minutesPicked && _capPicked) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, AppSettings>(
      builder: (context, settings) {
        final cubit = context.read<SettingsCubit>();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PanelGroup(
              children: [
                for (final m in _nudgeMinutes)
                  GlassListTile(
                    title: formatHm(Duration(minutes: m)),
                    selected: settings.nudgeThresholdMinutes == m,
                    onTap: () {
                      unawaited(cubit.setNudgeThresholdMinutes(m));
                      _picked(minutes: true);
                    },
                  ),
              ],
            ),
            const _SheetNote(
              'Counted from opening the app, not across the day',
            ),
            const SectionHeader('Most nudges per app, per day'),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final cap in _nudgeCaps)
                  AppChip(
                    label: '$cap',
                    // The visible text is a bare number; without this a screen
                    // reader announces "4, selected" with no idea of what.
                    semanticLabel: '$cap nudges per app per day',
                    selected: settings.nudgeDailyCap == cap,
                    onSelected: () {
                      unawaited(cubit.setNudgeDailyCap(cap));
                      _picked(cap: true);
                    },
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
