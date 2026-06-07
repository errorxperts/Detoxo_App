import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/app_settings.dart';
import 'package:detoxo/features/blocking/plans/domain/repositories/content_repository.dart';
import 'package:detoxo/features/blocking/plans/presentation/countdown_cubit.dart';
import 'package:detoxo/features/blocking/shared/presentation/settings_cubit.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';

/// Lets the user pause blocking for a chosen duration, with a mindful quote and
/// a live countdown while paused.
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
      context.read<CountdownCubit>().start(settings.pauseUntil!);
    } else {
      context.read<CountdownCubit>().stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pause')),
      body: BlocConsumer<SettingsCubit, AppSettings>(
        listener: (context, settings) => _syncCountdown(settings),
        builder: (context, settings) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: settings.isPaused
                ? _PausedView(quote: _quote)
                : const _PickerView(durations: _durations),
          );
        },
      ),
    );
  }
}

class _PickerView extends StatelessWidget {
  const _PickerView({required this.durations});

  final List<Duration> durations;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(
          'Take a mindful pause',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text('Blocking resumes automatically when the timer ends.'),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final d in durations)
              FilledButton.tonal(
                onPressed: () =>
                    context.read<SettingsCubit>().pauseFor(d),
                child: Text('${d.inMinutes} min'),
              ),
          ],
        ),
      ],
    );
  }
}

class _PausedView extends StatelessWidget {
  const _PausedView({required this.quote});

  final String quote;

  @override
  Widget build(BuildContext context) {
    final remaining = context.watch<CountdownCubit>().state;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.self_improvement, size: 64),
        const SizedBox(height: 16),
        Text(
          formatCountdown(remaining),
          style: Theme.of(context)
              .textTheme
              .displayMedium
              ?.copyWith(fontWeight: FontWeight.w800, fontFeatures: const []),
        ),
        const SizedBox(height: 8),
        const Text('Blocking is paused'),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            quote,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontStyle: FontStyle.italic),
          ),
        ),
        const SizedBox(height: 32),
        OutlinedButton(
          onPressed: () => context.read<SettingsCubit>().resume(),
          child: const Text('Resume blocking now'),
        ),
      ],
    );
  }
}
