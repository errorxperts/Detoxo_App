import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';
import 'package:detoxo/features/blocking/plans/domain/repositories/content_repository.dart';
import 'package:detoxo/features/blocking/plans/presentation/countdown_cubit.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/app_settings.dart';
import 'package:detoxo/features/blocking/shared/presentation/settings_cubit.dart';

/// Lets the user pause blocking for a chosen duration, with a mindful quote and
/// a live glass countdown while paused.
class PauseScreen extends StatelessWidget {
  const PauseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CountdownCubit(),
      child: const _PauseView(),
    );
  }
}

class _PauseView extends StatefulWidget {
  const _PauseView();

  @override
  State<_PauseView> createState() => _PauseViewState();
}

class _PauseViewState extends State<_PauseView> {
  String _quote = 'A short pause is fine. Choosing when is the point.';
  Duration? _ringTotal;

  static const _durations = [
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 15),
    Duration(minutes: 30),
  ];

  @override
  void initState() {
    super.initState();
    _loadQuote();
    _syncCountdown(context.read<SettingsCubit>().state);
  }

  Future<void> _loadQuote() async {
    final quote = await sl<ContentRepository>().randomQuote();
    if (mounted) setState(() => _quote = quote.text);
  }

  void _syncCountdown(AppSettings settings) {
    if (settings.isPaused && settings.pauseUntil != null) {
      _ringTotal ??= settings.pauseUntil!.difference(DateTime.now());
      context.read<CountdownCubit>().start(settings.pauseUntil!);
    } else {
      _ringTotal = null;
      context.read<CountdownCubit>().stop();
    }
  }

  void _pauseFor(Duration d) {
    _ringTotal = d;
    context.read<SettingsCubit>().pauseFor(d);
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: const GlassAppBar(title: Text('Pause')),
      body: BlocConsumer<SettingsCubit, AppSettings>(
        listener: (context, settings) => _syncCountdown(settings),
        builder: (context, settings) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: settings.isPaused
                ? _PausedView(quote: _quote, total: _ringTotal)
                : _PickerView(durations: _durations, onPick: _pauseFor),
          );
        },
      ),
    );
  }
}

class _PickerView extends StatelessWidget {
  const _PickerView({required this.durations, required this.onPick});

  final List<Duration> durations;
  final ValueChanged<Duration> onPick;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xs),
        const Icon(Icons.self_improvement, size: 56, color: AppColors.accent)
            .animate()
            .fadeIn()
            .scaleXY(begin: 0.9, end: 1, curve: Curves.easeOutBack),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Take a mindful pause',
          textAlign: TextAlign.center,
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Blocking resumes automatically when the timer ends.',
          textAlign: TextAlign.center,
          style: text.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final d in durations)
              AppChip(
                label: '${d.inMinutes} min',
                selected: false,
                onSelected: () => onPick(d),
              ),
          ],
        ),
      ],
    );
  }
}

class _PausedView extends StatelessWidget {
  const _PausedView({required this.quote, required this.total});

  final String quote;
  final Duration? total;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final remaining = context.watch<CountdownCubit>().state;
    final totalSecs = (total?.inSeconds ?? remaining.inSeconds).clamp(1, 1 << 30);
    final progress = remaining.inSeconds / totalSecs;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ProgressRing(
          progress: progress,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Blocking resumes in',
                style: text.bodySmall?.copyWith(color: context.glass.onGlassMuted),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(formatCountdown(remaining), style: AppTypography.mono(text.displaySmall)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        SectionCard(
          child: Text(
            quote,
            textAlign: TextAlign.center,
            style: text.titleMedium?.copyWith(fontStyle: FontStyle.italic),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        SecondaryButton(
          label: 'Resume blocking now',
          expand: true,
          onPressed: () => context.read<SettingsCubit>().resume(),
        ),
      ],
    );
  }
}
