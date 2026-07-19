import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// One of the five blocking plans, as a tappable onboarding preview.
class _Plan {
  const _Plan(this.label, this.icon, this.promise);
  final String label;
  final IconData icon;
  final String promise;
}

/// Screen 3 hero: the differentiator. Tapping a plan chip morphs the badge +
/// promise line above it, so the user *discovers* the flexibility by playing
/// instead of reading a wall of text. Defaults to Conscious — the signature
/// earn-as-you-abstain mode.
///
/// Deep per-plan teaching is deferred to the in-context feature showcase on the
/// dashboard; this only sells that "there's a plan that fits you".
class PlanPreview extends StatefulWidget {
  const PlanPreview({required this.accent, super.key});

  final Color accent;

  @override
  State<PlanPreview> createState() => _PlanPreviewState();
}

class _PlanPreviewState extends State<PlanPreview> {
  // Copy mirrors the dashboard showcase one-liners (kept short for onboarding).
  static const _plans = <_Plan>[
    _Plan('Block All', Icons.block, 'Total focus. Every reel closes the moment it appears.'),
    _Plan('Conscious', Icons.self_improvement,
        'Earn your scroll. Bank time by staying off, then spend it mindfully.'),
    _Plan('One Reel', Icons.looks_one_outlined,
        'One and done. Watch a single clip, then it locks straight back.'),
    _Plan('Unblock', Icons.lock_open_rounded,
        'Pick a number. Release a small batch — 2 to 20 reels — then it reverts.'),
    _Plan('Pause', Icons.pause_circle_outline,
        'Take a breather. Pause for a set window; blocking resumes on its own.'),
  ];

  int _selected = 1; // Conscious

  // AppChip already gives a light haptic via AppPressable — no extra tick here.
  void _select(int i) {
    if (i == _selected) return;
    setState(() => _selected = i);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final plan = _plans[_selected];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconBadge(
          key: ValueKey('badge$_selected'),
          icon: plan.icon,
          size: 72,
          color: widget.accent,
          bordered: true,
          fillAlpha: 0.20,
        ).animate(key: ValueKey('badgeAnim$_selected')).scaleXY(
              begin: 0.85,
              end: 1,
              duration: AppDurations.fast,
              curve: AppCurves.emphasized,
            ),
        const SizedBox(height: AppSpacing.md),
        // Fixed height so the chip row never jumps as the promise length changes.
        SizedBox(
          height: 64,
          child: Center(
            child: AnimatedSwitcher(
              duration: AppDurations.fast,
              child: Text(
                plan.promise,
                key: ValueKey(_selected),
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: context.glass.onGlass),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            children: [
              for (var i = 0; i < _plans.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.xs),
                AppChip(
                  label: _plans[i].label,
                  icon: _plans[i].icon,
                  selected: i == _selected,
                  onSelected: () => _select(i),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
