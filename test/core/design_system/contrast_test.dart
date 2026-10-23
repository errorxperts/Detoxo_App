import 'dart:math' as math;

import 'package:detoxo/core/design_system/tokens/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// WCAG contrast of every text and icon token on the surfaces it is drawn on,
// in both themes: 4.5:1 for text, 3:1 for icons (chevrons, the focus ring, the
// streak flame, the knob glyphs). Translucent surfaces are composited the way
// the screen stacks them: panel and sheet over either end of the bg gradient,
// glass over the bg and the cards, and the ring disc under its accent wash.
//
// Exempt: the status dots. In Light they are 2.2–2.8:1 on card-to, below the
// 3:1 icon rule, but a dot never carries status alone: the word beside it does,
// and status text uses statusText(), which is checked here.

/// Named opaque grounds, so a failure names the surface.
typedef _Grounds = Map<String, Color>;

/// WCAG contrast of [fg] on the opaque [ground]. A translucent [fg] is
/// composited over [ground] first, as it is on screen.
double _contrast(Color fg, Color ground) {
  final a = Color.alphaBlend(fg, ground).computeLuminance();
  final b = ground.computeLuminance();
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

/// Every translucent fill in [fills] composited over every ground in [grounds].
_Grounds _over(_Grounds fills, _Grounds grounds) => {
  for (final f in fills.entries)
    for (final g in grounds.entries)
      '${f.key} over ${g.key}': Color.alphaBlend(f.value, g.value),
};

void _expectContrast(String what, Color fg, _Grounds grounds, double min) {
  for (final MapEntry(key: ground, :value) in grounds.entries) {
    expect(
      _contrast(fg, value),
      greaterThanOrEqualTo(min),
      reason: '$what on $ground',
    );
  }
}

void main() {
  for (final t in const [AppTokens.light, AppTokens.dark]) {
    group(t.brightness.name, () {
      final palettes = {
        'brand': t.brand,
        'blockAll': t.blockAll,
        'conscious': t.conscious,
        'pause': t.pause,
        'oneReel': t.oneReel,
        'over': t.over,
      };
      final bg = {'bgTop': t.bgTop, 'bgBottom': t.bgBottom};
      final card = {'cardFrom': t.cardFrom, 'cardTo': t.cardTo};
      final panel = _over({
        'panelTop': t.panelTop,
        'panelBottom': t.panelBottom,
      }, bg);
      final glass = _over(
        {'glassTop': t.glassTop, 'glassBottom': t.glassBottom},
        {...bg, ...card},
      );
      final sheet = _over({
        'sheetTop': t.sheetTop,
        'sheetBottom': t.sheetBottom,
      }, bg);
      // The ring disc always carries the live accent's wash.
      _Grounds disc(String name, AccentPalette p) => _over(
        {'$name wash': p.main.withValues(alpha: AppTokens.discWash)},
        {'ringDiscFrom': t.ringDiscFrom, 'ringDiscTo': t.ringDiscTo},
      );
      final text = {
        ...bg,
        ...card,
        'optionBase': t.optionBase,
        for (final MapEntry(:key, :value) in palettes.entries)
          ...disc(key, value),
        ...panel,
        ...glass,
        ...sheet,
        'buttonFrom': t.buttonFrom,
        'buttonTo': t.buttonTo,
      };

      test('every palette is checked', () {
        expect(palettes.values, t.palettes);
      });

      test('ink and ink-2 read at 4.5:1 on every surface', () {
        _expectContrast('ink', t.ink, text, 4.5);
        _expectContrast('ink-2', t.ink2, text, 4.5);
        // The slide label is `button` in ink-2 on the track.
        _expectContrast('ink-2', t.ink2, {
          'trackFrom': t.trackFrom,
          'trackTo': t.trackTo,
        }, 4.5);
      });

      test('ink-3 chevrons, the focus ring and the streak reach 3:1', () {
        _expectContrast('ink-3', t.ink3, {
          ...bg,
          ...card,
          ...panel,
          ...sheet,
        }, 3);
        _expectContrast('focus', t.focus, text, 3);
        _expectContrast('streak', t.streak, text, 3);
      });

      test('accent text and mode card labels read at 4.5:1 per palette', () {
        for (final MapEntry(key: name, value: p) in palettes.entries) {
          // bundle.css --option-bg / --chip-bg: opaque mixes into option-base.
          final option = Color.lerp(t.optionBase, p.main, t.kOption)!;
          final chip = Color.lerp(t.optionBase, p.main, t.kChip)!;
          _expectContrast('accentText($name)', t.accentText(p), {
            ...bg,
            ...card,
            'optionBase': t.optionBase,
            'optionBg($name)': option,
            ...disc(name, p),
          }, 4.5);
          // Idle labels sit on the plain option-base card.
          _expectContrast('ink-2', t.ink2, {'optionBase': t.optionBase}, 4.5);
          // The selected option's label (--opt-selected).
          final selected = t.brightness == Brightness.light
              ? t.accentText(p)
              : t.ink;
          _expectContrast('selected label', selected, {
            'chipBg($name)': chip,
          }, 4.5);
        }
      });

      test('status words and destructive text read at 4.5:1', () {
        final grounds = {...bg, ...card, ...panel, ...glass, ...sheet};
        _expectContrast(
          'statusText(statusOn)',
          t.statusText(t.statusOn),
          grounds,
          4.5,
        );
        _expectContrast(
          'statusText(statusSetup)',
          t.statusText(t.statusSetup),
          grounds,
          4.5,
        );
        _expectContrast('accentText(over)', t.accentText(t.over), grounds, 4.5);
      });

      test('ink on a brand-main fill reads at 4.5:1', () {
        // The neutral tone ink, not white: white is 3.84:1 on Light brand-main.
        _expectContrast('neutral tone ink', ConfirmTone.neutral.ink, {
          'brand.main': t.brand.main,
        }, 4.5);
      });

      test('every tone glyph on the slide knob reaches 3:1', () {
        for (final tone in ConfirmTone.values) {
          _expectContrast('${tone.name} knob glyph', tone.knob, {
            'knob': t.knob,
          }, 3);
        }
      });

      test('tab bar labels read at 4.5:1 per palette', () {
        // The 13 px label band spans 60–90 % of the lens's vertical sheen
        // and 60–80 % of the bar's glass gradient, over the bg fade.
        final glass = _over({
          'glass@60%': Color.lerp(t.glassTop, t.glassBottom, .6)!,
          'glass@80%': Color.lerp(t.glassTop, t.glassBottom, .8)!,
        }, bg);
        _expectContrast('idle tab label', t.ink2, glass, 4.5);
        final dark = t.brightness == Brightness.dark;
        var accentFails = false;
        for (final MapEntry(key: name, value: p) in palettes.entries) {
          final lens = _over({
            'lens@60%': Color.lerp(t.lensHi, t.lensLo, .6)!,
            'lens@90%': Color.lerp(t.lensHi, t.lensLo, .9)!,
          }, _over({'$name tint': p.main.withValues(alpha: t.kTab)}, glass));
          // AppTabBar: accent text in Light, ink in Dark.
          _expectContrast(
            'current tab label',
            dark ? t.ink : t.accentText(p),
            lens,
            4.5,
          );
          accentFails |= lens.values.any(
            (g) => _contrast(t.accentText(p), g) < 4.5,
          );
        }
        // Why Dark falls back to ink: its accent text misses 4.5:1 on the
        // lens for some palette. Light's never does.
        expect(accentFails, dark);
      });

      test('Session sheet controls read at their minimums', () {
        // Quick picks: ink-2 on control, the selected label on control-on
        // (accentText in Light, ink in Dark), glyphs in accentText(brand).
        _expectContrast('ink-2', t.ink2, {'control': t.control}, 4.5);
        final selected = t.brightness == Brightness.light
            ? t.accentText(t.brand)
            : t.ink;
        _expectContrast('selected pick', selected, {
          'controlOn': t.controlOn,
        }, 4.5);
        _expectContrast('stepper glyph', t.accentText(t.brand), {
          'control': t.control,
        }, 3);
        // The 20 px label box spans 30–70 % of the 52 px vertical gradient.
        // Light white is 4.17:1 on the top stop alone but 4.66:1 at 30 %.
        Color band(Color from, Color to, double at) =>
            Color.lerp(from, to, at)!;
        _expectContrast('start ink', t.startInk, {
          'start@30%': band(t.startFrom, t.startTo, .3),
          'start@70%': band(t.startFrom, t.startTo, .7),
        }, 4.5);
        // Light white is 4.49:1 on the top stop alone; the label band passes.
        _expectContrast('started ink', t.startedInk, {
          'started@30%': band(t.startedFrom, t.startedTo, .3),
          'started@70%': band(t.startedFrom, t.startedTo, .7),
        }, 4.5);
      });
    });
  }

  test('every tone ink reads at 4.5:1 on its 55 % stop', () {
    // The slide label sits over stop b once the fill passes it. Critical ink
    // on the end stop c is 4.45:1, but the centred label never reaches c.
    for (final tone in ConfirmTone.values) {
      _expectContrast('${tone.name} ink', tone.ink, {'b': tone.b}, 4.5);
    }
  });

  test('the spec Light ink-3 is below 3:1 on card-to, hence the override', () {
    const spec = Color(0xFF8A93A6); // tool/design/tokens.json, ink-3 light
    expect(_contrast(spec, AppTokens.light.cardTo), lessThan(3));
    expect(AppTokens.light.ink3, isNot(spec));
  });
}
