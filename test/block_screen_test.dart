import 'dart:math' as math;

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/platform_channels/engine_channel.dart';
import 'package:detoxo/features/blocking/blocking.dart';
import 'package:detoxo/features/blocking/shared/data/repositories/engine_repository_impl.dart';
import 'package:detoxo/features/content_counter/content_counter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockChannel extends Mock implements EngineChannel {}

/// The block screen's wire shapes and copy. Two invariants live here: an
/// adult hit is never named (EVO-018), and the wire token `CURIOUS` never
/// reaches a user-visible string — the label is always "Conscious".
void main() {
  group('BlockScreenPayload', () {
    test('preview defaults are a reel block on the given plan', () {
      final p = BlockScreenPayload.preview();
      expect(p.referenceType, BlockReferenceType.reel);
      expect(p.blockReason, BlockReason.plan);
      expect(p.plan, BlockingPlan.blockAll);
      expect(p.todayCount, 12);
      expect(p.allowanceLeft, -1);
      expect(p.bankMs, -1);
      expect(p.opensToday, 7);
      expect(p.packageName, 'com.instagram.android');
      expect(p.offersOpenApp, isTrue);
      expect(p.offersUnblock, isFalse);
    });

    test('a zero count previews the sample 12, a real count shows itself', () {
      expect(BlockScreenPayload.preview(todayCount: 0).todayCount, 12);
      expect(BlockScreenPayload.preview(todayCount: 3).todayCount, 3);
    });

    test('toWire carries the wire tokens and CURIOUS verbatim', () {
      final w = BlockScreenPayload.preview(plan: BlockingPlan.curious).toWire();
      expect(w['referenceType'], 'REEL');
      expect(w['blockReason'], 'PLAN');
      expect(w['plan'], 'CURIOUS');
      expect(w['allowance'], 1);
    });

    test('survives a full wire round-trip', () {
      final original = BlockScreenPayload.preview(
        plan: BlockingPlan.oneReel,
        allowance: 5,
        todayCount: 3,
      ).copyWith(offersUnblock: true, appLabel: 'Instagram');
      expect(BlockScreenPayload.fromWire(original.toWire()), original);
    });

    test('fromWire defaults on null and garbage', () {
      expect(BlockScreenPayload.fromWire(null), BlockScreenPayload.preview());
      final p = BlockScreenPayload.fromWire(const {
        'referenceType': 'nope',
        'blockReason': 'nope',
        'plan': '',
        'todayCount': 'x',
      });
      expect(p.referenceType, BlockReferenceType.reel);
      expect(p.blockReason, BlockReason.plan);
      expect(p.plan, isNull);
      expect(p.todayCount, -1);
    });

    test('an adult hit is never named and never unblockable', () {
      const p = BlockScreenPayload(
        referenceType: BlockReferenceType.website,
        referenceId: 'example.test',
        displayName: 'example.test',
        appLabel: 'Chrome',
        blockReason: BlockReason.adult,
        plan: BlockingPlan.blockAll,
        offersUnblock: true,
      );
      final s = p.sanitised();
      expect(s.displayName, '');
      expect(s.referenceId, '');
      expect(s.appLabel, 'Chrome');
      expect(s.offersUnblock, isFalse);
      expect(s.plan, isNull);
    });

    test('only a plan block keeps its plan', () {
      const app = BlockScreenPayload(
        referenceType: BlockReferenceType.app,
        referenceId: 'com.a',
        displayName: 'A',
        blockReason: BlockReason.appBlock,
        plan: BlockingPlan.blockAll,
      );
      expect(app.sanitised().plan, isNull);
      expect(
        BlockScreenPayload.preview().sanitised().plan,
        BlockingPlan.blockAll,
      );
    });
  });

  group('planLabel', () {
    test('maps every plan to its user-facing name', () {
      expect(planLabel(BlockingPlan.curious), 'Conscious');
      expect(planLabel(BlockingPlan.oneReel), 'One Reel');
      expect(planLabel(BlockingPlan.oneReel, allowance: 5), 'Unblock');
      expect(planLabel(BlockingPlan.blockAll), 'Block All');
      expect(planLabel(BlockingPlan.paused), 'Paused');
      expect(planLabel(null), '');
    });

    test('the wire token never reaches a label', () {
      for (final plan in [...BlockingPlan.values, null]) {
        for (final allowance in [1, 5]) {
          expect(
            planLabel(plan, allowance: allowance).toLowerCase(),
            isNot(contains('curious')),
          );
        }
      }
    });
  });

  group('BlockScreenCopy', () {
    const style = BlockScreenStyle.defaults();

    test('a Conscious reel block reads as Conscious, never curious', () {
      final copy = BlockScreenCopy.from(
        BlockScreenPayload.preview(plan: BlockingPlan.curious, todayCount: 7),
        style,
      );
      expect(copy.headline, 'Instagram Reels is blocked by Detoxo');
      expect(copy.reason, 'Your Conscious time bank is empty');
      expect(copy.stats, [
        '7 reels today',
        '0:00 left in your bank',
        'Instagram opened 7 times today',
      ]);
      expect(copy.semanticsLabel.toLowerCase(), isNot(contains('curious')));
      expect(copy.meta.toLowerCase(), isNot(contains('curious')));
    });

    test(
      'a reel wall: Home icon, Open Detoxo filled, the way back counted',
      () {
        final copy = BlockScreenCopy.from(BlockScreenPayload.preview(), style);
        expect(copy.buttons.map((b) => b.label), [
          'Go home',
          'Open Detoxo',
          'Back to Instagram · 5',
        ]);
        expect(copy.buttons.map((b) => b.action), [
          'GO_HOME',
          'OPEN_APP',
          'DISMISS',
        ]);
        expect(copy.buttons[0].icon, isTrue);
        expect(copy.buttons[1].primary, isTrue);
        expect(copy.buttons[2].ghost && copy.buttons[2].locked, isTrue);
      },
    );

    test(
      'the ghost exit is locked while its countdown runs, instant when off',
      () {
        final counting = BlockScreenCopy.from(
          BlockScreenPayload.preview(),
          style,
        );
        final back = counting.buttons.last;
        expect(back.label, 'Back to Instagram · 5');
        expect(back.locked, isTrue);
        expect(back.ghost, isTrue);
        expect(back.action, 'DISMISS');
        expect(counting.buttons.where((b) => b.locked).length, 1);

        final instant = BlockScreenCopy.from(
          BlockScreenPayload.preview(),
          style.copyWith(backDelaySec: 0),
        );
        expect(instant.buttons.last.label, 'Back to Instagram');
        expect(instant.buttons.last.locked, isFalse);
      },
    );

    test('the opens line follows the usage layer and its toggle', () {
      final one = BlockScreenCopy.from(
        BlockScreenPayload.preview().copyWith(opensToday: 1),
        style,
      );
      expect(one.stats.last, 'Instagram opened 1 time today');
      final unknown = BlockScreenCopy.from(
        BlockScreenPayload.preview().copyWith(opensToday: -1),
        style,
      );
      expect(unknown.stats, ['12 reels today']);
      final off = BlockScreenCopy.from(
        BlockScreenPayload.preview(),
        style.copyWith(showOpens: false),
      );
      expect(off.stats, ['12 reels today']);
    });

    test('an Unblock-5 block names the allowance', () {
      final copy = BlockScreenCopy.from(
        BlockScreenPayload.preview(plan: BlockingPlan.oneReel, allowance: 5),
        style,
      );
      expect(copy.reason, 'You’ve watched your 5 reels');
      expect(copy.stats[1], '0 reels left');
      final one = BlockScreenCopy.from(
        BlockScreenPayload.preview(plan: BlockingPlan.oneReel, todayCount: 1),
        style,
      );
      expect(one.reason, 'You’ve watched your reel');
      expect(one.stats.first, '1 reel today');
    });

    test('an app wall keeps Home and Open Detoxo but has no way back in', () {
      const p = BlockScreenPayload(
        referenceType: BlockReferenceType.app,
        referenceId: 'com.instagram.android',
        displayName: 'Instagram',
        appLabel: 'Instagram',
        blockReason: BlockReason.appBlock,
        plan: BlockingPlan.blockAll,
      );
      final copy = BlockScreenCopy.from(p.sanitised(), style);
      expect(copy.reason, 'Locked in your App blocker');
      expect(copy.stats, isEmpty);
      expect(copy.meta, 'Locked in your App blocker');
      expect(copy.buttons.map((b) => b.label), ['Go home', 'Open Detoxo']);
      final allow = BlockScreenCopy.from(
        p.copyWith(offersUnblock: true).sanitised(),
        style,
      );
      expect(allow.buttons.map((b) => b.label), [
        'Go home',
        'Open Detoxo',
        'Allow for a while',
      ]);
      expect(allow.buttons.last.action, 'UNBLOCK');
      expect(allow.buttons.last.ghost, isTrue);
    });

    test('an adult web block is unnamed and offers the browser back', () {
      const p = BlockScreenPayload(
        referenceType: BlockReferenceType.website,
        referenceId: 'example.test',
        displayName: 'example.test',
        appLabel: 'Chrome',
        blockReason: BlockReason.adult,
        offersUnblock: true,
      );
      final copy = BlockScreenCopy.from(p.sanitised(), style);
      expect(copy.headline, 'Adult site blocked by Detoxo');
      expect(copy.headline, isNot(contains('example.test')));
      expect(copy.reason, 'Adult content (18+)');
      expect(copy.meta, 'Adult content (18+)');
      expect(copy.buttons.map((b) => b.label), [
        'Go home',
        'Open Detoxo',
        'Back to Chrome · 5',
      ]);
      expect(
        copy.spotlightLine,
        'Chrome is resting. Move your finger to find the light.',
      );
      expect(copy.faceDownLine, isNot(contains('example.test')));
    });

    test('a website wall names the host', () {
      const web = BlockScreenPayload(
        referenceType: BlockReferenceType.website,
        referenceId: 'reddit.com',
        displayName: 'reddit.com',
        appLabel: 'Chrome',
        blockReason: BlockReason.webRule,
      );
      expect(
        BlockScreenCopy.from(web, style).faceDownLine,
        'reddit.com can wait. Your peace can’t.',
      );
    });

    test('showCount off drops the count line only', () {
      final copy = BlockScreenCopy.from(
        BlockScreenPayload.preview(plan: BlockingPlan.curious, todayCount: 7),
        style.copyWith(showCount: false),
      );
      expect(copy.stats, [
        '0:00 left in your bank',
        'Instagram opened 7 times today',
      ]);
    });

    test('meta is the reason and every stat on one line', () {
      final copy = BlockScreenCopy.from(BlockScreenPayload.preview(), style);
      expect(
        copy.meta,
        'Block All is on · 12 reels today · Instagram opened 7 times today',
      );
      expect(copy.faceDownLine, 'Instagram can wait. Your peace can’t.');
      expect(
        copy.spotlightLine,
        'Instagram is resting. Move your finger to find the light.',
      );
    });
  });

  group('the wall palette', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
    }

    const fallback = Color(0xFF1C3D78); // BrandTint.FALLBACK
    // Every accent the wall can take: each palette main of both themes (the
    // live accent comes next), plus the native pre-push fallback.
    final primaries = {
      for (final t in const [AppTokens.light, AppTokens.dark])
        for (final p in t.palettes) p.main,
      fallback,
    };

    test('ink, muted and the accent as a label read on both grounds', () {
      for (final accent in primaries) {
        for (final dark in [false, true]) {
          final p = wallPaletteFor(dark: dark, accent: accent);
          final at = '$accent, dark: $dark';
          expect(
            contrast(p.ink, p.ground),
            greaterThanOrEqualTo(7),
            reason: at,
          );
          expect(
            contrast(p.muted, p.ground),
            greaterThanOrEqualTo(4.5),
            reason: at,
          );
          final label = legibleOn(accent, ground: p.ground, ink: p.ink);
          expect(
            contrast(label, p.ground),
            greaterThanOrEqualTo(4.5),
            reason: at,
          );
        }
      }
    });

    test('Face Down is the board ground; Spotlight carries the accent', () {
      final light = wallPaletteFor(dark: false, accent: fallback);
      expect(light.ground, const Color(0xFFECEFF4));
      expect(light.ink, const Color(0xFF12151B));
      expect(light.muted, const Color(0xFF5A6170));
      final mint = wallPaletteFor(dark: true, accent: const Color(0xFF37DFA0));
      final pink = wallPaletteFor(dark: true, accent: const Color(0xFFFF6FB0));
      expect(mint.ground, isNot(pink.ground));
      // The dark wall's ink and muted, for every accent a dark app uses.
      for (final palette in AppTokens.dark.palettes) {
        final p = wallPaletteFor(dark: true, accent: palette.main);
        expect(contrast(p.ink, p.ground), greaterThanOrEqualTo(17));
        expect(contrast(p.muted, p.ground), greaterThanOrEqualTo(7.8));
      }
    });

    test('legibleOn darkens Sky on the light wall, leaves ink alone', () {
      const sky = Color(0xFF2F6BFF);
      final p = wallPaletteFor(dark: false, accent: sky);
      expect(contrast(sky, p.ground), lessThan(4.5)); // 3.9:1
      final label = legibleOn(sky, ground: p.ground, ink: p.ink);
      expect(label, isNot(sky));
      expect(contrast(label, p.ground), greaterThanOrEqualTo(4.5));
      expect(legibleOn(p.ink, ground: p.ground, ink: p.ink), p.ink);
    });

    test('every palette main gives the primary button legible text', () {
      for (final t in const [AppTokens.light, AppTokens.dark]) {
        for (final palette in t.palettes) {
          final fill = legibleFill(palette.main);
          final at = '${palette.main}, ${t.brightness.name}';
          expect(
            contrast(onColorFor(fill), fill),
            greaterThanOrEqualTo(4.5),
            reason: at,
          );
          // Only Light over-main (#e5384f) needs darkening.
          if (palette.main != AppTokens.light.over.main) {
            expect(fill, palette.main, reason: at);
          }
        }
      }
    });

    test('the native fallback brand is already legible', () {
      expect(legibleFill(fallback), fallback);
    });
  });

  group('onColorFor', () {
    test('navy on a light fill, white on a deep one', () {
      const navy = Color(0xFF0B1326);
      expect(onColorFor(const Color(0xFF12A594)), navy);
      expect(onColorFor(const Color(0xFF44E2CD)), navy);
      expect(onColorFor(const Color(0xFF30A46C)), navy); // green
      expect(onColorFor(const Color(0xFFC63A3E)), Colors.white); // deep red
    });
  });

  group('BlockScreenStyle', () {
    test('defaults are on, count + opens shown, 5 s', () {
      const s = BlockScreenStyle.defaults();
      expect(s.enabled, isTrue);
      expect(s.showCount, isTrue);
      expect(s.showOpens, isTrue);
      expect(s.backDelaySec, 5);
    });

    test('survives a wire round-trip, writing its four keys only', () {
      const s = BlockScreenStyle(
        enabled: false,
        showCount: false,
        showOpens: false,
        backDelaySec: 0,
      );
      final w = s.toWire();
      expect(w, {
        'enabled': false,
        'showCount': false,
        'showOpens': false,
        'backDelaySec': 0,
      });
      expect(BlockScreenStyle.fromWire(w), s);
    });

    test(
      'an older build’s style still parses; its removed keys are ignored',
      () {
        final s = BlockScreenStyle.fromWire(const {
          'enabled': false,
          'theme': 'DARK',
          'background': 'USAGE_TINT',
          'design': 'QUOTES',
          'accentByUsage': true,
          'showCount': false,
          'showOpens': true,
          'backDelaySec': 5,
        });
        expect(s, const BlockScreenStyle(enabled: false, showCount: false));
        expect(s.toWire().keys, [
          'enabled',
          'showCount',
          'showOpens',
          'backDelaySec',
        ]);
      },
    );

    test('backDelaySec is clamped and tolerant', () {
      expect(
        BlockScreenStyle.fromWire(const {'backDelaySec': 900}).backDelaySec,
        60,
      );
      expect(
        BlockScreenStyle.fromWire(const {'backDelaySec': -3}).backDelaySec,
        0,
      );
      expect(
        BlockScreenStyle.fromWire(const {'backDelaySec': 'x'}).backDelaySec,
        5,
      );
    });

    test('fromWire defaults on null / empty / garbage', () {
      expect(
        BlockScreenStyle.fromWire(null),
        const BlockScreenStyle.defaults(),
      );
      expect(
        BlockScreenStyle.fromWire(const {}),
        const BlockScreenStyle.defaults(),
      );
      expect(
        BlockScreenStyle.fromWire(const {
          'enabled': 'x',
          'showCount': 3,
          'showOpens': null,
          'theme': 'weird',
        }),
        const BlockScreenStyle.defaults(),
      );
    });
  });

  group('the wall follows the app theme', () {
    test('the settings push carries the app theme for the wall', () async {
      final channel = _MockChannel();
      when(() => channel.pushSettings(any())).thenAnswer((_) async {});
      await EngineRepositoryImpl(channel).pushSettings(
        const AppSettings().copyWith(themeMode: AppThemeMode.light),
      );
      final pushed =
          verify(() => channel.pushSettings(captureAny())).captured.single
              as Map<String, dynamic>;
      expect(pushed['themeMode'], 'LIGHT');
    });
  });
}
