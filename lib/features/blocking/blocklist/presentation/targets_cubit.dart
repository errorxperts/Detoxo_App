import 'package:detoxo/core/services/firebase/performance/performance_service.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/block_target.dart';
import 'package:detoxo/features/blocking/shared/domain/repositories/blocking_repositories.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Loads the blockable targets (derived from the platform config) and pushes the
/// raw config to the native engine on first load. Every target is available —
/// the app has no paid tier.
class TargetsCubit extends Cubit<TargetsState> {
  TargetsCubit(this._config, this._engine, {this._performance})
      : super(const TargetsState());

  final ConfigRepository _config;
  final EngineRepository _engine;

  /// Optional performance tracer; null in tests (load runs untraced).
  final PerformanceService? _performance;

  Future<void> load() async {
    emit(const TargetsState(isLoading: true));
    try {
      final targets = await _traced('load_block_targets', _loadTargets);
      emit(TargetsState(targets: targets));
    } on Exception catch (e) {
      emit(TargetsState(error: e.toString()));
    }
  }

  /// Pulls the raw config, pushes it to native, then resolves the
  /// installed-package-aware target list (the slow leg — a native round-trip).
  Future<List<BlockTarget>> _loadTargets() async {
    final raw = await _config.rawConfigJson();
    await _engine.pushConfig(raw);
    // null off-Android / on error => blocklist falls back to showing all.
    final installed = await _engine.installedPackages();
    return _config.loadBlockTargets(installedPackages: installed);
  }

  /// Wraps [action] in a performance trace when a [PerformanceService] is wired
  /// (production); runs it directly otherwise (tests).
  Future<T> _traced<T>(String name, Future<T> Function() action) =>
      _performance?.traceAsync(name, action) ?? action();
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
