import 'dart:io';

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final _options = <ModeOption>[
  (icon: Assets.images.icons.iconBlockAll, label: 'Block All'),
  (icon: Assets.images.icons.iconConscious, label: 'Conscious'),
  (icon: Assets.images.icons.iconOneReel, label: 'One Reel'),
  (icon: Assets.images.icons.iconPause, label: 'Pause'),
  (icon: Assets.images.icons.iconReelCount, label: 'Unblock'),
];

const _labels = ['Block All', 'Conscious', 'One Reel', 'Pause', 'Unblock'];

/// An option's width on a phone, and the gap between two.
const _w = 76.0;
const _gap = AppSpacing.inset;

Future<void> _pump(
  WidgetTester tester, {
  int? selected = 0,
  bool dark = false,
  bool reduceMotion = false,
  double textScale = 1,
  String? title = 'Reels allowed',
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
              detail: 'Blocking resumes in 09:42',
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

Rect _chip(WidgetTester tester) => tester.getRect(_in(AnimatedPositioned));

ScrollController _scroll(WidgetTester tester) => tester
    .widget<SingleChildScrollView>(_in(SingleChildScrollView))
    .controller!;

/// A 360 dp phone: the card's 304 inside holds four options and a bit.
void _phone(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1080, 1920)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('five verbatim labels over five accent-tinted icons', (
    tester,
  ) async {
    await _pump(tester);
    for (final label in _labels) {
      expect(find.text(label), findsOneWidget);
    }
    final icons = tester.widgetList<Icon3d>(find.byType(Icon3d));
    expect(icons.length, 5);
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
    for (var i = 0; i < _labels.length; i++) {
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
    await tester.tap(find.text('One Reel'));
    await tester.tap(find.text('Pause'));
    await tester.tap(find.text('Unblock'));
    expect(taps, [2, 3, 4]);
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
      false,
    ]);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(taps, [0]);
  });

  testWidgets('a roomy card widens the options to fill it; the chip sits '
      'under each pick and slides between them', (tester) async {
    await _pump(tester);
    final card = tester.getRect(find.byType(ModeCard));
    final inner = card.width - 2 * AppSpacing.inset;
    final w = (inner - 4 * _gap) / 5;
    expect(w, greaterThan(_w));
    expect(_scroll(tester).position.maxScrollExtent, 0);
    for (var i = 0; i < _labels.length; i++) {
      await _pump(tester, selected: i);
      await tester.pumpAndSettle();
      final chip = _chip(tester);
      expect(
        chip.left,
        closeTo(card.left + AppSpacing.inset + i * (w + _gap), .01),
      );
      expect(chip.width, closeTo(w, 1e-9));
      expect(chip.height, 72);
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

  testWidgets('a phone: 76 wide, 8 apart, scrolling the pick into view', (
    tester,
  ) async {
    _phone(tester);
    await _pump(tester);
    final card = tester.getRect(find.byType(ModeCard));
    final view = card.width - 2 * AppSpacing.inset;
    const content = 5 * _w + 4 * _gap;
    expect(view, 304);
    expect(_scroll(tester).position.maxScrollExtent, content - view);
    for (var i = 0; i < _labels.length; i++) {
      expect(
        tester.getCenter(find.text(_labels[i])).dx,
        closeTo(card.left + AppSpacing.inset + i * (_w + _gap) + _w / 2, .01),
      );
    }

    // Unblock, past the edge, glides into view; the chip under it.
    await _pump(tester, selected: 4);
    await tester.pump(); // the glide's first tick
    await tester.pump(const Duration(milliseconds: 100));
    expect(_scroll(tester).offset, inExclusiveRange(0, content - view));
    await tester.pumpAndSettle();
    expect(_scroll(tester).offset, content - view);
    final unblock = tester.getRect(find.text('Unblock'));
    expect(unblock.right, lessThanOrEqualTo(card.right - AppSpacing.inset));
    expect(_chip(tester).right, closeTo(card.right - AppSpacing.inset, .01));

    // Pause, in view, needs no scroll; Block All scrolls back.
    await _pump(tester, selected: 3);
    await tester.pumpAndSettle();
    expect(_scroll(tester).offset, content - view);
    await _pump(tester);
    await tester.pumpAndSettle();
    expect(_scroll(tester).offset, 0);

    // A drag scrolls it by hand.
    await tester.drag(find.text('One Reel'), const Offset(-60, 0));
    await tester.pumpAndSettle();
    expect(_scroll(tester).offset, greaterThan(0));
  });

  testWidgets('a pick past the edge is in view once mounted', (tester) async {
    _phone(tester);
    await _pump(tester, selected: 4);
    expect(_scroll(tester).offset, 5 * _w + 4 * _gap - 304);
  });

  for (final dark in [false, true]) {
    final t = dark ? AppTokens.dark : AppTokens.light;
    testWidgets('${dark ? 'Dark' : 'Light'}: a plain option-base card; '
        'only the chip mixes in the live accent', (tester) async {
      await _pump(tester, selected: 3, dark: dark);
      final [card, chip] = _surfaces(tester);
      expect(card.surface, DxSurface.option);
      expect(card.color, isNull);
      final fill = tester
          .widgetList<CustomPaint>(_in(CustomPaint))
          .map((p) => p.painter)
          .whereType<DxSurfacePainter>()
          .first;
      expect(fill.color, t.optionBase);
      expect(card.padding, const EdgeInsets.all(AppSpacing.inset));
      expect(chip.color, Color.lerp(t.optionBase, t.pause.main, t.kChip));
      expect(chip.borderRadius, AppRadius.chip);
      // Spec strength: 20 % Light, 40 % Dark; Dark's base is the ring's
      // centre colour.
      expect(t.kChip, dark ? .4 : .2);
      if (dark) expect(t.optionBase, t.ringDiscFrom);

      // Every idle label is ink-2; the pick is accent text (Light) or ink.
      Color? ink(String label) =>
          tester.widget<Text>(find.text(label)).style!.color;
      expect(ink('Pause'), dark ? t.ink : t.accentText(t.pause));
      for (final label in _labels.where((l) => l != 'Pause')) {
        expect(ink(label), t.ink2, reason: label);
      }
    });
  }

  testWidgets('the picked icon is accent and vivid at 1.08, the rest '
      'neutral grey at .94', (tester) async {
    await _pump(tester, selected: 1);
    final icons = tester.widgetList<Icon3d>(find.byType(Icon3d));
    expect(icons.map((i) => i.selected), [false, true, false, false, false]);

    final filters = tester
        .widgetList<ColorFiltered>(_in(ColorFiltered))
        .map((f) => f.colorFilter)
        .toList();
    final pause = AppTokens.light.pause;
    expect(filters[1], accentIconFilter(pause));
    for (final i in [0, 2, 3, 4]) {
      expect(filters[i], Icon3d.idleFilter, reason: _labels[i]);
    }

    final scales = tester
        .widgetList<AnimatedScale>(
          find.ancestor(
            of: find.byType(Icon3d),
            matching: find.byType(AnimatedScale),
          ),
        )
        .map((s) => s.scale)
        .where((s) => s != 1); // AppPressable's own press scale stays 1
    expect(scales, [.94, 1.08, .94, .94, .94]);
  });

  testWidgets('title and detail open under a pick; no title or no pick '
      'hides them, no pick the chip too', (tester) async {
    await _pump(tester, selected: 3);
    expect(find.text('Reels allowed'), findsOneWidget);
    expect(find.text('Blocking resumes in 09:42'), findsOneWidget);
    expect(find.byType(StatusDot), findsOneWidget);

    await _pump(tester, title: null);
    await tester.pumpAndSettle();
    expect(find.text('Blocking resumes in 09:42'), findsNothing);
    expect(find.byType(Divider), findsNothing);

    await _pump(tester, selected: null);
    await tester.pumpAndSettle();
    expect(find.text('Reels allowed'), findsNothing);
    expect(find.byType(Divider), findsNothing);
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.descendant(
              of: find.byType(AnimatedPositioned),
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
    expect(seen, [0, 1, 2, 3, 4]);
    for (var i = 0; i < _labels.length; i++) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('tour-$i')),
          matching: find.text(_labels[i]),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('Reduce Motion: a new pick lands, and scrolls, in one frame', (
    tester,
  ) async {
    _phone(tester);
    await _pump(tester, reduceMotion: true);
    await tester.pumpAndSettle();
    await _pump(tester, selected: 4, reduceMotion: true);
    // The scroll jumps in the post-frame callback.
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(_scroll(tester).offset, 5 * _w + 4 * _gap - 304);
    final card = tester.getRect(find.byType(ModeCard));
    expect(_chip(tester).right, closeTo(card.right - AppSpacing.inset, .01));
  });

  testWidgets('2x text at 360 dp: no overflow, 48 dp targets', (tester) async {
    _phone(tester);
    final handle = tester.ensureSemantics();
    await _pump(tester, textScale: 2, dark: true);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  // Last: the font it loads stays loaded for the rest of the file.
  test('in Manrope every label fits 76 unscaled at 1x', () async {
    final bold = File('assets/fonts/Manrope-Bold.ttf').readAsBytesSync();
    await (FontLoader(
      AppTypography.family,
    )..addFont(Future.value(ByteData.sublistView(bold)))).load();
    for (final label in _labels) {
      final p = TextPainter(
        text: TextSpan(text: label, style: AppTypography.caption),
        textDirection: TextDirection.ltr,
      )..layout();
      expect(p.width, lessThanOrEqualTo(_w), reason: label);
      p.dispose();
    }
  });
}
