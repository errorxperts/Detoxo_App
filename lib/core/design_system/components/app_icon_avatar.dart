import 'dart:typed_data';

import 'package:detoxo/core/design_system/components/cards.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:detoxo/core/design_system/tokens/app_tokens.dart';
import 'package:detoxo/core/utils/device_app_icons.dart';
import 'package:flutter/material.dart';

/// A rounded app icon: the phone's own icon for the app, never a bundled one.
///
/// Resolution order:
/// 1. [iconBytes] → an icon the caller already holds;
/// 2. [packageName] → the device icon from [deviceAppIcons] (rebuilds when the
///    engine's scan lands);
/// 3. a drawn letter tile with the app's initial (an uninstalled app has no
///    device icon);
/// 4. a neutral smartphone badge when the name doesn't start with a letter.
class AppIconAvatar extends StatelessWidget {
  const AppIconAvatar({
    required this.appName,
    this.packageName = '',
    this.iconBytes,
    this.size = 34,
    this.borderRadius,
    this.dimmed = false,
    super.key,
  });

  final String appName;

  /// Looked up in [deviceAppIcons] when [iconBytes] is null.
  final String packageName;

  /// Raw PNG bytes from the device (takes precedence over [packageName]).
  final Uint8List? iconBytes;
  final double size;
  final BorderRadius? borderRadius;

  /// Dims the icon (e.g. an app that isn't installed).
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppRadius.icon);
    final bytes = iconBytes;
    final child = bytes != null || packageName.isEmpty
        ? _icon(context, radius, bytes)
        : ValueListenableBuilder(
            valueListenable: deviceAppIcons,
            builder: (context, icons, _) =>
                _icon(context, radius, icons[packageName]),
          );
    return dimmed ? Opacity(opacity: 0.4, child: child) : child;
  }

  Widget _icon(BuildContext context, BorderRadius radius, Uint8List? bytes) {
    final fallback = _letterOrBadge(context, radius);
    if (bytes == null || bytes.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: radius,
      child: Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }

  Widget _letterOrBadge(BuildContext context, BorderRadius radius) {
    final name = appName.trim();
    final initial = name.isEmpty ? '' : name[0].toUpperCase();
    // A cased letter (Latin, Greek, Cyrillic…). ponytail: uncased scripts
    // (CJK, Arabic) get the badge; draw them too if such names show up.
    if (initial == initial.toLowerCase()) {
      return IconBadge(size: size, icon: Icons.smartphone_rounded);
    }
    final t = context.tokens;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: t.control, borderRadius: radius),
      // Decorative, like the icon it stands in for: the row says the name.
      child: ExcludeSemantics(
        child: Text(
          initial,
          style: AppTypography.labelStrong.copyWith(
            color: t.ink2,
            // 15 on the 34 row avatar.
            fontSize: size * 0.44,
            height: 1,
          ),
        ),
      ),
    );
  }
}
