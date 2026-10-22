import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/features/additional_feature/appearance/presentation/appearance_screen.dart';
import 'package:detoxo/features/blocking/blocking.dart';
import 'package:detoxo/features/content_counter/content_counter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

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

/// The Appearance hub's block-screen tile: the wall's compact preview;
/// switched off it still opens the editor (where the same switch lives), and
/// its status says what "off" means.
void main() {
  setUp(() async {
    await sl.reset();
    PlatformAdaptive.debugUseCupertino = false;
  });

  tearDown(() async {
    PlatformAdaptive.debugUseCupertino = null;
    await sl.reset();
  });

  late _MockCounter counter;

  Future<void> pumpHub(
    WidgetTester tester,
    BlockScreenStyle style, {
    ContentCount count = const ContentCount(),
  }) async {
    final settings = _MockSettings();
    counter = _MockCounter();
    final blockScreen = _MockBlockScreen();
    when(() => settings.state).thenReturn(const AppSettings());
    when(() => settings.stream).thenAnswer((_) => const Stream.empty());
    when(() => counter.state).thenReturn(count);
    when(() => counter.requestOverlay()).thenAnswer((_) async {});
    when(() => counter.stream).thenAnswer((_) => const Stream.empty());
    when(() => blockScreen.state).thenReturn(style);
    when(() => blockScreen.stream).thenAnswer((_) => const Stream.empty());
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const AppearanceScreen()),
        GoRoute(
          path: Routes.blockScreenStyle,
          builder: (_, _) => const Text('the editor'),
        ),
      ],
    );
    addTearDown(router.dispose);
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
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  final editCard = find.byWidgetPredicate(
    (w) => w is AppPressable && w.semanticLabel == 'Edit Block screen style',
  );
  const offHint = 'Off · toast instead';
  Finder status(String label) =>
      find.descendant(of: find.byType(Pill), matching: find.text(label));

  testWidgets('switched off, the status says what off means and the tile '
      'still opens the editor', (tester) async {
    await pumpHub(tester, const BlockScreenStyle(enabled: false));

    // The tile shows the wall's compact crop.
    expect(
      find.byWidgetPredicate((w) => w is BlockScreenPreview && w.compact),
      findsOneWidget,
    );
    expect(status(offHint), findsOneWidget);
    expect(tester.widget<AppPressable>(editCard).enabled, isTrue);
    await tester.tap(editCard);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('the editor'), findsOneWidget);
  });

  testWidgets('switched on, the status reads On, with no off line', (
    tester,
  ) async {
    await pumpHub(tester, const BlockScreenStyle.defaults());

    expect(find.text(offHint), findsNothing);
    // On for the block screen, the bubble and the widget; no amber notice.
    expect(status('On'), findsNWidgets(3));
    expect(find.byType(NoticeLine), findsNothing);
    expect(tester.widget<AppPressable>(editCard).enabled, isTrue);
  });

  testWidgets('without the overlay grant the status is Needs access, and a '
      'tap opens the grant', (tester) async {
    await pumpHub(
      tester,
      const BlockScreenStyle.defaults(),
      count: const ContentCount(overlayGranted: false),
    );

    // The bubble's and the block screen's; a dot and a word, no amber line.
    expect(status('Needs access'), findsNWidgets(2));
    expect(find.byType(NoticeLine), findsNothing);
    await tester.tap(status('Needs access').last);
    verify(() => counter.requestOverlay()).called(1);
  });
}
