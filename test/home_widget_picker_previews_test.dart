import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:detoxo/features/content_counter/content_counter.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The widget picker's per-family pictures before Android 15 (EVO-071).
///
/// Android 15+ draws each family's demo face itself
/// (`HomeWidgets.publishPickerPreviews`). Older launchers show only the
/// drawable a provider info names in `android:previewImage`, so each family
/// has a checked-in PNG: its in-app [WidgetPreview], Small, on the board's
/// demo day (152 reels, tier 2, 1h 10m of a 2h limit; Plan shows its demo
/// plan, Block All on), light in `drawable-xhdpi` and dark in
/// `drawable-night-xhdpi`.
///
/// Run plainly, this file only checks that the set is current. After a
/// change to a face, the painter, the tokens or the model, re-render, then
/// commit the PNGs and the stamp:
///
///     flutter test test/home_widget_picker_previews_test.dart --dart-define=RENDER_PREVIEWS=true
void main() {
  // The faces draw in Manrope; flutter_test loads no app fonts by itself.
  setUpAll(() async {
    if (!_render) return;
    final manrope = FontLoader('Manrope');
    for (final weight in ['Bold', 'ExtraBold']) {
      final ttf = File('assets/fonts/Manrope-$weight.ttf').readAsBytesSync();
      manrope.addFont(Future.value(ByteData.sublistView(ttf)));
    }
    await manrope.load();
  });

  testWidgets('render the picker pictures', (tester) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final dark in [false, true]) {
      for (final family in WidgetFamily.values) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: WidgetPreview(
                key: ValueKey((family, dark)),
                family: family,
                size: WidgetSize.small,
                // HomeWidgets.previewViews' demo day, in a fixed theme.
                payload: WidgetPayload.demo(
                  limitMinutes: 120,
                  theme: dark ? 'dark' : 'light',
                  reduceMotion: true,
                  nowMs: now,
                ),
                width: _box,
                animate: false,
              ),
            ),
          ),
        );
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.descendant(
            of: find.byType(WidgetPreview),
            matching: find.byType(RepaintBoundary),
          ),
        );
        final png = await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: _px / _box);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          return data!.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
        });
        File(_png(family, dark: dark))
          ..createSync(recursive: true)
          ..writeAsBytesSync(png!);
      }
    }
    File(_stamp).writeAsStringSync('${_digest()}\n');
  }, skip: !_render);

  test('the pictures are current', () {
    expect(
      File(_stamp).readAsStringSync().trim(),
      _digest(),
      reason: 'a face, the painter, the tokens or the model changed: $_cmd',
    );
  });

  test('each family has a light and a dark $_px px picture', () {
    for (final f in WidgetFamily.values) {
      for (final dark in [false, true]) {
        final png = File(_png(f, dark: dark)).readAsBytesSync();
        // The IHDR chunk: width, then height, big-endian, from byte 16.
        final ihdr = ByteData.sublistView(png, 16, 24);
        expect(
          [ihdr.getUint32(0), ihdr.getUint32(4)],
          [_px, _px],
          reason: _png(f, dark: dark),
        );
      }
    }
  });

  test('one provider info per family, alike but for its picture', () {
    String xml(WidgetFamily f) =>
        File('$_res/xml/${_info(f)}.xml').readAsStringSync();
    final count = xml(WidgetFamily.count);
    // A previewLayout would win over the picture on Android 12-14.
    expect(count, isNot(contains('previewLayout')));
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    for (final f in WidgetFamily.values) {
      final info = xml(f);
      expect(
        info,
        contains('android:previewImage="@drawable/${_drawable(f)}"'),
      );
      expect(
        info
            .replaceAll(_drawable(f), _drawable(WidgetFamily.count))
            .replaceAll(_description(f), _description(WidgetFamily.count)),
        count,
        reason: '${_info(f)}.xml drifted from content_counter_widget_info.xml',
      );
      final meta = RegExp(
        'android:name="\\.widget\\.${_provider(f)}"'
        '[\\s\\S]*?android:resource="@xml/(\\w+)"',
      ).firstMatch(manifest);
      expect(meta?.group(1), _info(f), reason: _provider(f));
    }
  });
}

const _render = bool.fromEnvironment('RENDER_PREVIEWS');
const _cmd =
    'flutter test test/home_widget_picker_previews_test.dart '
    '--dart-define=RENDER_PREVIEWS=true';

/// The Small face's 160-unit box at 2x: 320 px in `-xhdpi` is 160 dp on
/// every screen. ponytail: a little soft in a 3x phone's picker; render at
/// 3x into `-xxhdpi` if that shows (about twice the bytes).
const _box = 160.0;
const _px = 320;

const _res = 'android/app/src/main/res';
const _stamp = 'tool/home_widget/picker_previews.sha256';
const _home = 'lib/features/content_counter/home_content_counter';

/// Everything besides the faces folder that changes a picture's pixels.
/// ponytail: a byte hash, so a comment or a reformat trips it too; just
/// re-render. It leaves out the blocking enums (`planLabel`), which the
/// demo plan, Block All, never reads; add them if the demo plan changes.
const _inputs = [
  'assets/fonts/Manrope-Bold.ttf',
  'assets/fonts/Manrope-ExtraBold.ttf',
  'lib/core/utils/duration_format.dart',
  '$_home/domain/entities/plan_state.dart',
  '$_home/domain/entities/widget_payload.dart',
  '$_home/domain/widget_model.dart',
  '$_home/domain/widget_rules.g.dart',
  '$_home/presentation/widget_face_painter.dart',
  '$_home/presentation/widget_geometry.dart',
  '$_home/presentation/widget_preview.dart',
  '$_home/presentation/widget_tokens.g.dart',
  'test/home_widget_picker_previews_test.dart',
];

/// [f]'s picture as a resource name, e.g. `cc_widget_preview_next_colour`.
String _drawable(WidgetFamily f) => 'cc_widget_preview_${f.wire.toLowerCase()}';

String _png(WidgetFamily f, {required bool dark}) =>
    '$_res/drawable-${dark ? 'night-' : ''}xhdpi/${_drawable(f)}.png';

/// [f]'s provider info; Count keeps the original file, Plan its own
/// (EVO-073).
String _info(WidgetFamily f) => switch (f) {
  WidgetFamily.count => 'content_counter_widget_info',
  WidgetFamily.plan => 'plan_widget_info',
  _ => 'content_counter_widget_info_${f.wire.toLowerCase()}',
};

/// [f]'s picker description: Plan's is its own, the reel families share one.
String _description(WidgetFamily f) => f == WidgetFamily.plan
    ? 'plan_widget_description'
    : 'cc_widget_description';

/// Kotlin `HomeWidgets.providerFor`, as the manifest names each receiver.
String _provider(WidgetFamily f) => switch (f) {
  WidgetFamily.count => 'ContentCounterWidgetProvider',
  WidgetFamily.nextColour => 'NextColourWidgetProvider',
  WidgetFamily.timeLimit => 'TimeLimitWidgetProvider',
  WidgetFamily.rhythm => 'RhythmWidgetProvider',
  WidgetFamily.bonsai => 'BonsaiWidgetProvider',
  WidgetFamily.bento => 'BentoWidgetProvider',
  WidgetFamily.plan => 'PlanWidgetProvider',
};

/// sha256 over each input's path and bytes, in path order.
String _digest() {
  final faces = Directory('$_home/presentation/faces')
      .listSync()
      .whereType<File>()
      .map((f) => f.path)
      .where((p) => p.endsWith('.dart'));
  final bytes = <int>[];
  for (final path in [..._inputs, ...faces]..sort()) {
    bytes
      ..addAll(utf8.encode('$path\n'))
      ..addAll(File(path).readAsBytesSync());
  }
  return sha256.convert(bytes).toString();
}
