import 'package:flutter/material.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart';

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/blocking/blocklist/presentation/blocklist_tab.dart';
import 'package:detoxo/features/dashboard/presentation/dashboard_tab.dart';
import 'package:detoxo/features/dashboard/presentation/more_tab.dart';

/// The main authenticated surface: Dashboard / Blocklist / More over the ambient
/// gradient, with a frosted floating bar that hides as you scroll.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _items = [
    (icon: Icons.dashboard_outlined, selected: Icons.dashboard, label: 'Dashboard'),
    (icon: Icons.block_outlined, selected: Icons.block, label: 'Blocklist'),
    (icon: Icons.more_horiz, selected: Icons.more_horiz, label: 'More'),
  ];

  Widget _tab(ScrollController controller) {
    // Only the active tab is built, so the floating bar's single controller
    // attaches cleanly to exactly one scrollable for hide-on-scroll.
    return switch (_index) {
      0 => DashboardTab(scrollController: controller),
      1 => BlocklistTab(scrollController: controller),
      _ => MoreTab(scrollController: controller),
    };
  }

  @override
  Widget build(BuildContext context) {
    final barWidth = MediaQuery.sizeOf(context).width - AppSpacing.xl;
    return GlassScaffold(
      safeArea: false,
      body: BottomBar(
        fit: StackFit.expand,
        borderRadius: AppRadius.brPill,
        barColor: Colors.transparent,
        barAlignment: Alignment.bottomCenter,
        width: barWidth > 460 ? 460 : barWidth,
        offset: AppSpacing.sm,
        duration: AppDurations.normal,
        curve: AppCurves.standard,
        showIcon: false,
        body: (context, controller) => SafeArea(
          bottom: false,
          child: _tab(controller),
        ),
        child: GlassContainer(
          borderRadius: AppRadius.pill,
          blurSigma: AppBlur.bar,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                _NavItem(
                  icon: _items[i].icon,
                  selectedIcon: _items[i].selected,
                  label: _items[i].label,
                  selected: _index == i,
                  onTap: () {
                    AppHaptics.selection();
                    setState(() => _index = i);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : Theme.of(context).colorScheme.onSurfaceVariant;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AppCurves.standard,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent.withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: AppRadius.brPill,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? selectedIcon : icon, color: color, size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
