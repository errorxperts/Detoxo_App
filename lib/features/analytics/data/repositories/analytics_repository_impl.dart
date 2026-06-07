import 'dart:convert';

import 'package:detoxo/features/blocking/shared/domain/entities/engine_event.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/features/analytics/domain/repositories/analytics_repository.dart';
import 'package:detoxo/core/storage/local_store.dart';

/// Local block-event buffer (capped JSON list). A cloud sink (Firebase
/// Analytics) can be added behind the same interface later.
class AnalyticsRepositoryImpl implements AnalyticsRepository {
  AnalyticsRepositoryImpl(this._store);

  final LocalStore _store;
  static const int _maxEvents = 500;

  @override
  Future<void> logBlock(BlockEvent event) async {
    final events = await recent(limit: _maxEvents);
    final updated = [event, ...events].take(_maxEvents).toList();
    await _store.write(
      StoreKeys.analyticsEvents,
      jsonEncode(updated.map(_toJson).toList()),
    );
  }

  @override
  Future<List<BlockEvent>> recent({int limit = 50}) async {
    final raw = _store.read(StoreKeys.analyticsEvents);
    if (raw == null) return const [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .take(limit)
        .map((e) => _fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<int> countToday() async {
    final now = DateTime.now();
    final events = await recent(limit: _maxEvents);
    return events
        .where((e) =>
            e.timestamp.year == now.year &&
            e.timestamp.month == now.month &&
            e.timestamp.day == now.day)
        .length;
  }

  Map<String, dynamic> _toJson(BlockEvent e) => {
        'platformId': e.platformId,
        'packageName': e.packageName,
        'mode': e.mode.wire,
        'ts': e.timestamp.millisecondsSinceEpoch,
      };

  BlockEvent _fromJson(Map<String, dynamic> json) => BlockEvent(
        platformId: json['platformId'] as String? ?? '',
        packageName: json['packageName'] as String? ?? '',
        mode: BlockingMode.fromWire(json['mode'] as String?),
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(json['ts'] as int? ?? 0),
      );
}
