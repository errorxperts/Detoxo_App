import 'package:detoxo/features/additional_feature/app_upgrader/domain/entities/upgrade_status.dart';
import 'package:detoxo/features/additional_feature/app_upgrader/domain/repositories/app_upgrade_service.dart';
import 'package:detoxo/features/additional_feature/app_upgrader/presentation/upgrade_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Configurable fake: returns a fixed status (or throws) from [check] and
/// records which action methods were invoked.
class _FakeAppUpgradeService implements AppUpgradeService {
  _FakeAppUpgradeService({this.result, this.throwOnCheck = false});

  final UpgradeStatus? result;
  final bool throwOnCheck;

  int openStoreCalls = 0;
  int remindLaterCalls = 0;
  int skipCalls = 0;
  bool? lastForce;

  @override
  Future<UpgradeStatus?> check({bool force = false}) async {
    lastForce = force;
    if (throwOnCheck) throw Exception('scrape failed');
    return result;
  }

  @override
  Future<void> openStore() async => openStoreCalls++;

  @override
  Future<void> remindLater() async => remindLaterCalls++;

  @override
  Future<void> skipThisVersion() async => skipCalls++;
}

UpgradeStatus _available({bool critical = false, bool belowMin = false}) =>
    UpgradeStatus(
      isUpdateAvailable: true,
      installedVersion: '1.0.0',
      storeVersion: '1.2.0',
      isCritical: critical,
      isBelowMinVersion: belowMin,
    );

void main() {
  group('UpgradeStatus', () {
    test('optional update can be dismissed', () {
      final status = _available();
      expect(status.isBlocking, isFalse);
      expect(status.canDismiss, isTrue);
    });

    test('critical or below-min update is blocking', () {
      expect(_available(critical: true).canDismiss, isFalse);
      expect(_available(belowMin: true).canDismiss, isFalse);
    });
  });

  group('UpgradeCubit', () {
    test('starts idle', () {
      final cubit = UpgradeCubit(_FakeAppUpgradeService());
      expect(cubit.state.view, UpgradeView.idle);
      expect(cubit.state.status, isNull);
    });

    test('check emits updateAvailable with the status', () async {
      final status = _available();
      final cubit = UpgradeCubit(_FakeAppUpgradeService(result: status));
      await cubit.check();
      expect(cubit.state.view, UpgradeView.updateAvailable);
      expect(cubit.state.status, status);
      expect(cubit.state.manual, isFalse);
    });

    test('check with no update emits upToDate', () async {
      final cubit = UpgradeCubit(_FakeAppUpgradeService());
      await cubit.check(manual: true);
      expect(cubit.state.view, UpgradeView.upToDate);
      expect(cubit.state.status, isNull);
      expect(cubit.state.manual, isTrue);
    });

    test('a manual check forces past the throttle', () async {
      final service = _FakeAppUpgradeService();
      final cubit = UpgradeCubit(service);
      await cubit.check();
      expect(service.lastForce, isFalse);
      await cubit.check(manual: true);
      expect(service.lastForce, isTrue);
    });

    test('a check failure emits error', () async {
      final cubit = UpgradeCubit(_FakeAppUpgradeService(throwOnCheck: true));
      await cubit.check();
      expect(cubit.state.view, UpgradeView.error);
    });

    test('openStore delegates to the service', () async {
      final service = _FakeAppUpgradeService(result: _available());
      final cubit = UpgradeCubit(service);
      await cubit.openStore();
      expect(service.openStoreCalls, 1);
    });

    test('remindLater persists and resets to idle', () async {
      final service = _FakeAppUpgradeService(result: _available());
      final cubit = UpgradeCubit(service);
      await cubit.check();
      await cubit.remindLater();
      expect(service.remindLaterCalls, 1);
      expect(cubit.state.view, UpgradeView.idle);
    });

    test('skip persists and resets to idle', () async {
      final service = _FakeAppUpgradeService(result: _available());
      final cubit = UpgradeCubit(service);
      await cubit.check();
      await cubit.skip();
      expect(service.skipCalls, 1);
      expect(cubit.state.view, UpgradeView.idle);
    });
  });
}
