import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/utils/app_logger.dart';
import 'package:detoxo/core/utils/clock_format.dart';
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
/// Pause and an N-reel unblock open the [SessionSheet], By time or By reel
/// count: Start commits, the sheet reads "Session started" and closes, and the
/// base mode returns on its own when the session ends. A Start that fails
/// keeps the sheet open behind an error toast. Conscious keeps its own
/// dual-state sheet. The live countdown lives in the dashboard hero.
abstract final class SessionDialogs {
  static const String startFailed = "Couldn't start the session — try again";

  /// Unblock reels for 1–10 minutes (a Pause).
  static Future<void> showPause(BuildContext context) {
    final settings = context.read<SettingsCubit>();
    return SessionSheet.show(
      context,
      kind: SessionKind.time,
      min: SessionDefaults.pauseMin,
      max: SessionDefaults.pauseMax,
      initial: SessionDefaults.pauseDefaultMinutes,
      picks: SessionDefaults.pausePicks,
      note: (v) {
        final at = DateTime.now().add(Duration(minutes: v));
        final time = formatLocalTime(context, at.hour * 60 + at.minute);
        return 'Blocking resumes at $time';
      },
      startLabel: (v) => 'Start $v-min session',
      onStart: (v) => _start(
        context,
        () => settings.startPause(pause: Duration(minutes: v)),
      ),
    );
  }

  /// Unblock 1–20 reels, then block again.
  static Future<void> showReels(BuildContext context) {
    final settings = context.read<SettingsCubit>();
    return SessionSheet.show(
      context,
      kind: SessionKind.reels,
      min: SessionDefaults.unblockMin,
      max: SessionDefaults.unblockMax,
      initial: SessionDefaults.unblockDefault,
      picks: SessionDefaults.unblockPicks,
      note: (v) => 'Blocking resumes after $v ${v == 1 ? 'reel' : 'reels'}',
      startLabel: (v) => 'Start $v-reel session',
      onStart: (v) => _start(context, () => settings.setOneReel(count: v)),
    );
  }

  /// The sheet's `onStart`: true once [commit] lands. A throw (the settings
  /// write or the native push) is logged and toasted, and the sheet stays.
  static Future<bool> _start(
    BuildContext context,
    Future<void> Function() commit,
  ) async {
    try {
      await commit();
      return true;
    } on Object catch (e, s) {
      AppLogger.e('session start failed', e, s);
      if (context.mounted) {
        GlassToast.show(context, startFailed, tone: AppTone.danger);
      }
      return false;
    }
  }

  static Future<void> showConscious(BuildContext context) =>
      GlassBottomSheet.show<void>(
        context: context,
        child: const _ConsciousDialog(),
      );
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
            SecondaryButton(
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
