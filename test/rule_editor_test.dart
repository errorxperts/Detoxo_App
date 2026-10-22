import 'package:bloc_test/bloc_test.dart';
import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/features/blocking/shared/domain/repositories/blocking_repositories.dart';
import 'package:detoxo/features/catalog/catalog.dart';
import 'package:detoxo/features/limits/rules/domain/entities/rule.dart';
import 'package:detoxo/features/limits/rules/domain/entities/rule_editor_args.dart';
import 'package:detoxo/features/limits/rules/presentation/rule_editor_screen.dart';
import 'package:detoxo/features/limits/rules/presentation/rules_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRules extends MockCubit<RulesState> implements RulesCubit {}

/// Every engine call is a no-op that answers null.
class _Engine implements EngineRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<Null>.value();
}

/// Fixed frames: the ambient ground never lets pumpAndSettle converge.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// The rule editor's pure parts (the category rail's icon map and the
/// "All distracting" quick-pick rule), plus its compact copy and the calm,
/// non-destructive Lock confirm.
void main() {
  test('every seed category has an icon on the rail', () {
    // A category added to the seed without a glyph would render as the one
    // bare chip in the rail — the same drift guard the adult list has.
    for (final c in AppCategorySeed.categories) {
      expect(RuleEditorScreen.categoryIcons[c.id], isNotNull, reason: c.id);
    }
  });

  test('the catalog names the distracting categories in seed order', () {
    expect(Catalog.bundled.categoriesWithBehavior(AppBehavior.distracting), [
      'short_form_video',
      'social',
      'video_streaming',
      'games',
    ]);
  });

  test('toggleAll adds the missing ids, then clears exactly those', () {
    const all = ['a', 'b'];
    expect(RuleEditorScreen.toggleAll(const [], all), all);
    expect(RuleEditorScreen.toggleAll(const ['b', 'z'], all), ['b', 'z', 'a']);
    // Every id present → the tap clears them, and only them.
    expect(RuleEditorScreen.toggleAll(const ['a', 'z', 'b'], all), ['z']);
    expect(RuleEditorScreen.toggleAll(all, all), isEmpty);
  });

  group('screen', () {
    setUp(() async {
      await sl.reset();
      sl.registerSingleton<EngineRepository>(_Engine());
    });
    tearDown(sl.reset);

    Future<void> pump(WidgetTester tester) async {
      final rules = _MockRules();
      when(() => rules.state).thenReturn(const RulesState(loaded: true));
      await tester.pumpWidget(
        BlocProvider<RulesCubit>.value(
          value: rules,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const RuleEditorScreen(
              args: RuleEditorArgs(kind: RuleKind.timeLimit),
            ),
          ),
        ),
      );
      await _settle(tester);
    }

    Future<void> toggle(WidgetTester tester, String title) async {
      final toggle = find.descendant(
        of: find.widgetWithText(AppToggleTile, title),
        matching: find.byType(AppToggle),
      );
      // Lazily built: scroll it into the tree, then fully into view.
      await tester.scrollUntilVisible(
        toggle,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(toggle);
      await _settle(tester);
      await tester.tap(toggle);
      await _settle(tester);
    }

    testWidgets('the budget reads compact; Categories is a section', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('30m a day'), findsOneWidget);
      expect(find.text('CATEGORIES'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('Strict explains itself in one sentence', (tester) async {
      await pump(tester);
      await toggle(tester, 'Strict');
      expect(
        find.text(
          'Strict rules keep blocking apps, reel feeds and websites even '
          'during a Pause.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Lock asks once, calmly, then waits for Save', (tester) async {
      await pump(tester);
      await toggle(tester, 'Lock this rule');
      expect(
        find.text(
          'A locked rule has no off switch and can’t be deleted. An override '
          'lifts it for up to an hour, twice a week. Reset app data is the '
          'only way to remove it.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Lock it'));
      await _settle(tester);
      expect(find.text('Takes effect when you save.'), findsOneWidget);
      expect(
        find.text(
          'Saving locks this rule. After that the only way in is an override.',
        ),
        findsOneWidget,
      );
    });
  });
}
