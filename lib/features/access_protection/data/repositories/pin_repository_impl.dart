import 'dart:convert';

import 'package:detoxo/core/storage/local_store.dart';
import 'package:detoxo/features/access_protection/domain/entities/pin_config.dart';
import 'package:detoxo/features/access_protection/domain/pin_hasher.dart';
import 'package:detoxo/features/access_protection/domain/repositories/pin_repository.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';

/// PIN persistence in secure storage.
///
/// There is no recovery channel by design. With no backend, the only "recovery"
/// that could exist would be a client-side code — which is a bypass of the lock,
/// not a recovery of it. The escape hatch is reinstalling the app, which clears
/// secure storage along with everything else.
class PinRepositoryImpl implements PinRepository {
  PinRepositoryImpl(this._store);

  final LocalStore _store;

  @override
  Future<PinConfig> load() async {
    final raw = await _store.readSecret(StoreKeys.pinConfig);
    if (raw == null) return const PinConfig();
    final json = jsonDecode(raw) as Map<String, dynamic>;

    // Migrate legacy installs that stored a plaintext custom PIN under `secret`
    // (pre-hashing): hash it, persist, and drop the plaintext so it never sits
    // unhashed again.
    final legacySecret = json['secret'] as String?;
    final hasHash = (json['secretHash'] as String?)?.isNotEmpty ?? false;
    final isCustom =
        PinType.fromWire(json['type'] as String?) == PinType.custom;
    if (isCustom &&
        !hasHash &&
        legacySecret != null &&
        legacySecret.isNotEmpty) {
      final salt = PinHasher.newSalt();
      final migrated = PinConfig.fromJson(json).copyWith(
        secretHash: PinHasher.hash(salt, legacySecret),
        salt: salt,
        secretLength: legacySecret.length,
      );
      await save(migrated);
      return migrated;
    }

    return PinConfig.fromJson(json);
  }

  @override
  Future<void> save(PinConfig config) async {
    await _store.writeSecret(StoreKeys.pinConfig, jsonEncode(config.toJson()));
  }
}
