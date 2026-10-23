import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// A screen with one button that runs [onTap] with its context.
Widget _app(
  void Function(BuildContext) onTap, {
  bool reduceMotion = false,
  bool accessibleNavigation = false,
}) => MaterialApp(
  theme: AppTheme.dark(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      disableAnimations: reduceMotion,
      accessibleNavigation: accessibleNavigation,
    ),
    child: child!,
  ),
  home: Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: TextButton(
          onPressed: () => onTap(context),
          child: const Text('open'),
        ),
      ),
    ),
  ),
);

Future<void> _openSheet(
  WidgetTester tester, {
  bool dismissible = true,
  bool reduceMotion = false,
}) async {
  await tester.pumpWidget(
    _app(
      (context) => GlassBottomSheet.show<void>(
        context: context,
        title: 'Sheet',
        dismissible: dismissible,
        child: const SizedBox(height: 120, child: Text('body')),
      ),
      reduceMotion: reduceMotion,
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  expect(find.text('body'), findsOneWidget);
}

void main() {
  group('GlassBottomSheet', () {
    testWidgets('the spec chrome: sheet surface, grabber, header title', (
      tester,
    ) async {
      // A 360 × 780 phone: wider screens centre the sheet at Material's
      // 640 dp cap.
      tester.view
        ..physicalSize = const Size(1080, 2340)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await _openSheet(tester);
      final surface = tester.widget<GlassContainer>(
        find.ancestor(
          of: find.text('body'),
          matching: find.byType(GlassContainer),
        ),
      );
      expect(surface.surface, DxSurface.sheet);
      expect(
        tester.getSize(find.byKey(GlassBottomSheet.grabberKey)).height,
        30,
      );
      // Inset 10 from the screen's sides and bottom.
      final rect = tester.getRect(find.byWidget(surface));
      expect(rect.left, 10);
      expect(rect.bottom, 780 - 10);
      // The scrim blurs behind it, as the sheet does, once it has settled.
      expect(find.byType(BackdropFilter), findsNWidgets(2));
      expect(
        tester
            .widgetList<BackdropFilter>(find.byType(BackdropFilter))
            .every((b) => b.enabled),
        isTrue,
      );
    });

    testWidgets('mid-slide the sheet holds its blur and keeps its state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          (context) => GlassBottomSheet.show<void>(
            context: context,
            child: const SizedBox(height: 120, child: Text('body')),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      BackdropFilter sheetBlur() => tester.widget<BackdropFilter>(
        find.descendant(
          of: find.byType(GlassContainer),
          matching: find.byType(BackdropFilter),
        ),
      );
      final body = tester.element(find.text('body'));
      expect(sheetBlur().enabled, isFalse);

      await tester.pumpAndSettle();
      expect(sheetBlur().enabled, isTrue);
      expect(
        tester.element(find.text('body')),
        same(body),
        reason: 'the content was not rebuilt from scratch',
      );
    });

    testWidgets('a 120 px drag closes it', (tester) async {
      await _openSheet(tester);
      await tester.drag(
        find.byKey(GlassBottomSheet.grabberKey),
        const Offset(0, 120),
      );
      await tester.pumpAndSettle();
      expect(find.text('body'), findsNothing);
    });

    testWidgets('an 80 px drag springs back', (tester) async {
      await _openSheet(tester);
      final rest = tester.getTopLeft(find.text('body'));
      await tester.drag(
        find.byKey(GlassBottomSheet.grabberKey),
        const Offset(0, 80),
      );
      await tester.pumpAndSettle();
      expect(find.text('body'), findsOneWidget);
      expect(tester.getTopLeft(find.text('body')), rest);
    });

    testWidgets('dismissible: false ignores the barrier, back and drag', (
      tester,
    ) async {
      await _openSheet(tester, dismissible: false);

      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.text('body'), findsOneWidget, reason: 'barrier');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('body'), findsOneWidget, reason: 'back');

      await tester.drag(
        find.byKey(GlassBottomSheet.grabberKey),
        const Offset(0, 200),
      );
      await tester.pumpAndSettle();
      expect(find.text('body'), findsOneWidget, reason: 'drag');
    });

    testWidgets('a refused 120 px drag springs back', (tester) async {
      await tester.pumpWidget(
        _app(
          (context) => GlassBottomSheet.show<void>(
            context: context,
            child: const PopScope(canPop: false, child: Text('held')),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final rest = tester.getTopLeft(find.text('held'));
      await tester.drag(
        find.byKey(GlassBottomSheet.grabberKey),
        const Offset(0, 120),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('held')), rest);
    });

    testWidgets('a barrier tap closes a dismissible sheet', (tester) async {
      await _openSheet(tester);
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.text('body'), findsNothing);
    });

    testWidgets('it slides 450 ms in, 300 out; not at all under Reduce '
        'Motion', (tester) async {
      ModalRoute<dynamic> route() =>
          ModalRoute.of(tester.element(find.text('body')))!;
      Duration duration() => route().transitionDuration;

      await _openSheet(tester);
      expect(duration(), AppDurations.sheet);
      expect(route().reverseTransitionDuration, AppDurations.sheetOut);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await _openSheet(tester, reduceMotion: true);
      expect(duration(), Duration.zero);
    });
  });

  group('AppDialog', () {
    testWidgets('confirm stacks the confirm above the cancel', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _app(
          (context) async => result = await AppDialog.confirm(
            context: context,
            title: 'Delete rule?',
            confirmLabel: 'Delete',
            cancelLabel: 'Keep',
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.text('Delete')).dy,
        lessThan(tester.getCenter(find.text('Keep')).dy),
      );

      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();
      expect(result, isFalse);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });
  });

  group('GlassToast', () {
    Duration shown(WidgetTester tester) =>
        tester.widget<SnackBar>(find.byType(SnackBar)).duration;

    testWidgets('a glass pill, ink glyph and label; 4 s', (tester) async {
      await tester.pumpWidget(
        _app((c) => GlassToast.show(c, 'Saved', tone: AppTone.success)),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      expect(find.text('Saved'), findsOneWidget);
      // Success wears the spec check glyph, in ink.
      expect(
        tester.widget<Glyph>(find.byType(Glyph)).asset.path,
        Assets.svg.check.path,
      );
      expect(
        tester.widget<SvgPicture>(find.byType(SvgPicture)).colorFilter,
        ColorFilter.mode(AppTokens.dark.ink, BlendMode.srcIn),
      );
      expect(find.byType(AppPressable), findsNothing, reason: 'no action');
      expect(shown(tester), const Duration(seconds: 4));
    });

    testWidgets('Undo calls back and hides the toast; 6 s', (tester) async {
      var undone = 0;
      await tester.pumpWidget(
        _app(
          (c) => GlassToast.show(
            c,
            'Instagram unblocked',
            action: (label: 'Undo', onPressed: () => undone++),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(shown(tester), const Duration(seconds: 6));

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(undone, 1);
      expect(find.text('Instagram unblocked'), findsNothing);
    });

    testWidgets('over an open sheet it floats on top, not under it', (
      tester,
    ) async {
      var undone = 0;
      await tester.pumpWidget(
        _app(
          (context) => GlassBottomSheet.show<void>(
            context: context,
            child: Builder(
              builder: (sheet) => TextButton(
                onPressed: () => GlassToast.show(
                  sheet,
                  'Couldn’t start',
                  action: (label: 'Retry', onPressed: () => undone++),
                ),
                child: const Text('fail'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('fail'));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(
        tester.getRect(find.text('Couldn’t start')).bottom,
        lessThan(tester.getRect(find.text('fail')).top),
      );
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(undone, 1);
      expect(find.text('Couldn’t start'), findsNothing);

      await tester.tap(find.text('fail'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.text('Couldn’t start'), findsNothing, reason: 'times out');
    });

    testWidgets('10 s while a screen reader navigates', (tester) async {
      await tester.pumpWidget(
        _app((c) => GlassToast.show(c, 'Saved'), accessibleNavigation: true),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      expect(shown(tester), const Duration(seconds: 10));
    });
  });
}
