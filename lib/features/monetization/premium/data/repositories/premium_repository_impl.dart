import 'dart:async';

import 'package:detoxo/core/error/failures.dart';
import 'package:detoxo/core/storage/local_store.dart';
import 'package:detoxo/core/utils/result.dart';
import 'package:detoxo/features/monetization/premium/domain/entities/premium_entitlement.dart';
import 'package:detoxo/features/monetization/premium/domain/repositories/premium_repository.dart';

/// Premium entitlement. Offline-first: defaults to free, with a local dev-unlock
/// for testing gated features. Real Play Billing wires into [purchase]/[restore]
/// (see README); the rest of the app only depends on this interface.
class PremiumRepositoryImpl implements PremiumRepository {
  PremiumRepositoryImpl(this._store);

  final LocalStore _store;
  final _controller = StreamController<PremiumEntitlement>.broadcast();

  @override
  Stream<PremiumEntitlement> watch() => _controller.stream;

  @override
  Future<PremiumEntitlement> current() async {
    final unlocked = _store.read(StoreKeys.premiumDevUnlock) == 'true';
    return PremiumEntitlement(
      isPremium: unlocked,
      activePlans: unlocked ? const ['dev_unlock'] : const [],
    );
  }

  @override
  Future<void> setDevUnlock({required bool unlocked}) async {
    await _store.write(StoreKeys.premiumDevUnlock, unlocked ? 'true' : 'false');
    _controller.add(await current());
  }

  @override
  Future<Result<void>> purchase(String productId) async {
    // Real impl: in_app_purchase buyNonConsumable / subscriptions. With no
    // store products configured we surface a clear, recoverable failure.
    return const Err(
      ServerFailure('Billing is not configured in this build. See README.'),
    );
  }

  @override
  Future<void> restore() async {
    _controller.add(await current());
  }
}
