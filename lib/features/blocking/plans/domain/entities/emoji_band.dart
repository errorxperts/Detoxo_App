// Emoji-band domain model for the Mindful Countdown.
//
// The bundled JSON (`assets/content/*.json`) and the remote `fetchcontent`
// response share one schema: a top-level `emojiSets` array; each set has
// `setId`, `placementId`, `enabled`, and an `emojis` array of duration/progress
// -bucketed items. Each item carries inclusive `rangeMin`/`rangeMax` bounds and
// one of 14 animation types. Bucket matching is `rangeMin <= value <= rangeMax`.

/// The 14 verified emoji animation styles (ordinals from `EmojiAnimationEnum`).
/// Wire tokens are the upper-case enum names in the JSON (`"BREATHING"`, …).
enum EmojiAnimation {
  breathing,
  scanning,
  melting,
  bouncing,
  waving,
  quaking,
  chaos,
  slide,
  lumber,
  sinking,
  glow,
  flash,
  fly,
  shake;

  /// Parse a wire token (case-insensitive); unknown values fall back to a calm
  /// [breathing] so a bad/extended server value never breaks the UI.
  static EmojiAnimation fromWire(String? v) {
    if (v == null) return EmojiAnimation.breathing;
    final name = v.toLowerCase();
    for (final a in values) {
      if (a.name == name) return a;
    }
    return EmojiAnimation.breathing;
  }
}

/// A single bucketed emoji: shown when its inclusive range covers the current
/// bucket value (re-open count, minutes elapsed, selected minutes, or cooldown %).
class EmojiItem {
  const EmojiItem({
    required this.id,
    required this.rangeMin,
    required this.rangeMax,
    required this.emoji,
    required this.title,
    required this.description,
    required this.animation,
  });

  factory EmojiItem.fromJson(Map<String, dynamic> j) => EmojiItem(
        id: j['emojiId'] as String? ?? '',
        rangeMin: (j['rangeMin'] as num?)?.toInt() ?? 0,
        rangeMax: (j['rangeMax'] as num?)?.toInt() ?? 0,
        emoji: j['emoji'] as String? ?? '🙂',
        title: j['title'] as String? ?? '',
        description: j['description'] as String? ?? '',
        animation: EmojiAnimation.fromWire(j['animation'] as String?),
      );

  final String id;
  final int rangeMin;
  final int rangeMax;
  final String emoji;
  final String title;
  final String description;
  final EmojiAnimation animation;

  /// Inclusive bucket test (verified semantics).
  bool covers(int value) => value >= rangeMin && value <= rangeMax;
}

/// A placement's emoji set (one `emojiSets[]` entry).
class EmojiSet {
  const EmojiSet({
    required this.setId,
    required this.placementId,
    required this.enabled,
    required this.items,
  });

  factory EmojiSet.fromJson(Map<String, dynamic> j) => EmojiSet(
        setId: j['setId'] as String? ?? '',
        placementId: j['placementId'] as String? ?? '',
        enabled: j['enabled'] as bool? ?? true,
        items: ((j['emojis'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(EmojiItem.fromJson)
            .toList(),
      );

  final String setId;
  final String placementId;
  final bool enabled;
  final List<EmojiItem> items;
}

/// A placement-keyed content holder: an [EmojiSet] for one [EmojiPlacementId].
class EmojiPlacement {
  const EmojiPlacement({
    required this.placementId,
    required this.enabled,
    required this.set,
  });

  /// Build from a bundled file's root JSON (`{ "emojiSets": [ {…} ] }`). Reads
  /// the first set; returns a disabled empty placement when absent.
  factory EmojiPlacement.fromBundle(Map<String, dynamic> root) {
    final sets = (root['emojiSets'] as List<dynamic>?) ?? const [];
    if (sets.isEmpty || sets.first is! Map<String, dynamic>) {
      return const EmojiPlacement(
        placementId: '',
        enabled: false,
        set: EmojiSet(setId: '', placementId: '', enabled: false, items: []),
      );
    }
    final set = EmojiSet.fromJson(sets.first as Map<String, dynamic>);
    return EmojiPlacement(
      placementId: set.placementId,
      enabled: true,
      set: set,
    );
  }

  final String placementId;
  final bool enabled;
  final EmojiSet set;

  /// True when both the placement and its set are enabled and non-empty.
  bool get isUsable => enabled && set.enabled && set.items.isNotEmpty;

  /// Items whose inclusive range covers [value] (mirrors `emojiForProgress`).
  List<EmojiItem> emojiFor(int value) =>
      isUsable ? set.items.where((e) => e.covers(value)).toList() : const [];

  /// The single best-matching item for [value], or null when none/disabled.
  EmojiItem? itemFor(int value) {
    final matches = emojiFor(value);
    return matches.isEmpty ? null : matches.first;
  }
}

/// Placement ids (verified `EmojiPlacementIdsEnum`). The `wire` matches the
/// `placementId` string inside each emoji set — the join key.
enum EmojiPlacementId {
  planPause('EMOJI_PLAN_PAUSE'),
  curiousPlan('EMOJI_CURIOUS_PLAN'),
  appLockSession('EMOJI_APP_LOCK_SESSION'),
  dailyLimitHero('DAILY_LIMIT_HERO'),
  pauseCountdown('EMOJI_PLAN_PAUSE_COUNTDOWN'),
  pauseCountdownCooldown('EMOJI_PAUSE_COUNTDOWN_COOLDOWN');

  const EmojiPlacementId(this.wire);
  final String wire;
}
