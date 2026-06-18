import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// The hamburger control that opens the app's right-side drawer. A single
/// source of truth so the Dashboard and Blocklist headers stay identical: a
/// primary-tinted circle with a [Icons.menu_rounded] glyph.
class DrawerMenuButton extends StatelessWidget {
  const DrawerMenuButton({required this.onTap, super.key});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Menu',
      child: InkWell(
        borderRadius: AppRadius.brPill,
        onTap: onTap == null
            ? null
            : () {
                AppHaptics.selection();
                onTap!();
              },
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.primary.withValues(alpha: 0.12),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.25), width: 2),
          ),
          child: Icon(Icons.menu_rounded, size: 22, color: scheme.primary),
        ),
      ),
    );
  }
}
