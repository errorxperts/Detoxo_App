import 'dart:async';

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';
import 'package:detoxo/features/content_counter/content_counter_appearance/presentation/widgets/bubble_preview.dart';
import 'package:detoxo/features/content_counter/content_counter_appearance/presentation/widgets/variant_carousel.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/domain/entities/bubble_style.dart';
import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_appearance.dart';
import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_style_enums.dart';
import 'package:detoxo/features/content_counter/content_counter_core/domain/repositories/content_counter_repository.dart';
import 'package:detoxo/features/content_counter/content_counter_core/domain/repositories/counter_appearance_repository.dart';
import 'package:detoxo/features/content_counter/content_counter_core/presentation/counter_appearance_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Live-preview customization for the floating counter bubble: pick a variant,
/// then tune size / text / spacing / opacity — the pinned preview and (if the
/// bubble is on screen) the real overlay update as you go.
class BubbleStyleScreen extends StatelessWidget {
  const BubbleStyleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CounterAppearanceCubit(sl<CounterAppearanceRepository>()),
      child: const GlassScaffold(
        appBar: GlassAppBar(title: Text('Bubble style')),
        body: SafeArea(child: _Body()),
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body();

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  // The preview scrubs across the usage range so the color/emoji variants are
  // legible even before the user has watched anything today.
  double _previewCount = 137;

  @override
  void initState() {
    super.initState();
    unawaited(_loadToday());
  }

  Future<void> _loadToday() async {
    final count = await sl<ContentCounterRepository>().current();
    if (!mounted || count.today <= 0) return;
    setState(() => _previewCount = count.today.toDouble());
  }

  void _setStyle(BubbleStyle style) =>
      context.read<CounterAppearanceCubit>().setBubble(style);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CounterAppearanceCubit, CounterAppearance>(
      builder: (context, appearance) {
        final style = appearance.bubble;
        final count = _previewCount.round();
        return ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md + MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
            _PreviewStage(style: style, count: count),
            const SizedBox(height: AppSpacing.sm),
            _LabeledSlider(
              label: 'Preview count',
              value: _previewCount,
              min: 0,
              max: 500,
              divisions: 10,
              valueLabel: '$count reels',
              onChanged: (v) => setState(() => _previewCount = v),
            ),
            const SizedBox(height: AppSpacing.md),
            const SectionHeader('Style'),
            VariantCarousel(
              options: [
                for (final v in BubbleVariant.values)
                  VariantOption(
                    label: _variantLabel(v),
                    selected: style.variant == v,
                    onTap: () => _setStyle(style.copyWith(variant: v)),
                    preview: BubblePreview(
                      style: style.copyWith(variant: v),
                      count: count,
                      area: 64,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const SectionHeader('Customize'),
            _LabeledSlider(
              label: 'Size',
              value: style.size,
              min: BubbleStyle.sizeMin,
              max: BubbleStyle.sizeMax,
              divisions: 8,
              valueLabel: '${style.size.round()} dp',
              onChanged: (v) => _setStyle(style.copyWith(size: v)),
            ),
            _LabeledSlider(
              label: 'Text size',
              value: style.textScale,
              min: BubbleStyle.textScaleMin,
              max: BubbleStyle.textScaleMax,
              divisions: 6,
              valueLabel: '${(style.textScale * 100).round()}%',
              onChanged: (v) => _setStyle(style.copyWith(textScale: v)),
            ),
            if (style.variant == BubbleVariant.minimalPill)
              _LabeledSlider(
                label: 'Spacing',
                value: style.spacing,
                min: BubbleStyle.spacingMin,
                max: BubbleStyle.spacingMax,
                divisions: 5,
                valueLabel: '${(style.spacing * 100).round()}%',
                onChanged: (v) => _setStyle(style.copyWith(spacing: v)),
              ),
            _LabeledSlider(
              label: 'Opacity',
              value: style.opacity,
              min: BubbleStyle.opacityMin,
              max: BubbleStyle.opacityMax,
              divisions: 5,
              valueLabel: '${(style.opacity * 100).round()}%',
              onChanged: (v) => _setStyle(style.copyWith(opacity: v)),
            ),
            const SizedBox(height: AppSpacing.xs),
            AdaptiveSwitchTile(
              leading: const IconBadge(icon: Icons.short_text_rounded),
              title: 'Show caption',
              subtitle: 'A tiny “reels” label under the count',
              value: style.showLabel,
              onChanged: (v) => _setStyle(style.copyWith(showLabel: v)),
            ),
          ],
        );
      },
    );
  }
}

class _PreviewStage extends StatelessWidget {
  const _PreviewStage({required this.style, required this.count});

  final BubbleStyle style;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 168,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.glass.fillTop,
            context.glass.fillBottom,
          ],
        ),
        border: Border.all(color: context.glass.border),
      ),
      child: BubblePreview(style: style, count: count),
    );
  }
}

String _variantLabel(BubbleVariant v) => switch (v) {
  BubbleVariant.glassOrb => 'Glass orb',
  BubbleVariant.usageRing => 'Usage ring',
  BubbleVariant.emojiMood => 'Emoji mood',
  BubbleVariant.minimalPill => 'Minimal pill',
};

/// A compact title + value row over an [AdaptiveSlider].
class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                valueLabel,
                style: text.bodySmall?.copyWith(color: context.glass.onGlassMuted),
              ),
            ],
          ),
          AdaptiveSlider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
