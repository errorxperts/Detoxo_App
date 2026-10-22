import 'dart:async';

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/blocking/blocking.dart';
import 'package:detoxo/features/content_counter/content_counter.dart';
import 'package:detoxo/features/dashboard/dashboard.dart';
import 'package:detoxo/features/limits/limits.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The accent mode for [s]: none while blocking is off (the master switch),
/// else the Today screen's lit mode ([modeIndex]), so the two never disagree.
AccentMode accentModeOf(AppSettings s, {required bool pauseLive}) {
  if (!s.masterEnabled) return AccentMode.none;
  return switch (modeIndex(s, pauseLive: pauseLive)) {
    0 => AccentMode.blockAll,
    1 => AccentMode.conscious,
    2 => AccentMode.pause,
    _ => AccentMode.oneReel,
  };
}

/// Resolves the app's live accent from the blocking mode, today's share of
/// the daily limit and a live Pause's time left, and publishes it to every
/// route, sheet and dialog through an [AccentScope]. Mounted outermost in
/// `MaterialApp.router(builder:)`, below Theme and MediaQuery.
class LiveAccent extends StatefulWidget {
  const LiveAccent({required this.child, super.key});

  final Widget child;

  @override
  State<LiveAccent> createState() => _LiveAccentState();
}

class _LiveAccentState extends State<LiveAccent> {
  // Ticks once a second, only while a Pause is live, so its last two minutes
  // can warm toward `over`.
  Timer? _tick;

  void _syncTick({required bool pauseLive}) {
    if (pauseLive && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!pauseLive && _tick != null) {
      _tick!.cancel();
      _tick = null;
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsCubit>().state;
    final (counting, timeToday) = context
        .select<ContentCounterCubit, (bool, Duration)>(
          (c) => (c.state.enabled, c.state.timeToday),
        );
    final limit = context.select<DailyLimitCubit, Duration>(
      (c) => c.state.limit,
    );
    final now = DateTime.now();
    final pauseLive = s.isPauseContractLive(now);
    _syncTick(pauseLive: pauseLive);

    final mode = accentModeOf(s, pauseLive: pauseLive);
    final used = counting && limit > Duration.zero
        ? timeToday.inSeconds / limit.inSeconds
        : 0.0;
    final pauseLeft = pauseLive
        ? s.pauseSession!.pauseEnd.difference(now)
        : null;
    AccentPalette at(AppTokens t) =>
        resolveAccent(t, mode, used: used, pauseLeft: pauseLeft);
    return AccentScope(
      light: at(AppTokens.light),
      dark: at(AppTokens.dark),
      // A mode or usage change glides; a Pause's per-second tick snaps.
      glideKey: (mode, used),
      child: widget.child,
    );
  }
}
