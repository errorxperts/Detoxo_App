import 'dart:convert';
import 'dart:typed_data';

import 'package:detoxo/core/design_system/components/app_icon_avatar.dart';
import 'package:detoxo/core/utils/device_app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A 1×1 transparent PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

Uint8List _bytesOf(WidgetTester tester) =>
    (tester.widget<Image>(find.byType(Image)).image as MemoryImage).bytes;

void main() {
  tearDown(() => deviceAppIcons.value = const {});

  testWidgets('explicit device bytes win over the cache', (tester) async {
    deviceAppIcons.value = {'com.instagram.android': Uint8List(0)};
    await _pump(
      tester,
      AppIconAvatar(
        appName: 'Instagram',
        packageName: 'com.instagram.android',
        iconBytes: _png,
      ),
    );
    expect(_bytesOf(tester), _png);
  });

  testWidgets('looks the device icon up by package, live', (tester) async {
    await _pump(
      tester,
      const AppIconAvatar(
        appName: 'Instagram',
        packageName: 'com.instagram.android',
      ),
    );
    // Before the scan lands: the letter tile.
    expect(find.byType(Image), findsNothing);
    expect(find.text('I'), findsOneWidget);

    deviceAppIcons.value = {'com.instagram.android': _png};
    await tester.pump();
    expect(_bytesOf(tester), _png);
    expect(find.text('I'), findsNothing);
  });

  testWidgets('draws a letter tile, no asset, without an icon', (tester) async {
    await _pump(tester, const AppIconAvatar(appName: ' bluesky'));
    expect(find.byType(Image), findsNothing);
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('uses the neutral badge for a non-letter initial', (
    tester,
  ) async {
    await _pump(tester, const AppIconAvatar(appName: '4chan'));
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.smartphone_rounded), findsOneWidget);
  });

  testWidgets('dimmed fades the icon', (tester) async {
    await _pump(tester, const AppIconAvatar(appName: 'Reddit', dimmed: true));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.4);
  });
}
