import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/core/utils/clock_format.dart';
import 'package:detoxo/core/utils/duration_format.dart';
import 'package:detoxo/features/content_counter/content_counter.dart';
import 'package:detoxo/features/limits/daily_limit/domain/entities/daily_limit.dart';
import 'package:detoxo/features/limits/daily_limit/presentation/daily_limit_cubit.dart';
import 'package:detoxo/features/limits/rules/domain/entities/rule.dart';
import 'package:detoxo/features/limits/rules/domain/entities/rule_editor_args.dart';
import 'package:detoxo/features/limits/rules/domain/entities/rule_preset.dart';
import 'package:detoxo/features/limits/rules/domain/entities/rule_snapshot.dart';
import 'package:detoxo/features/limits/rules/domain/usecases/rule_summary.dart';
import 'package:detoxo/features/limits/rules/presentation/rules_cubit.dart';
import 'package:detoxo/features/limits/rules/presentation/widgets/rule_kind_icon.dart';
import 'package:detoxo/features/permissions/permissions.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

/// The rules list. Reads the app-wide [RulesCubit] (provided in `main.dart`)
/// and re-syncs on entry so statuses and the usage grant are fresh.
class RulesScreen extends StatefulWidget {
  const RulesScreen({super.key});

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<RulesCubit>().resync();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: const GlassAppBar(
        title: Text('Blocker rules'),
        actions: [
          InfoButton(
            'Schedules block their targets during the hours you pick. Daily '
            "limits block once today's budget is spent, until midnight. A "
            'Pause lifts rules the way it lifts reel blocking — unless a rule '
            'is marked Strict or Locked. App Blocker locks always stay on.',
          ),
        ],
      ),
      floatingActionButton: GlassFab(
        onPressed: () => _newRule(context),
        icon: const Icon(Icons.add_rounded),
        label: 'New rule',
      ),
      body: BlocConsumer<RulesCubit, RulesState>(
        listenWhen: (p, c) => p.error != c.error && c.error != null,
        listener: (context, state) {
          // The editor is pushed OVER this screen, which stays mounted, so a
          // refusal raised from the editor would toast here as well — and
          // clear the message before the editor read it, leaving it the
          // generic "Couldn't save". The editor owns its own errors; this
          // listener speaks only while the list is the screen on top.
          if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
          GlassToast.show(context, state.error!, tone: AppTone.danger);
          context.read<RulesCubit>().clearError();
        },
        builder: (context, state) {
          final now = DateTime.now();
          return ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              0,
              AppSpacing.gutter,
              // The extended FAB, not the home shell's floating nav — same clearance
              // the App/Web blocker screens use.
              96 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            children: [
              // `== false`, not `!= true`: the grant is tri-state and unknown
              // is not denied — flashing "limits cannot enforce" on every cold
              // entry, before resync answers, is the repo's documented mistake
              // (see PermissionCard's "Checking…" row).
              if (state.hasLimitRule && state.hasUsageAccess == false)
                const _UsageAccessHint(),
              const _DailyReelLimitRow(),
              const SectionHeader('Your rules'),
              if (state.isLoading)
                const LoadingState()
              else if (state.rules.isEmpty) ...[
                const EmptyState(
                  icon: Icons.rule_folder_outlined,
                  title: 'No rules yet',
                  subtitle:
                      'Block apps on a schedule, or cap how long and how '
                      'often you use them each day.',
                ),
                // No CTA on the empty state itself — the FAB is the blank-page
                // entry point (the App Blocker screen makes the same call).
                // These are the shortcut past it.
                const SectionHeader('Start from a preset'),
                PanelGroup(
                  children: [
                    for (final preset in RulePreset.all)
                      _PresetTile(preset: preset),
                  ],
                ),
              ] else
                PanelGroup(
                  children: [
                    for (final rule in state.rules)
                      _RuleTile(
                        rule: rule,
                        status: state.statusOf(rule),
                        now: now,
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _newRule(BuildContext context) async {
    final cubit = context.read<RulesCubit>();
    if (cubit.state.rules.length >= maxRules) {
      GlassToast.show(context, RulesCubit.capReached, tone: AppTone.warning);
      return;
    }
    final kind = await GlassBottomSheet.show<RuleKind>(
      context: context,
      title: 'New rule',
      // Flat rows on the sheet itself, split by hairlines.
      child: PanelGroup(
        children: [
          for (final k in RuleKind.values)
            GlassListTile(
              leading: Icon(ruleKindIcon(k), color: context.tokens.ink2),
              title: k.label,
              subtitle: _kindHint(k),
              onTap: () => Navigator.of(context).pop(k),
            ),
        ],
      ),
    );
    if (kind == null || !context.mounted) return;
    await context.push(Routes.ruleEditor, extra: RuleEditorArgs(kind: kind));
  }

  static String _kindHint(RuleKind k) => switch (k) {
    RuleKind.schedule => 'Block apps, sites or reel feeds during set hours',
    RuleKind.timeLimit =>
      'A daily budget of minutes, then blocked until midnight',
    RuleKind.openLimit =>
      'A number of opens a day, then blocked until midnight',
  };
}

/// A starter rule (EVO-031). Opens the editor pre-filled — never saves on tap,
/// so the user still confirms the hours before anything blocks.
class _PresetTile extends StatelessWidget {
  const _PresetTile({required this.preset});

  final RulePreset preset;

  @override
  Widget build(BuildContext context) => GlassListTile(
    leading: Icon(
      ruleKindIcon(preset.template.kind),
      color: context.tokens.ink2,
    ),
    title: preset.template.name,
    subtitle: preset.describe(localTimeFormat(context)),
    trailing: Icon(Icons.add_circle_outline, color: context.tokens.ink2),
    onTap: () => context.push(
      Routes.ruleEditor,
      extra: RuleEditorArgs(
        kind: preset.template.kind,
        rule: preset.stamp(
          id: const Uuid().v4(),
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      ),
    ),
  );
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.rule,
    required this.status,
    required this.now,
  });

  final Rule rule;
  final RuleStatus status;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final time = localTimeFormat(context);
    final label = RuleSummary.status(rule, status, now, time: time);
    final tone = !rule.enabled
        ? AppTone.neutral
        : status.isLifted
        ? AppTone.warning
        : status.spent
        ? AppTone.warning
        : status.activeNow
        ? AppTone.success
        : !status.usageKnown && rule.kind.isLimit
        ? AppTone.warning
        : AppTone.neutral;
    return GlassListTile(
      leading: Icon(
        rule.locked ? Icons.lock_outline : ruleKindIcon(rule.kind),
        color: context.tokens.ink2,
      ),
      title: rule.name,
      subtitle: RuleSummary.describe(rule, time: time),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label.isNotEmpty) ...[
            Pill(label: label, tone: tone),
            const SizedBox(width: AppSpacing.xs),
          ],
          // A locked rule renders NO toggle — absent, not greyed out. A
          // disabled switch is an invitation to keep tapping, and the domain
          // would refuse it anyway (`LockGuard`). The way out is an override,
          // which the editor offers and which costs quota.
          if (rule.locked)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xxs),
              child: Icon(Icons.lock, size: 18, color: context.tokens.ink2),
            )
          else
            AppToggle(
              value: rule.enabled,
              semanticLabel: 'Enable ${rule.name}',
              onChanged: (on) => on
                  ? context.read<RulesCubit>().setEnabled(
                      rule.id,
                      enabled: true,
                    )
                  : _turnOff(context),
            ),
        ],
      ),
      onTap: () => context.push(
        Routes.ruleEditor,
        extra: RuleEditorArgs(kind: rule.kind, rule: rule),
      ),
    );
  }

  /// C10: one tap turns a rule off. Once the cubit's state shows it landed (a
  /// failed save reverts and toasts its own error), the toast offers Undo,
  /// re-resolved by rule id at tap time: a deleted rule stays deleted.
  Future<void> _turnOff(BuildContext context) async {
    final cubit = context.read<RulesCubit>();
    bool? enabled() =>
        cubit.state.rules.where((r) => r.id == rule.id).firstOrNull?.enabled;
    await cubit.setEnabled(rule.id, enabled: false);
    if (!context.mounted || enabled() != false) return;
    GlassToast.show(
      context,
      '${rule.name} off',
      action: (
        label: 'Undo',
        onPressed: () {
          if (enabled() == false) cubit.setEnabled(rule.id, enabled: true);
        },
      ),
    );
  }
}

/// Limits count app time and opens from UsageStats — without the grant they
/// can only watch, so say so and offer the settings page.
class _UsageAccessHint extends StatelessWidget {
  const _UsageAccessHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          const Expanded(
            child: Pill(label: 'Usage access needed', tone: AppTone.warning),
          ),
          SecondaryButton(
            label: 'Grant',
            // The one entry point: disclosure, the restricted-settings
            // walkthrough and the cubit re-read live there, not here.
            onPressed: () =>
                requestPermission(context, AppPermission.usageAccess),
          ),
        ],
      ),
    );
  }
}

/// The global Daily Limit, enforced natively against today's reel time —
/// pinned here so every enforced limit is visible in one place.
class _DailyReelLimitRow extends StatelessWidget {
  const _DailyReelLimitRow();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DailyLimitCubit, DailyLimit>(
      builder: (context, limit) {
        if (limit.limit == Duration.zero) return const SizedBox.shrink();
        final count = context.watch<ContentCounterCubit>().state;
        final t = context.tokens;
        final reached = count.enabled && count.timeToday >= limit.limit;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader('Daily reel limit'),
            GlassListTile(
              leading: Icon(Icons.timelapse, color: t.ink2),
              title: 'Reels · ${formatHm(limit.limit)} a day',
              subtitle: count.enabled
                  ? 'Blocks every reel feed at the limit, until midnight'
                  : 'Reel counter is off, so the limit can’t be enforced',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Pill(
                    label: reached
                        ? 'Limit reached'
                        : '${formatHm(count.timeToday)} of '
                              '${formatHm(limit.limit)}',
                    tone: reached
                        ? AppTone.warning
                        : count.enabled
                        ? AppTone.neutral
                        : AppTone.warning,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  // A trailing value replaces the row's own chevron, so it is
                  // drawn here (the Insights limit row does the same).
                  Glyph(Assets.svg.chevronRight, size: 18, color: t.ink3),
                ],
              ),
              onTap: () => context.push(Routes.dailyLimit),
            ),
          ],
        );
      },
    );
  }
}
