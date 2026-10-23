import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// One theme object each: a fresh ThemeData per pump would start
// MaterialApp's theme lerp, a ticker of its own.
final _light = AppTheme.light();
final _dark = AppTheme.dark();

String _hm(int m) => m >= 60 ? '${m ~/ 60}h ${m % 60}m' : '${m}m';

TimeLeftRing _ring({
  int? value = 135,
  double? progress = .75,
  bool accentEyebrow = false,
}) => TimeLeftRing(
  eyebrow: 'Time left',
  accentEyebrow: accentEyebrow,
  value: value,
  format: _hm,
  sub: '45m of 3h used',
  progress: progress,
  reels: 20,
  streak: 1,
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  bool reduceMotion = false,
  double width = 390,
  double textScale = 1,
}) {
  tester.view
    ..physicalSize = Size(width, 1000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark ? _dark : _light,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduceMotion,
          textScaler: TextScaler.linear(textScale),
        ),
        child: app!,
      ),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: Column(children: [child]),
        ),
      ),
    ),
  );
}

ProgressRing _ringOf(WidgetTester tester) =>
    tester.widget<ProgressRing>(find.byType(ProgressRing));

Finder _glyph(SvgGenImage asset) =>
    find.byWidgetPredicate((w) => w is Glyph && w.asset.path == asset.path);

void main() {
  testWidgets('the normal face counts up once, then ticks snap', (
    tester,
  ) async {
    await _pump(tester, _ring());
    expect(find.text('TIME LEFT'), findsOneWidget);
    expect(find.text('45m of 3h used'), findsOneWidget);
    // Unblock is a mode option now: the ring holds no pill.
    expect(find.byType(LiquidPill), findsNothing);
    // First frame: everything at zero.
    expect(find.text('0m'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(2));
    expect(_ringOf(tester).progress, 0);

    await tester.pump(const Duration(milliseconds: 500));
    expect(_ringOf(tester).progress, inExclusiveRange(0, .75));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('2h 15m'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(_ringOf(tester).progress, .75);
    // The controller retires on the frame after its last value.
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.transientCallbackCount, 0);

    // A tick lands at once and schedules nothing more.
    await _pump(tester, _ring(value: 134, progress: .74));
    expect(find.text('2h 14m'), findsOneWidget);
    expect(_ringOf(tester).progress, .74);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('Reduce Motion: the first frame is already final', (
    tester,
  ) async {
    await _pump(tester, _ring(), reduceMotion: true);
    expect(find.text('2h 15m'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(_ringOf(tester).progress, .75);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('semantics: the face and the stats', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _ring());
    // The final value from the first frame, not the count.
    expect(
      find.bySemanticsLabel('Time left, 2h 15m, 45m of 3h used'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('20 reels today, 1 day streak'),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    handle.dispose();
  });

  testWidgets('null value and null progress', (tester) async {
    await _pump(tester, _ring(value: null, progress: null));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('—'), findsOneWidget);
    expect(_ringOf(tester).progress, isNull);
  });

  testWidgets('210 px on any phone, smaller only in a narrower box', (
    tester,
  ) async {
    for (final width in const [390.0, 340.0, 320.0]) {
      await _pump(tester, _ring(), width: width, reduceMotion: true);
      expect(tester.getSize(find.byType(ProgressRing)), const Size(210, 210));
    }
    await _pump(tester, _ring(), width: 240, reduceMotion: true);
    expect(tester.getSize(find.byType(ProgressRing)), const Size(200, 200));
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    final t = AppTokens.forBrightness(brightness);

    testWidgets('${brightness.name}: the live accent, at 2x text on 360', (
      tester,
    ) async {
      await _pump(
        tester,
        AccentScope(
          light: AppTokens.light.pause,
          dark: AppTokens.dark.pause,
          child: _ring(accentEyebrow: true),
        ),
        brightness: brightness,
        width: 360,
        textScale: 2,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_ringOf(tester).palette, t.pause);
      expect(
        tester.widget<Text>(find.text('TIME LEFT')).style?.color,
        t.accentText(t.pause),
      );
      final play = tester.widget<Glyph>(_glyph(Assets.svg.playCircle));
      expect(play.color, t.accentText(t.pause));
      expect(tester.widget<Glyph>(_glyph(Assets.svg.flame)).color, t.streak);
    });
  }

  testWidgets('the eyebrow is ink-2 unless accentEyebrow', (tester) async {
    await _pump(tester, _ring(), reduceMotion: true);
    expect(
      tester.widget<Text>(find.text('TIME LEFT')).style?.color,
      AppTokens.light.ink2,
    );
  });

  group('AmbientLights', () {
    /// Each light as (rect in the box, centre colour, edge colour).
    List<(Rect, Color, Color)> lights(WidgetTester tester) {
      final origin = tester.getTopLeft(find.byType(AmbientLights));
      return [
        for (final e
            in find
                .descendant(
                  of: find.byType(AmbientLights),
                  matching: find.byType(DecoratedBox),
                )
                .evaluate())
          if (((e.widget as DecoratedBox).decoration as BoxDecoration).gradient
              case final RadialGradient g)
            (
              tester.getRect(find.byWidget(e.widget)).shift(-origin),
              g.colors.first,
              g.colors.last,
            ),
      ];
    }

    Widget host(AccentPalette light, AccentPalette dark) => SizedBox(
      width: 390,
      height: 1000,
      child: AccentScope(
        light: light,
        dark: dark,
        child: const Stack(children: [Positioned.fill(child: AmbientLights())]),
      ),
    );

    for (final brightness in Brightness.values) {
      final t = AppTokens.forBrightness(brightness);

      testWidgets('${brightness.name}: main and deep follow the AccentScope', (
        tester,
      ) async {
        Future<void> show(AccentPalette Function(AppTokens) p) => _pump(
          tester,
          host(p(AppTokens.light), p(AppTokens.dark)),
          brightness: brightness,
        );

        await show((t) => t.pause);
        expect(lights(tester), [
          (
            const Rect.fromLTWH(5, 45, 380, 380),
            t.pause.main.withValues(alpha: t.kAmb),
            t.pause.main.withValues(alpha: 0),
          ),
          (
            const Rect.fromLTWH(120, 560, 400, 400),
            t.pause.deep.withValues(alpha: t.kAmbDeep),
            t.pause.deep.withValues(alpha: 0),
          ),
        ]);

        await show((t) => t.blockAll);
        await tester.pumpAndSettle();
        expect(lights(tester).map((l) => l.$2).toList(), [
          t.blockAll.main.withValues(alpha: t.kAmb),
          t.blockAll.deep.withValues(alpha: t.kAmbDeep),
        ]);
      });
    }
  });
}
