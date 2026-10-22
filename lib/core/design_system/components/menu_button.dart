import 'package:detoxo/core/design_system/components/buttons.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

/// The drawer ("sidebar") button of a tab header: a [GlassIconButton] holding
/// the spec sidebar glyph in `ink`.
///
/// Lives in the design system rather than under the dashboard because three
/// features draw it; reaching into `dashboard/presentation/` for it was a
/// boundary violation the gate could not see (2026-09-06).
class DrawerMenuButton extends StatelessWidget {
  const DrawerMenuButton({required this.onTap, super.key});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GlassIconButton(
    semanticLabel: 'Menu',
    onPressed: onTap,
    icon: Builder(
      builder: (context) => SvgPicture.asset(
        Assets.svg.sidebar.path,
        colorFilter: ColorFilter.mode(
          IconTheme.of(context).color!,
          BlendMode.srcIn,
        ),
        width: 22,
      ),
    ),
  );
}
