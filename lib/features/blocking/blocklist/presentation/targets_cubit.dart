import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:detoxo/features/blocking/shared/domain/entities/block_target.dart';
import 'package:detoxo/features/blocking/shared/domain/repositories/blocking_repositories.dart';
import 'package:detoxo/features/monetization/premium/domain/repositories/premium_repository.dart';

/// Loads the blockable targets (derived from the platform config), pushes the
/// raw config to the native engine on first load, and tracks premium status via
/// the monetization DOMAIN contract (never its presentation layer).
class TargetsCubit extends Cubit<TargetsState> {
  TargetsCubit(this._config, this._engine, this._premium)
      : super(const TargetsState()) {
    _premiumSub = _premium
        .watch()
        .listen((e) => emit(state.copyWith(isPremium: e.isPremium)));
  }

  final ConfigRepository _config;
  final EngineRepository _engine;
  final PremiumRepository _premium;
  StreamSubscription<dynamic>? _premiumSub;

  Future<void> load() async {
    emit(const TargetsState(isLoading: true));
    try {
      final raw = await _config.rawConfigJson();
      await _engine.pushConfig(raw);
      final targets = await _config.loadBlockTargets();
      final entitlement = await _premium.current();
      emit(TargetsState(targets: targets, isPremium: entitlement.isPremium));
    } on Exception catch (e) {
      emit(TargetsState(error: e.toString()));
    }
  }

  @override
  Future<void> close() {
    _premiumSub?.cancel();
    return super.close();
  }
}

class TargetsState extends Equatable {
  const TargetsState({
    this.isLoading = false,
    this.targets = const [],
    this.error,
    this.isPremium = false,
  });

  final bool isLoading;
  final List<BlockTarget> targets;
  final String? error;
  final bool isPremium;

  TargetsState copyWith({
    bool? isLoading,
    List<BlockTarget>? targets,
    String? error,
    bool? isPremium,
  }) =>
      TargetsState(
        isLoading: isLoading ?? this.isLoading,
        targets: targets ?? this.targets,
        error: error ?? this.error,
        isPremium: isPremium ?? this.isPremium,
      );

  @override
  List<Object?> get props => [isLoading, targets, error, isPremium];
}
