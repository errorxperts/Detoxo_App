import 'package:detoxo/features/access_protection/domain/entities/pin_config.dart';
import 'package:detoxo/features/access_protection/domain/pin_hasher.dart';
import 'package:detoxo/features/access_protection/domain/repositories/pin_repository.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_auth/local_auth.dart';

/// PIN setup + verification with the escalating lockout ladder, plus biometric
/// unlock and email-OTP recovery.
class PinCubit extends Cubit<PinConfig> {
  PinCubit(this._repo, {LocalAuthentication? localAuth})
    : _localAuth = localAuth ?? LocalAuthentication(),
      super(const PinConfig());

  final PinRepository _repo;
  final LocalAuthentication _localAuth;

  Future<void> load() async => emit(await _repo.load());

  Future<void> setup({
    required PinType type,
    required String secret,
    required Set<PinScope> scopes,
    String verifiedEmail = '',
    bool biometricEnabled = false,
  }) async {
    // Custom PINs are stored as a salted hash; Date/Time derive from the clock
    // and keep no secret at all.
    final salt = type == PinType.custom ? PinHasher.newSalt() : '';
    final config = PinConfig(
      type: type,
      secretHash: type == PinType.custom ? PinHasher.hash(salt, secret) : '',
      salt: salt,
      secretLength: type == PinType.custom ? secret.length : 0,
      scopes: scopes,
      verifiedEmail: verifiedEmail,
      biometricEnabled: biometricEnabled,
    );
    await _repo.save(config);
    emit(config);
  }

  Future<void> disable() async {
    const config = PinConfig();
    await _repo.save(config);
    emit(config);
  }

  /// After a verified recovery, set a fresh custom PIN — keeping the guarded
  /// scopes, recovery email and biometric preference, and clearing the retry /
  /// lockout state. Used by the "Forgot PIN" flow instead of disabling the lock.
  Future<void> resetSecretAfterRecovery(String newSecret) async {
    final salt = PinHasher.newSalt();
    final next = state.copyWith(
      type: PinType.custom,
      secretHash: PinHasher.hash(salt, newSecret),
      salt: salt,
      secretLength: newSecret.length,
      retryCount: 0,
      clearLockout: true,
    );
    await _repo.save(next);
    emit(next);
  }

  /// Digit count that constitutes a complete entry for the active PIN type, so
  /// the lock screen can auto-submit at the right length (custom PINs may be
  /// 4–10 digits; DATE is `ddMMyyyy` = 8, TIME is `HHmm` = 4).
  int get expectedLength => switch (state.type) {
    PinType.custom => state.secretLength,
    PinType.date => 8,
    PinType.time => 4,
    _ => 4,
  };

  /// Whether biometric/device-credential unlock is usable on this device, used
  /// to hide the biometric toggle where it isn't supported.
  Future<bool> canUseBiometrics() async {
    try {
      return await _localAuth.isDeviceSupported() &&
          await _localAuth.canCheckBiometrics;
    } on Exception {
      return false;
    }
  }

  /// Verifies [entry]; updates the retry/lockout state on failure.
  Future<bool> verify(String entry) async {
    final config = state;
    if (config.isLockedOut) return false;

    final ok = _matches(config, entry);
    if (ok) {
      final reset = config.copyWith(retryCount: 0, clearLockout: true);
      await _repo.save(reset);
      emit(reset);
      return true;
    }

    final retries = config.retryCount + 1;
    final lockout = PinLockoutPolicy.lockoutFor(retries);
    final updated = config.copyWith(
      retryCount: retries,
      lockedUntil: lockout == null ? null : DateTime.now().add(lockout),
    );
    await _repo.save(updated);
    emit(updated);
    return false;
  }

  /// Whether [entry] matches the configured PIN. DATE/TIME are derived from the
  /// clock; custom PINs compare against the salted hash (never plaintext).
  bool _matches(PinConfig config, String entry) {
    final now = DateTime.now();
    return switch (config.type) {
      PinType.date => entry == '${_two(now.day)}${_two(now.month)}${now.year}',
      PinType.time => entry == '${_two(now.hour)}${_two(now.minute)}',
      PinType.custom =>
        PinHasher.verify(config.salt, config.secretHash, entry),
      _ => false,
    };
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  Future<bool> authenticateBiometric() async {
    try {
      final canCheck =
          await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
      if (!canCheck) return false;
      return await _localAuth.authenticate(
        localizedReason: 'Unlock Detoxo',
        persistAcrossBackgrounding: true,
      );
    } on Exception {
      return false;
    }
  }

  Future<bool> sendRecoveryOtp(String email) async =>
      (await _repo.sendRecoveryOtp(email)).isOk;

  Future<bool> validateRecoveryOtp(String email, String otp) async {
    final result = await _repo.validateOtp(email, otp);
    return result.fold((_) => false, (valid) => valid);
  }
}
