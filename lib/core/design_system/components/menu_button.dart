import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

/// identical: a primary-tinted circle with a [Icons.menu_rounded] glyph.
///
/// Lives in the design system rather than under the dashboard because three
/// features draw it; reaching into `dashboard/presentation/` for it was a
/// boundary violation the gate could not see (2026-09-06).
class DrawerMenuButton extends StatelessWidget {
  const DrawerMenuButton({required this.onTap, super.key});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Menu',
      child: GestureDetector(
        onTap: onTap == null
            ? null
            : () {
                onTap!();
              },
        child: SvgPicture.asset(
          Assets.svg.sidebar.path,
          colorFilter: ColorFilter.mode(scheme.primary, BlendMode.srcIn),
          width: 22,
        ),
      ),
    );
  }
}
