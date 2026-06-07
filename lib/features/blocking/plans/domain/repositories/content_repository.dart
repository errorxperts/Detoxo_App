import 'package:detoxo/features/blocking/plans/domain/entities/mindful_quote.dart';

/// Dynamic content (quotes / emoji bands) from bundled assets.
abstract interface class ContentRepository {
  Future<List<MindfulQuote>> mindfulQuotes();
  Future<MindfulQuote> randomQuote();
}
