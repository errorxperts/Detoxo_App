import 'dart:async';

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/core/utils/clock_format.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';
import 'package:detoxo/features/access_protection/presentation/pin_cubit.dart';
import 'package:detoxo/features/access_protection/presentation/pin_help_sheet.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Full-screen PIN gate. Serves three roles via its callbacks:
/// * **Launch gate** (routed via `/pin/lock`): the router supplies an
///   [onUnlocked] that just clears the gate flag (`AppGate.unlockPin`) and lets
///   the redirect apply whatever gate comes next — a PIN user must still not
///   skip permissions. A null [onUnlocked] falls back to navigating home.
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

  /// Whether a *forced* app-scope gate (launch gate or auto-relock — the
  /// non-cancellable ones) is currently on screen. `PinAutoRelock` consults
  /// this so a background/resume cycle at the lock never stacks a second lock.
  static bool get appGateVisible => _appGateCount > 0;
  static int _appGateCount = 0;

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  /// Entry buffer + error line as notifiers, so a keystroke repaints only the
  /// dots and the status row — never all twelve shadowed keys.
  final ValueNotifier<String> _entry = ValueNotifier('');
  final ValueNotifier<String?> _error = ValueNotifier(null);
  Timer? _lockTimer;

  bool get _isForcedAppGate =>
      widget.scope == PinScope.app && widget.onCancel == null;

  @override
  void initState() {
    super.initState();
    if (_isForcedAppGate) PinLockScreen._appGateCount++;
    final config = context.read<PinCubit>().state;
    // Anti-tamper: realign the wall-clock lockout stamp with the monotonic
    // truth on every lock-screen entry, so a Settings clock change made
    // between visits can neither hide an active lockout (keypad up, correct
    // PIN "wrong") nor freeze the keypad past the real remaining time.
    unawaited(context.read<PinCubit>().reconcileLockout());
    if (config.biometricEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
  }

  @override
  void dispose() {
    if (_isForcedAppGate) PinLockScreen._appGateCount--;
    _lockTimer?.cancel();
    _entry.dispose();
    _error.dispose();
    super.dispose();
  }

  /// Schedules exactly one rebuild for the moment the lockout window ends, so
  /// the keypad re-enables itself. The ticking countdown lives inside
  /// [_LockoutText] — a periodic tick here would rebuild the whole screen at
  /// 1 Hz for windows that can last 24 h.
  void _syncLockTimer(DateTime? lockedUntil) {
    if (lockedUntil != null) {
      final wait = lockedUntil.difference(DateTime.now());
      _lockTimer ??= Timer(wait.isNegative ? Duration.zero : wait, () {
        _lockTimer = null;
        if (mounted) setState(() {});
      });
    } else {
      _lockTimer?.cancel();
      _lockTimer = null;
    }
  }

  void _succeed() {
    AppHaptics.success();
    if (widget.onUnlocked != null) {
      widget.onUnlocked!();
    } else {
      context.go(Routes.home);
    }
  }

  Future<void> _tryBiometric() async {
    final ok = await context.read<PinCubit>().authenticateBiometric();
    if (!ok || !mounted) return;
    // A success arriving while another route sits on top (e.g. the auto-relock
    // pushed over a settings gate during the credential prompt) must not fire
    // this gate's callback — it would pop the wrong route, unlocking nothing
    // the user actually authenticated for.
    if (ModalRoute.of(context)?.isCurrent ?? true) _succeed();
  }

  Future<void> _onKey(String digit) async {
    final cubit = context.read<PinCubit>();
    // The keypad is disabled during a lockout; this catches a key that lands
    // in the frame the window starts. The inline countdown says why.
    if (cubit.state.isLockedOut) return;
    final expected = cubit.expectedLength;
    if (_entry.value.length >= expected) return;
    AppHaptics.selection();
    _entry.value += digit;
    _error.value = null;
    if (_entry.value.length >= expected) await _attempt();
  }

  Future<void> _attempt() async {
    final cubit = context.read<PinCubit>();
    final ok = await cubit.verify(_entry.value);
    if (!mounted) return;
    if (ok) {
      _succeed();
      return;
    }
    // A distinct stronger buzz (gated on the haptics setting); a new
    // lockout window replaces this line with the live countdown.
    AppHaptics.error();
    _error.value = 'Incorrect PIN';
    _entry.value = '';
  }

  void _backspace() {
    if (_entry.value.isEmpty) return;
    _entry.value = _entry.value.substring(0, _entry.value.length - 1);
  }

  Future<void> _forgotPin() async {
    await PinHelpSheet.show(context);
  }

  /// Title and supporting line for the active scope.
  ({String title, String subtitle}) get _copy => switch (widget.scope) {
    PinScope.app => (
      title: 'Enter your PIN',
      subtitle: 'Unlock Detoxo to continue',
    ),
    PinScope.settings => (
      title: 'Enter PIN',
      subtitle: 'Confirm to change protected settings',
    ),
    PinScope.appLocker => (
      title: 'Enter PIN',
      subtitle: 'Confirm to manage locked apps',
    ),
    PinScope.planSwitch || PinScope.detoxoSettings => (
      title: 'Enter your PIN',
      subtitle: 'Confirm to continue',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final config = context.watch<PinCubit>().state;
    final t = context.tokens;
    final expected = context.read<PinCubit>().expectedLength;
    final copy = _copy;
    // One clock read per build: isLockedOut re-reads DateTime.now() on every
    // call, and consulting it thrice could disagree within a single frame.
    final locked = config.isLockedOut;
    _syncLockTimer(locked ? config.lockedUntil : null);

    return PopScope(
      canPop: false,
      child: GlassScaffold(
        body: Stack(
          children: [
            // The scroll view fills the body, so anything meant to be tappable
            // must come AFTER it in the stack — a Stack hit-tests top-down and
            // the scrollable swallows pointers for its whole viewport. With the
            // ✕ underneath, Cancel was unreachable by touch.
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.xxl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const DetoxoLogo(),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      copy.title,
                      textAlign: TextAlign.center,
                      style: AppTypography.title.copyWith(color: t.ink),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      copy.subtitle,
                      textAlign: TextAlign.center,
                      style: AppTypography.body.copyWith(color: t.ink2),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    ValueListenableBuilder<String>(
                      valueListenable: _entry,
                      builder: (_, entry, _) =>
                          _Dots(length: expected, filled: entry.length),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Min-height, not fixed: the lockout line wraps at large
                    // text scales and must grow instead of painting over the
                    // keypad below.
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 24),
                      child: Center(
                        child: locked
                            ? _LockoutText(until: config.lockedUntil!)
                            : ValueListenableBuilder<String?>(
                                valueListenable: _error,
                                builder: (_, error, _) => Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    error ?? '',
                                    textAlign: TextAlign.center,
                                    style: _statusStyle(context),
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _Keypad(
                      enabled: !locked,
                      showBiometric: config.biometricEnabled,
                      onKey: _onKey,
                      onBackspace: _backspace,
                      onBiometric: _tryBiometric,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SecondaryButton(
                      label: 'Forgot PIN?',
                      onPressed: _forgotPin,
                    ),
                  ],
                ),
              ),
            ),
            if (widget.onCancel != null)
              SafeArea(
                child: Padding(
                  // Where GlassAppBar puts its back button.
                  padding: const EdgeInsets.only(
                    left: AppSpacing.gutter - 2,
                    top: AppSpacing.xs,
                  ),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: GlassIconButton(
                      icon: const Icon(Icons.close_rounded),
                      semanticLabel: 'Cancel',
                      onPressed: widget.onCancel,
                    ),
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
    final t = context.tokens;
    return Semantics(
      label: '$filled of $length digits entered',
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            length.clamp(1, 10),
            (i) => AnimatedContainer(
              duration: context.motion(AppDurations.fast),
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: i < filled ? t.ink : Colors.transparent,
                border: Border.all(
                  color: i < filled ? t.ink : t.hairline,
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

/// Live "try again in…" countdown. Owns its own 1 Hz tick so the rest of the
/// screen isn't rebuilt every second for windows that can last 24 h; the
/// parent's one-shot timer handles re-enabling the keypad at expiry.
class _LockoutText extends StatefulWidget {
  const _LockoutText({required this.until});
  final DateTime until;

  @override
  State<_LockoutText> createState() => _LockoutTextState();
}

class _LockoutTextState extends State<_LockoutText> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final diff = widget.until.difference(now);
    final remaining = diff.isNegative ? Duration.zero : diff;
    final until = widget.until;
    final at = formatLocalTime(context, until.hour * 60 + until.minute);
    final day = DateUtils.isSameDay(until, now) ? '' : ' tomorrow';
    // A live region re-announces every change, so TalkBack hears the fixed
    // end time once instead of a countdown every second.
    return Semantics(
      liveRegion: true,
      label: 'Too many attempts. Try again$day at $at',
      child: ExcludeSemantics(
        child: Text(
          'Too many attempts. Try again in ${formatCountdown(remaining)}',
          textAlign: TextAlign.center,
          style: _statusStyle(context),
        ),
      ),
    );
  }
}

/// The error and lockout line: subhead words in ink, never red.
TextStyle _statusStyle(BuildContext context) =>
    AppTypography.subhead.copyWith(color: context.tokens.ink);

/// Four rows of three: digits on soft raised circles, the biometric shortcut
/// (or nothing) and Delete as flat glyph keys on the bottom row.
class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.enabled,
    required this.showBiometric,
    required this.onKey,
    required this.onBackspace,
    required this.onBiometric,
  });

  final bool enabled;
  final bool showBiometric;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final VoidCallback onBiometric;

  @override
  Widget build(BuildContext context) {
    Widget digit(int d) =>
        _Key(enabled: enabled, onTap: () => onKey('$d'), label: '$d');
    Widget row(List<Widget> keys) =>
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: keys);
    return SizedBox(
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.sm,
        children: [
          for (var r = 0; r < 3; r++)
            row([for (var c = 1; c <= 3; c++) digit(r * 3 + c)]),
          row([
            if (showBiometric)
              _Key(
                enabled: enabled,
                onTap: onBiometric,
                label: 'Unlock with fingerprint or device credential',
                icon: Icons.fingerprint,
              )
            else
              const SizedBox.square(dimension: _Key.size),
            digit(0),
            _Key(
              enabled: enabled,
              onTap: onBackspace,
              label: 'Delete',
              icon: Icons.backspace_outlined,
            ),
          ]),
        ],
      ),
    );
  }
}

/// One keypad key: a single button node TalkBack can activate, labelled by
/// [label]. A digit key (no [icon]) is the spec soft button as a circle — the
/// 145° button gradient with its soft shadow — and its digit in title ink; a
/// glyph key is flat. Disabled keys fade and announce as disabled.
class _Key extends StatelessWidget {
  const _Key({
    required this.enabled,
    required this.onTap,
    required this.label,
    this.icon,
  });

  static const double size = 72;

  final bool enabled;
  final VoidCallback onTap;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final face = icon == null
        ? CustomPaint(
            painter: DxSurfacePainter(
              radius: AppRadius.brPill,
              gradient: [t.buttonFrom, t.buttonTo],
              angle: 145,
              shadows: t.shadowButton,
            ),
            child: Center(
              child: Text(
                label,
                style: AppTypography.title.copyWith(
                  color: t.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          )
        : Center(child: Icon(icon, size: 26, color: t.ink2));
    return AppPressable(
      onTap: onTap,
      enabled: enabled,
      // Digits buzz from the screen's own selection haptic.
      haptic: icon != null,
      pressedScale: 0.95,
      radius: AppRadius.brPill,
      semanticLabel: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: ExcludeSemantics(
          child: SizedBox.square(dimension: size, child: face),
        ),
      ),
    );
  }
}
