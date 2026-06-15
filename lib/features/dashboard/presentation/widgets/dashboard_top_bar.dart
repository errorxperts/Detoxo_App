import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Dashboard header: the brand wordmark, a notifications action, and a
/// decorative profile avatar. There's no profile feature yet, so the avatar is
/// a static placeholder (matches the mockup's layout without inventing data).
class DashboardTopBar extends StatelessWidget {
  const DashboardTopBar({this.onNotifications, super.key});

  final VoidCallback? onNotifications;

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
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withValues(alpha: 0.12),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.25),
                  width: 2,
                ),
              ),
              child: Icon(Icons.person, size: 22, color: scheme.primary),
            ),
          ],
        ),
      ],
    );
  }
}
