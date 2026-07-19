import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Screen 2 hero: the apps you already use (real app-pack icons) ring a rising
/// "reel" card that a shield sweeps away — the in-the-moment catch, built
/// entirely from design-system primitives. No new assets.
///
/// Under reduce-motion it settles to the protected end-state (card at rest with
/// the shield sealed over it) so the meaning survives without motion.
class CaughtHero extends StatelessWidget {
  const CaughtHero({required this.accent, super.key});

  final Color accent;

  static const _icons = <String>[
    'assets/images/social_icon_pack/instagram.png',
    'assets/images/social_icon_pack/youtube_google.png',
    'assets/images/social_icon_pack/snapchat.png',
    'assets/images/social_icon_pack/whatsapp.png',
  ];
  static const _alignments = <Alignment>[
    Alignment(-0.95, -0.85),
    Alignment(0.95, -0.85),
    Alignment(-0.95, 0.85),
    Alignment(0.95, 0.85),
  ];

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return SizedBox(
      height: 220,
      width: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < _icons.length; i++)
            Align(alignment: _alignments[i], child: _appIcon(_icons[i], i, reduceMotion)),
          if (reduceMotion) _shield(sealed: true) else _animatedCatch(),
        ],
      ),
    );
  }

  Widget _appIcon(String path, int i, bool reduceMotion) {
    final tile = ClipRRect(
      borderRadius: AppRadius.brMd,
      child: Image.asset(path, width: 46, height: 46, fit: BoxFit.cover),
    );
    if (reduceMotion) return tile;
    // Calm, staggered bob so the ring feels alive without pulling focus.
    return tile
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .move(
          begin: Offset.zero,
          end: const Offset(0, -6),
          duration: (2200 + i * 200).ms,
          curve: AppCurves.gentle,
        );
  }

  Widget _animatedCatch() {
    // The reel card rises from the feed, holds, then the shield sweeps it off.
    final card = _reelCard()
        .animate(onPlay: (c) => c.repeat())
        .slideY(begin: 0.6, end: 0, duration: 700.ms, curve: AppCurves.standard)
        .fadeIn(duration: 400.ms)
        .then(delay: 500.ms)
        .slideX(end: 1.6, duration: 500.ms, curve: Curves.easeInBack)
        .fadeOut(duration: 500.ms);

    final shield = _shield(sealed: false)
        .animate(onPlay: (c) => c.repeat())
        .fadeIn(delay: 1150.ms, duration: 180.ms)
        .scaleXY(begin: 0.5, end: 1, delay: 1150.ms, duration: 320.ms, curve: AppCurves.emphasized)
        .then(delay: 250.ms)
        .fadeOut(duration: 350.ms);

    return Stack(alignment: Alignment.center, children: [card, shield]);
  }

  Widget _reelCard() {
    return GlassContainer(
      enableBlur: false,
      borderRadius: AppRadius.lg,
      tintTop: accent.withValues(alpha: 0.18),
      tintBottom: accent.withValues(alpha: 0.05),
      child: SizedBox(
        width: 96,
        height: 120,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_circle_fill, size: 40, color: accent),
            const SizedBox(height: AppSpacing.xs),
            Text('Reels', style: TextStyle(color: accent, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _shield({required bool sealed}) => IconBadge(
        icon: Icons.shield_rounded,
        size: sealed ? 72 : 64,
        color: accent,
        bordered: true,
        fillAlpha: 0.22,
        semanticLabel: 'Reel blocked',
      );
}
