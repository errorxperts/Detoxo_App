import 'package:detoxo/core/navigation/app_gate.dart';
import 'package:detoxo/features/access_protection/domain/entities/pin_config.dart';
import 'package:detoxo/features/access_protection/presentation/pin_cubit.dart';
import 'package:detoxo/features/access_protection/presentation/pin_lock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Smart Auto Lock: re-locks the app when it comes back from the background,
/// per [PinConfig.autoLock]. Wraps `MaterialApp.router` (see `main.dart`) and
/// pushes a forced [PinLockScreen] on the root navigator — the same idiom as
/// `requirePin` — so navigation state, open dialogs and sheets survive
/// underneath, and the system back button is blocked by the lock's `PopScope`.
///
/// The cold-start launch gate is the router redirect (`AppGate`); this only
/// handles resume.
class PinAutoRelock extends StatefulWidget {
  const PinAutoRelock({
    required this.router,
    required this.gate,
    required this.child,
    super.key,
  });

  final GoRouter router;

  /// Where [AppGate.relocking] is raised while a re-lock is decided or shown.
  final AppGate gate;
  final Widget child;

  @override
  State<PinAutoRelock> createState() => _PinAutoRelockState();
}

class _PinAutoRelockState extends State<PinAutoRelock>
    with WidgetsBindingObserver {
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Stamp on `paused` only: biometric and permission prompts surface as
    // `inactive`, and `hidden` always precedes `paused` — stamping those
    // would re-lock during in-app system sheets.
    if (state == AppLifecycleState.paused) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAt;
      _pausedAt = null;
      _maybeRelock(pausedAt);
    }
  }

  Future<void> _maybeRelock(DateTime? pausedAt) async {
    // A forced app gate already on screen (launch gate, or the pause happened
    // at the relock itself) means there is nothing to add.
    if (pausedAt == null || PinLockScreen.appGateVisible) return;
    // Raised synchronously and held until the lock is decided and, if shown,
    // dismissed. `AppResumeSync` (an ancestor) registered first and runs first,
    // but every resume leg it starts is async; what matters is that this
    // registers before the builder-mounted listeners (`WidgetTapListener`,
    // `PendingUnblockListener`), so they already see the flag up.
    final gate = widget.gate..relocking.value = true;
    try {
      await _relockIfDue(pausedAt);
    } finally {
      gate.relocking.value = false;
    }
  }

  Future<void> _relockIfDue(DateTime pausedAt) async {
    final cubit = context.read<PinCubit>();
    final config = cubit.state;
    var screenOffMillis = 0;
    if (config.autoLock == AutoLockTimeout.screenOff) {
      screenOffMillis = await cubit.lastScreenOff();
    }
    final relock = AutoLockPolicy.shouldRelock(
      config: config,
      pausedAt: pausedAt,
      now: DateTime.now(),
      lastScreenOffMillis: screenOffMillis,
    );
    // Re-check after the async gap — a gate may have appeared meanwhile.
    if (!relock || !mounted || PinLockScreen.appGateVisible) return;
    final nav = widget.router.routerDelegate.navigatorKey.currentState;
    if (nav == null) return;
    // ponytail: a pageless route — a go() while it is up drops it with the
    // page beneath. Guarded where post-boot navigation comes from: the gate
    // holds its permissions redirect while `relocking` is up, and the resume
    // listeners wait on `AppGate.screensMayOpen`. A screen's own async go()
    // landing mid-lock is not; make the lock a routed page if one appears.
    await nav.push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (ctx) =>
            PinLockScreen(onUnlocked: () => Navigator.of(ctx).pop()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
