import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/dashboard/presentation/widgets/mode_toggle.dart';
import 'package:detoxo/features/dashboard/presentation/widgets/stat_pill.dart';
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return GlassContainer(
      borderRadius: 36,
      blurSigma: AppBlur.hero,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Stack(
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
                  child: ProgressRing(
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
                            child: Text(
                              timeSaved,
                              style: text.displaySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _StatusBadge(label: statusLabel),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    StatPill(icon: Icons.smart_display, value: blockedValue, label: 'Blocked'),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A soft radial glow blob; clipped to the panel corners by the parent's
  /// rounded clip.
  static Widget _glow(Color color) {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs + 2),
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
