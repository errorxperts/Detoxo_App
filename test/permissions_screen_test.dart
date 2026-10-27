import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/features/permissions/domain/entities/permission_status.dart';
import 'package:detoxo/features/permissions/domain/repositories/permission_repository.dart';
import 'package:detoxo/features/permissions/presentation/permissions_cubit.dart';
import 'package:detoxo/features/permissions/presentation/permissions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo implements PermissionRepository {
  _FakeRepo(this.granted);

  final Set<AppPermission> granted;

  @override
  Future<List<PermissionStatus>> statuses() async => [
    for (final p in AppPermission.values)
      PermissionStatus(
        kind: p,
        state: granted.contains(p)
            ? PermissionState.granted
            : PermissionState.denied,
      ),
  ];

  @override
  Future<PermissionStatus> status(AppPermission p) async =>
      (await statuses()).firstWhere((s) => s.kind == p);

  @override
  Future<void> request(AppPermission p) async {}

  @override
  Future<Set<AppPermission>> lastKnownGranted() async => granted;

  @override
  Future<bool> installedOutsidePlay() async => false;

  @override
  Future<void> openAppSettings() async {}
}

/// The bottom button is never a dead control: it grants the next required
/// permission in order, then reads Continue (qa_walk waits for that word).
void main() {
  Future<void> pump(WidgetTester tester, Set<AppPermission> granted) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: BlocProvider(
          key: UniqueKey(),
          create: (_) => PermissionsCubit(_FakeRepo(granted)),
          child: const PermissionsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  PrimaryButton button(WidgetTester tester) =>
      tester.widget<PrimaryButton>(find.byType(PrimaryButton));

  testWidgets('walks the required grants in order, then Continue', (
    tester,
  ) async {
    await pump(tester, {});
    expect(button(tester).label, 'Grant Accessibility');
    expect(button(tester).onPressed, isNotNull);
    expect(find.text('0 of 2 on'), findsOneWidget);

    await pump(tester, {AppPermission.accessibility});
    expect(button(tester).label, 'Grant Display over other apps');
    expect(find.text('1 of 2 on'), findsOneWidget);

    // Optional grants never hold the user back.
    await pump(tester, {AppPermission.accessibility, AppPermission.overlay});
    expect(button(tester).label, 'Continue');
    expect(find.text('Ready to block'), findsOneWidget);
  });
}
