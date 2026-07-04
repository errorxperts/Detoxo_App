import 'package:bloc/bloc.dart';
import 'package:detoxo/core/services/firebase/analytics/analytics_service.dart';
import 'package:detoxo/core/services/firebase/crashlytics/crash_reporting_service.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/app_settings.dart';

/// Global [BlocObserver] that turns cubit activity into telemetry — the app's
/// single event-capture seam, so no feature has to import Firebase:
///
/// * `onChange` watches [AppSettings] transitions (the app's central settings /
///   plan / pause state machine) and emits semantic analytics events while
///   keeping the Crashlytics context keys current. It matches on the *state
///   type*, so it never imports any Cubit (`presentation`) class — the only
///   feature link is to the `domain` entity, which the architecture allows.
/// * `onError` forwards every uncaught cubit error to Crashlytics.
class FirebaseBlocObserver extends BlocObserver {
  FirebaseBlocObserver(this._analytics, this._crash);

  final AnalyticsService _analytics;
  final CrashReportingService _crash;

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    final prev = change.currentState;
    final next = change.nextState;
    if (prev is AppSettings && next is AppSettings) {
      _onSettingsChange(prev, next);
    }
  }

  void _onSettingsChange(AppSettings prev, AppSettings next) {
    if (prev.activePlan != next.activePlan) {
      _analytics.logPlanChanged(next.activePlan.name);
      _crash.setKey('plan', next.activePlan.wire);
    }
    if (prev.masterEnabled != next.masterEnabled) {
      _analytics.logBlockingToggled(enabled: next.masterEnabled);
      _crash.setKey('master_enabled', next.masterEnabled);
    }
    final wasPaused = prev.pauseSession != null;
    final isPaused = next.pauseSession != null;
    if (!wasPaused && isPaused) {
      _analytics.logPauseStarted(next.pauseSession!.pauseDuration);
    } else if (wasPaused && !isPaused) {
      _analytics.logPauseEnded();
    }
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    _crash.recordError(error, stackTrace, reason: '${bloc.runtimeType} error');
    super.onError(bloc, error, stackTrace);
  }
}
