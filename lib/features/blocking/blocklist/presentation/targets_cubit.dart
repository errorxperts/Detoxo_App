import 'package:detoxo/features/blocking/shared/domain/entities/block_target.dart';
import 'package:detoxo/features/blocking/shared/domain/repositories/blocking_repositories.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Loads the blockable targets (derived from the platform config) and pushes the
/// raw config to the native engine on first load. Every target is available —
/// the app has no paid tier.
class TargetsCubit extends Cubit<TargetsState> {
  TargetsCubit(this._config, this._engine) : super(const TargetsState());

  final ConfigRepository _config;
  final EngineRepository _engine;

  Future<void> load() async {
    emit(const TargetsState(isLoading: true));
    try {
      final raw = await _config.rawConfigJson();
      await _engine.pushConfig(raw);
      // null off-Android / on error => blocklist falls back to showing all.
      final installed = await _engine.installedPackages();
      final targets =
          await _config.loadBlockTargets(installedPackages: installed);
      emit(TargetsState(targets: targets));
    } on Exception catch (e) {
      emit(TargetsState(error: e.toString()));
    }
  }
}

class TargetsState extends Equatable {
  const TargetsState({
    this.isLoading = false,
    this.targets = const [],
    this.error,
  });

  final bool isLoading;
  final List<BlockTarget> targets;
  final String? error;

  TargetsState copyWith({
    bool? isLoading,
    List<BlockTarget>? targets,
    String? error,
  }) =>
      TargetsState(
        isLoading: isLoading ?? this.isLoading,
        targets: targets ?? this.targets,
        error: error ?? this.error,
      );

  @override
  List<Object?> get props => [isLoading, targets, error];
}
