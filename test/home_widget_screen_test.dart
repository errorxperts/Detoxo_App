import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/features/content_counter/content_counter.dart';
import 'package:detoxo/features/content_counter/content_counter_appearance/presentation/home_widget_cubit.dart';
import 'package:detoxo/features/content_counter/content_counter_appearance/presentation/home_widget_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo implements HomeWidgetRepository {
  _FakeRepo({this.limitMinutes = 0});

  final int limitMinutes;
  bool? pinAnswer = true;
  final pinned = <WidgetFamily>[];

  @override
  Future<WidgetPayload> payload() async => WidgetPayload.demo(
    limitMinutes: limitMinutes,
    theme: 'system',
    reduceMotion: false,
    nowMs: DateTime.now().millisecondsSinceEpoch,
  );

  @override
  Future<bool?> pin(WidgetFamily family) async {
    pinned.add(family);
    return pinAnswer;
  }

  @override
  Future<void> push({WidgetPushReason reason = WidgetPushReason.refresh}) =>
      throw UnimplementedError();

  @override
  Future<WidgetTap?> takePendingTap() => throw UnimplementedError();
}

class _FakeAppearance implements CounterAppearanceRepository {
  @override
  Future<CounterAppearance> current() async =>
      const CounterAppearance.defaults();

  @override
  Future<void> setBubbleStyle(BubbleStyle style) async {}

  @override
  Future<void> setWidgetStyle(WidgetStyle style) async {}

  @override
  Future<void> setBrands({required int light, required int dark}) async {}
}

ThemeData _theme() => AppTheme.dark();

/// The home-widget picker (doc 17 §6.4): a swipeable stage and a rail that
/// share one selection, a size switch, the Time-limit link and Add.
void main() {
  late _FakeRepo repo;

  setUp(() async {
    await sl.reset();
    PlatformAdaptive.debugUseCupertino = false;
  });

  tearDown(() async {
    PlatformAdaptive.debugUseCupertino = null;
    await sl.reset();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    int limitMinutes = 0,
    bool disableAnimations = false,
  }) async {
    repo = _FakeRepo(limitMinutes: limitMinutes);
    sl.registerSingleton<HomeWidgetRepository>(repo);
    // Wide enough that the whole rail is on screen, tall enough for it all.
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      BlocProvider(
        create: (_) => CounterAppearanceCubit(_FakeAppearance()),
        child: MaterialApp(
          theme: _theme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: disableAnimations),
            child: child!,
          ),
          home: const HomeWidgetScreen(),
        ),
      ),
    );
    // The payload lands and the entrance plays out. No pumpAndSettle: the
    // ambient background loops.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// Lets a page flight, the caption and link switches, and what they chain
  /// (the rail scrolling to the selection) finish. Each pump elapses time, so
  /// it also fires the start timers of whatever the frame before inflated (a
  /// toast's entrance), which a bare `pump()` would leave pending.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// A `GlassSegmented` segment. The control's own detector takes the tap,
  /// not the label under it, so the miss warning is expected.
  Future<void> tapSegment(WidgetTester tester, String label) =>
      tester.tap(find.text(label), warnIfMissed: false);

  HomeWidgetCubit cubit(WidgetTester tester) =>
      tester.element(find.byType(VariantCarousel)).read<HomeWidgetCubit>();

  PageController pages(WidgetTester tester) =>
      tester.widget<PageView>(find.byType(PageView)).controller!;

  Finder rail(String label) => find.descendant(
    of: find.byType(VariantCarousel),
    matching: find.text(label),
  );

  /// The label on the rail card wearing the selection check.
  Finder selectedRailLabel(String label) => find.descendant(
    of: find
        .ancestor(
          of: find.descendant(
            of: find.byType(VariantCarousel),
            matching: find.byIcon(Icons.check),
          ),
          matching: find.byType(AnimatedContainer),
        )
        .first,
    matching: find.text(label),
  );

  testWidgets('the rail lists the seven families, Count selected', (
    tester,
  ) async {
    await pumpScreen(tester);
    for (final family in WidgetFamily.values) {
      expect(rail(family.label), findsOneWidget, reason: family.label);
    }
    expect(selectedRailLabel('Count'), findsOneWidget);
  });

  testWidgets('swiping the stage selects the next family; the rail follows', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await settle(tester);

    expect(cubit(tester).state.family, WidgetFamily.nextColour);
    expect(selectedRailLabel('Next colour'), findsOneWidget);
    // The caption under the stage switched too.
    expect(find.text(WidgetFamily.nextColour.blurb), findsOneWidget);
  });

  testWidgets('on a phone, the rail scrolls to a family swiped off screen', (
    tester,
  ) async {
    await pumpScreen(tester);
    tester.view.physicalSize = const Size(400, 2400);
    await settle(tester);
    // Built in the rail's cache extent, but off screen.
    final offstage = find.descendant(
      of: find.byType(VariantCarousel),
      matching: find.text('Bento', skipOffstage: false),
      skipOffstage: false,
    );
    expect(tester.getRect(offstage).left, greaterThan(400));

    for (var i = 0; i < 5; i++) {
      await tester.drag(find.byType(PageView), const Offset(-250, 0));
      await settle(tester);
    }
    expect(cubit(tester).state.family, WidgetFamily.bento);
    final bento = tester.getRect(rail('Bento'));
    expect(bento.left, greaterThanOrEqualTo(0));
    expect(bento.right, lessThanOrEqualTo(400));
  });

  testWidgets('tapping a rail item moves the stage there', (tester) async {
    await pumpScreen(tester);
    await tester.tap(rail('Rhythm'));
    await settle(tester);

    expect(pages(tester).page, closeTo(3, 1e-6));
    expect(cubit(tester).state.family, WidgetFamily.rhythm);
    expect(selectedRailLabel('Rhythm'), findsOneWidget);
  });

  testWidgets('a rail flight selects only its target, not the pages passed', (
    tester,
  ) async {
    await pumpScreen(tester); // no limit: Time limit would show the link
    final picked = <WidgetFamily>[];
    final sub = cubit(tester).stream.listen((s) => picked.add(s.family));
    addTearDown(sub.cancel);

    await tester.tap(rail('Bento'));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      // Flying past Time limit must not fold its link in and out.
      expect(find.text('Set a daily limit'), findsNothing);
    }
    await settle(tester);

    expect(picked.toSet(), {WidgetFamily.bento});
    expect(pages(tester).page, closeTo(5, 1e-6));
  });

  testWidgets('Bonsai then Add pins Bonsai, with the size-aware toast', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(rail('Bonsai'));
    await settle(tester);
    await tester.tap(find.text('Add to home screen'));
    await settle(tester);

    expect(repo.pinned, [WidgetFamily.bonsai]);
    expect(find.text('Confirm the prompt to add it.'), findsOneWidget);

    await tapSegment(tester, 'Medium');
    await settle(tester);
    expect(cubit(tester).state.size, WidgetSize.medium);
    await tester.tap(find.text('Add to home screen'));
    await settle(tester);
    expect(
      find.text('Confirm the prompt, then long-press it to resize.'),
      findsOneWidget,
    );
  });

  testWidgets("a launcher that can't pin gets the add-by-hand copy", (
    tester,
  ) async {
    await pumpScreen(tester);
    repo.pinAnswer = false;
    await tester.tap(find.text('Add to home screen'));
    await settle(tester);
    expect(find.textContaining('pick Detoxo from Widgets'), findsOneWidget);
  });

  testWidgets('a failed pin call says to try again, not to add by hand', (
    tester,
  ) async {
    await pumpScreen(tester);
    repo.pinAnswer = null;
    await tester.tap(find.text('Add to home screen'));
    await settle(tester);
    expect(find.text('Couldn’t add the widget. Try again.'), findsOneWidget);
    expect(find.textContaining('pick Detoxo from Widgets'), findsNothing);
    // The warning tone's icon.
    expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
  });

  group('the daily-limit link', () {
    testWidgets('shows only on Time limit with no limit', (tester) async {
      await pumpScreen(tester);
      expect(find.text('Set a daily limit'), findsNothing);

      await tester.tap(rail('Time limit'));
      await settle(tester);
      // A panel row with the chevron, not a button.
      expect(
        find.widgetWithText(GlassListTile, 'Set a daily limit'),
        findsOneWidget,
      );

      await tester.tap(rail('Count'));
      await settle(tester);
      expect(find.text('Set a daily limit'), findsNothing);
    });

    testWidgets('stays hidden once a limit is set', (tester) async {
      await pumpScreen(tester, limitMinutes: 120);
      await tester.tap(rail('Time limit'));
      await settle(tester);
      expect(find.text('Set a daily limit'), findsNothing);
    });
  });

  testWidgets('with remove animations it still pumps and selects', (
    tester,
  ) async {
    await pumpScreen(tester, disableAnimations: true);
    await tester.tap(rail('Bento'));
    await tester.pump();

    expect(pages(tester).page, closeTo(5, 1e-6));
    expect(cubit(tester).state.family, WidgetFamily.bento);

    await tapSegment(tester, 'Large');
    await tester.pump();
    expect(cubit(tester).state.size, WidgetSize.large);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Plan is the seventh family: its blurb, and no limit link', (
    tester,
  ) async {
    await pumpScreen(tester); // no limit
    await tester.ensureVisible(rail('Plan'));
    await settle(tester);
    await tester.tap(rail('Plan'));
    await settle(tester);

    expect(pages(tester).page, closeTo(6, 1e-6));
    expect(cubit(tester).state.family, WidgetFamily.plan);
    expect(find.text(WidgetFamily.plan.blurb), findsOneWidget);
    expect(find.text('Set a daily limit'), findsNothing);
  });
}
