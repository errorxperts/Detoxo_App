import 'package:detoxo/core/constants/app_constants.dart';
import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Minimal right-side navigation drawer: the secondary entry points that used to
/// live in the "More" tab, as a plain list over a single frosted panel. App and
/// website blockers are reached from the Dashboard, so they're not repeated here.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  /// Close the drawer first, then push — never navigate while the drawer route
  /// is still on top (it would sit under the new screen and reappear on pop).
  void _go(BuildContext context, String route) {
    Navigator.pop(context);
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: 300,
      child: DecoratedBox(
        // A leading hairline defines the panel edge against the content,
        // especially in the light theme.
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: context.glass.border)),
        ),
        child: GlassContainer(
          borderRadius: 0,
          blurSigma: AppBlur.sheet,
          borderColor: Colors.transparent,
          // Standard translucent glass fill (glass.fillTop/fillBottom) so the
          // drawer matches the app's glassmorphism; the frosted blur here plus
          // the background blur behind it keep nav text readable.
          padding: EdgeInsets.zero,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header: wordmark + close.
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.xs,
                    AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppConstants.appName,
                          style: text.titleLarge?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        icon: Icon(Icons.close, color: context.glass.onGlass),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: context.glass.border),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    children: [
                      _DrawerItem(
                        icon: Icons.hourglass_bottom,
                        label: 'Daily limit',
                        onTap: () => _go(context, Routes.dailyLimit),
                      ),
                      _DrawerItem(
                        icon: Icons.bar_chart,
                        label: 'Activity',
                        onTap: () => _go(context, Routes.analytics),
                      ),
                      _DrawerItem(
                        icon: Icons.lock,
                        label: 'PIN lock',
                        onTap: () => _go(context, Routes.pinSetup),
                      ),
                      _DrawerItem(
                        icon: Icons.settings,
                        label: 'Settings',
                        onTap: () => _go(context, Routes.settings),
                      ),
                    ],
                  ),
                ),
                // Footer: version.
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    'v${AppConstants.appVersion}',
                    style: text.bodySmall?.copyWith(
                      color: context.glass.onGlassMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A plain drawer row: leading icon + label.
class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListTile(
      leading: Icon(icon, color: AppColors.accent),
      title: Text(
        label,
        style: text.bodyLarge?.copyWith(color: context.glass.onGlass),
      ),
      onTap: onTap,
    );
  }
}
