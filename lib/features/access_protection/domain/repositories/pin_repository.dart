import 'package:detoxo/core/utils/result.dart';
import 'package:detoxo/features/access_protection/domain/entities/pin_config.dart';

/// PIN setup/verification and email-OTP recovery.
abstract interface class PinRepository {
  Future<PinConfig> load();
  Future<void> save(PinConfig config);
  Future<Result<void>> sendRecoveryOtp(String email);
  Future<Result<bool>> validateOtp(String email, String otp);
}
