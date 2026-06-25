import 'dart:async';
import 'dart:convert';

import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/features/blocking/shared/domain/repositories/blocking_repositories.dart';
import 'package:detoxo/features/limits/app_blocker/domain/repositories/app_block_repository.dart';
import 'package:detoxo/features/limits/web_blocker/domain/entities/app_domain_catalog.dart';
import 'package:detoxo/features/limits/web_blocker/domain/entities/popular_site.dart';
import 'package:detoxo/features/limits/web_blocker/domain/entities/web_block_entry.dart';
import 'package:detoxo/features/limits/web_blocker/domain/entities/web_block_source.dart';
import 'package:detoxo/features/limits/web_blocker/domain/entities/web_block_stats.dart';
import 'package:detoxo/features/limits/web_blocker/domain/repositories/web_block_repository.dart';
import 'package:detoxo/features/limits/web_blocker/domain/repositories/web_block_stats_repository.dart';
import 'package:detoxo/features/limits/web_blocker/domain/utils/domain_validator.dart';
import 'package:detoxo/features/limits/web_blocker/presentation/web_block_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Owns the website blocklist: CRUD + persistence, the two protection toggles,
/// live stats, and pushing the merged active blocklist to the native engine.
class WebBlockCubit extends Cubit<WebBlockState> {
  WebBlockCubit(
    this._repo,
    this._settings,
    this._appBlocks,
    this._statsRepo,
    this._engine,
  ) : super(const WebBlockState());

  final WebBlockRepository _repo;
  final SettingsRepository _settings;
  final AppBlockRepository _appBlocks;
  final WebBlockStatsRepository _statsRepo;
  final EngineRepository _engine;

  StreamSubscription<WebBlockStats>? _statsSub;

  Future<void> load() async {
    try {
      final entries = await _repo.load();
      final settings = await _settings.load();
      final stats = await _statsRepo.load();
      emit(
        WebBlockState(
          isLoading: false,
          entries: entries,
          stats: stats,
          blockAdult: settings.blockAdultWebsites,
          blockForApps: settings.blockWebsitesForBlockedApps,
        ),
      );
      _statsSub ??= _statsRepo.watch().listen((s) {
        if (!isClosed) emit(state.copyWith(stats: s));
      });
      // Re-sync native with the persisted blocklist on (re)entry.
      await _pushAll();
    } on Object catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// Adds a user-typed domain after validation + dedupe.
  Future<void> addCustom(String domain) async {
    final host = DomainValidator.normalize(domain);
    if (host == null) {
      emit(state.copyWith(error: 'Enter a valid domain like youtube.com'));
      return;
    }
    if (state.entries.any((e) => e.pattern == host)) {
      emit(state.copyWith(error: '$host is already blocked'));
      return;
    }
    await _commit([
      ...state.entries,
      // source defaults to WebBlockSource.custom.
      WebBlockEntry(pattern: host, createdAt: DateTime.now()),
    ]);
  }

  /// Enables/disables a popular site with a single tap.
  Future<void> togglePopular(PopularSite site) async {
    final exists = state.entries.any((e) => e.pattern == site.primaryDomain);
    if (exists) {
      await _commit(
        state.entries.where((e) => e.pattern != site.primaryDomain).toList(),
      );
    } else {
      await _commit([
        ...state.entries,
        WebBlockEntry(
          pattern: site.primaryDomain,
          displayName: site.name,
          source: WebBlockSource.popular,
          brandColor: site.brandColor,
          createdAt: DateTime.now(),
        ),
      ]);
    }
  }

  Future<void> toggleEntry(WebBlockEntry entry, {required bool enabled}) async {
    await _commit([
      for (final e in state.entries)
        if (e.pattern == entry.pattern) e.copyWith(enabled: enabled) else e,
    ]);
  }

  Future<void> removeEntry(WebBlockEntry entry) async {
    await _commit(
      state.entries.where((e) => e.pattern != entry.pattern).toList(),
    );
  }

  /// Edits a custom entry's domain (re-validates + dedupes). Only custom entries
  /// are editable, so there is no display name to preserve.
  Future<void> editEntry(WebBlockEntry entry, String newDomain) async {
    final host = DomainValidator.normalize(newDomain);
    if (host == null) {
      emit(state.copyWith(error: 'Enter a valid domain like youtube.com'));
      return;
    }
    if (host != entry.pattern && state.entries.any((e) => e.pattern == host)) {
      emit(state.copyWith(error: '$host is already blocked'));
      return;
    }
    await _commit([
      for (final e in state.entries)
        if (e.pattern == entry.pattern) e.copyWith(pattern: host) else e,
    ]);
  }

  Future<void> setBlockAdult({required bool value}) async {
    emit(state.copyWith(blockAdult: value, clearError: true));
    final next = (await _settings.load()).copyWith(blockAdultWebsites: value);
    await _settings.save(next);
    await _engine.pushSettings(next);
  }

  Future<void> setBlockForApps({required bool value}) async {
    emit(state.copyWith(blockForApps: value, clearError: true));
    final next = (await _settings.load()).copyWith(
      blockWebsitesForBlockedApps: value,
    );
    await _settings.save(next);
    await _engine.pushSettings(next);
    // The derived app→domain rules changed, so re-push the blocklist too.
    await _pushAll();
  }

  void search(String query) => emit(state.copyWith(query: query));

  void clearError() => emit(state.copyWith(clearError: true));

  Future<void> _commit(List<WebBlockEntry> entries) async {
    emit(state.copyWith(entries: entries, clearError: true));
    await _repo.save(entries);
    await _pushAll();
  }

  /// Builds the merged, deduped active blocklist and ships it to native.
  ///
  /// Includes every active entry, the aliases of any popular entry, and — when
  /// [WebBlockState.blockForApps] is on — the domains derived from the enabled
  /// App Blocker entries via [AppDomainCatalog].
  Future<void> _pushAll() async {
    final patterns = <String, String>{}; // pattern -> matchType wire
    for (final e in state.entries) {
      if (!e.isActive) continue;
      patterns[e.pattern] = e.matchType.wire;
      if (e.source == WebBlockSource.popular) {
        for (final alias in PopularSites.aliasesFor(e.pattern)) {
          patterns.putIfAbsent(alias, () => WebMatchType.domain.wire);
        }
      }
    }
    if (state.blockForApps) {
      final apps = await _appBlocks.load();
      for (final app in apps) {
        if (!app.enabled) continue;
        for (final domain in AppDomainCatalog.domainsFor(app.packageName)) {
          patterns.putIfAbsent(domain, () => WebMatchType.domain.wire);
        }
      }
    }
    final wire = [
      for (final entry in patterns.entries)
        {'pattern': entry.key, 'matchType': entry.value},
    ];
    await _engine.pushWebBlocklist(jsonEncode(wire));
  }

  @override
  Future<void> close() {
    _statsSub?.cancel();
    return super.close();
  }
}
