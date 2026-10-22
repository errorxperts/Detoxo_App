import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';
import 'package:detoxo/features/blocking/blocking.dart' show BlockingMode;
import 'package:detoxo/features/permissions/permissions.dart'
    show AppPermission;
import 'package:flutter/material.dart';

/// The block-mode picker and its entry tile, cubit-free so a widget test can
/// pump them bare (the `ModeCard` precedent). The Settings screen supplies
/// the cubit reads and the permission funnel.
///
/// The picker offers four of `BlockingMode`'s values. `BLOCK_SCREEN` is the
/// only mode that raises the wall on a plan block; a spent daily limit, a
/// schedule or a drained Conscious bank raise it in every mode (native
/// `WallPolicy`).
const blockModes = <(BlockingMode, String, String)>[
  (BlockingMode.pressBack, 'Press back', 'Exits the reel (recommended)'),
  (
    BlockingMode.blockScreen,
    'Block screen',
    'Exits the reel and shows a full-screen wall with a way back',
  ),
  (BlockingMode.killApp, 'Close the app', 'Closes the app'),
  (
    BlockingMode.lockApp,
    'Lock app',
    'Locks the app behind your PIN, like an app locker',
  ),
];

String blockModeTitle(BlockingMode m) =>
    blockModes.firstWhere((e) => e.$1 == m, orElse: () => blockModes.first).$2;

/// The truthful row under a feature whose switch is on but whose Android grant
/// is missing (EVO-036 / EVO-042): the grant's name, what is not happening,
/// and the status 'Needs access'; a tap asks for the grant. One shape for the
/// block mode, the soft nudge and notification silence, drawn in the panel of
/// the row it belongs to.
class PermissionNeededRow extends StatelessWidget {
  const PermissionNeededRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassListTile(
      // Indents the text to the row above's title (a 24 px glyph).
      leading: const SizedBox(width: 24),
      title: title,
      subtitle: subtitle,
      trailing: const Pill(label: 'Needs access', tone: AppTone.warning),
      onTap: onTap,
    );
  }
}

/// The four modes as option rows; the picked one carries the check and is
/// announced as selected.
class BlockModeOptions extends StatelessWidget {
  const BlockModeOptions({
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final BlockingMode selected;
  final ValueChanged<BlockingMode> onSelect;

  @override
  Widget build(BuildContext context) {
    return PanelGroup(
      children: [
        for (final e in blockModes)
          GlassListTile(
            title: e.$2,
            subtitle: e.$3,
            selected: selected == e.$1,
            onTap: () => onSelect(e.$1),
          ),
      ],
    );
  }
}

/// Settings entry for the picker. With [needsOverlay] the Block screen mode
/// still bounces the reel but no wall can ever appear — the row says so and
/// [onGrant] offers the fix.
class BlockModeTile extends StatelessWidget {
  const BlockModeTile({
    required this.mode,
    required this.needsOverlay,
    required this.onTap,
    required this.onGrant,
    super.key,
  });

  final BlockingMode mode;
  final bool needsOverlay;
  final VoidCallback onTap;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FeatureTile(
          icon: Icons.touch_app_outlined,
          title: 'When a reel is detected',
          subtitle: blockModeTitle(mode),
          onTap: onTap,
        ),
        if (needsOverlay)
          PermissionNeededRow(
            title: AppPermission.overlay.label,
            subtitle: 'No block screen can appear until you allow it',
            onTap: onGrant,
          ),
      ],
    );
  }
}
