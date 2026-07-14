import 'package:detoxo/core/design_system/components/app_icon_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _dir = 'assets/images/social_icon_pack/';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(home: Scaffold(body: Center(child: child))),
);

String _assetOf(WidgetTester tester) =>
    (tester.widget<Image>(find.byType(Image)).image as AssetImage).assetName;

void main() {
  testWidgets('renders the bundled icon asset directly', (tester) async {
    await _pump(
      tester,
      const AppIconAvatar(
        iconUrl: '${_dir}instagram.png',
        appName: 'Instagram',
      ),
    );
    expect(_assetOf(tester), '${_dir}instagram.png');
  });

  testWidgets('shows the letter tile when there is no icon', (tester) async {
    await _pump(tester, const AppIconAvatar(iconUrl: '', appName: 'BlueSky'));
    expect(_assetOf(tester), '${_dir}b.png');
  });

  testWidgets('uses the neutral badge for a non a–z initial', (tester) async {
    await _pump(tester, const AppIconAvatar(iconUrl: '', appName: '4chan'));
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.smartphone_rounded), findsOneWidget);
  });
}
