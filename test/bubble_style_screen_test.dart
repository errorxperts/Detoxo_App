import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/content_counter/content_counter.dart';
import 'package:detoxo/features/content_counter/content_counter_appearance/presentation/bubble_style_screen.dart';
import 'package:detoxo/features/content_counter/content_counter_appearance/presentation/widgets/stage_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAppearance implements CounterAppearanceRepository {
  final bubbles = <BubbleStyle>[];

  // These tests drive the carousel from its first page, Mascot (new installs
  // start on Ring at the smallest size).
  @override
  Future<CounterAppearance> current() async =>
      const CounterAppearance.defaults().copyWith(
        bubble: const BubbleStyle(variant: BubbleVariant.mascot, size: 68),
      );

  @override
  Future<void> setBubbleStyle(BubbleStyle style) async => bubbles.add(style);

  @override
  Future<void> setWidgetStyle(WidgetStyle style) async {}

  @override
  Future<void> setBrands({required int light, required int dark}) async {}
}

class _FakeCounter implements ContentCounterRepository {
  @override
  Stream<ContentCount> watch() => const Stream.empty();

  @override
  Future<ContentCount> current() async => const ContentCount.empty();

  @override
  Future<void> setEnabled({required bool enabled}) async {}
}

class _FakeBubble implements BubbleRepository {
  @override
  Future<bool?> canShow() async => true;

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> setEnabled({required bool enabled}) async {}
}

ThemeData _theme() => AppTheme.dark();

/// Lets the stage's flight or fling land (the rail's selected glow repeats,
/// so it never settles).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The stage's settled page.
int _page(WidgetTester tester) =>
    tester.widget<PageView>(find.byType(PageView)).controller!.page!.round();

/// The one animating stage preview: the centred page's.
BubblePreview _live(WidgetTester tester) => tester
    .widgetList<BubblePreview>(
      find.descendant(
        of: find.byType(PageView),
        matching: find.byType(BubblePreview),
      ),
    )
    .singleWhere((p) => p.animate);

void main() {
  late _FakeAppearance appearance;

  Future<void> pumpScreen(WidgetTester tester) async {
    appearance = _FakeAppearance();
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => CounterAppearanceCubit(appearance)),
          BlocProvider(
            create: (_) => ContentCounterCubit(_FakeCounter(), _FakeBubble()),
          ),
        ],
        child: MaterialApp(theme: _theme(), home: const BubbleStyleScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('shows the six styles and the two controls', (tester) async {
    await pumpScreen(tester);
    final rail = find.byType(VariantCarousel);
    for (final v in BubbleVariant.values) {
      expect(
        find.descendant(of: rail, matching: find.text(v.label)),
        findsOneWidget,
        reason: v.label,
      );
    }
    for (final t in ['Neon', 'Steps', 'Weather', 'Outline']) {
      expect(find.text(t), findsNothing, reason: t);
    }
    for (final t in ['Size', 'Opacity']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.byTooltip('Replay appear'), findsOneWidget);
    expect(find.bySemanticsLabel('Preview count'), findsOneWidget);
    for (final t in ['Show caption', 'Show time on tap', 'Text size']) {
      expect(find.text(t), findsNothing, reason: t);
    }
  });

  testWidgets('picking Ring pushes the style and flies the stage', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(VariantCarousel),
        matching: find.text('Ring'),
      ),
    );
    await _settle(tester);
    expect(appearance.bubbles.last.variant, BubbleVariant.ring);
    expect(
      find.text('Ring · ${BubbleModel.nextLine(137)}', findRichText: true),
      findsOneWidget,
    );
    expect(_page(tester), BubbleVariant.ring.index);
    expect(_live(tester).style.variant, BubbleVariant.ring);
  });

  testWidgets('a swipe selects the style it settles on', (tester) async {
    await pumpScreen(tester);
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await _settle(tester);
    expect(_page(tester), 1);
    expect(appearance.bubbles.last.variant, BubbleVariant.values[1]);
    final v = BubbleVariant.values[1];
    expect(
      find.text(
        '${v.label} · ${BubbleModel.nextLine(137)}',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('the mascot shows its mood line', (tester) async {
    await pumpScreen(tester);
    // The seeded 137 reels is past tier 0, so the line is that tier's mood.
    final line = BubbleModel.mascotLine(BubbleModel.tier(137));
    expect(find.text('Mascot · $line', findRichText: true), findsOneWidget);
    expect(line, isNot(contains('happy to see you')));
  });

  testWidgets('the stage is the theme glass, not a fixed backdrop', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(
      find.descendant(
        of: find.byType(PageView),
        matching: find.byType(StageSurface),
      ),
      findsWidgets,
    );
    final hint = tester.widget<Text>(
      find.text('Tap the bubble for the timer').first,
    );
    expect(hint.style?.color, AppTokens.dark.ink2);
  });

  testWidgets('the stage and the rail line up with the page gutter', (
    tester,
  ) async {
    await pumpScreen(tester);
    await _settle(tester);
    const w = 1080.0;
    final glass = find.descendant(
      of: find.byType(PageView),
      matching: find.byType(GlassContainer),
    );
    final rects = [
      for (var i = 0; i < glass.evaluate().length; i++)
        tester.getRect(glass.at(i)),
    ];
    // The centred glass spans the 20 dp gutter (to float precision).
    bool centred(Rect r) =>
        (r.left - AppSpacing.gutter).abs() < 0.01 &&
        (r.right - (w - AppSpacing.gutter)).abs() < 0.01;
    expect(rects.where(centred), hasLength(1));
    // A neighbour shows only `gutter - 2 · xxs` (12) at the screen edge.
    final side = rects.where((r) => !centred(r)).toList();
    expect(side, isNotEmpty);
    for (final r in side) {
      final shown = r.right <= w / 2 ? r.right : w - r.left;
      expect(shown, closeTo(AppSpacing.gutter - 2 * AppSpacing.xxs, 0.01));
    }
    // The rail runs edge to edge and rests on the gutter.
    final rail = find.byType(VariantCarousel);
    expect(tester.getRect(rail).width, w);
    expect(
      tester
          .getTopLeft(
            find
                .descendant(of: rail, matching: find.byType(AppPressable))
                .first,
          )
          .dx,
      AppSpacing.gutter,
    );
  });

  testWidgets('only the centred stage page animates', (tester) async {
    await pumpScreen(tester);
    final stage = tester.widgetList<BubblePreview>(
      find.descendant(
        of: find.byType(PageView),
        matching: find.byType(BubblePreview),
      ),
    );
    expect(stage.length, greaterThan(1)); // a neighbour peeks in
    expect(stage.every((p) => p.interactive), isTrue);
    expect(stage.where((p) => p.animate).map((p) => p.style.variant), [
      BubbleVariant.mascot,
    ]);
  });
}
