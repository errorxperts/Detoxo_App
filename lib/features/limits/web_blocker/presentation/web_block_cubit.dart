import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/features/limits/web_blocker/domain/entities/web_block_entry.dart';
import 'package:detoxo/features/limits/web_blocker/domain/repositories/web_block_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Manages the website blocklist (CRUD + persistence).
class WebBlockCubit extends Cubit<List<WebBlockEntry>> {
  WebBlockCubit(this._repo) : super(const []);

  final WebBlockRepository _repo;

  Future<void> load() async => emit(await _repo.load());

  Future<void> add(String pattern, WebMatchType type, BlockingMode mode) async {
    final cleaned = pattern.trim();
    if (cleaned.isEmpty) return;
    final next = [
      ...state,
      WebBlockEntry(pattern: cleaned, matchType: type, blockMode: mode),
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

  Future<void> _commit(List<WebBlockEntry> entries) async {
    emit(entries);
    await _repo.save(entries);
  }
}
