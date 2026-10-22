import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/features/additional_feature/appearance/presentation/appearance_screen.dart';
import 'package:detoxo/features/blocking/blocking.dart';
import 'package:detoxo/features/content_counter/content_counter.dart';
import 'package:detoxo/features/content_counter/content_counter_appearance/presentation/home_widget_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _FakeRepo implements HomeWidgetRepository {
  @override
  Future<WidgetPayload> payload() async => WidgetPayload.demo(
    limitMinutes: 120,
    theme: 'system',
    reduceMotion: false,
    nowMs: DateTime.now().millisecondsSinceEpoch,
  );

  @override
  Future<bool?> pin(WidgetFamily family) async => true;

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

class _MockSettings extends Mock implements SettingsCubit {}

class _MockCounter extends Mock implements ContentCounterCubit {}

class _MockBlockScreen extends Mock implements BlockScreenStyleCubit {}

ThemeData _theme() => AppTheme.dark();

/// What a screen reader hears from the home-widget previews: on the picker,
/// one stage node naming the centred family and size, and rail cards that
/// read as their family; on the Appearance hub, the card and not the demo
/// numbers.
void main() {
  setUp(() async {
    await sl.reset();
    PlatformAdaptive.debugUseCupertino = false;
  });

  tearDown(() async {
    PlatformAdaptive.debugUseCupertino = null;
    await sl.reset();
  });

  group('the picker', () {
    Future<void> pumpScreen(WidgetTester tester) async {
      sl.registerSingleton<HomeWidgetRepository>(_FakeRepo());
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        BlocProvider(
          create: (_) => CounterAppearanceCubit(_FakeAppearance()),
          child: MaterialApp(theme: _theme(), home: const HomeWidgetScreen()),
        ),
      );
      // No pumpAndSettle: the ambient background loops. The stage's fade-in
      // starts on the second pump, and at opacity 0 it has no semantics.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
    }

    String stageLabel(WidgetTester tester) {
      final stage = find.bySemanticsLabel(RegExp(' preview: '));
      expect(stage, findsOneWidget, reason: 'one stage preview node');
      return tester.getSemantics(stage).label;
    }

    Finder railCard(String label) => find.descendant(
      of: find.byType(VariantCarousel),
      matching: find.text(label),
    );

    testWidgets('the centred stage page names its family and size', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpScreen(tester);
      expect(stageLabel(tester), startsWith('Count, Small preview: '));
      expect(stageLabel(tester), contains('152 reels today'));

      // A swipe: the neighbour that was peeking is now the one node.
      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await settle(tester);
      expect(stageLabel(tester), startsWith('Next colour, Small preview: '));

      await tester.tap(find.text('Medium'), warnIfMissed: false);
      await settle(tester);
      expect(stageLabel(tester), startsWith('Next colour, Medium preview: '));
      semantics.dispose();
    });

    testWidgets('rail cards read their family, the selected one selected', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpScreen(tester);
      expect(
        tester.getSemantics(railCard('Count')),
        isSemantics(label: 'Count', isButton: true, isSelected: true),
      );
      for (final family in WidgetFamily.values.skip(1)) {
        expect(
          tester.getSemantics(railCard(family.label)),
          isSemantics(label: family.label, isButton: true, isSelected: false),
          reason: family.label,
        );
      }
      semantics.dispose();
    });

    testWidgets('tap targets are big enough and labelled', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpScreen(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  });

  testWidgets("the Appearance hub's widget card keeps the demo to itself", (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final settings = _MockSettings();
    final counter = _MockCounter();
    final blockScreen = _MockBlockScreen();
    when(() => settings.state).thenReturn(const AppSettings());
    when(() => settings.stream).thenAnswer((_) => const Stream.empty());
    when(() => counter.state).thenReturn(const ContentCount());
    when(() => counter.stream).thenAnswer((_) => const Stream.empty());
    when(() => blockScreen.state).thenReturn(const BlockScreenStyle.defaults());
    when(() => blockScreen.stream).thenAnswer((_) => const Stream.empty());
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<SettingsCubit>.value(value: settings),
          BlocProvider<ContentCounterCubit>.value(value: counter),
          BlocProvider<BlockScreenStyleCubit>.value(value: blockScreen),
          BlocProvider(
            create: (_) => CounterAppearanceCubit(_FakeAppearance()),
          ),
        ],
        child: MaterialApp(theme: _theme(), home: const AppearanceScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.bySemanticsLabel(RegExp(' preview: ')), findsNothing);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel(RegExp('^Edit Widget style')))
          .label,
      isNot(contains('reels')),
    );
    // Floored to the minute, so a rebuild hands the preview an equal payload.
    final preview = tester.widget<WidgetPreview>(find.byType(WidgetPreview));
    expect(preview.payload.updatedAt % Duration.millisecondsPerMinute, 0);
    semantics.dispose();
  });
}
