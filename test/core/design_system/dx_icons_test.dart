import 'dart:ui' show ImageFilter;

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child, {bool dark = false}) =>
    tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        home: Center(child: child),
      ),
    );

ImageFilter _blur(double sigma) =>
    ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal);

final _modeIcon = Assets.images.icons.iconPause;

void main() {
  group('Icon3d', () {
    testWidgets('keeps its own colour unless tinted; decorative', (
      tester,
    ) async {
      await _pump(tester, Icon3d(Assets.images.icons.iconAppBlocker, size: 56));
      expect(find.byType(ColorFiltered), findsNothing);
      expect(tester.getSize(find.byType(Icon3d)), const Size(56, 56));
      expect(
        tester.widget<Image>(find.byType(Image)).excludeFromSemantics,
        true,
      );
    });

    testWidgets('a selected mode icon wears the live accent, vivid', (
      tester,
    ) async {
      const accent = AppTokens.light;
      await _pump(
        tester,
        AccentScope(
          light: accent.conscious,
          dark: accent.conscious,
          child: Icon3d(_modeIcon, size: 34, accentTint: true),
        ),
      );
      expect(
        tester.widget<ColorFiltered>(find.byType(ColorFiltered)).colorFilter,
        accentIconFilter(accent.conscious),
      );
    });

    testWidgets('an idle mode icon is soft: saturate .7 at 80 %', (
      tester,
    ) async {
      await _pump(
        tester,
        Icon3d(_modeIcon, size: 34, accentTint: true, selected: false),
      );
      expect(
        tester.widget<ColorFiltered>(find.byType(ColorFiltered)).colorFilter,
        accentIconFilter(
          AppTokens.light.brand,
          saturate: AppTokens.iconSaturateOff,
          opacity: AppTokens.iconOpacityOff,
        ),
      );
      expect((AppTokens.iconSaturateOff, AppTokens.iconOpacityOff), (.7, .8));
    });

    testWidgets('a label makes it an image node', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, Icon3d(_modeIcon, size: 34, semanticLabel: 'Pause'));
      expect(find.bySemanticsLabel('Pause'), findsOneWidget);
      handle.dispose();
    });
  });

  group('Glyph', () {
    SvgPicture svg(WidgetTester tester) =>
        tester.widget<SvgPicture>(find.byType(SvgPicture));

    testWidgets('sized and drawn srcIn in its colour', (tester) async {
      await _pump(
        tester,
        Glyph(Assets.svg.chevronRight, size: 18, color: AppTokens.light.ink3),
      );
      expect((svg(tester).width, svg(tester).height), (18, 18));
      expect(
        svg(tester).colorFilter,
        ColorFilter.mode(AppTokens.light.ink3, BlendMode.srcIn),
      );
      expect(svg(tester).excludeFromSemantics, true);
    });

    testWidgets('24 px in ink by default, per theme', (tester) async {
      await _pump(tester, Glyph(Assets.svg.check), dark: true);
      expect(svg(tester).width, 24);
      expect(
        svg(tester).colorFilter,
        ColorFilter.mode(AppTokens.dark.ink, BlendMode.srcIn),
      );
    });

    testWidgets('a label makes it an image node', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, Glyph(Assets.svg.lock, semanticLabel: 'Locked'));
      expect(find.bySemanticsLabel('Locked'), findsOneWidget);
      handle.dispose();
    });
  });

  group('DetoxoLogo', () {
    Iterable<ColorFilter> tints(WidgetTester tester) => tester
        .widgetList<ColorFiltered>(find.byType(ColorFiltered))
        .map((f) => f.colorFilter);

    ColorFilter srcIn(int argb) =>
        ColorFilter.mode(Color(argb), BlendMode.srcIn);

    Iterable<ImageFilter> blurs(WidgetTester tester) => tester
        .widgetList<ImageFiltered>(find.byType(ImageFiltered))
        .map((f) => f.imageFilter);

    testWidgets('keeps 100:192 and is never recoloured', (tester) async {
      await _pump(tester, const DetoxoLogo());
      expect(tester.getSize(find.byType(DetoxoLogo)), const Size(31.25, 60));
      final mark = find.byType(Image).last;
      expect(tester.widget<Image>(mark).color, isNull);
      expect(
        find.ancestor(of: mark, matching: find.byType(ColorFiltered)),
        findsNothing,
      );
    });

    testWidgets('Light: a sigma 10 glow at +4 under a sigma 1 contour', (
      tester,
    ) async {
      await _pump(tester, const DetoxoLogo(height: 44));
      // Bottom to top, as CSS stacks `drop-shadow(contour) drop-shadow(glow)`.
      expect(blurs(tester), [_blur(10), _blur(1)]);
      expect(tints(tester), [
        srcIn(0x733D7BFF), // rgba(61, 123, 255, .45): brand-main at 45 %
        srcIn(0x991E326E), // rgba(30, 50, 110, .6)
      ]);
      final mark = tester.getTopLeft(find.byType(Image).last);
      expect(
        tester.getTopLeft(find.byType(ImageFiltered).first) - mark,
        const Offset(0, 4),
      );
      expect(
        tester.getTopLeft(find.byType(ImageFiltered).last) - mark,
        Offset.zero,
      );
    });

    testWidgets('Dark: one sigma 8 glow in brand-main at 55 %', (tester) async {
      await _pump(tester, const DetoxoLogo(), dark: true);
      expect(blurs(tester), [_blur(8)]);
      expect(tints(tester), [srcIn(0x8C6AA8FF)]); // rgba(106, 168, 255, .55)
    });

    testWidgets('decorative unless labelled; the glow is never read', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const DetoxoLogo());
      expect(
        tester
            .widgetList<Image>(find.byType(Image))
            .every((i) => i.excludeFromSemantics),
        true,
      );

      await _pump(tester, const DetoxoLogo(semanticLabel: 'Detoxo'));
      expect(find.bySemanticsLabel('Detoxo'), findsOneWidget);
      handle.dispose();
    });
  });
}
