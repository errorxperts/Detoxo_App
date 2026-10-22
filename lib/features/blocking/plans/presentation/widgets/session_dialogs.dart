import 'dart:async';
import 'dart:math' as math;

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';
import 'package:detoxo/features/blocking/plans/domain/entities/conscious_state.dart';
import 'package:detoxo/features/blocking/plans/domain/entities/session_defaults.dart';
import 'package:detoxo/features/blocking/plans/presentation/conscious_cubit.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/app_settings.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/features/blocking/shared/presentation/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The global surfaces for the session modes, opened from the dashboard.
///
/// Pause opens the frosted Unblock [GlassBottomSheet]: unblock reels for N
/// minutes (a Pause) or for N reels, then the base mode returns on its own.
/// While a Pause runs, the sheet shows the live action (Resume) instead.
/// Conscious keeps its own dual-state [GlassDialog]. The live countdown lives
/// in the dashboard hero.
abstract final class SessionDialogs {
  static Future<void> showPause(BuildContext context) =>
      GlassBottomSheet.show<void>(
        context: context,
        child: const _UnblockSheet(),
      );

  static Future<void> showConscious(BuildContext context) =>
      GlassDialog.show<void>(context: context, child: const _ConsciousDialog());
}

// ── Unblock: N minutes or N reels, then back to the base mode ────────────────

class _UnblockSheet extends StatefulWidget {
  const _UnblockSheet();

  @override
  State<_UnblockSheet> createState() => _UnblockSheetState();
}

class _UnblockSheetState extends State<_UnblockSheet> {
  bool _byReels = false;
  int _minutes = SessionDefaults.pauseDefaultMinutes;
  int _reels = SessionDefaults.unblockDefault;

  /// Hold-to-repeat on the − / + buttons.
  Timer? _hold;

  int get _value => _byReels ? _reels : _minutes;
  int get _min =>
      _byReels ? SessionDefaults.unblockMin : SessionDefaults.pauseMin;
  int get _max =>
      _byReels ? SessionDefaults.unblockMax : SessionDefaults.pauseMax;
  String get _unit =>
      _byReels ? 'reels' : (_minutes == 1 ? 'minute' : 'minutes');

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  Duration _motion(Duration d) =>
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
      ? Duration.zero
      : d;

  void _set(int v) => setState(() {
    if (_byReels) {
      _reels = v;
    } else {
      _minutes = v;
    }
  });

  /// Steps the active value by [d]; false at a bound, which also ends a hold.
  bool _step(int d) {
    final next = (_value + d).clamp(_min, _max);
    if (next == _value) return false;
    AppHaptics.selection();
    _set(next);
    return true;
  }

  /// Keeps stepping while held, speeding up from 200 ms to 60 ms a step.
  void _repeat(int d, [int delayMs = 200]) {
    _hold?.cancel();
    _hold = Timer(Duration(milliseconds: delayMs), () {
      if (_step(d)) _repeat(d, math.max(60, delayMs * 4 ~/ 5));
    });
  }

  void _confirm() {
    final settings = context.read<SettingsCubit>();
    if (_byReels) {
      settings.setOneReel(count: _reels);
    } else {
      settings.startPause(pause: Duration(minutes: _minutes));
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, AppSettings>(
      buildWhen: (a, b) => a.isPauseContractLive() != b.isPauseContractLive(),
      builder: (context, settings) => settings.isPauseContractLive()
          ? const _PauseLive()
          : _picker(context),
    );
  }

  Widget _picker(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final picks = _byReels
        ? SessionDefaults.unblockPicks
        : SessionDefaults.pausePicks;
    final base = planLabel(context.read<SettingsCubit>().state.baseMode);
    final until = TimeOfDay.fromDateTime(
      DateTime.now().add(Duration(minutes: _minutes)),
    ).format(context);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Unblock reels',
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          GlassSegmented(
            segments: const [
              (label: 'Time', icon: null),
              (label: 'Reels', icon: null),
            ],
            selectedIndex: _byReels ? 1 : 0,
            height: AppSizes.controlHeight,
            onChanged: (i) => setState(() => _byReels = i == 1),
          ),
          const SizedBox(height: AppSpacing.md),
          _stepper(context),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            container: true,
            label: 'Quick pick, ${_byReels ? 'reels' : 'minutes'}',
            child: GlassSegmented(
              segments: [for (final n in picks) (label: '$n', icon: null)],
              // -1 (a custom value) hides the pill.
              selectedIndex: picks.indexOf(_value),
              height: AppSizes.controlHeight,
              onChanged: (i) => _set(picks[i]),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _byReels
                ? '$base returns after your last reel.'
                : '$base returns at $until. App locks stay on.',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: context.tokens.ink2),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: _byReels
                ? 'Unlock $_reels reels'
                : 'Unblock for $_minutes min',
            expand: true,
            onPressed: _confirm,
          ),
        ],
      ),
    );
  }

  /// − value + — one control for both tabs. A tap steps by one, holding
  /// repeats. Screen readers get one adjustable node (swipe up/down) whose
  /// live region announces every change, including − / + and quick picks.
  Widget _stepper(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final noun = _byReels ? 'reels' : 'minutes';
    return Row(
      children: [
        _stepButton(
          -1,
          Icons.remove_rounded,
          'Fewer $noun',
          enabled: _value > _min,
        ),
        Expanded(
          child: Semantics(
            slider: true,
            liveRegion: true,
            label: _byReels ? 'Reels to unlock' : 'Minutes to unblock',
            value: '$_value $_unit',
            increasedValue: '${math.min(_value + 1, _max)} $noun',
            decreasedValue: '${math.max(_value - 1, _min)} $noun',
            onIncrease: () => _step(1),
            onDecrease: () => _step(-1),
            child: ExcludeSemantics(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: _motion(AppDurations.fast),
                      transitionBuilder: (child, a) => FadeTransition(
                        opacity: a,
                        child: ScaleTransition(
                          scale: Tween(begin: 0.85, end: 1.0).animate(a),
                          child: child,
                        ),
                      ),
                      child: Text(
                        '$_value',
                        key: ValueKey((_byReels, _value)),
                        style: text.displayLarge?.copyWith(
                          fontSize: 56,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -2,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Text(
                      _unit,
                      style: text.titleSmall?.copyWith(
                        color: context.tokens.ink2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _stepButton(1, Icons.add_rounded, 'More $noun', enabled: _value < _max),
      ],
    );
  }

  Widget _stepButton(
    int d,
    IconData icon,
    String label, {
    required bool enabled,
  }) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: PressScale(
        pressedScale: enabled ? 0.9 : 1,
        child: GestureDetector(
          onTap: enabled ? () => _step(d) : null,
          onLongPressStart: enabled
              ? (_) {
                  if (_step(d)) _repeat(d);
                }
              : null,
          onLongPressEnd: (_) => _hold?.cancel(),
          onLongPressCancel: () => _hold?.cancel(),
          child: AnimatedOpacity(
            opacity: enabled ? 1 : 0.35,
            duration: _motion(AppDurations.fast),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: context.tokens.hairline,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: context.tokens.ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown instead of the picker while a Pause runs.
class _PauseLive extends StatelessWidget {
  const _PauseLive();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Pause active',
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Reels and blocked sites are allowed; app locks stay on. Blocking '
          'resumes automatically when the window ends.',
          style: text.bodyMedium?.copyWith(color: context.tokens.ink2),
        ),
        const SizedBox(height: AppSpacing.md),
        SecondaryButton(
          label: 'Resume blocking now',
          expand: true,
          onPressed: () {
            context.read<SettingsCubit>().resumeNow();
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

// ── Conscious ─────────────────────────────────────────────────────────────────

class _ConsciousDialog extends StatelessWidget {
  const _ConsciousDialog();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, AppSettings>(
      buildWhen: (a, b) => a.activePlan != b.activePlan,
      builder: (context, settings) {
        final on = settings.activePlan == BlockingPlan.curious;
        return on ? const _ConsciousLive() : const _ConsciousIntro();
      },
    );
  }
}

class _ConsciousIntro extends StatelessWidget {
  const _ConsciousIntro();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cap = SessionDefaults.consciousMaxBank.inMinutes;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Icon(
            Icons.self_improvement,
            size: 44,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Conscious mode',
          textAlign: TextAlign.center,
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Earn reel time by staying off it.',
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: context.tokens.ink2),
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: 'How it works',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Bullet('Reels stay blocked while you abstain.'),
              const _Bullet(
                'Every ${SessionDefaults.consciousEarnDivisor} min blocked '
                'banks 1 min of allowance.',
              ),
              _Bullet('Unused time collects, up to $cap min.'),
              const _Bullet(
                'Open reels to spend it — when the bank empties, blocking '
                'returns automatically.',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Turn on Conscious',
          expand: true,
          onPressed: () {
            context.read<SettingsCubit>().enterConscious();
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

class _ConsciousLive extends StatelessWidget {
  const _ConsciousLive();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cap = SessionDefaults.consciousMaxBank.inMinutes;

    return BlocBuilder<ConsciousCubit, ConsciousState>(
      builder: (context, state) {
        final String headline;
        final String hint;
        if (state.watching) {
          headline = 'Watching — spending';
          hint =
              'Your banked time is draining. Step away to start earning '
              'again.';
        } else if (state.hasAllowance) {
          headline = 'Banked allowance';
          hint =
              'Open reels to spend it. Earns '
              '${SessionDefaults.consciousEarnLabel} while you abstain.';
        } else {
          headline = 'Earn to watch';
          hint =
              'Abstain to bank time: ${SessionDefaults.consciousEarnLabel}, '
              'up to $cap min.';
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Icon(
                Icons.shield_outlined,
                size: 44,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              headline,
              textAlign: TextAlign.center,
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${formatCountdown(state.banked)} banked · cap $cap:00',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: context.tokens.ink2),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: context.tokens.ink2),
            ),
            const SizedBox(height: AppSpacing.lg),
            GhostButton(
              label: 'Turn off Conscious',
              onPressed: () {
                context.read<SettingsCubit>().stopConscious();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: AppSpacing.sm),
            child: Icon(
              Icons.circle,
              size: 6,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
