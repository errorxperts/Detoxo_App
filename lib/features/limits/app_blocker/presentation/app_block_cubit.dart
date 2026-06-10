import 'package:detoxo/features/limits/app_blocker/domain/entities/app_block_entry.dart';
import 'package:detoxo/features/limits/app_blocker/domain/repositories/app_block_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Manages the full-app blocklist (CRUD + persistence).
class AppBlockCubit extends Cubit<List<AppBlockEntry>> {
  AppBlockCubit(this._repo) : super(const []);

  final AppBlockRepository _repo;

  Future<void> load() async => emit(await _repo.load());

  Future<void> add(String packageName, String appName) async {
    final pkg = packageName.trim();
    if (pkg.isEmpty || state.any((e) => e.packageName == pkg)) return;
    final next = [
      ...state,
      AppBlockEntry(
        packageName: pkg,
        appName: appName.trim().isEmpty ? pkg : appName.trim(),
      ),
    ];
    await _commit(next);
  }

  Future<void> toggle(int index, {required bool enabled}) async {
    final next = [...state];
    next[index] = next[index].copyWith(enabled: enabled);
    await _commit(next);
  }

  Future<void> removeAt(int index) async {
    final next = [...state]..removeAt(index);
    await _commit(next);
  }

  Future<void> _commit(List<AppBlockEntry> entries) async {
    emit(entries);
    await _repo.save(entries);
  }
}
