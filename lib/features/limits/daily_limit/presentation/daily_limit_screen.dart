import 'dart:async';

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/core/utils/duration_format.dart';
import 'package:detoxo/features/content_counter/content_counter.dart';
import 'package:detoxo/features/limits/daily_limit/domain/entities/daily_limit.dart';
import 'package:detoxo/features/limits/daily_limit/presentation/daily_limit_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Reads and mutates the app-wide [DailyLimitCubit] (provided in `main.dart`),
/// not a private instance — so a saved limit updates the dashboard ring live.
/// "Used" is today's reel time from the native counter ([ContentCounterCubit]),
/// the same meter that enforces the limit (the rules snapshot's daily reel
/// limit entry).
class DailyLimitScreen extends StatelessWidget {
  const DailyLimitScreen({super.key});

  @override
  Widget build(BuildContext context) => const _DailyLimitView();
}

class _DailyLimitView extends StatefulWidget {
  const _DailyLimitView();

  @override
  State<_DailyLimitView> createState() => _DailyLimitViewState();
}

class _DailyLimitViewState extends State<_DailyLimitView> {
  /// The slider's unsaved value; null shows the saved limit.
  double? _draftMinutes;

  /// The slider's range: 0 (no limit) to 8 h, in 15-minute steps.
  static const double _maxMinutes = 480;
  static const int _stepMinutes = 15;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final count = context.watch<ContentCounterCubit>().state;
    final used = count.timeToday;
    // Only a *definite* missing grant (tri-state, EVO-014): the wall is forced
    // past the Appearance switch when the limit runs out, but it can never be
    // drawn without this permission. The tap is the fix.
    final notice = count.loaded && !count.enabled
        ? NoticeLine(
            'Reel counter is off. Turn it on in Appearance to enforce the '
            'limit.',
            onTap: () => context.push(Routes.appearance),
          )
        : count.overlayGranted == false
        ? NoticeLine(
            'Needs “Display over other apps”. Feeds still close at the '
            'limit; the block screen needs this permission.',
            onTap: () =>
                unawaited(context.read<ContentCounterCubit>().requestOverlay()),
          )
        : null;

    // GlassScaffold applies the SafeArea itself; the global feedback action
    // rides on GlassAppBar.
    return GlassScaffold(
      appBar: const GlassAppBar(title: Text('Daily limit')),
      body: BlocBuilder<DailyLimitCubit, DailyLimit>(
        builder: (context, saved) {
          final limit = saved.limit;
          final draft = Duration(
            minutes: (_draftMinutes ?? limit.inMinutes).round(),
          );
          return ListView(
            // The app bar supplies the top gap, and each section header its
            // own rhythm.
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              0,
              AppSpacing.gutter,
              AppSpacing.xxl,
            ),
            children: [
              const SectionHeader('Today'),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatHm(used),
                      style: AppTypography.number.copyWith(color: t.ink),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      limit == Duration.zero
                          ? 'No daily limit'
                          : '${formatHm(used)} of ${formatHm(limit)} used',
                      style: AppTypography.subhead.copyWith(color: t.ink2),
                    ),
                    if (limit > Duration.zero) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _UsageBar(used: used, limit: limit),
                    ],
                  ],
                ),
              ),
              const SectionHeader('Daily limit'),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      draft == Duration.zero
                          ? 'No daily limit'
                          : '${formatHm(draft)} a day',
                      style: AppTypography.headline.copyWith(color: t.ink),
                    ),
                    Slider(
                      value: draft.inMinutes.clamp(0, _maxMinutes).toDouble(),
                      max: _maxMinutes,
                      divisions: _maxMinutes ~/ _stepMinutes,
                      label: formatHm(draft),
                      // TalkBack reads "3h", not the default percentage.
                      semanticFormatterCallback: (v) =>
                          formatHm(Duration(minutes: v.round())),
                      onChanged: (v) => setState(() => _draftMinutes = v),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    PrimaryButton(
                      label: 'Save limit',
                      icon: Icons.check_rounded,
                      expand: true,
                      onPressed: () {
                        context.read<DailyLimitCubit>().setLimit(draft);
                        setState(() => _draftMinutes = null);
                        GlassToast.show(
                          context,
                          'Daily limit saved',
                          tone: AppTone.success,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                child: Text(
                  'Reel feeds stay blocked until midnight once today’s reel '
                  'time reaches the limit. A Pause lifts it.',
                  style: AppTypography.subhead.copyWith(color: t.ink2),
                ),
              ),
              ?notice,
            ],
          );
        },
      ),
    );
  }
}

/// Today's reel time against the limit. The line above it says the same in
/// words; the bar still names its share for a screen reader.
class _UsageBar extends StatelessWidget {
  const _UsageBar({required this.used, required this.limit});

  final Duration used;
  final Duration limit;

  @override
  Widget build(BuildContext context) {
    final share = (used.inMinutes / limit.inMinutes).clamp(0.0, 1.0);
    return ProgressBar(
      progress: share,
      semanticLabel: '${(share * 100).round()}% of the daily limit used',
    );
  }
}

/// Off this screen since the Frozen Glass move: the Settings version row is its
/// last caller, and it goes once that row does.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    required this.text,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    super.key,
  });
  final String text;
  final String? title;
  final String? subtitle;

  /// Optional compact action shown at the trailing edge (e.g. an "Update"
  /// button on the app-version banner).
  final Widget? trailing;

  /// Makes the whole banner tappable (e.g. to trigger a manual update check).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final banner = Container(
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
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null)
                  Text(title!, style: Theme.of(context).textTheme.titleSmall),
                if (title != null) const SizedBox(height: 4),
                Text(text, style: Theme.of(context).textTheme.bodySmall),
                if (subtitle != null) const SizedBox(height: 4),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
    if (onTap == null) return banner;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: banner,
    );
  }
}
