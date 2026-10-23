import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/block_target.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';

/// One app's blockable surfaces, grouped from the flat target list so the
/// blocklist renders a single compact tile per app instead of a long flat list
/// (Instagram's Feed / Reels / Stories collapse under one "Instagram" tile).
class BlockAppGroup {
  BlockAppGroup(this.surfaces) : assert(surfaces.isNotEmpty, 'needs a surface');

  final List<BlockTarget> surfaces;

  BlockTarget get _head => surfaces.first;
  String get appName => _head.appName;
  String get packageName => _head.packageName;
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

/// One app's row in a section panel. A single-surface app is a plain switch
/// row; a multi-surface app is a summary header (app + "N of M blocked") that
/// expands to one indented switch per surface. Uninstalled apps are dimmed,
/// read-only and don't expand. On a panel it draws no surface of its own:
/// stack tiles in a [PanelGroup].
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

  /// Where the row's title starts: the row inset, the 34 avatar and its gap.
  /// The surface rows indent to it so they read as children of the app.
  static const double _textInset = AppSpacing.md + 34 + AppSpacing.sm;

  bool _isOn(BlockTarget t) =>
      widget.group.isInstalled && widget.enabledIds.contains(t.platformId);

  /// Named per surface: a screen reader hears "Block Instagram Reels", not
  /// the same bare "switch" once per row.
  Widget _switch(BlockTarget t) => AppToggle(
    value: _isOn(t),
    enabled: widget.group.isInstalled,
    semanticLabel: 'Block ${t.displayName}',
    onChanged: (v) => widget.onToggle(t.platformId, enabled: v),
  );

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final installed = group.isInstalled;
    final avatar = AppIconAvatar(
      packageName: group.packageName,
      appName: group.appName,
      dimmed: !installed,
    );

    // Single surface → a plain switch row; nothing to expand.
    if (group.isSingle) {
      final t = group.surfaces.first;
      return GlassListTile(
        leading: avatar,
        title: t.displayName,
        subtitle: installed ? t.appName : 'Not installed',
        trailing: _switch(t),
      );
    }

    final on = group.surfaces.where(_isOn).length;
    final header = GlassListTile(
      leading: avatar,
      title: group.appName,
      subtitle: !installed
          ? 'Not installed'
          : on == 0
          ? 'Tap to choose what to block'
          : '$on of ${group.surfaces.length} blocked',
      // Only installed apps expand (uninstalled switches would be inert). The
      // spec chevron turns to point down while open.
      trailing: installed
          ? AnimatedRotation(
              turns: _expanded ? .25 : 0,
              duration: context.motion(AppDurations.fast),
              curve: AppCurves.standard,
              child: Glyph(
                Assets.svg.chevronRight,
                size: 18,
                color: context.tokens.ink3,
              ),
            )
          : null,
      onTap: installed ? () => setState(() => _expanded = !_expanded) : null,
    );
    final tile = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(expanded: installed ? _expanded : null, child: header),
        AnimatedSize(
          duration: context.motion(AppDurations.normal),
          curve: AppCurves.standard,
          alignment: Alignment.topCenter,
          child: _expanded && installed
              ? _surfaces(context)
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
    // Standalone, the header and its surfaces share one panel, as a
    // GlassListTile would make its own.
    if (GlassContainer.surfaceOf(context) != null) return tile;
    return GlassContainer(padding: EdgeInsets.zero, child: tile);
  }

  Widget _surfaces(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final t in widget.group.surfaces) ...[
        const Divider(height: 1, indent: _textInset, endIndent: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            _textInset,
            AppSpacing.xxs,
            AppSpacing.md,
            AppSpacing.xxs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t.displayName,
                  style: AppTypography.body.copyWith(color: context.tokens.ink),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _switch(t),
            ],
          ),
        ),
      ],
    ],
  );
}
