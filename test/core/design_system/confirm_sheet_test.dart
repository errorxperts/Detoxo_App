import 'dart:async';
import 'dart:math' as math;

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _action = 'Slide to unblock';
const _title = 'Unblock Instagram?';
const _message = 'It gets blocked again when the time is up.';

final _knob = find.byKey(ConfirmSheet.knobKey);
final _track = find.byKey(ConfirmSheet.trackKey);

/// Pumps a screen, opens a caution ConfirmSheet on it and lets the sheet
/// slide in (the wait is then 600 ms old). Returns the sheet's answer.
Future<Future<bool>> _open(
  WidgetTester tester, {
  ThemeData? theme,
  String title = _title,
  String message = _message,
  Widget? content,
  double textScale = 1,
}) async {
  final result = Completer<bool>();
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => result.complete(
                ConfirmSheet.show(
                  context,
                  icon: Icon3d(Assets.images.icons.iconAppBlocker, size: 58),
                  title: title,
                  message: message,
                  content: content,
                  action: _action,
                  cancel: 'Keep it blocked',
                  tone: ConfirmTone.caution,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  // Past the slide-in; the timings below count from here.
  await tester.pump(const Duration(milliseconds: 600));
  return result.future;
}

/// Runs the rest of the 5 s wait and the ready nudge.
Future<void> _ready(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

double _travel(WidgetTester tester) => tester.getSize(_track).width - 64;

/// Puts a finger on the knob and slides it [share] of the travel.
Future<TestGesture> _slide(WidgetTester tester, double share) async {
  final g = await tester.startGesture(tester.getCenter(_knob));
  await g.moveBy(Offset(_travel(tester) * share, 0));
  await tester.pump();
  return g;
}

/// Whether [future] has completed, after the microtasks ran.
Future<bool> _isDone(Future<bool> future) async {
  var done = false;
  unawaited(future.then((_) => done = true));
  await Future<void>.value();
  return done;
}

Finder _glyph(SvgGenImage asset) =>
    find.byWidgetPredicate((w) => w is Glyph && w.asset.path == asset.path);

double _contrast(Color fg, Color ground) {
  final a = Color.alphaBlend(fg, ground).computeLuminance();
  final b = ground.computeLuminance();
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

void main() {
  testWidgets('the wait: inert, counting down, announced disabled', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _open(tester);
    expect(find.text('Take a breath…'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(
      tester.getSemantics(_knob),
      isSemantics(
        label: '$_action, available in 5 seconds',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );

    // A full drag before the wait ends does nothing.
    final rest = tester.getTopLeft(_knob);
    await tester.drag(_knob, Offset(_travel(tester), 0));
    await tester.pump();
    expect(tester.getTopLeft(_knob), rest);
    expect(find.text('Confirmed'), findsNothing);

    await tester.pump(const Duration(milliseconds: 3600)); // 4.2 s
    expect(
      tester.getSemantics(_knob),
      isSemantics(label: '$_action, available in 1 second', isEnabled: false),
    );

    // Ready at 5 s: white knob with chevrons, nudging 10 px once.
    await tester.pump(const Duration(milliseconds: 800));
    expect(_glyph(Assets.svg.chevronsRight), findsOneWidget);
    expect(find.text(_action), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getTopLeft(_knob).dx - rest.dx, closeTo(10, 0.5));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(_knob), rest);
    expect(
      tester.getSemantics(_knob),
      isSemantics(label: _action, isButton: true, isEnabled: true),
    );
    semantics.dispose();
  });

  testWidgets('a release below 88 % springs back and stays open', (
    tester,
  ) async {
    final result = await _open(tester);
    await _ready(tester);
    final rest = tester.getTopLeft(_knob);

    for (final share in [0.5, 0.875]) {
      final g = await _slide(tester, share);
      expect(find.text('Release to confirm'), findsNothing);
      await g.up();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(_knob), rest, reason: '$share');
      expect(find.text('Confirmed'), findsNothing);
      expect(await _isDone(result), isFalse);
    }
  });

  testWidgets('88 % or more: release to confirm, then true after 1 s', (
    tester,
  ) async {
    final result = await _open(tester);
    await _ready(tester);

    final g = await _slide(tester, 0.885);
    // Both copies of the label (track and fill) switch.
    expect(find.text('Release to confirm'), findsWidgets);
    await g.up();
    await tester.pump();
    expect(find.text('Confirmed'), findsWidgets);
    expect(_glyph(Assets.svg.check), findsOneWidget);

    // The confirmed second holds against back and the barrier.
    await tester.binding.handlePopRoute();
    await tester.tapAt(const Offset(20, 20));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text(_title), findsOneWidget);
    expect(await _isDone(result), isFalse);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text(_title), findsNothing);
    expect(await result, isTrue);
  });

  testWidgets('the label is painted twice, clipped either side of the fill', (
    tester,
  ) async {
    await _open(tester, theme: AppTheme.dark());
    await _ready(tester);
    final g = await _slide(tester, 0.6);
    final edge = 0.6 * _travel(tester) + 64;

    final copies = find.text(_action);
    expect(copies, findsNWidgets(2));
    final bands = {
      for (final e in copies.evaluate())
        (e.widget as Text).style!.color: () {
          final clip = tester.renderObject<RenderClipRect>(
            find
                .ancestor(
                  of: find.byWidget(e.widget),
                  matching: find.byType(ClipRect),
                )
                .first,
          );
          return clip.clipper!.getClip(clip.size);
        }(),
    };
    final ink2 = bands[AppTokens.dark.ink2]!;
    final onFill = bands[ConfirmTone.caution.ink]!;
    expect(ink2.left, closeTo(edge, 0.5));
    expect(onFill.left, 0);
    expect(onFill.right, closeTo(edge, 0.5));

    await g.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a finger tap hints for 1.5 s; it never confirms', (
    tester,
  ) async {
    final result = await _open(tester);
    await _ready(tester);
    await tester.tap(_knob);
    await tester.pump();
    expect(find.text('Slide all the way →'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('Slide all the way →'), findsNothing);
    expect(find.text(_action), findsOneWidget);
    expect(await _isDone(result), isFalse);
  });

  testWidgets('after the wait a semantic tap confirms', (tester) async {
    final semantics = tester.ensureSemantics();
    final result = await _open(tester);
    await _ready(tester);
    tester.semantics.tap(find.semantics.byLabel(_action));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    semantics.dispose();
  });

  for (final (name, key) in [
    ('Enter', LogicalKeyboardKey.enter),
    ('Space', LogicalKeyboardKey.space),
  ]) {
    testWidgets('after the wait $name on the knob confirms', (tester) async {
      final result = await _open(tester);
      await _ready(tester);
      Focus.of(tester.element(_knob)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(key);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
    });
  }

  testWidgets('Reduce Motion keeps the full 5 s wait', (tester) async {
    // Platform "remove animations" (a default controller would run at 5 %)
    // plus the MediaQuery flag it feeds.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final semantics = tester.ensureSemantics();

    await _open(tester);
    await tester.pump(const Duration(milliseconds: 3400)); // 4 s
    expect(tester.getSemantics(_knob), isSemantics(isEnabled: false));
    await tester.pump(const Duration(seconds: 1)); // 5 s
    expect(
      tester.getSemantics(_knob),
      isSemantics(label: _action, isEnabled: true),
    );
    // No nudge.
    final rest = tester.getTopLeft(_knob);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getTopLeft(_knob), rest);
    semantics.dispose();
  });

  group('resolves false', () {
    testWidgets('on cancel', (tester) async {
      final result = await _open(tester);
      await tester.tap(find.text('Keep it blocked'));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });

    testWidgets('on a barrier tap and on back', (tester) async {
      var result = await _open(tester);
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(await result, isFalse);

      result = await _open(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });

    testWidgets('on a 120 px grabber drag; 60 px stays open', (tester) async {
      final result = await _open(tester);
      await tester.drag(
        find.byKey(GlassBottomSheet.grabberKey),
        const Offset(0, 60),
      );
      await tester.pumpAndSettle();
      expect(find.text(_title), findsOneWidget);

      await tester.drag(
        find.byKey(GlassBottomSheet.grabberKey),
        const Offset(0, 120),
      );
      await tester.pumpAndSettle();
      expect(find.text(_title), findsNothing);
      expect(await result, isFalse);
    });
  });

  testWidgets('layout: well, header title, message, content, track', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _open(tester, content: const Text('15 min'));
    expect(tester.getSize(_track).height, 64);
    expect(tester.getSize(_knob), const Size.square(56));
    expect(tester.widget<Text>(find.text(_title)).maxLines, 2);
    expect(tester.widget<Text>(find.text(_message)).maxLines, 3);
    expect(tester.getSemantics(find.text(_title)), isSemantics(isHeader: true));
    final content = tester.getCenter(find.text('15 min')).dy;
    expect(content, greaterThan(tester.getBottomLeft(find.text(_message)).dy));
    expect(content, lessThan(tester.getTopLeft(_track).dy));
    semantics.dispose();
  });

  testWidgets('2x text on a 360 dp phone: no overflow, the body scrolls', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1080, 1920)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await _open(
      tester,
      textScale: 2,
      title: 'Lift the Work hours rule for a while?',
      message:
          'You have 2 overrides left this week. It locks again when '
          'the time is up.',
      content: const Column(
        children: [Text('5 min'), Text('15 min'), Text('30 min')],
      ),
    );
    expect(tester.takeException(), isNull);

    final cancel = find.text('Keep it blocked');
    expect(
      find.ancestor(of: cancel, matching: find.byType(SecondaryButton)),
      findsOneWidget,
      reason: 'a flat text cancel',
    );
    final before = tester.getTopLeft(cancel).dy;
    await tester.drag(find.text('15 min'), const Offset(0, -300));
    await tester.pump();
    expect(tester.getTopLeft(cancel).dy, lessThan(before));
    expect(tester.takeException(), isNull);
  });

  test('waitSeconds is asserted to 1..30', () {
    expect(
      () => ConfirmSheet.show(
        _FakeContext(),
        icon: const SizedBox(),
        title: _title,
        action: _action,
        cancel: 'Keep it blocked',
        tone: ConfirmTone.caution,
        waitSeconds: 31,
      ),
      throwsAssertionError,
    );
  });

  group('waitKnob', () {
    test('Light: the knob at 55 %', () {
      expect(
        ConfirmSheet.waitKnob(AppTokens.light),
        AppTokens.light.knob.withValues(alpha: 0.55),
      );
    });

    test('Dark: the track mixed 18 % toward the knob, about rgb(62,65,77)', () {
      final c = ConfirmSheet.waitKnob(AppTokens.dark);
      expect(c.a, 1);
      expect((c.r * 255).round(), inInclusiveRange(62, 63));
      expect((c.g * 255).round(), inInclusiveRange(65, 66));
      expect((c.b * 255).round(), inInclusiveRange(77, 78));
    });

    test('the countdown in ink-2 reads at 4.5:1 on it, both themes', () {
      for (final t in [AppTokens.light, AppTokens.dark]) {
        for (final track in [t.trackFrom, t.trackTo]) {
          final knob = Color.alphaBlend(ConfirmSheet.waitKnob(t), track);
          expect(
            _contrast(t.ink2, knob),
            greaterThanOrEqualTo(4.5),
            reason: '${t.brightness}',
          );
        }
      }
    });
  });
}

/// Enough of a context for the assert, which runs before any lookup.
class _FakeContext extends Fake implements BuildContext {}
