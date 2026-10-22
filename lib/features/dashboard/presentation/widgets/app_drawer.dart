import 'package:detoxo/core/constants/app_constants.dart';
import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The sidebar: the secondary entry points as flat, hairline-divided rows on
/// a sheet surface inset 10 from the screen edges. App and website blockers
/// are reached from Today, and the numbers from the Insights tab, so neither
/// is repeated here (the pushed `/analytics` route stays for deep links).
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  /// The sheet's gap to the screen edges (`.dx-sheet`).
  static const double _inset = 10;

  /// Close the drawer first, then push — never navigate while the drawer route
  /// is still on top (it would sit under the new screen and reappear on pop).
  void _go(BuildContext context, String route) {
    Navigator.pop(context);
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final items = [
      (Icons.hourglass_bottom, 'Daily limit', Routes.dailyLimit),
      (Icons.palette_outlined, 'Appearance', Routes.appearance),
      (Icons.lock, 'PIN lock', Routes.pinSetup),
      (Icons.settings, 'Settings', Routes.settings),
      (Icons.help_outline, 'Help & support', Routes.help),
    ];
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: 300,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        left: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, _inset, _inset, _inset),
          child: GlassContainer(
            surface: DxSurface.sheet,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header: wordmark + close.
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.xxs,
                    AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            AppConstants.appName,
                            style: AppTypography.title.copyWith(color: t.ink),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        icon: Icon(Icons.close, color: t.ink2),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: PanelGroup(
                      children: [
                        for (final (icon, label, route) in items)
                          GlassListTile(
                            leading: Icon(icon, color: t.ink2),
                            title: label,
                            onTap: () => _go(context, route),
                          ),
                      ],
                    ),
                  ),
                ),
                // Footer: version.
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    'v${AppConstants.appVersion}',
                    style: AppTypography.subhead.copyWith(color: t.ink2),
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
