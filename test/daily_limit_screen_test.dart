import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/content_counter/content_counter.dart';
import 'package:detoxo/features/limits/daily_limit/domain/entities/daily_limit.dart';
import 'package:detoxo/features/limits/daily_limit/domain/repositories/daily_limit_repository.dart';
import 'package:detoxo/features/limits/daily_limit/presentation/daily_limit_cubit.dart';
import 'package:detoxo/features/limits/daily_limit/presentation/daily_limit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MemRepo implements DailyLimitRepository {
  DailyLimit stored = const DailyLimit();

  @override
  Future<DailyLimit> load() async => stored;

  @override
  Future<void> save(DailyLimit limit) async => stored = limit;
}

class _MockCounter extends Mock implements ContentCounterCubit {}

/// The Daily limit screen: today's reel time against the limit in `formatHm`
/// words, a 15-minute slider that saves straight through the app-wide cubit,
/// and a layout that holds at 2× text on a small phone.
void main() {
  late DailyLimitCubit cubit;

  Future<void> pump(
    WidgetTester tester, {
    ContentCount count = const ContentCount(
      timeToday: Duration(minutes: 45),
      overlayGranted: true,
    ),
    double textScale = 1,
  }) async {
    cubit = DailyLimitCubit(_MemRepo());
    await cubit.setLimit(const Duration(hours: 3));
    final counter = _MockCounter();
    when(() => counter.state).thenReturn(count);
    when(() => counter.stream).thenAnswer((_) => const Stream.empty());
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<DailyLimitCubit>.value(value: cubit),
          BlocProvider<ContentCounterCubit>.value(value: counter),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const DailyLimitScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a 3h limit with 45m used reads in formatHm words', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('45m'), findsOneWidget);
    expect(find.text('45m of 3h used'), findsOneWidget);
    expect(find.text('3h a day'), findsOneWidget);
    expect(find.byType(NoticeLine), findsNothing);
    expect(find.byType(InfoBanner), findsNothing);
  });

  testWidgets('Save writes the slider value through setLimit', (tester) async {
    await pump(tester);

    tester.widget<Slider>(find.byType(Slider)).onChanged!(255);
    await tester.pump();
    expect(find.text('4h 15m a day'), findsOneWidget);
    expect(cubit.state.limit, const Duration(hours: 3), reason: 'a draft');

    await tester.tap(find.text('Save limit'));
    await tester.pump();
    expect(cubit.state.limit, const Duration(hours: 4, minutes: 15));
    expect(find.text('45m of 4h 15m used'), findsOneWidget);
    // Let the toast time out.
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('the counter switched off shows its notice line', (tester) async {
    await pump(tester, count: const ContentCount(enabled: false));

    expect(
      find.text(
        'Reel counter is off. Turn it on in Appearance to enforce the limit.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('2x text at 360x640 does not overflow', (tester) async {
    await pump(
      tester,
      count: const ContentCount(
        timeToday: Duration(hours: 2, minutes: 45),
        overlayGranted: false,
      ),
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
    // The list builds lazily: scroll the notice in, then check again.
    await tester.scrollUntilVisible(find.byType(NoticeLine), 200);
    expect(tester.takeException(), isNull);
  });
}
