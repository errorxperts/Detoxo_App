import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:equatable/equatable.dart';

/// Live status of the native engine plus block counters, streamed to the UI.
class ServiceSnapshot extends Equatable {
  const ServiceSnapshot({
    this.status = ServiceStatus.unknown,
    this.blocksToday = 0,
    this.blocksTotal = 0,
  });

  final ServiceStatus status;
  final int blocksToday;
  final int blocksTotal;

  ServiceSnapshot copyWith({
    ServiceStatus? status,
    int? blocksToday,
    int? blocksTotal,
  }) =>
      ServiceSnapshot(
        status: status ?? this.status,
        blocksToday: blocksToday ?? this.blocksToday,
        blocksTotal: blocksTotal ?? this.blocksTotal,
      );

  @override
  List<Object?> get props => [status, blocksToday, blocksTotal];
}

/// A single block event emitted by the native engine over the EventChannel.
class BlockEvent extends Equatable {
  const BlockEvent({
    required this.platformId,
    required this.packageName,
    required this.mode,
    required this.timestamp,
  });

  final String platformId;
  final String packageName;
  final BlockingMode mode;
  final DateTime timestamp;

  @override
  List<Object?> get props => [platformId, packageName, mode, timestamp];
}
