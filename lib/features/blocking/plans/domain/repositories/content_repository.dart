import 'package:detoxo/features/blocking/plans/domain/entities/emoji_band.dart';
import 'package:detoxo/features/blocking/plans/domain/entities/mindful_quote.dart';

/// Dynamic content (quotes / emoji bands) from bundled assets. This is the
/// offline layer of the Dynamic Content Engine; a remote tier can be layered
/// behind the same interface later (TTL-gated `fetchcontent`).
abstract interface class ContentRepository {
  Future<List<MindfulQuote>> mindfulQuotes();
  Future<MindfulQuote> randomQuote();

  /// The bundled emoji placement for [id]; an empty *disabled* placement when
  /// the asset is missing or unparseable (never throws).
  Future<EmojiPlacement> emojiPlacement(EmojiPlacementId id);

  /// Items whose inclusive range covers [threshold] for [id] (re-open count,
  /// minutes elapsed, selected minutes, or cooldown %). Mirrors the verified
  /// `emojiForProgress`.
  Future<List<EmojiItem>> emojiFor(EmojiPlacementId id, int threshold);
}
