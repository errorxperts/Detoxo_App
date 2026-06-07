import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import 'package:detoxo/core/constants/app_constants.dart';
import 'package:detoxo/features/blocking/plans/domain/entities/mindful_quote.dart';
import 'package:detoxo/features/blocking/plans/domain/repositories/content_repository.dart';

/// Bundled dynamic content (mindful quotes). Emoji bands can be loaded the same
/// way from the other bundled JSON files when those screens need them.
class ContentRepositoryImpl implements ContentRepository {
  ContentRepositoryImpl({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final _random = Random();
  List<MindfulQuote>? _cache;

  @override
  Future<List<MindfulQuote>> mindfulQuotes() async {
    if (_cache != null) return _cache!;
    try {
      final raw = await _bundle.loadString(AppConstants.mindfulQuotes);
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final quotes = (map['quotes'] as List<dynamic>? ?? const [])
          .map((e) => MindfulQuote(e as String))
          .toList();
      return _cache = quotes;
    } on Exception {
      return _cache = const [MindfulQuote('Stay focused. The feed can wait.')];
    }
  }

  @override
  Future<MindfulQuote> randomQuote() async {
    final quotes = await mindfulQuotes();
    if (quotes.isEmpty) return const MindfulQuote('Stay focused.');
    return quotes[_random.nextInt(quotes.length)];
  }
}
