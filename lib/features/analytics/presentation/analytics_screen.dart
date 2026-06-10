import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';
import 'package:detoxo/features/analytics/domain/repositories/analytics_repository.dart';
import 'package:detoxo/features/analytics/presentation/analytics_cubit.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/engine_event.dart';
import 'package:detoxo/features/blocking/shared/domain/repositories/blocking_repositories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AnalyticsCubit(
        sl<AnalyticsRepository>(),
        sl<EngineRepository>(),
      )..load(),
      child: const _AnalyticsView(),
    );
  }
}

class _AnalyticsView extends StatelessWidget {
  const _AnalyticsView();

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, HH:mm');
    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: BlocBuilder<AnalyticsCubit, List<BlockEvent>>(
        builder: (context, events) {
          if (events.isEmpty) {
            return const EmptyState(
              icon: Icons.bar_chart,
              title: 'Nothing blocked yet',
              subtitle: 'Block events will show up here as they happen.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: events.length,
            itemBuilder: (context, i) {
              final e = events[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.block),
                  title: Text(e.platformId),
                  subtitle: Text('${e.packageName} · ${e.mode.wire}'),
                  trailing: Text(
                    fmt.format(e.timestamp),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
