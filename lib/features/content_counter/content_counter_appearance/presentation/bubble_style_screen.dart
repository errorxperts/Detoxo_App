import 'dart:async';

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/content_counter/content_counter_appearance/presentation/widgets/stage_carousel.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/domain/bubble_model.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/domain/entities/bubble_style.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_preview.dart';
import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_appearance.dart';
import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_style_enums.dart';
import 'package:detoxo/features/content_counter/content_counter_core/presentation/content_counter_cubit.dart';
import 'package:detoxo/features/content_counter/content_counter_core/presentation/counter_appearance_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The floating-bubble picker: swipe the stage (or tap the rail) through the
/// styles, scrub the preview count, and tune size and opacity; the stage and
/// (if the bubble is on screen) the real overlay update as you go. Reads the
/// app-wide `CounterAppearanceCubit` (shared with the Appearance hub). Each
/// section rebuilds only for what it shows.
class BubbleStyleScreen extends StatelessWidget {
  const BubbleStyleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // GlassScaffold applies the SafeArea itself.
    return const GlassScaffold(
      appBar: GlassAppBar(title: Text('Bubble style')),
      body: _Body(),
    );
  }
}

/// Stage page order = rail order = the enum's.
const _variants = BubbleVariant.values;

/// The stage's height: the largest bubble with its pill, `sizeMax · (1 + 60 /
/// 68)` = 150.6 (`BubblePreview.height`), rounded up.
const _stageHeight = 152.0;

/// The stage preview's width: the widest timer at the largest size
/// (`BubblePreview` documents the bound).
const _previewWidth = 220.0;

/// The style being edited.
BubbleStyle _style(BuildContext context) =>
    context.select((CounterAppearanceCubit c) => c.state.bubble);

void _setStyle(BuildContext context, BubbleStyle style) =>
    context.read<CounterAppearanceCubit>().setBubble(style);

class _Body extends StatefulWidget {
  const _Body();

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  late final PageController _pages;

  /// The previews' reel count. It scrubs across the usage range so the tier
  /// colours read even before anything is watched today.
  late final ValueNotifier<int> _count;

  /// One per style, so Replay appear reaches the centred stage page.
  final _previews = {
    for (final v in _variants) v: GlobalKey<BubblePreviewState>(),
  };

  /// True while a rail tap drives the stage: the pages it flies past are
  /// neither selected nor ticked (the tap selected its target).
  var _flying = false;

  @override
  void initState() {
    super.initState();
    // Seed from the live count once; the slider owns the figure from here.
    final today = context.read<ContentCounterCubit>().state.today;
    _count = ValueNotifier(today > 0 ? today : 137);
    _pages = PageController(
      viewportFraction: 0.86,
      initialPage: context
          .read<CounterAppearanceCubit>()
          .state
          .bubble
          .variant
          .index,
    );
  }

  @override
  void dispose() {
    _pages.dispose();
    _count.dispose();
    super.dispose();
  }

  void _select(BubbleVariant v) {
    final style = context.read<CounterAppearanceCubit>().state.bubble;
    if (style.variant != v) _setStyle(context, style.copyWith(variant: v));
  }

  /// A swipe selects the page it settles on.
  void _onPageChanged(int i) {
    if (_flying) return;
    AppHaptics.selection();
    _select(_variants[i]);
  }

  /// A rail tap (or a tap on a side page) selects its style at once, then
  /// flies the stage there.
  Future<void> _goTo(int i) async {
    if (!_pages.hasClients) return;
    _select(_variants[i]);
    _flying = true;
    final flight = context.motion(const Duration(milliseconds: 380));
    try {
      if (flight == Duration.zero) {
        _pages.jumpToPage(i);
      } else {
        await _pages.animateToPage(
          i,
          duration: flight,
          curve: Curves.easeOutCubic,
        );
      }
    } finally {
      _flying = false;
      // A drag that interrupted the flight decides where it ended.
      final page = mounted && _pages.positions.length == 1
          ? _pages.page?.round()
          : null;
      if (page != null) _select(_variants[page]);
    }
  }

  /// Follows a style set elsewhere (the cubit's first load).
  void _follow(BubbleVariant v) {
    if (_flying || _pages.positions.length != 1) return;
    if (_pages.page?.round() != v.index) _pages.jumpToPage(v.index);
  }

  void _replay() {
    final v = context.read<CounterAppearanceCubit>().state.bubble.variant;
    _previews[v]!.currentState?.replayAppear();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CounterAppearanceCubit, CounterAppearance>(
      listenWhen: (a, b) => a.bubble.variant != b.bubble.variant,
      listener: (_, s) => _follow(s.bubble.variant),
      // The stage and the rail run edge to edge and inset themselves; the
      // rest sits in the gutter.
      child: ListView(
        padding: EdgeInsets.only(
          top: AppSpacing.md,
          bottom: AppSpacing.xxl + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          _Stage(
            controller: _pages,
            previews: _previews,
            count: _count,
            onPageChanged: _onPageChanged,
            onPick: (i) => unawaited(_goTo(i)),
          ),
          const SizedBox(height: AppSpacing.xs),
          // One list child each: grouped, their semantics would merge.
          Padding(
            padding: AppInsets.screen,
            child: _Caption(count: _count),
          ),
          Padding(
            padding: AppInsets.screen,
            child: _CountRow(count: _count, onReplay: _replay),
          ),
          const Padding(
            padding: AppInsets.screen,
            child: SectionHeader('Style'),
          ),
          _Rail(count: _count, onPick: (i) => unawaited(_goTo(i))),
          const Padding(padding: AppInsets.screen, child: _Customize()),
        ],
      ),
    );
  }
}

/// Every style on its board stage, in a pager whose glass lines up with the
/// page gutter and whose neighbours peek in at the screen edge. Only the
/// centred page animates and takes taps; a side page is a way to it.
class _Stage extends StatelessWidget {
  const _Stage({
    required this.controller,
    required this.previews,
    required this.count,
    required this.onPageChanged,
    required this.onPick,
  });

  final PageController controller;
  final Map<BubbleVariant, GlobalKey<BubblePreviewState>> previews;
  final ValueListenable<int> count;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final style = _style(context);
    final watch = context.select((ContentCounterCubit c) => c.state.timeToday);
    final stage = SizedBox(
      height: _stageHeight,
      child: LayoutBuilder(
        builder: (context, box) {
          // The glass spans gutter to gutter ([StageSurface] insets it `xxs`
          // in its page), so the pager is widened past the screen until that
          // page is its `viewportFraction`; a neighbour's glass then starts
          // `gutter - 2 · xxs` (12) before the screen edge.
          final glass = box.maxWidth - 2 * AppSpacing.gutter;
          final pager =
              (glass + 2 * AppSpacing.xxs) / controller.viewportFraction;
          return OverflowBox(
            minWidth: pager,
            maxWidth: pager,
            child: ValueListenableBuilder(
              valueListenable: count,
              builder: (context, n, _) => PageView.builder(
                controller: controller,
                onPageChanged: onPageChanged,
                itemCount: _variants.length,
                itemBuilder: (context, i) {
                  final v = _variants[i];
                  return StagePage(
                    controller: controller,
                    index: i,
                    // A side page shrinks 10 % (`StagePage`), its glass edge
                    // moving 5 % of the glass outward; this pulls it back.
                    peek: 0.05 * glass,
                    child: _StageCard(
                      preview: BubblePreview(
                        key: previews[v],
                        style: style.copyWith(variant: v),
                        count: n,
                        watch: watch,
                        area: _previewWidth,
                        height: _stageHeight,
                        interactive: true,
                        animate: v == style.variant,
                      ),
                      centred: v == style.variant,
                      onPick: () => onPick(i),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
    final entrance = context.motion(AppDurations.normal);
    if (entrance == Duration.zero) return stage;
    return stage
        .animate()
        .fadeIn(duration: entrance, curve: AppCurves.decelerate)
        .scaleXY(
          begin: 0.94,
          end: 1,
          duration: entrance,
          curve: AppCurves.standard,
        );
  }
}

/// One style's stage: the shared glass surface, the hint, and the [preview]
/// docked right.
class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.preview,
    required this.centred,
    required this.onPick,
  });

  final Widget preview;
  final bool centred;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final card = StageSurface(
      child: Stack(
        children: [
          Positioned(
            left: 12,
            bottom: 12,
            child: Text(
              'Tap the bubble for the timer',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.tokens.ink2),
            ),
          ),
          Positioned.fill(
            child: Align(alignment: Alignment.centerRight, child: preview),
          ),
        ],
      ),
    );
    if (centred) return card;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPick,
      child: AbsorbPointer(child: card),
    );
  }
}

/// One centred line: the selected style's name, then what it says at the
/// preview count (the mascot's mood, else the reels to the next colour).
class _Caption extends StatelessWidget {
  const _Caption({required this.count});

  final ValueListenable<int> count;

  @override
  Widget build(BuildContext context) {
    final variant = context.select(
      (CounterAppearanceCubit c) => c.state.bubble.variant,
    );
    final text = Theme.of(context).textTheme.bodyMedium;
    return ValueListenableBuilder(
      valueListenable: count,
      builder: (context, n, _) {
        final line = variant == BubbleVariant.mascot
            ? BubbleModel.mascotLine(BubbleModel.tier(n))
            : BubbleModel.nextLine(n);
        return AnimatedSwitcher(
          duration: context.motion(const Duration(milliseconds: 220)),
          child: Text.rich(
            // A new style cross-fades; a new count swaps in place.
            key: ValueKey(variant),
            TextSpan(
              children: [
                TextSpan(
                  text: variant.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: ' · $line',
                  style: TextStyle(color: context.tokens.ink2),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: text,
          ),
        );
      },
    );
  }
}

/// The preview count on one row: its value, the slider, and Replay appear.
class _CountRow extends StatelessWidget {
  const _CountRow({required this.count, required this.onReplay});

  final ValueNotifier<int> count;
  final VoidCallback onReplay;

  static String _reels(double v) => '${v.round()} reels';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: context.tokens.ink2,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return ValueListenableBuilder(
      valueListenable: count,
      builder: (context, n, _) => Row(
        children: [
          // Wide enough for "500 reels", so the slider never shifts; the
          // slider announces it.
          SizedBox(
            width: MediaQuery.textScalerOf(context).scale(64),
            child: ExcludeSemantics(
              child: Text(_reels(n.toDouble()), style: text),
            ),
          ),
          Expanded(
            child: Semantics(
              label: 'Preview count',
              child: Slider(
                value: n.toDouble(),
                max: 500,
                divisions: 50,
                semanticFormatterCallback: _reels,
                onChanged: (v) => count.value = v.round(),
              ),
            ),
          ),
          IconButton(
            onPressed: onReplay,
            tooltip: 'Replay appear',
            color: context.tokens.ink2,
            icon: const Icon(Icons.replay),
          ),
        ],
      ),
    );
  }
}

/// The styles as static thumbnails at the preview count; the selected card's
/// ring and glow animate (`VariantCarousel`).
class _Rail extends StatelessWidget {
  const _Rail({required this.count, required this.onPick});

  final ValueListenable<int> count;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final style = _style(context);
    return ValueListenableBuilder(
      valueListenable: count,
      builder: (context, n, _) => VariantCarousel(
        height: 96,
        cardWidth: 84,
        inset: AppSpacing.gutter,
        options: [
          for (final (i, v) in _variants.indexed)
            VariantOption(
              label: v.label,
              selected: v == style.variant,
              onTap: () => onPick(i),
              preview: RailThumb(
                index: i,
                selected: v == style.variant,
                child: BubblePreview(
                  style: style.copyWith(variant: v),
                  count: n,
                  area: 88,
                  animate: false,
                  // The card reads its label and selected state.
                  excludeFromSemantics: true,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Size and opacity: one panel of two slider rows.
class _Customize extends StatelessWidget {
  const _Customize();

  @override
  Widget build(BuildContext context) {
    final style = _style(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Customize'),
        PanelGroup(
          children: [
            _SliderRow(
              label: 'Size',
              value: style.size,
              min: BubbleStyle.sizeMin,
              max: BubbleStyle.sizeMax,
              divisions: 8,
              format: (v) => '${v.round()} dp',
              onChanged: (v) => _setStyle(context, style.copyWith(size: v)),
            ),
            _SliderRow(
              label: 'Opacity',
              value: style.opacity,
              min: BubbleStyle.opacityMin,
              max: BubbleStyle.opacityMax,
              divisions: 5,
              format: _percent,
              onChanged: (v) => _setStyle(context, style.copyWith(opacity: v)),
            ),
          ],
        ),
      ],
    );
  }
}

String _percent(double v) => '${(v * 100).round()}%';

/// A flat panel row: the label in label / ink and its value in subhead /
/// ink-2 over a themed [Slider]. [format] renders the value both for the
/// visible label and for screen readers, so they agree.
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.format,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double value) format;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xxs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.label.copyWith(color: t.ink),
                ),
              ),
              Text(
                format(value),
                style: AppTypography.subhead.copyWith(color: t.ink2),
              ),
            ],
          ),
          Semantics(
            label: label,
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              semanticFormatterCallback: format,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
