import 'dart:async';

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/domain/repositories/bubble_repository.dart';
import 'package:detoxo/features/content_counter/content_counter_core/domain/repositories/content_counter_repository.dart';
import 'package:detoxo/features/content_counter/content_counter_core/presentation/content_counter_cubit.dart';
import 'package:detoxo/features/content_counter/content_counter_core/presentation/widgets/reel_counter_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Compact hub for the short-video counter: a live count-up card, the counting
/// and bubble toggles, and entries into the dedicated Bubble-style and Home-widget
/// appearance screens. Reached from the app drawer.
class ContentCounterScreen extends StatelessWidget {
  const ContentCounterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ContentCounterCubit(sl<ContentCounterRepository>()),
      child: const GlassScaffold(
        appBar: GlassAppBar(title: Text('Reel counter')),
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
  final ContentCounterRepository _counter = sl<ContentCounterRepository>();
  final BubbleRepository _bubble = sl<BubbleRepository>();

  bool _counterOn = true;
  bool _bubbleOn = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final c = await _counter.current();
    if (!mounted) return;
    setState(() {
      _counterOn = c.enabled;
      _bubbleOn = c.bubbleEnabled;
      _loaded = true;
    });
  }

  void _toggleCounter(bool on) {
    setState(() => _counterOn = on);
    unawaited(_counter.setEnabled(enabled: on));
  }

  void _toggleBubble(bool on) {
    setState(() => _bubbleOn = on);
    unawaited(_applyBubble(on));
  }

  Future<void> _applyBubble(bool on) async {
    await _bubble.setEnabled(enabled: on);
    if (on && !await _bubble.canShow()) {
      await _bubble.requestPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md + MediaQuery.viewPaddingOf(context).bottom,
      ),
      children: [
        const ReelCounterCard(),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader('Counting'),
        AdaptiveSwitchTile(
          leading: const IconBadge(icon: Icons.movie_filter_rounded),
          title: 'Count short videos',
          subtitle: 'Tally reels & shorts you watch across apps',
          value: _counterOn,
          onChanged: _loaded ? _toggleCounter : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        AdaptiveSwitchTile(
          leading: const IconBadge(icon: Icons.bubble_chart_rounded),
          title: 'Floating counter bubble',
          subtitle: 'Show a live count while you’re in a reel app',
          value: _bubbleOn,
          enabled: _counterOn,
          onChanged: (_loaded && _counterOn) ? _toggleBubble : null,
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader('Appearance'),
        FeatureTile(
          icon: Icons.bubble_chart_rounded,
          title: 'Bubble style',
          subtitle: 'Variant, size, colour & emoji reactions',
          onTap: () => unawaited(context.push(Routes.bubbleStyle)),
        ),
        FeatureTile(
          icon: Icons.widgets_rounded,
          title: 'Home widget',
          subtitle: 'Background, theme & size — add it to your home screen',
          onTap: () => unawaited(context.push(Routes.homeWidget)),
        ),
        const SizedBox(height: AppSpacing.md),
        const _HowItWorksHint(),
      ],
    );
  }
}

/// A plain, compact inline hint — deliberately NOT a glass card, since it isn't
/// interactive (keeps the hub light).
class _HowItWorksHint extends StatelessWidget {
  const _HowItWorksHint();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 18,
            color: context.glass.onGlassMuted,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'A video counts only after you’ve watched it for about 2 seconds '
              '— quick scrolls are ignored, so the number reflects what you '
              'actually watched.',
              style: text.bodySmall?.copyWith(color: context.glass.onGlassMuted),
            ),
          ),
        ],
      ),
    );
  }
}
