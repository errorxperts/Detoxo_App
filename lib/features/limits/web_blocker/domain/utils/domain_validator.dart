import 'package:detoxo/features/limits/web_blocker/domain/entities/web_block_entry.dart';

/// Normalizes and validates user-entered website domains before they become
/// blocklist entries. Accepts `example.com`, `www.example.com`,
/// `sub.example.com`, and full URLs (`https://example.com/path`); rejects empty
/// input, spaces, scheme-only text and single-label hosts.
abstract final class DomainValidator {
  // One or more dot-separated labels (letters/digits/hyphens, not edge hyphens)
  // followed by a 2–24 character TLD.
  static final RegExp _host = RegExp(
    r'^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,24}$',
  );

  /// Returns the cleaned host (scheme/`www.`/path/query/port stripped, lower
  /// cased) or `null` when the input is not a valid domain.
  static String? normalize(String input) {
    var s = input.trim().toLowerCase();
    if (s.isEmpty) return null;
    s = s.replaceFirst(RegExp('^[a-z][a-z0-9+.-]*://'), ''); // scheme
    s = s.split('/').first; // path
    s = s.split('?').first.split('#').first; // query / fragment
    s = s.split(':').first; // port
    s = s.replaceFirst(RegExp(r'^www\.'), '');
    if (s.isEmpty || s.contains(' ') || !s.contains('.')) return null;
    return _host.hasMatch(s) ? s : null;
  }

  static bool isDuplicate(String host, Iterable<WebBlockEntry> existing) =>
      existing.any((e) => e.pattern == host);
}
