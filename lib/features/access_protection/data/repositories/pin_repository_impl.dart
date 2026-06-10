import 'dart:convert';

import 'package:detoxo/core/error/failures.dart';
import 'package:detoxo/core/storage/local_store.dart';
import 'package:detoxo/core/utils/result.dart';
import 'package:detoxo/features/access_protection/domain/entities/pin_config.dart';
import 'package:detoxo/features/access_protection/domain/repositories/pin_repository.dart';

/// PIN persistence (secure storage) + email-OTP recovery.
///
/// Offline-first: with no backend configured, recovery uses a documented dev
/// code (see README). Wire a real OTP endpoint behind [sendRecoveryOtp] /
/// [validateOtp] when the API is available.
class PinRepositoryImpl implements PinRepository {
  PinRepositoryImpl(this._store);

  final LocalStore _store;

  /// Dev recovery code used while no OTP backend is configured.
  static const String _devOtp = '000000';

  @override
  Future<PinConfig> load() async {
    final raw = await _store.readSecret(StoreKeys.pinConfig);
    if (raw == null) return const PinConfig();
    return PinConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> save(PinConfig config) async {
    await _store.writeSecret(StoreKeys.pinConfig, jsonEncode(config.toJson()));
  }

  @override
  Future<Result<void>> sendRecoveryOtp(String email) async {
    if (!_isValidEmail(email)) {
      return const Err(ValidationFailure('Enter a valid email address.'));
    }
    // No backend in offline mode; a real impl POSTs to /communication/sendOtp.
    return const Ok(null);
  }

  @override
  Future<Result<bool>> validateOtp(String email, String otp) async {
    // A real impl POSTs to /communication/validateOtp.
    return Ok(otp.trim() == _devOtp);
  }

  bool _isValidEmail(String email) =>
      RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(email.trim());
}
