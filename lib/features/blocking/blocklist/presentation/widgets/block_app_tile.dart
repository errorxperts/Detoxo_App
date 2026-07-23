import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/block_target.dart';
import 'package:flutter/material.dart';

/// One app's blockable surfaces, grouped from the flat target list so the
/// blocklist renders a single compact tile per app instead of a long flat list
/// (Instagram's Feed / Reels / Stories collapse under one "Instagram" tile).
class BlockAppGroup {
  BlockAppGroup(this.surfaces) : assert(surfaces.isNotEmpty, 'needs a surface');

  final List<BlockTarget> surfaces;

  BlockTarget get _head => surfaces.first;
  String get appName => _head.appName;
  String get iconUrl => _head.iconUrl;
  bool get isInstalled => _head.isInstalled;
  bool get isSingle => surfaces.length == 1;

  /// Groups targets by app package, preserving the incoming (already installed-
  /// first, alphabetical) order from the repository.
  static List<BlockAppGroup> from(List<BlockTarget> targets) {
    final byApp = <String, List<BlockTarget>>{};
    for (final t in targets) {
      (byApp[t.packageName] ??= <BlockTarget>[]).add(t);
    }
    return [for (final surfaces in byApp.values) BlockAppGroup(surfaces)];
  }
}

/// Compact, expandable tile for one app. A single-surface app renders as a plain
/// switch row; a multi-surface app collapses to a summary header (app + "N of M
/// blocked") that expands to reveal one switch per surface. Uninstalled apps are
/// dimmed, read-only and non-expandable.
class BlockAppTile extends StatefulWidget {
  const BlockAppTile({
    required this.group,
    required this.enabledIds,
    required this.onToggle,
    super.key,
  });

  final BlockAppGroup group;
  final Set<String> enabledIds;
  final void Function(String platformId, {required bool enabled}) onToggle;

  @override
  State<BlockAppTile> createState() => _BlockAppTileState();
}

class _BlockAppTileState extends State<BlockAppTile> {
  bool _expanded = false;

  int get _enabledCount => widget.group.surfaces
      .where((t) => widget.enabledIds.contains(t.platformId))
      .length;

  bool _isOn(BlockTarget t) =>
      widget.group.isInstalled && widget.enabledIds.contains(t.platformId);

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final installed = group.isInstalled;

    // Single surface → a plain switch row; nothing to expand.
    if (group.isSingle) {
      final t = group.surfaces.first;
      return _padded(
        AdaptiveSwitchTile(
          leading: AppIconAvatar(
            iconUrl: group.iconUrl,
            appName: group.appName,
            dimmed: !installed,
          ),
          title: t.displayName,
          subtitle: installed ? t.appName : 'Not installed',
          enabled: installed,
          value: _isOn(t),
          selected: _isOn(t),
          onChanged:
              installed ? (v) => widget.onToggle(t.platformId, enabled: v) : null,
        ),
      );
    }

    return _padded(
      GlassContainer(
        enableBlur: false,
        selected: installed && _enabledCount > 0,
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(context, installed),
            // Only installed apps expand (uninstalled switches would be inert).
            AnimatedSize(
              duration: AppDurations.normal,
              curve: AppCurves.standard,
              alignment: Alignment.topCenter,
              child: _expanded && installed
                  ? _body(context)
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  Widget _padded(Widget child) =>
      Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: child);

  Widget _header(BuildContext context, bool installed) {
    final text = Theme.of(context).textTheme;
    final total = widget.group.surfaces.length;
    final on = _enabledCount;
    final highlight = installed && on > 0;
    final subtitle = !installed
        ? 'Not installed'
        : on == 0
            ? 'Tap to choose what to block'
            : '$on of $total blocked';

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          AppIconAvatar(
            iconUrl: widget.group.iconUrl,
            appName: widget.group.appName,
            dimmed: !installed,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.group.appName,
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: text.bodySmall?.copyWith(
                    color: highlight
                        ? Theme.of(context).colorScheme.secondary
                        : context.glass.onGlassMuted,
                  ),
                ),
              ],
            ),
          ),
          if (installed) ...[
            const SizedBox(width: AppSpacing.sm),
            AnimatedRotation(
              turns: _expanded ? 0.5 : 0,
              duration: AppDurations.fast,
              curve: AppCurves.standard,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: context.glass.onGlassMuted,
              ),
            ),
          ],
        ],
      ),
    );

    if (!installed) return row;
    return AppPressable(
      pressedScale: 0.99,
      onTap: () => setState(() => _expanded = !_expanded),
      child: row,
    );
  }

  Widget _body(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(height: 1, thickness: 1, color: context.glass.border),
        for (final t in widget.group.surfaces)
          Padding(
            // Indent past the avatar so surfaces read as children of the app.
            padding: const EdgeInsets.fromLTRB(56, 6, 14, 6),
            child: Row(
              children: [
                Expanded(child: Text(t.displayName, style: text.bodyMedium)),
                const SizedBox(width: AppSpacing.sm),
                AdaptiveSwitch(
                  value: widget.enabledIds.contains(t.platformId),
                  onChanged: (v) => widget.onToggle(t.platformId, enabled: v),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
      ],
    );
  }
}
