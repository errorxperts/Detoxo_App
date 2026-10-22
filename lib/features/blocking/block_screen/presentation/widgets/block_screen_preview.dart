import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/blocking/block_screen/domain/entities/block_screen_copy.dart';
import 'package:detoxo/features/blocking/block_screen/domain/entities/block_screen_payload.dart';
import 'package:detoxo/features/blocking/block_screen/domain/entities/block_screen_style.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';

/// Flutter mirror of the native block screen (`overlay/QuoteWall.kt` and the
/// button column in `overlay/BlockScreenRenderer.kt` — the declared source of
/// truth): one Frozen Glass layout in both themes, from the same generated
/// tokens and the live accent (`context.accent`, which the wall's
/// `AccentResolver.forWall` reads from the same inputs). Drawn on a fixed
/// board in native dp — 360 × 780, or the Appearance card's 352 × 220 crop
/// when [compact] (header, quote, button row) — that a [FittedBox] scales to
/// [height], so every size is the native one, as is.
///
/// MIRROR CONTRACT: copy from [BlockScreenCopy], the icon from [_heroIcon];
/// only the layout lives here.
class BlockScreenPreview extends StatelessWidget {
  const BlockScreenPreview({
    required this.style,
    this.payload,
    this.height = 300,
    this.compact = false,
    super.key,
  });

  final BlockScreenStyle style;
  final BlockScreenPayload? payload;
  final double height;
  final bool compact;

  static const _board = Size(360, 780);
  static const _compactBoard = Size(352, 220);

  @override
  Widget build(BuildContext context) {
    final p = (payload ?? BlockScreenPayload.preview()).sanitised();
    final t = context.tokens;
    final copy = BlockScreenCopy.from(p, style);
    final board = compact ? _compactBoard : _board;
    final off = !style.enabled;

    final wall = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: AppRadius.brLg,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.bgTop, t.bgBottom],
        ),
      ),
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: t.hairline),
        borderRadius: AppRadius.brLg,
      ),
      child: FittedBox(
        child: SizedBox.fromSize(
          size: board,
          // A picture of the wall: nothing in it takes a tap or focus, and
          // the reader's text size is already in the scale.
          child: IgnorePointer(
            child: ExcludeFocus(
              child: MediaQuery.withNoTextScaling(
                child: compact
                    ? _CompactWall(copy: copy)
                    : _Wall(copy: copy, icon: _heroIcon(p)),
              ),
            ),
          ),
        ),
      ),
    );
    final ease = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppDurations.normal;
    return Semantics(
      label:
          'Block screen preview${off ? ', off' : ''}. ${copy.semanticsLabel}',
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        width: height * board.aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Switched off, the wall eases to a faded grey. The filter is
            // always there (identity while on): adding it only when off would
            // rebuild the wall under it, replaying the quote's fade-up.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: off ? 1 : 0, end: off ? 1 : 0),
              duration: ease,
              curve: AppCurves.standard,
              builder: (_, t, child) => ColorFiltered(
                colorFilter: ColorFilter.matrix(_offMatrix(t)),
                child: child,
              ),
              child: wall,
            ),
            Positioned(
              top: AppSpacing.xs,
              right: AppSpacing.xs,
              child: AnimatedSwitcher(
                duration: ease,
                child: off
                    ? const AppBadge.label('Off')
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Identity at [t] 0; at 1, greyscale (Rec. 709 luma) at 60 % alpha — the
/// switched-off wall.
List<double> _offMatrix(double t) {
  const r = 0.2126;
  const g = 0.7152;
  const b = 0.0722;
  final k = 1 - t;
  return [
    k + t * r, t * g, t * b, 0, 0, //
    t * r, k + t * g, t * b, 0, 0,
    t * r, t * g, k + t * b, 0, 0,
    0, 0, 0, 1 - 0.4 * t, 0,
  ];
}

/// The reason's 3D icon (MIRROR: `heroIconFor` in `overlay/FrozenGlass.kt`):
/// a plan block shows its mode — an N-reel unblock is a break, so Pause —
/// the other reasons their feature.
({AssetGenImage asset, bool mode}) _heroIcon(BlockScreenPayload p) {
  final icons = Assets.images.icons;
  return switch (p.blockReason) {
    BlockReason.appBlock => (asset: icons.iconAppBlocker, mode: false),
    BlockReason.webRule ||
    BlockReason.adult => (asset: icons.iconWebBlocker, mode: false),
    BlockReason.schedule ||
    BlockReason.dailyLimit => (asset: icons.iconBlockerRules, mode: false),
    BlockReason.plan => (
      asset: switch (p.plan) {
        BlockingPlan.curious => icons.iconConscious,
        BlockingPlan.oneReel =>
          p.allowance <= 1 ? icons.iconOneReel : icons.iconPause,
        _ => icons.iconBlockAll,
      },
      mode: true,
    ),
  };
}

/// The canvas's own sample — sr 46 of `assets/content/motivational_quotes.json`.
/// The real wall draws one of the hundred at random, natively
/// (`overlay/QuoteBook.kt`).
const _quote = (
  text: 'Do not let the behavior of others destroy your inner peace.',
  writer: 'Dalai Lama',
);

/// sr 62: the Appearance card's two lines hold only a short quote.
const _shortQuote = 'Lost time is never found again.';

/// The full wall (MIRROR CONTRACT: `QuoteWallView`), top down at the 20 dp
/// gutter: the header, the icon well under the ambient light, the quote
/// panel, the line and the meta, the buttons at the foot. The quote and its
/// writer fade up once; nothing loops.
class _Wall extends StatelessWidget {
  const _Wall({required this.copy, required this.icon});

  final BlockScreenCopy copy;
  final ({AssetGenImage asset, bool mode}) icon;

  /// The ambient's reach (MIRROR: `AMBIENT_R`).
  static const _ambient = 120.0;
  static const _well = 88.0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final accent = context.accent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.headerTop,
        AppSpacing.gutter,
        AppSpacing.gutter,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header(),
          const SizedBox(height: 24),
          SizedBox.square(
            dimension: _well,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // The accent's static light, centred on the well and only
                // with it (MIRROR: the `ambient` paint).
                Positioned(
                  left: _well / 2 - _ambient,
                  top: _well / 2 - _ambient,
                  width: 2 * _ambient,
                  height: 2 * _ambient,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          accent.main.withValues(alpha: t.kAmb),
                          accent.main.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.3, -0.4),
                      radius: 0.955,
                      colors: [t.wellFrom, t.wellTo],
                    ),
                  ),
                  child: Center(
                    child: Icon3d(
                      icon.asset,
                      size: ConfirmSheet.iconSize,
                      accentTint: icon.mode,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GlassContainer(
            borderRadius: AppRadius.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FadeUp(
                  child: Text(
                    _quote.text,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.title.copyWith(color: t.ink),
                  ),
                ),
                const SizedBox(height: 12),
                _FadeUp(
                  delayMs: 300,
                  child: Text(
                    _quote.writer.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.eyebrow.copyWith(color: t.ink2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.card),
          Text(
            copy.line,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body.copyWith(color: t.ink2),
          ),
          if (copy.meta.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              copy.meta,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.subhead.copyWith(color: t.ink2),
            ),
          ],
          const Spacer(),
          _Buttons(copy: copy, compact: false),
        ],
      ),
    );
  }
}

/// The Appearance card's crop: the header, a two-line quote at headline size
/// on the panel (the wall's fit, with no room for the well or the writer),
/// and the button row.
class _CompactWall extends StatelessWidget {
  const _CompactWall({required this.copy});

  final BlockScreenCopy copy;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.gutter,
        AppSpacing.gutter,
        AppSpacing.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Header(),
          const SizedBox(height: 12),
          Expanded(
            child: GlassContainer(
              borderRadius: AppRadius.card,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.card,
                vertical: 12,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _shortQuote,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headline.copyWith(color: t.ink),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _Buttons(copy: copy, compact: true),
        ],
      ),
    );
  }
}

/// The logo with its glow beside the wordmark (MIRROR: the header in
/// `QuoteWallView`).
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const DetoxoLogo(height: 44),
      const SizedBox(width: 10),
      Text(
        'Detoxo',
        style: AppTypography.titleXl.copyWith(color: context.tokens.ink),
      ),
    ],
  );
}

/// The exits, top to bottom: [Home | Open Detoxo], then the text exits (the
/// full stage only), each in a 48-tall slot as the native views are. Home is
/// the glass circle, Open Detoxo the accent pill in the live accent.
class _Buttons extends StatelessWidget {
  const _Buttons({required this.copy, required this.compact});

  final BlockScreenCopy copy;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final texts = compact
        ? const <BlockScreenButton>[]
        : copy.buttons.where((b) => b.ghost).toList();
    void none() {}
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (final b in copy.buttons)
              if (b.icon)
                GlassIconButton(
                  icon: const Icon(Icons.home_rounded, size: 20),
                  semanticLabel: b.label,
                  onPressed: none,
                )
              else if (b.primary) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: LiquidPill(
                    tint: context.accent.main,
                    onPressed: none,
                    expand: true,
                    child: Text(
                      b.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
          ],
        ),
        if (texts.isNotEmpty) const SizedBox(height: 6),
        for (final b in texts)
          SizedBox(
            height: AppSizes.minTapTarget,
            width: double.infinity,
            child: Center(
              // A locked way back (its countdown running) is dimmed like the
              // real one.
              child: Opacity(
                opacity: b.locked ? 0.55 : 1,
                child: Text(
                  b.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label.copyWith(color: t.ink2),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The quote fades up 10 dp over 1.2 s; its writer follows [delayMs] later.
/// Once, on the full stage; drawn as is under Reduce Motion.
class _FadeUp extends StatelessWidget {
  const _FadeUp({required this.child, this.delayMs = 0});

  final Widget child;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    final total = context.motion(Duration(milliseconds: 1200 + delayMs));
    if (total == Duration.zero) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(delayMs / total.inMilliseconds, 1, curve: Curves.ease),
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 10 * (1 - v)), child: c),
      ),
      child: child,
    );
  }
}
