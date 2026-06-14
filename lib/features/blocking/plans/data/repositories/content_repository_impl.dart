import 'dart:convert';
import 'dart:math';

import 'package:detoxo/core/constants/app_constants.dart';
import 'package:detoxo/features/blocking/plans/domain/entities/emoji_band.dart';
import 'package:detoxo/features/blocking/plans/domain/entities/mindful_quote.dart';
import 'package:detoxo/features/blocking/plans/domain/repositories/content_repository.dart';
import 'package:flutter/services.dart';

/// Bundled dynamic content: mindful quotes + the six placement-keyed emoji
/// bands. Each asset is parsed lazily and memoized; failures degrade to a
/// safe empty/disabled value so the countdown UI never crashes.
class ContentRepositoryImpl implements ContentRepository {
  ContentRepositoryImpl({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final _random = Random();
  List<MindfulQuote>? _quoteCache;
  final Map<EmojiPlacementId, EmojiPlacement> _emojiCache = {};

  static const _emptyPlacement = EmojiPlacement(
    placementId: '',
    enabled: false,
    set: EmojiSet(setId: '', placementId: '', enabled: false, items: []),
  );

  /// Maps a placement id to its bundled asset (null where no bundle exists).
  String? _assetFor(EmojiPlacementId id) => switch (id) {
        EmojiPlacementId.planPause => AppConstants.pauseEmojis,
        EmojiPlacementId.curiousPlan => AppConstants.curiousEmojis,
        EmojiPlacementId.dailyLimitHero => AppConstants.dailyLimitEmojiBands,
        EmojiPlacementId.pauseCountdown => AppConstants.pauseCountdownEmojis,
        EmojiPlacementId.pauseCountdownCooldown => AppConstants.cooldownEmojis,
        EmojiPlacementId.appLockSession => null,
      };

  @override
  Future<List<MindfulQuote>> mindfulQuotes() async {
    if (_quoteCache != null) return _quoteCache!;
    try {
      final raw = await _bundle.loadString(AppConstants.mindfulQuotes);
      final map = jsonDecode(raw) as Map<String, dynamic>;
      // Keep both sources (doc §6.2): the 52 timer quotes + the paired set.
      final quotes = <MindfulQuote>[
        ...(map['quotes'] as List<dynamic>? ?? const [])
            .map((e) => MindfulQuote(e as String)),
        ..._pairedQuotes.map(MindfulQuote.new),
      ];
      return _quoteCache = quotes;
    } on Exception {
      return _quoteCache = const [MindfulQuote('Stay focused. The feed can wait.')];
    }
  }

  @override
  Future<MindfulQuote> randomQuote() async {
    final quotes = await mindfulQuotes();
    if (quotes.isEmpty) return const MindfulQuote('Stay focused.');
    return quotes[_random.nextInt(quotes.length)];
  }

  @override
  Future<EmojiPlacement> emojiPlacement(EmojiPlacementId id) async {
    final cached = _emojiCache[id];
    if (cached != null) return cached;
    final asset = _assetFor(id);
    if (asset == null) return _emojiCache[id] = _emptyPlacement;
    try {
      final raw = await _bundle.loadString(asset);
      final root = jsonDecode(raw) as Map<String, dynamic>;
      return _emojiCache[id] = EmojiPlacement.fromBundle(root);
    } on Exception {
      return _emojiCache[id] = _emptyPlacement;
    }
  }

  @override
  Future<List<EmojiItem>> emojiFor(EmojiPlacementId id, int threshold) async {
    final placement = await emojiPlacement(id);
    return placement.emojiFor(threshold);
  }

  /// Pause-screen quotes paired with an emoji in the reference app
  /// (`QuotesManagerKt`). Text-only here — the countdown's emoji band already
  /// supplies the glyphs; these add rotation variety.
  static const List<String> _pairedQuotes = [
    'The successful warrior is the average man, with laser-like focus.',
    'Discipline is choosing between what you want now and what you want most.',
    'You will never always be motivated. You have to learn to be disciplined.',
    'The pain of discipline is far less than the pain of regret.',
    'Almost everything will work again if you unplug it for a few minutes.',
    'Your future self is watching you right now through memories.',
    'Small daily improvements are the key to staggering long-term results.',
    'Don’t watch the clock; do what it does — keep going.',
    'The feed is endless. Your time is not.',
  ];
}
