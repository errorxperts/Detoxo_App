import 'dart:async';

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/features/blocking/plans/domain/entities/emoji_band.dart';
import 'package:detoxo/features/blocking/plans/domain/repositories/content_repository.dart';
import 'package:detoxo/features/blocking/plans/presentation/widgets/mindful_countdown.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:flutter/material.dart';

/// Everything the [MindfulCountdownView] needs to render one tick: the live
/// phase, label, remaining time, ring progress, and which emoji band + bucket
/// to show. Computed from the live session on every tick.
class MindfulPhaseSpec {
  const MindfulPhaseSpec({
    required this.phase,
    required this.label,
    required this.remaining,
    required this.progress,
    this.placement,
    this.bucket = 0,
  });

  final SessionPhase phase;
  final String label;
  final Duration remaining;
  final double progress;
  final EmojiPlacementId? placement;
  final int bucket;
}

/// Drives a [MindfulCountdown] from a live session: owns a 1 Hz ticker (so the
/// timer / ring update every second), preloads the bundled emoji [placements],
/// and rotates the quote every few seconds and on each phase change.
class MindfulCountdownView extends StatefulWidget {
  const MindfulCountdownView({
    required this.describe,
    required this.placements,
    required this.actionsBuilder,
    super.key,
  });

  /// Computes the spec for "now" from the live session (read fresh each tick).
  final MindfulPhaseSpec Function(DateTime now) describe;

  /// Emoji placements to preload so band lookups are synchronous in build.
  final Set<EmojiPlacementId> placements;

  /// Phase-specific actions (e.g. "Resume now" / "End session" / "Stop").
  final Widget Function(SessionPhase phase) actionsBuilder;

  @override
  State<MindfulCountdownView> createState() => _MindfulCountdownViewState();
}

class _MindfulCountdownViewState extends State<MindfulCountdownView> {
  static const _secondsPerQuote = 6;

  final _content = sl<ContentRepository>();
  final Map<EmojiPlacementId, EmojiPlacement> _placements = {};
  List<String> _quotes = const ['Stay focused. The feed can wait.'];

  Timer? _ticker;
  int _quoteIndex = 0;
  int _secondsOnQuote = 0;
  SessionPhase? _lastPhase;

  @override
  void initState() {
    super.initState();
    _loadContent();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  Future<void> _loadContent() async {
    final quotes = await _content.mindfulQuotes();
    for (final id in widget.placements) {
      _placements[id] = await _content.emojiPlacement(id);
    }
    if (!mounted) return;
    setState(() {
      if (quotes.isNotEmpty) _quotes = quotes.map((q) => q.text).toList();
    });
  }

  void _onTick() {
    if (!mounted) return;
    final spec = widget.describe(DateTime.now());
    if (spec.phase != _lastPhase) {
      _lastPhase = spec.phase;
      _advanceQuote();
    } else if (++_secondsOnQuote >= _secondsPerQuote) {
      _advanceQuote();
    }
    setState(() {});
  }

  void _advanceQuote() {
    _quoteIndex++;
    _secondsOnQuote = 0;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.describe(DateTime.now());
    final placement = spec.placement == null ? null : _placements[spec.placement];
    final emoji = placement?.itemFor(spec.bucket);
    final quote = _quotes[_quoteIndex % _quotes.length];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        MindfulCountdown(
          phaseLabel: spec.label,
          remaining: spec.remaining,
          progress: spec.progress,
          quote: quote,
          emoji: emoji,
        ),
        const SizedBox(height: AppSpacing.lg),
        widget.actionsBuilder(spec.phase),
      ],
    );
  }
}
