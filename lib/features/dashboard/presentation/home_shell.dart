import 'package:flutter/material.dart';

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/blocking/blocklist/presentation/blocklist_tab.dart';
import 'package:detoxo/features/dashboard/presentation/dashboard_tab.dart';
import 'package:detoxo/features/dashboard/presentation/more_tab.dart';

/// The main authenticated surface: Dashboard / Blocklist / More tabs over the
/// ambient gradient, with a floating frosted tab bar.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _tabs = [DashboardTab(), BlocklistTab(), MoreTab()];

  static const _items = [
    AdaptiveTabItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      sfSymbol: 'square.grid.2x2',
    ),
    AdaptiveTabItem(
      label: 'Blocklist',
      icon: Icons.block_outlined,
      selectedIcon: Icons.block,
      sfSymbol: 'nosign',
    ),
    AdaptiveTabItem(
      label: 'More',
      icon: Icons.more_horiz,
      sfSymbol: 'ellipsis',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomBar: GlassBottomBar(
        enableBlur: !PlatformAdaptive.useCupertino,
        child: AdaptiveTabBar(
          items: _items,
          currentIndex: _index,
          onChanged: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}
