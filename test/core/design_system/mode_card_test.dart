import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final _options = <ModeOption>[
  (icon: Assets.images.icons.iconBlockAll, label: 'Block All'),
  (icon: Assets.images.icons.iconConscious, label: 'Conscious'),
  (icon: Assets.images.icons.iconPause, label: 'Pause'),
  (icon: Assets.images.icons.iconOneReel, label: 'One Reel'),
];

const _labels = ['Block All', 'Conscious', 'Pause', 'One Reel'];

Future<void> _pump(
  WidgetTester tester, {
  int? selected = 0,
  bool dark = false,
  bool reduceMotion = false,
  double textScale = 1,
  String? title = 'All reels blocked',
  ValueChanged<int>? onSelected,
  Widget Function(int, Widget)? decorateOption,
}) => tester.pumpWidget(
  MaterialApp(
    theme: dark ? AppTheme.dark() : AppTheme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: reduceMotion,
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: Scaffold(
      body: AccentScope(
        light: AppTokens.light.pause,
        dark: AppTokens.dark.pause,
        child: ListView(
          padding: AppInsets.screen,
          children: [
            ModeCard(
              options: _options,
              selectedIndex: selected,
              onSelected: onSelected ?? (_) {},
              title: title,
              detail: 'Across every app on your list',
              decorateOption: decorateOption,
            ),
          ],
        ),
      ),
    ),
  ),
);

Finder _in(Type type) =>
    find.descendant(of: find.byType(ModeCard), matching: find.byType(type));

/// The card (first) and the chip (second) surfaces.
List<GlassContainer> _surfaces(WidgetTester tester) =>
    tester.widgetList<GlassContainer>(_in(GlassContainer)).toList();

Rect _chip(WidgetTester tester) => tester.getRect(_in(FractionallySizedBox));

void main() {
  testWidgets('four verbatim labels over four accent-tinted icons', (
    tester,
  ) async {
    await _pump(tester);
    for (final label in _labels) {
      expect(find.text(label), findsOneWidget);
    }
    final icons = tester.widgetList<Icon3d>(find.byType(Icon3d));
    expect(icons.length, 4);
    expect(icons.every((i) => i.accentTint && i.size == 34), isTrue);
    expect(tester.getSize(_in(Row).first).height, 72);
  });

  testWidgets('one selected radio per pick, in a Blocking mode group', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final taps = <int>[];
    await _pump(tester, selected: 2, onSelected: taps.add);

    expect(find.bySemanticsLabel('Blocking mode'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      expect(
        tester.getSemantics(find.text(_labels[i])),
        isSemantics(
          label: _labels[i],
          isButton: true,
          isInMutuallyExclusiveGroup: true,
          hasSelectedState: true,
          isSelected: i == 2,
          hasTapAction: true,
        ),
      );
    }

    // The picked option still reports a tap; the caller decides.
    await tester.tap(find.text('Pause'));
    await tester.tap(find.text('One Reel'));
    expect(taps, [2, 3]);
    handle.dispose();
  });

  testWidgets('Tab draws the focus ring on an option; Enter picks it', (
    tester,
  ) async {
    final taps = <int>[];
    await _pump(tester, onSelected: taps.add);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(tester.widgetList<FocusRing>(_in(FocusRing)).map((r) => r.visible), [
      true,
      false,
      false,
      false,
    ]);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(taps, [0]);
  });

  testWidgets('the chip sits under each pick and slides between them', (
    tester,
  ) async {
    await _pump(tester);
    final card = tester.getRect(find.byType(ModeCard));
    final quarter = (card.width - 2 * AppSpacing.inset) / 4;
    for (var i = 0; i < 4; i++) {
      await _pump(tester, selected: i);
      await tester.pumpAndSettle();
      final chip = _chip(tester);
      expect(
        chip.left,
        closeTo(card.left + AppSpacing.inset + i * quarter, .01),
      );
      expect(chip.size, Size(quarter, 72));
      expect(
        chip.center.dx,
        closeTo(tester.getCenter(find.text(_labels[i])).dx, .01),
      );
    }

    // Mid-slide back to Block All it is between the two.
    final from = _chip(tester).left;
    await _pump(tester);
    await tester.pump(const Duration(milliseconds: 150));
    expect(_chip(tester).left, inExclusiveRange(card.left, from));
    await tester.pumpAndSettle();
  });

  for (final dark in [false, true]) {
    final t = dark ? AppTokens.dark : AppTokens.light;
    testWidgets('${dark ? 'Dark' : 'Light'}: card and chip mix the live '
        'accent into option-base', (tester) async {
      await _pump(tester, selected: 2, dark: dark);
      final [card, chip] = _surfaces(tester);
      expect(card.surface, DxSurface.option);
      expect(card.color, Color.lerp(t.optionBase, t.pause.main, t.kOption));
      expect(card.padding, const EdgeInsets.all(AppSpacing.inset));
      expect(chip.color, Color.lerp(t.optionBase, t.pause.main, t.kChip));
      expect(chip.borderRadius, AppRadius.chip);
      // Spec strengths: 6 / 20 % Light, 14 / 40 % Dark; Dark's base is the
      // ring's centre colour.
      expect((t.kOption, t.kChip), dark ? (.14, .4) : (.06, .2));
      if (dark) expect(t.optionBase, t.ringDiscFrom);

      Color? ink(String label) =>
          tester.widget<Text>(find.text(label)).style!.color;
      expect(ink('Pause'), dark ? t.ink : t.accentText(t.pause));
      expect(ink('Block All'), t.ink2);
    });
  }

  testWidgets('the picked icon is vivid at 1.08, the rest soft at .94', (
    tester,
  ) async {
    await _pump(tester, selected: 1);
    final icons = tester.widgetList<Icon3d>(find.byType(Icon3d));
    expect(icons.map((i) => i.selected), [false, true, false, false]);

    final filters = tester
        .widgetList<ColorFiltered>(_in(ColorFiltered))
        .map((f) => f.colorFilter)
        .toList();
    final pause = AppTokens.light.pause;
    expect(filters[1], accentIconFilter(pause));
    expect(
      filters[0],
      accentIconFilter(
        pause,
        saturate: AppTokens.iconSaturateOff,
        opacity: AppTokens.iconOpacityOff,
      ),
    );

    final scales = tester
        .widgetList<AnimatedScale>(
          find.ancestor(
            of: find.byType(Icon3d),
            matching: find.byType(AnimatedScale),
          ),
        )
        .map((s) => s.scale)
        .where((s) => s != 1); // AppPressable's own press scale stays 1
    expect(scales, [.94, 1.08, .94, .94]);
  });

  testWidgets('title and detail open under a pick; none hides them and the '
      'chip', (tester) async {
    await _pump(tester);
    expect(find.text('All reels blocked'), findsOneWidget);
    expect(find.text('Across every app on your list'), findsOneWidget);
    expect(find.byType(StatusDot), findsOneWidget);

    await _pump(tester, selected: null);
    await tester.pumpAndSettle();
    expect(find.text('All reels blocked'), findsNothing);
    expect(find.byType(Divider), findsNothing);
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.ancestor(
              of: find.byType(FractionallySizedBox),
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity,
      0,
    );
  });

  testWidgets('decorateOption wraps each option once, in order', (
    tester,
  ) async {
    final seen = <int>[];
    await _pump(
      tester,
      decorateOption: (i, w) {
        seen.add(i);
        return KeyedSubtree(key: ValueKey('tour-$i'), child: w);
      },
    );
    expect(seen, [0, 1, 2, 3]);
    for (var i = 0; i < 4; i++) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('tour-$i')),
          matching: find.text(_labels[i]),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('Reduce Motion: a new pick lands in one frame', (tester) async {
    await _pump(tester, reduceMotion: true);
    await tester.pumpAndSettle();
    await _pump(tester, selected: 3, reduceMotion: true);
    expect(tester.binding.hasScheduledFrame, isFalse);
    final card = tester.getRect(find.byType(ModeCard));
    expect(_chip(tester).right, closeTo(card.right - AppSpacing.inset, .01));
  });

  testWidgets('2x text at 360 dp: no overflow, 48 dp targets', (tester) async {
    tester.view
      ..physicalSize = const Size(1080, 1920)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final handle = tester.ensureSemantics();
    await _pump(tester, textScale: 2, dark: true);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });
}
