import 'package:detoxo/core/utils/result.dart';
import 'package:detoxo/features/monetization/premium/domain/entities/premium_entitlement.dart';

/// Premium entitlement (billing or local dev-unlock).
abstract interface class PremiumRepository {
  Stream<PremiumEntitlement> watch();
  Future<PremiumEntitlement> current();
  Future<void> setDevUnlock(bool unlocked);
  Future<Result<void>> purchase(String productId);
  Future<void> restore();
}
