import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';
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

/// Configures and runs a "Curious" pomodoro: a watch session, then a mandatory
/// cooldown, looping until the user stops. Reuses the Mindful Countdown.
class CuriousScreen extends StatelessWidget {
  const CuriousScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: const GlassAppBar(title: Text('Curious')),
      body: BlocBuilder<SettingsCubit, AppSettings>(
        builder: (context, settings) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: settings.isCuriousContractLive()
                ? const _CuriousActiveView()
                : const _CuriousPickerView(),
          );
        },
      ),
    );
  }
}

class _CuriousPickerView extends StatefulWidget {
  const _CuriousPickerView();

  @override
  State<_CuriousPickerView> createState() => _CuriousPickerViewState();
}

class _CuriousPickerViewState extends State<_CuriousPickerView> {
  int _sessionMin = SessionDefaults.curiousSessionMinuteOptions.first;
  int _cooldownMin = SessionDefaults.curiousCooldownMinuteOptions.first;
  bool _allowInCooldown = false;
  bool _lockSwitch = false;
  EmojiPlacement? _preview;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    final placement =
        await sl<ContentRepository>().emojiPlacement(EmojiPlacementId.curiousPlan);
    if (mounted) setState(() => _preview = placement);
  }

  void _start() {
    context.read<SettingsCubit>().startCurious(
          session: Duration(minutes: _sessionMin),
          cooldown: Duration(minutes: _cooldownMin),
          allowInCooldown: _allowInCooldown,
          disablePlanSwitchInCooldown: _lockSwitch,
        );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final band = _preview?.itemFor(0); // "start of session" preview

    return ListView(
      children: [
        const SizedBox(height: AppSpacing.xs),
        Center(
          child: band != null
              ? AnimatedEmoji(emoji: band.emoji, animation: band.animation, size: 56)
              : const Icon(Icons.search, size: 44, color: AppColors.accent),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Curious mode',
          textAlign: TextAlign.center,
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Watch for a while, then a forced cooldown. It repeats until you stop.',
          textAlign: TextAlign.center,
          style: text.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: 'Session length',
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final m in SessionDefaults.curiousSessionMinuteOptions)
                AppChip(
                  label: '$m min',
                  selected: m == _sessionMin,
                  onSelected: () => setState(() => _sessionMin = m),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SectionCard(
          title: 'Cooldown length',
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final m in SessionDefaults.curiousCooldownMinuteOptions)
                AppChip(
                  label: '$m min',
                  selected: m == _cooldownMin,
                  onSelected: () => setState(() => _cooldownMin = m),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AdaptiveSwitchTile(
          title: 'Allow videos during cooldown',
          subtitle: 'Off = reels are blocked while cooling down',
          value: _allowInCooldown,
          onChanged: (v) => setState(() => _allowInCooldown = v),
        ),
        const SizedBox(height: AppSpacing.xs),
        AdaptiveSwitchTile(
          title: 'Lock plan switching in cooldown',
          subtitle: 'Stops you bailing out mid-cooldown',
          value: _lockSwitch,
          onChanged: (v) => setState(() => _lockSwitch = v),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Start curious session',
          expand: true,
          onPressed: _start,
        ),
      ],
    );
  }
}

class _CuriousActiveView extends StatelessWidget {
  const _CuriousActiveView();

  MindfulPhaseSpec _describe(BuildContext context, DateTime now) {
    final session = context.read<SettingsCubit>().state.curiousSession;
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
        label: session.allowInCooldown
            ? 'Cooling down — videos still allowed'
            : 'Reels paused — cooling down',
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
      placement: EmojiPlacementId.curiousPlan,
      bucket: session.minutesElapsedInSession(now),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SettingsCubit>();
    final locked = !context.watch<SettingsCubit>().state.switcherEnabled();

    return MindfulCountdownView(
      describe: (now) => _describe(context, now),
      placements: const {
        EmojiPlacementId.curiousPlan,
        EmojiPlacementId.pauseCountdownCooldown,
      },
      actionsBuilder: (phase) => switch (phase) {
        SessionPhase.active => Column(
            children: [
              SecondaryButton(
                label: 'End session',
                expand: true,
                onPressed: cubit.endCuriousSessionEarly,
              ),
              const SizedBox(height: AppSpacing.sm),
              GhostButton(label: 'Stop Curious', onPressed: cubit.stopCurious),
            ],
          ),
        SessionPhase.cooldown => Column(
            children: [
              if (locked) const Pill(label: 'Plan switching locked', tone: AppTone.warning),
              const SizedBox(height: AppSpacing.sm),
              GhostButton(label: 'Stop Curious', onPressed: cubit.stopCurious),
            ],
          ),
        SessionPhase.idle => const SizedBox.shrink(),
      },
    );
  }
}
