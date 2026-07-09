import 'package:equatable/equatable.dart';

/// The outcome of a store-version check: what's installed, what's available, and
/// whether the user is allowed to defer the update.
///
/// A `null` [UpgradeStatus] (from `AppUpgradeService.check`) means "nothing to
/// show" — offline, no newer version, already dismissed, or an unsupported
/// platform. Only a non-null value with [isUpdateAvailable] true should surface
/// the prompt.
class UpgradeStatus extends Equatable {
  const UpgradeStatus({
    required this.isUpdateAvailable,
    this.installedVersion,
    this.storeVersion,
    this.releaseNotes,
    this.isCritical = false,
    this.isBelowMinVersion = false,
  });

  /// The version running on the device (e.g. `1.0.0`). May be `null` if the
  /// package info could not be read.
  final String? installedVersion;

  /// The latest version on the Play Store. `null` when the listing could not be
  /// scraped (kept nullable so the dialog degrades gracefully).
  final String? storeVersion;

  /// The store's "What's New" text. Frequently `null`/locale-dependent — the
  /// dialog must render without it.
  final String? releaseNotes;

  /// Whether a newer version than the installed one is available.
  final bool isUpdateAvailable;

  /// The store flagged this as a critical update (`[Critical update: ...]`).
  final bool isCritical;

  /// The installed version is below the configured minimum (`minAppVersion` /
  /// `[Minimum supported app version: ...]`).
  final bool isBelowMinVersion;

  /// A blocking update cannot be deferred: the user must update to continue.
  bool get isBlocking => isCritical || isBelowMinVersion;

  /// Optional updates can be postponed ("Later") or skipped for this version.
  bool get canDismiss => !isBlocking;

  @override
  List<Object?> get props => [
    installedVersion,
    storeVersion,
    releaseNotes,
    isUpdateAvailable,
    isCritical,
    isBelowMinVersion,
  ];
}
