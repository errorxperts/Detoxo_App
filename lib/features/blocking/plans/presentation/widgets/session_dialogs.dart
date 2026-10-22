import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/utils/app_logger.dart';
import 'package:detoxo/core/utils/clock_format.dart';
import 'package:detoxo/core/utils/duration_format.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';
import 'package:detoxo/features/blocking/plans/domain/entities/conscious_state.dart';
import 'package:detoxo/features/blocking/plans/domain/entities/session_defaults.dart';
import 'package:detoxo/features/blocking/plans/presentation/conscious_cubit.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/app_settings.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/features/blocking/shared/presentation/settings_cubit.dart';
import 'package:detoxo/gen/assets.gen.dart';
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

/// One head over both states: the 3D mode icon in the live accent and the
/// mode's name; below it the intro or the live bank, keyed on the plan.
class _ConsciousDialog extends StatelessWidget {
  const _ConsciousDialog();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Icon3d(
            Assets.images.icons.iconConscious,
            size: ConfirmSheet.iconSize,
            accentTint: true,
          ),
        ),
        const SizedBox(height: AppSpacing.gap),
        Semantics(
          header: true,
          child: Text(
            'Conscious mode',
            textAlign: TextAlign.center,
            style: AppTypography.titleSheet.copyWith(color: context.tokens.ink),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        BlocBuilder<SettingsCubit, AppSettings>(
          buildWhen: (a, b) => a.activePlan != b.activePlan,
          builder: (context, settings) {
            final on = settings.activePlan == BlockingPlan.curious;
            return on ? const _ConsciousLive() : const _ConsciousIntro();
          },
        ),
      ],
    );
  }
}

class _ConsciousIntro extends StatelessWidget {
  const _ConsciousIntro();

  @override
  Widget build(BuildContext context) {
    const every = SessionDefaults.consciousEarnDivisor;
    final cap = SessionDefaults.consciousMaxBank.inMinutes;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Earn 1 minute of reels for every $every minutes away, up to $cap '
          'minutes banked.',
          textAlign: TextAlign.center,
          style: AppTypography.message.copyWith(color: context.tokens.ink2),
        ),
        const SizedBox(height: AppSpacing.xl),
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
    final t = context.tokens;
    const every = SessionDefaults.consciousEarnDivisor;
    final cap = formatHm(SessionDefaults.consciousMaxBank);
    return BlocBuilder<ConsciousCubit, ConsciousState>(
      builder: (context, state) {
        final status = state.watching
            ? 'Spending banked time now. Step away to earn more.'
            : state.hasAllowance
            ? 'Open reels to spend it.'
            : 'Earning 1 minute for every $every minutes away.';
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              formatCountdown(state.banked),
              textAlign: TextAlign.center,
              style: AppTypography.number.copyWith(color: t.ink),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'banked · cap $cap',
              textAlign: TextAlign.center,
              style: AppTypography.subhead.copyWith(color: t.ink2),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              status,
              textAlign: TextAlign.center,
              style: AppTypography.message.copyWith(color: t.ink2),
            ),
            const SizedBox(height: AppSpacing.xl),
            SecondaryButton(
              label: 'Turn off Conscious',
              expand: true,
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
