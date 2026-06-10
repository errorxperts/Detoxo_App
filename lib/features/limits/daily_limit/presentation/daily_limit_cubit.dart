import 'package:detoxo/features/limits/daily_limit/domain/entities/daily_limit.dart';
import 'package:detoxo/features/limits/daily_limit/domain/repositories/daily_limit_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Manages the per-day usage quota with a device-local midnight reset.
class DailyLimitCubit extends Cubit<DailyLimit> {
  DailyLimitCubit(this._repo) : super(const DailyLimit());

  final DailyLimitRepository _repo;

  /// Device-local date signature, e.g. "07-06-2026".
  static String todaySignature() =>
      DateFormat('dd-MM-yyyy').format(DateTime.now());

  Future<void> load() async {
    final loaded = (await _repo.load()).refreshed(todaySignature());
    await _repo.save(loaded);
    emit(loaded);
  }

  Future<void> setLimit(Duration limit) async {
    final next = state.copyWith(
      limit: limit,
      dateSignature: todaySignature(),
    );
    await _repo.save(next);
    emit(next);
  }

  @visibleForTesting
  Future<void> addConsumed(Duration delta) async {
    final next = state.copyWith(consumed: state.consumed + delta);
    await _repo.save(next);
    emit(next);
  }
}
