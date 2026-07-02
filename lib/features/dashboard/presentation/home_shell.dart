import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/additional_feature/showcase_view/showcase_view.dart';
import 'package:detoxo/features/analytics/presentation/analytics_screen.dart';
import 'package:detoxo/features/blocking/shared/presentation/settings_cubit.dart';
import 'package:detoxo/features/dashboard/presentation/dashboard_tab.dart';
import 'package:detoxo/features/dashboard/presentation/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart';

/// The main authenticated surface: Dashboard / Activity over the ambient
/// gradient, with a frosted floating bar that hides as you scroll. The active
/// tab expands into an accent "pill"; the others stay icon-only (compact). The
/// former "More" tab now lives in a right-side [AppDrawer], openable from each
/// tab's header menu button. (All blocking management now lives in the App
/// Blocker screen, reached from the dashboard capsule.)
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  // Drives the end-drawer (the former "More" tab) via the inner Scaffold.
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  void _openDrawer() => _scaffoldKey.currentState?.openEndDrawer();

  static const _items = [
    (icon: AppIcon.dashboard, label: 'Dashboard'),
    (icon: AppIcon.activity, label: 'Activity'),
  ];

  Widget _tab(ScrollController controller) {
    // Only the active tab is built, so the floating bar's single controller
    // attaches cleanly to exactly one scrollable for hide-on-scroll.
    return switch (_index) {
      0 => DashboardTab(scrollController: controller, onMenu: _openDrawer),
      _ => AnalyticsTab(scrollController: controller, onMenu: _openDrawer),
    };
  }

  @override
  Widget build(BuildContext context) {
    // Size the floating bar to its content (one slot per item) so it stays a
    // compact centered capsule instead of stretching to the screen width.
    const slot = 64.0;
    final screenMax = MediaQuery.sizeOf(context).width - AppSpacing.xl;
    final contentWidth = _items.length * slot + AppSpacing.sm;
    final barWidth = contentWidth > screenMax ? screenMax : contentWidth;
    // Lighter drawer dim in light theme: the scrim sits behind the glass drawer
    // and is blurred into it, so a heavy black scrim would make the frosted
    // panel read murky/dark instead of as light glass.
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GlassScaffold(
      safeArea: false,
      scaffoldKey: _scaffoldKey,
      endDrawer: const AppDrawer(),
      drawerScrimColor: Colors.black.withValues(alpha: dark ? 0.5 : 0.22),
      body: BottomBar(
        fit: StackFit.expand,
        borderRadius: AppRadius.brPill,
        barColor: Colors.transparent,
        width: barWidth, 
        offset: AppSpacing.sm,
        duration: AppDurations.normal,
        curve: AppCurves.standard,
        showIcon: false,
        body: (context, controller) => buildFeatureShowcaseScope(
          // Persist on finish AND dismiss so a skipped tour is remembered too.
          onSeen: () => context.read<SettingsCubit>().setShowcaseSeen(value: true),
          child: SafeArea(bottom: false, child: _tab(controller)),
        ),
        child: GlassContainer(
          borderRadius: AppRadius.pill,
          blurSigma: AppBlur.bar,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < _items.length; i++)
                _NavPillItem(
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

/// A bottom-nav item: a muted icon when unselected, and a primary→secondary
/// gradient circle when selected. The Lucide icon morph replays each time the
/// tab becomes selected (controller-driven, so the opaque [GestureDetector]
/// keeps owning the tap).
class _NavPillItem extends StatefulWidget {
  const _NavPillItem({
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
  State<_NavPillItem> createState() => _NavPillItemState();
}

class _NavPillItemState extends State<_NavPillItem> {
  final AnimatedIconController _controller = AnimatedIconController();

  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    if (widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_reduceMotion) _controller.animate();
      });
    }
  }

  @override
  void didUpdateWidget(_NavPillItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) {
      if (!_reduceMotion) _controller.animate();
    } else if (!widget.selected && oldWidget.selected) {
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
    final scheme = Theme.of(context).colorScheme;
    final iconColor = widget.selected ? scheme.onPrimary : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AppCurves.standard,
          width: widget.selected ? 40 : 32,
          height: widget.selected ? 40 : 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: widget.selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [scheme.primary, scheme.secondary],
                  )
                : null,
            boxShadow: widget.selected
                ? [
                    BoxShadow(
                      color: scheme.secondary.withValues(alpha: 0.40),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: AppAnimatedIcon(
            icon: widget.icon,
            size: 24,
            color: iconColor,
            controller: _controller,
          ),
        ),
      ),
    );
  }
}
