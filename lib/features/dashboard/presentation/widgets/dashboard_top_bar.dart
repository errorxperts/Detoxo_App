import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/dashboard/presentation/widgets/menu_button.dart';
import 'package:flutter/material.dart';

/// Dashboard header: the brand wordmark, a notifications action, and the menu
/// button that opens the right-side app drawer.
class DashboardTopBar extends StatelessWidget {
  const DashboardTopBar({this.onNotifications, this.onMenu, super.key});

  final VoidCallback? onNotifications;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Detoxo',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onNotifications,
              tooltip: 'Notifications',
              icon: Icon(Icons.notifications_active, color: scheme.primary),
            ),
            const SizedBox(width: AppSpacing.xs),
            DrawerMenuButton(onTap: onMenu),
          ],
        ),
      ],
    );
  }
}
