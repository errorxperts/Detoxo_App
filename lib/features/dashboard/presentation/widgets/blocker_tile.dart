import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// A tall spatial-glass tile for the dashboard's blocker pair (App Blocker /
/// Web Blocker).
///
/// Three layers over a tile surface: an oversized
/// illustration bleeding off the left edge as a translucent watermark, a
/// levitating glass capsule holding the same artwork top-right, and the
/// title + live status caption anchored bottom-left.
class BlockerTile extends StatelessWidget {
  const BlockerTile({
    required this.image,
    required this.title,
    required this.caption,
    required this.active,
    required this.onTap,
    this.accent,
    super.key,
  });

  /// Illustration asset path, used for both the watermark and the capsule.
  final String image;
  final String title;

  /// Live status line, rendered uppercase (e.g. `3 apps blocked`).
  final String caption;

  /// Whether the blocker actually has entries — lifts the status dot and the
  /// caption to the accent colour.
  final bool active;
  final VoidCallback onTap;
  final Color? accent;

  /// Decoded width for the watermark. Without a cache hint every tile would pin
  /// the full-resolution bitmap for a decorative layer.
  static const int _watermarkCacheWidth = 400;

  /// The capsule disc is 80dp, so 240px covers a 3x screen exactly.
  static const int _capsuleCacheWidth = 240;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c = accent ?? scheme.primary;

    return AppPressable(
      onTap: onTap,
      semanticLabel: '$title, $caption',
      child: AspectRatio(
        aspectRatio: 4 / 4,
        child: GlassContainer(
          surface: DxSurface.tile,
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Stack(
            children: [
              // Oversized watermark, pushed left so it bleeds past the edge.
              Positioned.fill(
                child: Transform.translate(
                  offset: const Offset(-36, 0),
                  child: Transform.scale(
                    scale: 1.6,
                    child: Image.asset(
                      image,
                      cacheWidth: _watermarkCacheWidth,
                      opacity: AlwaysStoppedAnimation(dark ? 0.07 : 0.10),
                    ),
                  ),
                ),
              ),
              Positioned(top: 0, right: 0, child: _Capsule(image: image)),
              Align(
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StatusDot(color: active ? c : scheme.onSurfaceVariant),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            caption.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelSmall?.copyWith(
                              color: active ? c : scheme.onSurfaceVariant,
                              fontSize: 11,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The glass disc in the tile's top-right corner. Still: nothing loops.
class _Capsule extends StatelessWidget {
  const _Capsule({required this.image});

  final String image;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 80,
    child: Image.asset(image, cacheWidth: BlockerTile._capsuleCacheWidth),
  );
}
