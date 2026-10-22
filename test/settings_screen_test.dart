import 'package:bloc_test/bloc_test.dart';
import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/features/access_protection/access_protection.dart';
import 'package:detoxo/features/access_protection/presentation/pin_cubit.dart';
import 'package:detoxo/features/additional_feature/app_upgrader/app_upgrader.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/app_settings.dart';
import 'package:detoxo/features/blocking/shared/presentation/settings_cubit.dart';
import 'package:detoxo/features/limits/unblock/presentation/unblock_cubit.dart';
import 'package:detoxo/features/permissions/domain/entities/permission_status.dart';
import 'package:detoxo/features/permissions/domain/repositories/permission_repository.dart';
import 'package:detoxo/features/permissions/presentation/permissions_cubit.dart';
import 'package:detoxo/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

// M6: Settings is four SectionHeader + panel sections of flat rows; the
// version row is the update check; the nudge sheet takes both picks.

class _NoPin implements PinRepository {
  @override
  Future<PinConfig> load() async => const PinConfig();
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _NoPermissions implements PermissionRepository {
  @override
  Future<List<PermissionStatus>> statuses() async => const [];
  @override
  Future<Set<AppPermission>> lastKnownGranted() async => const {};
  @override
  Future<bool> installedOutsidePlay() async => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _Upgrade implements AppUpgradeService {
  _Upgrade([this.status]);
  final UpgradeStatus? status;
  @override
  Future<UpgradeStatus?> check({bool force = false}) async => status;
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _MockSettings extends MockCubit<AppSettings> implements SettingsCubit {}

class _MockUnblock extends MockCubit<UnblockState> implements UnblockCubit {}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(
      finder.hitTestable(),
      200,
      scrollable: find.byType(Scrollable).first,
    );

void main() {
  late _MockSettings settings;

  setUp(() async {
    await sl.reset();
    settings = _MockSettings();
    when(
      () => settings.state,
    ).thenReturn(const AppSettings(nudgeEnabled: true));
    when(
      () => settings.setNudgeThresholdMinutes(any()),
    ).thenAnswer((_) async {});
    when(() => settings.setNudgeDailyCap(any())).thenAnswer((_) async {});
  });

  tearDown(sl.reset);

  Future<void> pump(WidgetTester tester, {UpgradeStatus? update}) async {
    sl.registerSingleton<AppUpgradeService>(_Upgrade(update));
    final unblock = _MockUnblock();
    when(() => unblock.state).thenReturn(const UnblockState());
    final router = GoRouter(
      initialLocation: Routes.settings,
      routes: [
        GoRoute(
          path: Routes.settings,
          builder: (_, _) => const SettingsScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<SettingsCubit>.value(value: settings),
          BlocProvider<UnblockCubit>.value(value: unblock),
          BlocProvider(create: (_) => PinCubit(_NoPin())),
          BlocProvider(create: (_) => PermissionsCubit(_NoPermissions())),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await _settle(tester);
  }

  testWidgets('panel rows draw their own chevrons; the version row checks', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('PROTECTION'), findsOneWidget);
    expect(find.byType(PanelGroup), findsWidgets);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    await _scrollTo(tester, find.text('Tap to check for updates'));
    expect(find.text('Update'), findsNothing);
  });

  testWidgets('an available update shows a 48 dp Update button', (
    tester,
  ) async {
    await pump(
      tester,
      update: const UpgradeStatus(
        isUpdateAvailable: true,
        storeVersion: '9.0.0',
      ),
    );
    final update = find.widgetWithText(SecondaryButton, 'Update');
    await _scrollTo(tester, update);
    expect(find.text('Version 9.0.0 is available'), findsOneWidget);
    final size = tester.getSize(update);
    expect(size.height, greaterThanOrEqualTo(AppSizes.minTapTarget));
    expect(size.width, greaterThanOrEqualTo(AppSizes.minTapTarget));
  });

  testWidgets('the nudge sheet stays open until both values are picked', (
    tester,
  ) async {
    await pump(tester);
    await _scrollTo(tester, find.text('Nudge me every'));
    expect(find.text('5m · up to 4 per app a day'), findsOneWidget);
    await tester.tap(find.text('Nudge me every'));
    await _settle(tester);

    await tester.tap(find.text('10m'));
    await _settle(tester);
    verify(() => settings.setNudgeThresholdMinutes(10)).called(1);
    expect(find.text('MOST NUDGES PER APP, PER DAY'), findsOneWidget);

    await tester.tap(find.text('6'));
    await _settle(tester);
    await tester.pump(const Duration(seconds: 2));
    verify(() => settings.setNudgeDailyCap(6)).called(1);
    expect(find.text('MOST NUDGES PER APP, PER DAY'), findsNothing);
  });
}
