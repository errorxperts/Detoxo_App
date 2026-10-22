import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/utils/clock_format.dart';
import 'package:detoxo/features/limits/rules/domain/entities/rule.dart';
import 'package:detoxo/features/limits/rules/domain/usecases/rule_summary.dart';
import 'package:detoxo/features/limits/rules/presentation/rules_cubit.dart';
import 'package:detoxo/features/limits/unblock/domain/entities/bypass_config.dart';
import 'package:detoxo/features/limits/unblock/domain/entities/bypass_entry.dart';
import 'package:detoxo/features/limits/unblock/presentation/unblock_cubit.dart';
import 'package:detoxo/features/limits/unblock/presentation/widgets/unblock_duration_sheet.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The honest way past a locked rule: spend one of a small weekly quota, name
/// a reason, pick a window. Shown inside the editor of a rule that is already
/// locked, so the escape sits exactly where the user goes looking for the off
/// switch they cannot find.
///
/// Deliberately NOT behind the PIN as well. The PIN guards settings; the quota
/// guards the rule. Stacking both means meeting two gates for one intention.
class OverrideTile extends StatelessWidget {
  const OverrideTile({required this.rule, super.key});

  final Rule rule;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final state = context.watch<UnblockCubit>().state;
    final live = context.read<UnblockCubit>().activeOverrideFor(rule.id);
    final time = localTimeFormat(context);
    // Is the rule actually blocking right now? An override buys a window
    // starting NOW, so spending one on a closed schedule (or an unspent budget)
    // costs a scarce resource and lifts nothing.
    final enforcing = context
        .watch<RulesCubit>()
        .state
        .statusOf(rule)
        .enforcing;
    final lockOpen = Icon(Icons.lock_open, color: t.ink2);
    if (live != null) {
      return GlassListTile(
        leading: lockOpen,
        title:
            'Lifted until ${RuleSummary.clock(live.untilMs, DateTime.now(), time: time)}',
        subtitle: live.reason?.label,
        trailing: StatusDot(color: t.statusPaused),
      );
    }
    final left = state.overridesLeft;
    final resets = state.overridesResetAtMs;
    return GlassListTile(
      leading: lockOpen,
      title: 'Lift this rule for a while',
      subtitle: !enforcing
          ? 'Not blocking right now'
          : left > 0
          ? _leftLine(state)
          : resets > 0
          ? 'None left. Back ${RuleSummary.clock(resets, DateTime.now(), time: time)}'
          : 'None left',
      // Never lead the user into a sheet that will refuse: no tap, no chevron.
      onTap: left > 0 && enforcing
          ? () => showOverrideSheet(context, rule)
          : null,
    );
  }
}

/// "1 override left this week" / "2 overrides left today" — the quota's
/// period, not a hard-coded week, so a daily config reads true.
String _leftLine(UnblockState state) {
  final left = state.overridesLeft;
  final period = state.config.overridePeriod == BypassPeriod.day
      ? 'today'
      : 'this week';
  return '$left ${left == 1 ? 'override' : 'overrides'} left $period';
}

/// Reason first, then the window on the [ConfirmSheet] — in that order on
/// purpose: naming the reason is the friction, and picking a duration before
/// it would make the reason feel like paperwork after the fact.
Future<void> showOverrideSheet(BuildContext context, Rule rule) async {
  final unblock = context.read<UnblockCubit>();
  final rules = context.read<RulesCubit>();
  final reason = await GlassBottomSheet.show<OverrideReason>(
    context: context,
    title: 'Why do you need ${rule.name} now?',
    child: Builder(
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final r in OverrideReason.values)
            GlassListTile(
              title: r.label,
              onTap: () => Navigator.of(sheetContext).pop(r),
            ),
        ],
      ),
    ),
  );
  if (reason == null || !context.mounted) return;
  final window = await showUnblockDurationSheet(
    context,
    title: 'Lift ${rule.name} for a while?',
    icon: Assets.images.icons.iconBlockerRules,
    message: 'You have ${_leftLine(unblock.state)}.',
    action: 'Slide to lift',
    cancel: 'Keep it locked',
    maxWindow: Duration(milliseconds: unblock.state.config.overrideMaxWindowMs),
  );
  if (window == null) return;
  // Re-read the status at commit time, not at build time: the sheet is two
  // taps long, and a schedule window can close inside it.
  final status = rules.state.statusOf(rule);
  final refused = await unblock.requestOverride(
    ruleId: rule.id,
    reason: reason,
    window: window,
    enforcingNow: status.enforcing,
  );
  // The snapshot resolver subtracts the lift from this rule's own windows, so
  // native re-arms at the far edge by the long compare it already does — the
  // rule comes back on time even if Detoxo is never reopened.
  if (refused == null) await rules.resync();
  if (!context.mounted) return;
  GlassToast.show(
    context,
    refused ?? '${rule.name} lifted for ${window.inMinutes} min',
    tone: refused == null ? AppTone.success : AppTone.warning,
  );
}
