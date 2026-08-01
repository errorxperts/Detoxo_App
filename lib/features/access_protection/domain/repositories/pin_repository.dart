import 'package:detoxo/features/access_protection/domain/entities/pin_config.dart';

/// PIN persistence. There is deliberately no recovery channel: the PIN never
/// leaves the device and there is no account behind it, so nothing here can
/// unlock on the user's behalf. See `docs/code_docs/08-pin-lock-recovery.md`.
abstract interface class PinRepository {
  Future<PinConfig> load();
  Future<void> save(PinConfig config);
}
