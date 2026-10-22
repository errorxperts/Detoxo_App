import 'dart:convert';
import 'dart:io';

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _cases() =>
    jsonDecode(File('test/fixtures/accent_cases.json').readAsStringSync())
        as Map<String, dynamic>;

/// A palette as ARGB ints: Color equality compares doubles, so two blends
/// of the same palettes can differ in the last bit.
List<int> _argb(AccentPalette p) => [
  p.main.toARGB32(),
  p.light.toARGB32(),
  p.deep.toARGB32(),
];

AccentMode _mode(String name) =>
    AccentMode.values.firstWhere((m) => m.name == name);

void main() {
  test('every shared fixture row resolves exactly (Kotlin reads it too)', () {
    final rows = (_cases()['cases'] as List).cast<Map<String, dynamic>>();
    expect(rows, hasLength(46));
    for (final c in rows) {
      final t = c['theme'] == 'dark' ? AppTokens.dark : AppTokens.light;
      final left = c['pauseLeftMs'] as int?;
      final p = resolveAccent(
        t,
        _mode(c['mode'] as String),
        used: (c['used'] as num).toDouble(),
        pauseLeft: left == null ? null : Duration(milliseconds: left),
      );
      expect(
        [p.main.toARGB32(), p.light.toARGB32(), p.deep.toARGB32()],
        [c['main'], c['light'], c['deep']],
        reason: '$c',
      );
    }
  });

  group('invariants', () {
    const t = AppTokens.dark;

    test('calm usage keeps each mode its own palette', () {
      expect(resolveAccent(t, AccentMode.none, used: .59), t.brand);
      expect(resolveAccent(t, AccentMode.blockAll, used: .6), t.blockAll);
      expect(resolveAccent(t, AccentMode.conscious), t.conscious);
      expect(resolveAccent(t, AccentMode.oneReel), t.oneReel);
    });

    test(
      'no mode reaches over at the limit; a mode stops at an 80 % blend',
      () {
        expect(
          _argb(resolveAccent(t, AccentMode.none, used: 1)),
          _argb(t.over),
        );
        expect(
          _argb(resolveAccent(t, AccentMode.none, used: 3)),
          _argb(t.over),
        );
        expect(
          _argb(resolveAccent(t, AccentMode.blockAll, used: 1)),
          _argb(AccentPalette.lerp(t.blockAll, t.over, .8)),
        );
      },
    );

    test('Pause warms only in its last two minutes; N reels stay pause', () {
      expect(
        resolveAccent(
          t,
          AccentMode.pause,
          pauseLeft: const Duration(minutes: 5),
        ),
        t.pause,
      );
      expect(
        _argb(resolveAccent(t, AccentMode.pause, pauseLeft: Duration.zero)),
        _argb(t.over),
      );
      expect(resolveAccent(t, AccentMode.pause, used: 1), t.pause);
    });
  });

  group('mode icon filter', () {
    test("an accent at the icons' own hue, saturate 1, is the identity", () {
      final c = const HSVColor.fromAHSV(
        1,
        AppTokens.iconBaseHue,
        .7,
        .9,
      ).toColor();
      final m = accentIconMatrix(AccentPalette(c, c, c), saturate: 1);
      const identity = [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0];
      // The 8-bit colour moves the hue a fraction of a degree off 214°.
      for (var i = 0; i < identity.length; i++) {
        expect(m[i], closeTo(identity[i], 5e-3), reason: 'entry $i');
      }
      expect(m.sublist(15), [0, 0, 0, 1, 0]);
    });

    test('opacity scales alpha only', () {
      final m = accentIconMatrix(AppTokens.dark.pause, opacity: .8);
      expect(m.sublist(15), [0, 0, 0, .8, 0]);
    });
  });

  group('AccentScope', () {
    const a = AppTokens.light;
    const b = AppTokens.dark;

    Future<void> pump(
      WidgetTester tester,
      AccentPalette light, {
      Object? glideKey,
      bool reduceMotion = false,
      void Function(AccentPalette)? onBuild,
    }) => tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Theme(
          data: AppTheme.light(),
          child: AccentScope(
            light: light,
            dark: b.brand,
            glideKey: glideKey,
            child: Builder(
              builder: (context) {
                onBuild?.call(context.accent);
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );

    testWidgets('glides 1 s on the CSS ease curve', (tester) async {
      late AccentPalette seen;
      void read(AccentPalette p) => seen = p;
      await pump(tester, a.brand, onBuild: read);
      expect(seen, a.brand);
      await pump(tester, a.over, onBuild: read);
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        seen,
        AccentPalette.lerp(a.brand, a.over, Curves.ease.transform(.5)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(seen, a.over);
    });

    testWidgets('Reduce Motion makes a change instant', (tester) async {
      late AccentPalette seen;
      await pump(tester, a.brand, reduceMotion: true);
      await pump(tester, a.over, reduceMotion: true, onBuild: (p) => seen = p);
      expect(seen, a.over);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('a change under the same glideKey snaps (pause ticks)', (
      tester,
    ) async {
      late AccentPalette seen;
      await pump(tester, a.pause, glideKey: 'pause');
      await pump(tester, a.over, glideKey: 'pause', onBuild: (p) => seen = p);
      expect(seen, a.over);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('no scope: the static brand', (tester) async {
      late AccentPalette seen;
      await tester.pumpWidget(
        Theme(
          data: AppTheme.dark(),
          child: Builder(
            builder: (context) {
              seen = context.accent;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen, b.brand);
    });
  });
}
