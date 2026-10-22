import 'dart:async';
import 'dart:math' as math;

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/features/content_counter/content_counter_appearance/presentation/home_widget_cubit.dart';
import 'package:detoxo/features/content_counter/content_counter_appearance/presentation/widgets/stage_carousel.dart';
import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_style_enums.dart';
import 'package:detoxo/features/content_counter/content_counter_core/presentation/counter_appearance_cubit.dart';
import 'package:detoxo/features/content_counter/home_content_counter/domain/entities/widget_payload.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/widget_geometry.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/widget_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The home-widget picker: swipe the stage (or tap the rail) through the seven
/// families, preview one at Small / Medium / Large in the widget theme, and
/// pin it. Family, size and the preview payload live in a screen-scoped
/// [HomeWidgetCubit]; the theme in the app-wide `CounterAppearanceCubit`
/// (shared with the Appearance hub), overlaid onto the payload here.
class HomeWidgetScreen extends StatelessWidget {
  const HomeWidgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeWidgetCubit(sl())..load(),
      // GlassScaffold applies the SafeArea itself.
      child: const GlassScaffold(
        appBar: GlassAppBar(title: Text('Home widget')),
        body: _Body(),
      ),
    );
  }
}

/// Stage page order = rail order = the enum's.
const _families = WidgetFamily.values;

/// Explicit control orders, decoupled from enum declaration order.
const _sizes = [WidgetSize.small, WidgetSize.medium, WidgetSize.large];
const _themes = [WidgetTheme.system, WidgetTheme.light, WidgetTheme.dark];

bool _still(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// [d], or none under the OS's "remove animations".
Duration _motion(BuildContext context, Duration d) =>
    _still(context) ? Duration.zero : d;

/// Animates [child]'s size changes; under "remove animations" it is just
/// [child], since a zero-length `AnimatedSize` re-dirties itself mid-layout.
Widget _resizing(BuildContext context, Widget child) => _still(context)
    ? child
    : AnimatedSize(
        duration: AppDurations.fast,
        curve: AppCurves.standard,
        alignment: Alignment.topCenter,
        child: child,
      );

/// The widget theme, which the previews overlay onto the cubit's payload.
WidgetTheme _widgetTheme(BuildContext context) =>
    context.select((CounterAppearanceCubit c) => c.state.widget.theme);

class _Body extends StatefulWidget {
  const _Body();

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  late final PageController _pages;

  /// True while a rail tap drives the stage: the pages it flies past are
  /// neither selected nor ticked (the tap selected its target and gave the
  /// haptic).
  var _flying = false;

  @override
  void initState() {
    super.initState();
    _pages = PageController(
      viewportFraction: 0.86,
      initialPage: context.read<HomeWidgetCubit>().state.family.index,
    );
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// A swipe selects the page it settles on.
  void _onPageChanged(int i) {
    if (_flying) return;
    AppHaptics.selection();
    context.read<HomeWidgetCubit>().select(_families[i]);
  }

  /// A rail tap selects its family at once, then flies the stage there.
  Future<void> _goTo(int i) async {
    if (!_pages.hasClients) return;
    final cubit = context.read<HomeWidgetCubit>()..select(_families[i]);
    _flying = true;
    try {
      if (_still(context)) {
        _pages.jumpToPage(i);
      } else {
        await _pages.animateToPage(
          i,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
        );
      }
    } finally {
      _flying = false;
      // A drag that interrupted the flight decides where it ended.
      final page = mounted && _pages.positions.length == 1
          ? _pages.page?.round()
          : null;
      if (page != null) cubit.select(_families[page]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xxl + MediaQuery.viewPaddingOf(context).bottom,
      ),
      children: [
        _Stage(controller: _pages, onPageChanged: _onPageChanged),
        const SizedBox(height: AppSpacing.md),
        const _Caption(),
        const SizedBox(height: AppSpacing.md),
        _Rail(onPick: (i) => unawaited(_goTo(i))),
        const _SizeSection(),
        const _LimitLink(),
        const _ThemeSection(),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Add to home screen',
          icon: Icons.add_to_home_screen_rounded,
          expand: true,
          onPressed: () => unawaited(_add(context)),
        ),
      ],
    );
  }
}

/// The selected family drawn big, straight on the page (the tile is its own
/// surface), in a pager whose neighbours peek in. Its height morphs with the
/// size; a swipe rebuilds nothing here (only the pages' transforms repaint).
class _Stage extends StatelessWidget {
  const _Stage({required this.controller, required this.onPageChanged});

  final PageController controller;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final theme = _widgetTheme(context);
    final stage = BlocBuilder<HomeWidgetCubit, HomeWidgetState>(
      buildWhen: (a, b) => a.size != b.size || a.payload != b.payload,
      builder: (context, state) => LayoutBuilder(
        builder: (context, constraints) {
          final page = constraints.maxWidth * controller.viewportFraction;
          // One scale for every size, so Small reads smaller than Large.
          final scale = math.min(
            1.0,
            (page - 2 * AppSpacing.xs) / WidgetSize.large.box.width,
          );
          final box = state.size.box * scale;
          final payload = state.payload.copyWith(theme: theme.name);
          return AnimatedContainer(
            duration: _motion(context, AppDurations.normal),
            curve: AppCurves.emphasized,
            height: box.height,
            child: PageView.builder(
              controller: controller,
              onPageChanged: onPageChanged,
              itemCount: _families.length,
              itemBuilder: (context, i) => StagePage(
                controller: controller,
                index: i,
                // Pulls a narrow (Small) neighbour in until it peeks, a gap
                // from the centre tile; a page-wide one already does.
                peek: math.max(0, page - box.width - AppSpacing.md),
                child: _StagePreview(
                  family: _families[i],
                  size: state.size,
                  payload: payload,
                  width: box.width,
                ),
              ),
            ),
          );
        },
      ),
    );
    if (_still(context)) return stage;
    return stage
        .animate()
        .fadeIn(duration: AppDurations.normal, curve: AppCurves.decelerate)
        .scaleXY(
          begin: 0.94,
          end: 1,
          duration: AppDurations.normal,
          curve: AppCurves.standard,
        );
  }
}

/// A page's preview. A size switch cross-fades, and each look scales down to
/// the morphing stage height, so growing into Large never clips or jumps.
class _StagePreview extends StatelessWidget {
  const _StagePreview({
    required this.family,
    required this.size,
    required this.payload,
    required this.width,
  });

  final WidgetFamily family;
  final WidgetSize size;
  final WidgetPayload payload;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedSwitcher(
        duration: _motion(context, AppDurations.fast),
        child: FittedBox(
          key: ValueKey(size),
          fit: BoxFit.scaleDown,
          child: WidgetPreview(
            family: family,
            size: size,
            payload: payload,
            width: width,
          ),
        ),
      ),
    );
  }
}

/// The selected family's name and its one muted line.
class _Caption extends StatelessWidget {
  const _Caption();

  @override
  Widget build(BuildContext context) {
    final family = context.select((HomeWidgetCubit c) => c.state.family);
    final text = Theme.of(context).textTheme;
    return _resizing(
      context,
      AnimatedSwitcher(
        duration: _motion(context, const Duration(milliseconds: 220)),
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.12),
              end: Offset.zero,
            ).animate(a),
            child: child,
          ),
        ),
        child: Column(
          key: ValueKey(family),
          children: [
            Text(
              family.label,
              textAlign: TextAlign.center,
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              family.blurb,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: context.tokens.ink2),
            ),
          ],
        ),
      ),
    );
  }
}

/// The seven families as static thumbnails; the selected card's ring and glow
/// animate (`VariantCarousel`).
class _Rail extends StatelessWidget {
  const _Rail({required this.onPick});

  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = _widgetTheme(context);
    return BlocBuilder<HomeWidgetCubit, HomeWidgetState>(
      buildWhen: (a, b) => a.family != b.family || a.payload != b.payload,
      builder: (context, state) {
        final payload = state.payload.copyWith(theme: theme.name);
        return VariantCarousel(
          options: [
            for (final (i, family) in _families.indexed)
              VariantOption(
                label: family.label,
                selected: family == state.family,
                onTap: () => onPick(i),
                preview: RailThumb(
                  index: i,
                  selected: family == state.family,
                  child: WidgetPreview(
                    family: family,
                    size: WidgetSize.small,
                    payload: payload,
                    width: 64,
                    animate: false,
                    // The card reads its label and selected state.
                    excludeFromSemantics: true,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Preview-only: a pinned widget lands 2×2 and the user resizes it, which the
/// info button says once, quietly.
class _SizeSection extends StatelessWidget {
  const _SizeSection();

  @override
  Widget build(BuildContext context) {
    final size = context.select((HomeWidgetCubit c) => c.state.size);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Expanded(child: SectionHeader('Size')),
            InfoButton('Resize the widget on your home screen to switch sizes'),
          ],
        ),
        GlassSegmented(
          segments: [for (final s in _sizes) (label: s.label, icon: null)],
          selectedIndex: _sizes.indexOf(size),
          onChanged: (i) =>
              context.read<HomeWidgetCubit>().selectSize(_sizes[i]),
          height: AppSizes.controlHeight,
        ),
      ],
    );
  }
}

/// Time limit with no limit set reads "No daily limit"; this offers the fix.
/// It folds in and out rather than jumping the layout.
class _LimitLink extends StatelessWidget {
  const _LimitLink();

  @override
  Widget build(BuildContext context) {
    final show = context.select((HomeWidgetCubit c) {
      final s = c.state;
      return !s.loading &&
          s.family == WidgetFamily.timeLimit &&
          s.payload.limitMinutes == 0;
    });
    return _resizing(
      context,
      AnimatedSwitcher(
        duration: _motion(context, AppDurations.fast),
        child: show
            ? Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Center(
                  child: GhostButton(
                    label: 'Set a daily limit',
                    onPressed: () => unawaited(_setLimit(context)),
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _ThemeSection extends StatelessWidget {
  const _ThemeSection();

  @override
  Widget build(BuildContext context) {
    final style = context.select((CounterAppearanceCubit c) => c.state.widget);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Theme'),
        GlassSegmented(
          segments: const [
            (label: 'System', icon: null),
            (label: 'Light', icon: null),
            (label: 'Dark', icon: null),
          ],
          selectedIndex: _themes.indexOf(style.theme),
          onChanged: (i) => context.read<CounterAppearanceCubit>().setWidget(
            style.copyWith(theme: _themes[i]),
          ),
          height: AppSizes.controlHeight,
        ),
      ],
    );
  }
}

/// The limit set there is the one Time limit shows, so the payload reloads.
Future<void> _setLimit(BuildContext context) async {
  final cubit = context.read<HomeWidgetCubit>();
  await context.push<void>(Routes.dailyLimit);
  await cubit.load();
}

/// Asks the launcher to pin the selected family; the toast is truthful because
/// native `pinContentWidget` answers false on launchers that can't pin, and
/// the call answers null when it failed.
Future<void> _add(BuildContext context) async {
  final cubit = context.read<HomeWidgetCubit>();
  final size = cubit.state.size;
  final ok = await cubit.pin();
  if (!context.mounted) return;
  GlassToast.show(context, switch ((ok, size)) {
    (null, _) => 'Couldn’t add the widget. Try again.',
    (false, _) =>
      'Your launcher doesn’t support adding widgets this way — '
          'long-press your home screen and pick Detoxo from Widgets.',
    (true, WidgetSize.small) =>
      'Confirm the prompt to add it to your home screen.',
    (true, _) =>
      'Confirm the prompt to add it, then long-press it and drag to resize.',
  }, tone: ok == true ? AppTone.neutral : AppTone.warning);
}
