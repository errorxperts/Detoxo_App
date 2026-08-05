import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// A tall spatial-glass tile for the dashboard's blocker pair (App Blocker /
/// Web Blocker).
///
/// Three layers over a [LiquidGlassBorder]-edged surface: an oversized
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
    this.levitateDelay = Duration.zero,
    super.key,
  });

  /// Illustration asset path, used for both the watermark and the capsule.
  final String image;
  final String title;

  /// Live status line, rendered uppercase (e.g. `3 apps blocked`).
  final String caption;

  /// Whether the blocker actually has entries — pulses the status dot and
  /// lifts the caption to the accent colour.
  final bool active;
  final VoidCallback onTap;
  final Color? accent;

  /// Offsets the capsule's levitation so a row of tiles doesn't bob in unison.
  final Duration levitateDelay;

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
              Positioned(
                top: 0,
                right: 0,
                child: _Capsule(image: image, delay: levitateDelay),
              ),
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
                        StatusDot(
                          color: active ? c : scheme.onSurfaceVariant,
                          size: 8,
                          pulsing: active,
                        ),
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

/// The floating glass disc in the tile's top-right corner. Levitates unless the
/// user has asked for reduced motion.
class _Capsule extends StatelessWidget {
  const _Capsule({required this.image, required this.delay});

  final String image;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final disc = Transform.scale(
      scale: 1,
      child: SizedBox(
        height: 80,
        child: Image.asset(image, cacheWidth: BlockerTile._capsuleCacheWidth),
      ),
    );

    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return disc;
    return disc
        .animate(delay: delay, onPlay: (c) => c.repeat(reverse: true))
        .moveY(begin: 0, end: -6, duration: 3.seconds, curve: AppCurves.gentle);
  }
}
