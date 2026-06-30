/// Controls the floating reel-counter bubble. The bubble's actual show/hide is
/// native (driven by the foreground app); this gates it on/off and handles the
/// overlay permission it needs.
abstract interface class BubbleRepository {
  /// Whether the overlay (draw-over-other-apps) permission is granted.
  Future<bool> canShow();

  /// Opens the system overlay-permission screen.
  Future<void> requestPermission();

  /// Enables/disables the bubble natively.
  Future<void> setEnabled({required bool enabled});
}
