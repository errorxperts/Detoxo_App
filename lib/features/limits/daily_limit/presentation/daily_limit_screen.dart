import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';
import 'package:detoxo/features/limits/daily_limit/domain/entities/daily_limit.dart';
import 'package:detoxo/features/limits/daily_limit/domain/repositories/daily_limit_repository.dart';
import 'package:detoxo/features/limits/daily_limit/presentation/daily_limit_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DailyLimitScreen extends StatelessWidget {
  const DailyLimitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DailyLimitCubit(sl<DailyLimitRepository>())..load(),
      child: const _DailyLimitView(),
    );
  }
}

class _DailyLimitView extends StatefulWidget {
  const _DailyLimitView();

  @override
  State<_DailyLimitView> createState() => _DailyLimitViewState();
}

class _DailyLimitViewState extends State<_DailyLimitView> {
  double? _draftMinutes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily limit')),
      body: SafeArea(
        child: BlocBuilder<DailyLimitCubit, DailyLimit>(
        builder: (context, limit) {
          final minutes = _draftMinutes ?? limit.limit.inMinutes.toDouble();
          final consumed = limit.consumed.inMinutes;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: 'Today',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      limit.limit == Duration.zero
                          ? 'No daily limit set'
                          : '$consumed of ${limit.limit.inMinutes} min used',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: limit.limit == Duration.zero
                          ? 0
                          : (consumed / limit.limit.inMinutes).clamp(0.0, 1.0),
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Set your daily limit',
                child: Column(
                  children: [
                    Text('${minutes.round()} minutes per day',
                        style: Theme.of(context).textTheme.headlineSmall),
                    Slider(
                      value: minutes.clamp(0, 180),
                      max: 180,
                      divisions: 36,
                      label: '${minutes.round()} min',
                      onChanged: (v) => setState(() => _draftMinutes = v),
                    ),
                    const SizedBox(height: 8),
                    AnimatedIconButton(
                      label: 'Save limit',
                      icon: AppIcon.check,
                      expand: true,
                      onPressed: () {
                        context
                            .read<DailyLimitCubit>()
                            .setLimit(Duration(minutes: minutes.round()));
                        setState(() => _draftMinutes = null);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Daily limit saved.')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const _InfoBanner(
                text:
                    'Usage counting is enforced by the native service on a real '
                    'device with usage access granted.',
              ),
            ],
          );
        },
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const AppAnimatedIcon(
            icon: AppIcon.info,
            size: 20,
            interactive: true,
            playOnAppear: true,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}
