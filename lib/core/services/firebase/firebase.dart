/// Public surface of the Firebase telemetry layer (analytics, crashlytics,
/// performance). Import this barrel — never reach into the subfolders directly.
///
/// The event taxonomy and privacy rules are documented in `docs/code_docs`.
library;

export 'analytics/analytics_events.dart';
export 'analytics/analytics_service.dart';
export 'analytics/firebase_bloc_observer.dart';
export 'analytics/native_event_reporter.dart';
export 'crashlytics/crash_reporting_service.dart';
export 'firebase_services.dart';
export 'performance/performance_service.dart';
