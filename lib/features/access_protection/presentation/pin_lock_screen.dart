import 'dart:async';

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';
import 'package:detoxo/features/access_protection/presentation/pin_cubit.dart';
import 'package:detoxo/features/access_protection/presentation/pin_recovery_sheet.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Full-screen PIN gate. Serves three roles via its callbacks:
/// * **Launch gate** (`onUnlocked == null`): on unlock, navigates to home.
/// * **Inline guard** (see `PinGuard`): calls [onUnlocked] to reveal the screen.
/// * **Action gate** (see `requirePin`): pushed as a route; [onUnlocked] /
///   [onCancel] pop a result.
///
/// The system back gesture never dismisses it; a close affordance is shown only
/// when [onCancel] is provided.
class PinLockScreen extends StatefulWidget {
  const PinLockScreen({
    super.key,
    this.scope = PinScope.app,
    this.onUnlocked,
    this.onCancel,
  });

  /// Which protected scope is being unlocked (drives the heading).
  final PinScope scope;

  /// Called on a correct PIN / biometric unlock. When null this is the launch
  /// gate and the screen navigates to home itself.
  final VoidCallback? onUnlocked;

  /// Called when the user backs out of an optional (in-app) gate. When null no
  /// cancel affordance is shown (forced gate).
  final VoidCallback? onCancel;

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _entry = '';
  String? _error;
  Timer? _lockTimer;

  /// The lockout window we've already surfaced as a dialog, so the 1 Hz rebuild
  /// (and repeated keypad pokes) can't re-fire it. Re-shows when the window changes.
  DateTime? _shownFor;
  final AnimatedIconController _lockController = AnimatedIconController();
  final AnimatedIconController _backspaceController = AnimatedIconController();

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    final config = context.read<PinCubit>().state;
    if (config.biometricEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _lockController.dispose();
    _backspaceController.dispose();
    super.dispose();
  }

  /// Keeps a 1 Hz timer alive only while locked, so the countdown ticks and the
  /// keypad re-enables itself the instant the window ends.
  void _syncLockTimer(bool locked) {
    if (locked && _lockTimer == null) {
      _lockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!locked && _lockTimer != null) {
      _lockTimer!.cancel();
      _lockTimer = null;
    }
  }

  void _succeed() {
    if (widget.onUnlocked != null) {
      widget.onUnlocked!();
    } else {
      context.go(Routes.home);
    }
  }

  Future<void> _tryBiometric() async {
    final ok = await context.read<PinCubit>().authenticateBiometric();
    if (ok && mounted) _succeed();
  }

  Future<void> _onKey(String digit) async {
    final cubit = context.read<PinCubit>();
    final config = cubit.state;
    if (config.isLockedOut) {
      _showLockoutDialog(config.lockedUntil!);
      return;
    }
    final expected = cubit.expectedLength;
    if (_entry.length >= expected) return;
    AppHaptics.selection();
    setState(() {
      _entry += digit;
      _error = null;
    });
    if (_entry.length >= expected) await _attempt();
  }

  Future<void> _attempt() async {
    final cubit = context.read<PinCubit>();
    final ok = await cubit.verify(_entry);
    if (!mounted) return;
    if (ok) {
      _succeed();
      return;
    }
    _wrongPinFeedback();
    setState(() {
      _error = 'Incorrect PIN';
      _entry = '';
    });
    // verify() has emitted; read the fresh state to catch a new lockout window.
    final config = cubit.state;
    if (config.isLockedOut) _showLockoutDialog(config.lockedUntil!);
  }

  /// A wrong PIN gets a distinct stronger buzz (gated on the haptics setting)
  /// plus the existing shake.
  void _wrongPinFeedback() {
    if (AppHaptics.enabled) HapticFeedback.heavyImpact();
    if (!_reduceMotion) _lockController.animate();
  }

  /// Surfaces the cooldown as a glass dialog, once per distinct lockout window —
  /// the inline [_LockoutText] remains the live, ticking countdown.
  void _showLockoutDialog(DateTime until) {
    if (_shownFor == until) return;
    _shownFor = until;
    final diff = until.difference(DateTime.now());
    final remaining = diff.isNegative ? Duration.zero : diff;
    AppDialog.show<void>(
      context: context,
      title: 'Too many attempts',
      message: 'Please wait ${formatCountdown(remaining)} before trying again.',
      icon: Icons.lock_clock,
      accent: AppColors.danger,
      actions: [
        PrimaryButton(
          label: 'OK',
          tint: AppColors.danger,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  void _backspace() {
    if (_entry.isNotEmpty) {
      if (!_reduceMotion) {
        _backspaceController
          ..reset()
          ..animate();
      }
      setState(() => _entry = _entry.substring(0, _entry.length - 1));
    }
  }

  Future<void> _forgotPin() async {
    await PinRecoverySheet.show(context, onRecovered: _succeed);
  }

  /// Title, supporting line and glyph for the active scope.
  ({String title, String subtitle, AppIcon icon}) get _copy =>
      switch (widget.scope) {
        PinScope.app => (
          title: 'Enter your PIN',
          subtitle: 'Unlock Detoxo to continue',
          icon: AppIcon.pinLock,
        ),
        PinScope.settings => (
          title: 'Enter PIN',
          subtitle: 'Confirm to change protected settings',
          icon: AppIcon.shieldCheck,
        ),
        PinScope.appLocker => (
          title: 'Enter PIN',
          subtitle: 'Confirm to manage locked apps',
          icon: AppIcon.shieldCheck,
        ),
        PinScope.planSwitch || PinScope.detoxoSettings => (
          title: 'Enter your PIN',
          subtitle: 'Confirm to continue',
          icon: AppIcon.pinLock,
        ),
      };

  @override
  Widget build(BuildContext context) {
    final config = context.watch<PinCubit>().state;
    final text = Theme.of(context).textTheme;
    final expected = context.read<PinCubit>().expectedLength;
    final copy = _copy;
    _syncLockTimer(config.isLockedOut);

    return PopScope(
      canPop: false,
      child: GlassScaffold(
        body: Stack(
          children: [
            if (widget.onCancel != null)
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    tooltip: 'Cancel',
                    icon: const Icon(Icons.close),
                    onPressed: widget.onCancel,
                  ),
                ),
              ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.xxl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppAnimatedIcon(
                      icon: copy.icon,
                      size: 52,
                      controller: _lockController,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      copy.title,
                      textAlign: TextAlign.center,
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      copy.subtitle,
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(
                        color: context.glass.onGlassMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _Dots(length: expected, filled: _entry.length),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      height: 24,
                      child: Center(
                        child: config.isLockedOut
                            ? _LockoutText(until: config.lockedUntil!)
                            : Text(
                                _error ?? '',
                                style: text.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _Keypad(
                      enabled: !config.isLockedOut,
                      showBiometric: config.biometricEnabled,
                      onKey: _onKey,
                      onBackspace: _backspace,
                      onBiometric: _tryBiometric,
                      backspaceController: _backspaceController,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: _forgotPin,
                      child: const Text('Forgot PIN?'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fixed-length progress dots (one per expected digit), filled as you type.
class _Dots extends StatelessWidget {
  const _Dots({required this.length, required this.filled});
  final int length;
  final int filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$filled of $length digits entered',
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            length.clamp(1, 10),
            (i) => AnimatedContainer(
              duration: AppDurations.fast,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: i < filled ? scheme.primary : Colors.transparent,
                border: Border.all(
                  color: i < filled ? scheme.primary : context.glass.border,
                  width: 1.5,
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LockoutText extends StatelessWidget {
  const _LockoutText({required this.until});
  final DateTime until;

  @override
  Widget build(BuildContext context) {
    final diff = until.difference(DateTime.now());
    final remaining = diff.isNegative ? Duration.zero : diff;
    return Text(
      'Too many attempts. Try again in ${formatCountdown(remaining)}',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Theme.of(context).colorScheme.error,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.enabled,
    required this.showBiometric,
    required this.onKey,
    required this.onBackspace,
    required this.onBiometric,
    required this.backspaceController,
  });

  final bool enabled;
  final bool showBiometric;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final VoidCallback onBiometric;
  final AnimatedIconController backspaceController;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1.3,
        children: [
          for (var i = 1; i <= 9; i++)
            _DigitKey(digit: '$i', enabled: enabled, onKey: onKey),
          // Bottom-left: biometric shortcut when enabled, else empty.
          if (showBiometric)
            _IconKey(
              enabled: enabled,
              onTap: onBiometric,
              semanticLabel: 'Unlock with biometrics',
              child: const Icon(Icons.fingerprint, size: 26),
            )
          else
            const SizedBox.shrink(),
          _DigitKey(digit: '0', enabled: enabled, onKey: onKey),
          _IconKey(
            enabled: enabled,
            onTap: onBackspace,
            semanticLabel: 'Delete',
            child: AppAnimatedIcon(
              icon: AppIcon.backspace,
              size: 24,
              controller: backspaceController,
            ),
          ),
        ],
      ),
    );
  }
}

class _DigitKey extends StatelessWidget {
  const _DigitKey({
    required this.digit,
    required this.enabled,
    required this.onKey,
  });

  final String digit;
  final bool enabled;
  final ValueChanged<String> onKey;

  @override
  Widget build(BuildContext context) {
    final key = GlassContainer(
      borderRadius: AppRadius.pill,
      padding: EdgeInsets.zero,
      child: Center(
        child: Text(
          digit,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: digit,
      excludeSemantics: true,
      child: enabled
          ? AppPressable(onTap: () => onKey(digit), child: key)
          : Opacity(opacity: 0.4, child: key),
    );
  }
}

class _IconKey extends StatelessWidget {
  const _IconKey({
    required this.enabled,
    required this.onTap,
    required this.child,
    required this.semanticLabel,
  });

  final bool enabled;
  final VoidCallback onTap;
  final Widget child;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final key = GlassContainer(
      enableBlur: false,
      borderRadius: AppRadius.pill,
      borderColor: Colors.transparent,
      tintTop: Colors.transparent,
      tintBottom: Colors.transparent,
      padding: EdgeInsets.zero,
      child: Center(child: child),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      excludeSemantics: true,
      child: enabled
          ? AppPressable(onTap: onTap, child: key)
          : Opacity(opacity: 0.4, child: key),
    );
  }
}
