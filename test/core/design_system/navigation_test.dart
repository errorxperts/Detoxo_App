import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _items = <TabItem>[
  (
    label: 'Today',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
  ),
  (
    label: 'Insights',
    icon: Icons.leaderboard_outlined,
    selectedIcon: Icons.leaderboard,
  ),
];

/// Pumps an [AppTabBar] that follows its own taps; returns the taps.
Future<List<int>> _pumpBar(
  WidgetTester tester, {
  ThemeData? theme,
  bool reduceMotion = false,
  double textScale = 1,
}) async {
  final taps = <int>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduceMotion,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: StatefulBuilder(
            builder: (context, setState) => AppTabBar(
              items: _items,
              current: taps.isEmpty ? 0 : taps.last,
              onSelect: (i) => setState(() => taps.add(i)),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return taps;
}

Rect _lens(WidgetTester tester) =>
    tester.getRect(find.byKey(AppTabBar.lensKey));

Color? _labelColor(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style?.color;

void main() {
  testWidgets('is 208 x 64 with a half-width lens under the current tab', (
    tester,
  ) async {
    final taps = await _pumpBar(tester);
    final bar = tester.getRect(find.byType(AppTabBar));
    expect(bar.size, const Size(208, 64));
    // 6 px padding; the lens is half the 196 px inner width.
    expect(_lens(tester), Rect.fromLTWH(bar.left + 6, bar.top + 6, 98, 52));
    expect(find.byIcon(Icons.dashboard), findsOneWidget);
    expect(find.byIcon(Icons.leaderboard_outlined), findsOneWidget);

    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();
    expect(taps, [1]);
    expect(_lens(tester).left, bar.left + 6 + 98);
    expect(find.byIcon(Icons.dashboard_outlined), findsOneWidget);
    expect(find.byIcon(Icons.leaderboard), findsOneWidget);
  });

  testWidgets('the current tab is selected in semantics, the other not', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpBar(tester);
    expect(
      tester.getSemantics(find.text('Today')),
      isSemantics(label: 'Today', isButton: true, isSelected: true),
    );
    expect(
      tester.getSemantics(find.text('Insights')),
      isSemantics(
        label: 'Insights',
        isButton: true,
        hasSelectedState: true,
        isSelected: false,
      ),
    );
    handle.dispose();
  });

  testWidgets('labels: ink-2 idle; accent text, or ink in Dark, current', (
    tester,
  ) async {
    await _pumpBar(tester);
    const light = AppTokens.light;
    expect(_labelColor(tester, 'Today'), light.accentText(light.brand));
    expect(_labelColor(tester, 'Insights'), light.ink2);

    await _pumpBar(tester, theme: AppTheme.dark());
    expect(_labelColor(tester, 'Today'), AppTokens.dark.ink);
    expect(_labelColor(tester, 'Insights'), AppTokens.dark.ink2);
  });

  testWidgets('under Reduce Motion a tab change is static', (tester) async {
    await _pumpBar(tester, reduceMotion: true);
    final bar = tester.getRect(find.byType(AppTabBar));

    await tester.tap(find.text('Insights'));
    await tester.pump();
    expect(_lens(tester).left, bar.left + 6 + 98);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('clamps text at 1.3 and fits at 2x', (tester) async {
    await _pumpBar(tester, textScale: 2);
    expect(tester.takeException(), isNull);
    final scaler = MediaQuery.textScalerOf(
      tester.element(find.text('Insights')),
    );
    expect(scaler.scale(10), closeTo(13, .001));
    expect(tester.getSize(find.byType(AppTabBar)), AppTabBar.size);
  });

  group('TabHeader', () {
    testWidgets('a Detoxo heading, its actions and a Menu button', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var menu = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TabHeader(
              title: 'Detoxo',
              onMenu: () => menu++,
              actions: const [Text('action')],
            ),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.text('Detoxo')),
        isSemantics(label: 'Detoxo', isHeader: true),
      );
      expect(find.text('action'), findsOneWidget);

      final button = find.bySemanticsLabel('Menu');
      expect(
        find.descendant(
          of: find.byType(GlassIconButton),
          matching: find.byType(GlassContainer),
        ),
        findsNothing,
        reason: 'a plain icon, no glass circle',
      );
      final size = tester.getSize(button);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      await tester.tap(button);
      expect(menu, 1);
      handle.dispose();
    });

    testWidgets('listPadding: gutter, inset on top, 132 + inset below', (
      tester,
    ) async {
      late EdgeInsets padding;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(viewPadding: EdgeInsets.only(bottom: 24)),
          child: Builder(
            builder: (context) {
              padding = TabHeader.listPadding(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(padding, const EdgeInsets.fromLTRB(20, 8, 20, 132 + 24.0));
    });
  });
}
