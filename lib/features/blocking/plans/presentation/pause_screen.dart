import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/features/blocking/plans/domain/entities/emoji_band.dart';
import 'package:detoxo/features/blocking/plans/domain/entities/session_defaults.dart';
import 'package:detoxo/features/blocking/plans/domain/repositories/content_repository.dart';
import 'package:detoxo/features/blocking/plans/presentation/widgets/animated_emoji.dart';
import 'package:detoxo/features/blocking/plans/presentation/widgets/mindful_countdown_view.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/app_settings.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/features/blocking/shared/presentation/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Lets the user start a mindful pause (allowed window → mandatory cooldown),
/// then shows the live Mindful Countdown for each phase.
class PauseScreen extends StatelessWidget {
  const PauseScreen({super.key});

  static String planLabel(BlockingPlan p) => switch (p) {
        BlockingPlan.blockAll => 'Block all',
        BlockingPlan.curious => 'Curious',
        BlockingPlan.oneReel => 'One reel',
        BlockingPlan.paused => 'Block all',
      };

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: const GlassAppBar(title: Text('Pause')),
      body: BlocBuilder<SettingsCubit, AppSettings>(
        builder: (context, settings) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: settings.isPauseContractLive()
                ? const _PausedView()
                : const _PickerView(),
          );
        },
      ),
    );
  }
}

class _PickerView extends StatefulWidget {
  const _PickerView();

  @override
  State<_PickerView> createState() => _PickerViewState();
}

class _PickerViewState extends State<_PickerView> {
  int _selectedMin = SessionDefaults.pauseOptions.first;
  EmojiPlacement? _preview;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    final placement =
        await sl<ContentRepository>().emojiPlacement(EmojiPlacementId.pauseCountdown);
    if (mounted) setState(() => _preview = placement);
  }

  void _start() {
    context.read<SettingsCubit>().startPause(pause: Duration(minutes: _selectedMin));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cooldownMin = SessionDefaults.pauseCooldown.inMinutes.clamp(1, 999);
    final resume = PauseScreen.planLabel(context.watch<SettingsCubit>().state.activePlan);
    final band = _preview?.itemFor(_selectedMin);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xs),
        if (band != null)
          AnimatedEmoji(emoji: band.emoji, animation: band.animation, size: 56)
        else
          const Icon(Icons.self_improvement, size: 44, color: AppColors.accent),
        const SizedBox(height: AppSpacing.md),
        Text(
          band?.title ?? 'Take a mindful pause',
          textAlign: TextAlign.center,
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          band?.description ??
              'Choose how long to allow content. Blocking returns automatically.',
          textAlign: TextAlign.center,
          style: text.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final m in SessionDefaults.pauseOptions)
              AppChip(
                label: '$m min',
                selected: m == _selectedMin,
                onSelected: () => setState(() => _selectedMin = m),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Reels allowed for $_selectedMin min, then a $cooldownMin-min '
          'wind-down. Blocking (“$resume”) resumes after that.',
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(color: context.glass.onGlassMuted),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(label: 'Start pause', expand: true, onPressed: _start),
      ],
    );
  }
}

class _PausedView extends StatelessWidget {
  const _PausedView();

  MindfulPhaseSpec _describe(BuildContext context, DateTime now) {
    final session = context.read<SettingsCubit>().state.pauseSession;
    if (session == null) {
      return const MindfulPhaseSpec(
        phase: SessionPhase.idle,
        label: 'Done',
        remaining: Duration.zero,
        progress: 0,
      );
    }
    final phase = session.phaseAt(now);
    final remaining = session.remainingIn(now);
    final phaseMs = session.phaseLengthAt(now).inMilliseconds;
    final progress = phaseMs <= 0 ? 0.0 : remaining.inMilliseconds / phaseMs;

    if (phase == SessionPhase.cooldown) {
      return MindfulPhaseSpec(
        phase: phase,
        label: 'Winding down',
        remaining: remaining,
        progress: progress.clamp(0, 1),
        placement: EmojiPlacementId.pauseCountdownCooldown,
        bucket: session.cooldownProgressPct(now),
      );
    }
    return MindfulPhaseSpec(
      phase: phase,
      label: 'Reels allowed for',
      remaining: remaining,
      progress: progress.clamp(0, 1),
      placement: EmojiPlacementId.pauseCountdown,
      bucket: session.pauseDuration.inMinutes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return MindfulCountdownView(
      describe: (now) => _describe(context, now),
      placements: const {
        EmojiPlacementId.pauseCountdown,
        EmojiPlacementId.pauseCountdownCooldown,
      },
      actionsBuilder: (phase) {
        if (phase == SessionPhase.idle) return const SizedBox.shrink();
        return Column(
          children: [
            if (phase == SessionPhase.cooldown)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'Content’s still allowed while it winds down — blocking '
                  'returns when this ends.',
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: context.glass.onGlassMuted),
                ),
              ),
            SecondaryButton(
              label: 'Resume blocking now',
              expand: true,
              onPressed: () => context.read<SettingsCubit>().resumeNow(),
            ),
          ],
        );
      },
    );
  }
}
