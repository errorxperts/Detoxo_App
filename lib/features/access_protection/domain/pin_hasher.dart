import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Salted SHA-256 hashing for custom PINs, so the secret is never persisted in
/// plaintext. Date/Time PINs are derived from the clock and never stored, so
/// they don't pass through here.
abstract final class PinHasher {
  /// A fresh, cryptographically-random 16-byte salt, base64Url-encoded for
  /// JSON-safe storage.
  static String newSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Hashes [secret] with [salt] (`sha256(salt:secret)`), returned as hex.
  static String hash(String salt, String secret) =>
      sha256.convert(utf8.encode('$salt:$secret')).toString();

  /// Whether [entry] hashes (with [salt]) to [expectedHash]. Returns false if
  /// no hash/salt is set, so a misconfigured custom PIN can never unlock.
  static bool verify(String salt, String expectedHash, String entry) {
    if (salt.isEmpty || expectedHash.isEmpty) return false;
    return hash(salt, entry) == expectedHash;
  }
}
