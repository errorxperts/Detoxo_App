import 'package:detoxo/core/services/firebase/analytics/analytics_service.dart';
import 'package:detoxo/core/services/firebase/analytics/firebase_bloc_observer.dart';
import 'package:detoxo/core/services/firebase/crashlytics/crash_reporting_service.dart';
import 'package:detoxo/features/blocking/plans/domain/entities/sessions.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/app_settings.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnalytics extends Mock implements AnalyticsService {}

class _MockCrash extends Mock implements CrashReportingService {}

/// Placeholder bloc for the `onChange`/`onError` bloc argument — the observer
/// matches on state *type*, not on the cubit class.
class _DummyCubit extends Cubit<int> {
  _DummyCubit() : super(0);
}

void main() {
  late _MockAnalytics analytics;
  late _MockCrash crash;
  late FirebaseBlocObserver observer;
  late _DummyCubit bloc;

  setUpAll(() {
    registerFallbackValue(Duration.zero);
    registerFallbackValue(Object());
  });

  setUp(() {
    analytics = _MockAnalytics();
    crash = _MockCrash();
    when(() => analytics.logPlanChanged(any())).thenAnswer((_) async {});
    when(() => analytics.logBlockingToggled(enabled: any(named: 'enabled')))
        .thenAnswer((_) async {});
    when(() => analytics.logPauseStarted(any())).thenAnswer((_) async {});
    when(() => analytics.logPauseEnded()).thenAnswer((_) async {});
    when(() => crash.setKey(any(), any())).thenAnswer((_) async {});
    observer = FirebaseBlocObserver(analytics, crash);
    bloc = _DummyCubit();
  });

  tearDown(() => bloc.close());

  void change(AppSettings prev, AppSettings next) => observer.onChange(
        bloc,
        Change<AppSettings>(currentState: prev, nextState: next),
      );

  test('plan change logs plan_changed and sets the crash key', () {
    change(
      const AppSettings(),
      const AppSettings(activePlan: BlockingPlan.curious),
    );
    verify(() => analytics.logPlanChanged(BlockingPlan.curious.name)).called(1);
    verify(() => crash.setKey('plan', BlockingPlan.curious.wire)).called(1);
  });

  test('master toggle logs blocking_toggled and sets the crash key', () {
    change(
      const AppSettings(),
      const AppSettings(masterEnabled: false),
    );
    verify(() => analytics.logBlockingToggled(enabled: false)).called(1);
    verify(() => crash.setKey('master_enabled', false)).called(1);
  });

  test('pause start then end logs pause_started/pause_ended', () {
    final paused = AppSettings(
      pauseSession: PauseSession(
        startedAt: DateTime(2026),
        pauseDuration: const Duration(minutes: 15),
        cooldownDuration: Duration.zero,
        planToResume: BlockingPlan.blockAll,
      ),
    );
    change(const AppSettings(), paused);
    verify(() => analytics.logPauseStarted(const Duration(minutes: 15)))
        .called(1);

    change(paused, const AppSettings());
    verify(() => analytics.logPauseEnded()).called(1);
  });

  test('an unrelated change logs nothing', () {
    change(
      const AppSettings(),
      const AppSettings(vibrationEnabled: false),
    );
    verifyNever(() => analytics.logPlanChanged(any()));
    verifyNever(
      () => analytics.logBlockingToggled(enabled: any(named: 'enabled')),
    );
    verifyNever(() => analytics.logPauseStarted(any()));
  });

  test('onError forwards the error to crash reporting', () {
    final error = StateError('boom');
    final stack = StackTrace.current;
    when(() => crash.recordError(error, stack, reason: any(named: 'reason')))
        .thenAnswer((_) async {});

    observer.onError(bloc, error, stack);

    verify(() => crash.recordError(error, stack, reason: any(named: 'reason')))
        .called(1);
  });
}
