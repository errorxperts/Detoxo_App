import 'package:equatable/equatable.dart';

/// Per-app reel/short tally, enriched with the app's display name + icon from
/// the platform catalog so the analytics card can render it richly.
class AppContentCount extends Equatable {
  const AppContentCount({
    required this.packageName,
    required this.appName,
    required this.displayName,
    required this.iconUrl,
    required this.count,
  });

  final String packageName;

  /// Human app label (e.g. "Instagram"); falls back to the package name.
  final String appName;

  /// Surface label (e.g. "Instagram Reels"); falls back to [appName].
  final String displayName;

  /// Remote icon URL from the platform config (may be empty).
  final String iconUrl;

  /// Reels counted for this app in the active window (today or all-time).
  final int count;

  @override
  List<Object?> get props => [packageName, count];
}
