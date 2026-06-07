import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:detoxo/features/monetization/premium/domain/entities/premium_entitlement.dart';
import 'package:detoxo/features/monetization/premium/domain/repositories/premium_repository.dart';

/// Exposes the current premium entitlement and the actions that change it.
class PremiumCubit extends Cubit<PremiumEntitlement> {
  PremiumCubit(this._repo) : super(const PremiumEntitlement()) {
    _sub = _repo.watch().listen(emit);
  }

  final PremiumRepository _repo;
  StreamSubscription<PremiumEntitlement>? _sub;

  Future<void> load() async => emit(await _repo.current());

  Future<void> toggleDevUnlock(bool unlocked) =>
      _repo.setDevUnlock(unlocked);

  Future<String?> purchase(String productId) async {
    final result = await _repo.purchase(productId);
    return result.fold((f) => f.message, (_) => null);
  }

  Future<void> restore() => _repo.restore();

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
