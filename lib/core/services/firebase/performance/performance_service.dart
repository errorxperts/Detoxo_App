import 'package:firebase_performance/firebase_performance.dart';

/// App-facing performance-tracing surface. Behind an interface so hot paths can
/// be traced without importing Firebase directly, and so it mocks in tests.
///
/// Automatic app-start, screen-render and HTTP traces are provided by the
/// Firebase Performance Gradle plugin with no code; this service is for the
/// bespoke custom traces the plugin can't infer.
abstract interface class PerformanceService {
  Future<void> setCollectionEnabled({required bool enabled});

  /// Times [action] under a custom trace [name] and returns its result. The
  /// trace is always stopped, even if [action] throws.
  Future<T> traceAsync<T>(String name, Future<T> Function() action);
}

/// [PerformanceService] backed by Firebase Performance Monitoring.
class FirebasePerformanceService implements PerformanceService {
  FirebasePerformanceService({FirebasePerformance? performance})
      : _performance = performance ?? FirebasePerformance.instance;

  final FirebasePerformance _performance;

  @override
  Future<void> setCollectionEnabled({required bool enabled}) =>
      _performance.setPerformanceCollectionEnabled(enabled);

  @override
  Future<T> traceAsync<T>(String name, Future<T> Function() action) async {
    final trace = _performance.newTrace(name);
    await trace.start();
    try {
      return await action();
    } finally {
      await trace.stop();
    }
  }
}
