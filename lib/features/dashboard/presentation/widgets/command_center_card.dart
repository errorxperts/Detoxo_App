import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/blocking/plans/presentation/widgets/animated_digit_timer.dart';
import 'package:detoxo/features/blocking/plans/presentation/widgets/countdown_ring.dart';
import 'package:detoxo/features/dashboard/presentation/widgets/mode_toggle.dart';
import 'package:detoxo/features/dashboard/presentation/widgets/stat_pill.dart';
import 'package:flutter/material.dart';

/// A live Pause / Conscious session rendered in the hero ring: a 0..1 [progress]
/// fill, the [remaining] time as ticking digits, a short [caption], and an
/// optional animated [icon]. When present it replaces the idle TIME-SAVED ring.
class SessionCountdown {
  const SessionCountdown({
    required this.progress,
    required this.remaining,
    required this.caption,
    this.tone = AppTone.accent,
    this.icon,
  });

  /// 0..1 ring fill (remaining fraction for Pause, banked fraction for Conscious).
  final double progress;
  final Duration remaining;

  /// A one- or two-word live state shown in the ring, e.g. "apps allowed".
  final String caption;
  final AppTone tone;

  /// Optional animated icon shown above the digits (e.g. [AppIcon.pause]).
  final AppIcon? icon;
}

/// The unified hero ("Command Center"): a gradient progress ring around the
/// primary metric, a live status badge, two secondary stat pills, and the
/// integrated mode toggle — all inside one glass panel with ambient corner
/// glows.
class CommandCenterCard extends StatelessWidget {
  const CommandCenterCard({
    required this.timeSaved,
    required this.progress,
    required this.statusLabel,
    required this.blockedValue,
    required this.streakValue,
    required this.modeOptions,
    required this.selectedMode,
    required this.onModeChanged,
    this.modeEnabled = true,
    this.modeCellBuilder,
    this.countdown,
    super.key,
  });

  final String timeSaved;

  /// 0..1 ring fill.
  final double progress;
  final String statusLabel;
  final String blockedValue;
  final String streakValue;
  final List<ModeOption> modeOptions;
  final int selectedMode;
  final ValueChanged<int> onModeChanged;
  final bool modeEnabled;

  /// Optional per-cell decorator forwarded to [ModeToggle.cellBuilder] — used to
  /// attach feature-showcase targets to the individual mode cells.
  final Widget Function(int index, Widget child)? modeCellBuilder;

  /// When a Pause / Conscious session is live, the hero ring becomes this
  /// countdown gauge instead of the TIME-SAVED ring.
  final SessionCountdown? countdown;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Stack(
      children: [
        SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: 240,
                height: 240,
                child: countdown == null
                    ? _timeSavedRing(context, text, scheme)
                    : _countdownRing(context, text, countdown!),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  StatPill(
                    icon: Icons.smart_display,
                    value: blockedValue,
                    label: 'Blocked',
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  StatPill(
                    icon: Icons.bolt,
                    value: streakValue,
                    label: 'Streak',
                    iconColor: scheme.secondary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              ModeToggle(
                options: modeOptions,
                selectedIndex: selectedMode,
                onChanged: onModeChanged,
                enabled: modeEnabled,
                cellBuilder: modeCellBuilder,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The idle hero: a gradient ring around the TIME-SAVED metric.
  Widget _timeSavedRing(
    BuildContext context,
    TextTheme text,
    ColorScheme scheme,
  ) {
    return ProgressRing(
      progress: progress,
      size: 240,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'TIME SAVED',
            style: text.labelSmall?.copyWith(
              color: scheme.secondary,
              letterSpacing: 2,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            width: 170,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppColors.tealBright, AppColors.indigoBright],
                ).createShader(bounds),
                blendMode: BlendMode.srcIn,
                child: Text(
                  timeSaved,
                  style: text.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _StatusBadge(label: statusLabel),
        ],
      ),
    );
  }

  /// The live hero: the read-only countdown gauge with ticking digits, an
  /// animated emoji and a state pill.
  Widget _countdownRing(
    BuildContext context,
    TextTheme text,
    SessionCountdown cd,
  ) {
    final icon = cd.icon;
    return CountdownRing(
      progress: cd.progress,
      center: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            AppAnimatedIcon(
              icon: icon,
              size: 30,
              color: AppColors.accent,
              playOnAppear: true,
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          AnimatedDigitTimer(
            remaining: cd.remaining,
            style: text.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Pill(label: cd.caption, tone: cd.tone),
        ],
      ),
    );
  }
}

/// Pulsing dot + uppercase plan label, e.g. "● CONSCIOUS".
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs + 2,
      ),
      decoration: BoxDecoration(
        color: scheme.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusDot(color: scheme.secondary, size: 6),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.secondary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
