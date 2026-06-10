import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/blocking/blocklist/presentation/blocklist_tab.dart';
import 'package:detoxo/features/dashboard/presentation/dashboard_tab.dart';
import 'package:detoxo/features/dashboard/presentation/more_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart';

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
    (icon: AppIcon.dashboard, label: 'Dashboard'),
    (icon: AppIcon.blocklist, label: 'Blocklist'),
    (icon: AppIcon.more, label: 'More'),
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
                _AnimatedNavItem(
                  icon: _items[i].icon,
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

/// A bottom-nav item whose icon plays its Lucide morph each time the tab
/// becomes selected. The icon is controller-driven (`interactive: false`) so
/// the opaque [GestureDetector] keeps owning the tap.
class _AnimatedNavItem extends StatefulWidget {
  const _AnimatedNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AppIcon icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_AnimatedNavItem> createState() => _AnimatedNavItemState();
}

class _AnimatedNavItemState extends State<_AnimatedNavItem> {
  final AnimatedIconController _controller = AnimatedIconController();

  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    // Play once for the tab that's already active on launch.
    if (widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_reduceMotion) _controller.animate();
      });
    }
  }

  @override
  void didUpdateWidget(_AnimatedNavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) {
      if (!_reduceMotion) _controller.animate();
    } else if (!widget.selected && oldWidget.selected) {
      // Settle to the first frame so re-selecting replays the morph cleanly.
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.selected
        ? AppColors.accent
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AppCurves.standard,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppColors.accent.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: AppRadius.brPill,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppAnimatedIcon(
                icon: widget.icon,
                color: color,
                controller: _controller,
              ),
              const SizedBox(height: 2),
              Text(
                widget.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
