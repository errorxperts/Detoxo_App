import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/utils/clock_format.dart';
import 'package:detoxo/features/limits/rules/domain/usecases/rule_summary.dart';
import 'package:detoxo/features/limits/unblock/domain/entities/temporary_unblock.dart';
import 'package:detoxo/features/limits/unblock/presentation/unblock_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// EVO-051 — the one place that says what is open right now.
///
/// M8 shipped grants but no inventory of them: a grant was visible only on the
/// row that minted it, and a `REEL` grant (mintable from the block screen) was
/// visible **nowhere at all**. Detoxo's promise is that you cannot forget to
/// re-enable protection; without this you could still forget *what you opened*,
/// which is the same failure wearing a different hat.
///
/// One panel of flat rows: the name, "Allowed until 11 PM" and "Block now",
/// which ends the grant at once (strengthening, so no confirm). Hides itself
/// entirely when nothing is allowed, so the ordinary dashboard is unchanged.
/// Reads the cubit's DERIVED `active` list, which is re-emitted when a grant
/// lapses — so a row leaves on its own, without a ticker. On Today it sits
/// under the Blockers header and brings its own top gap.
class ActiveUnblocksCard extends StatelessWidget {
  const ActiveUnblocksCard({this.nameOf, super.key});

  /// The grant's display name. The stored id is a `platformId`, a package or
  /// a host; the caller resolves it from what it has already loaded, so this
  /// card never waits on the installed-apps scan. Defaults to the id.
  final String Function(TemporaryUnblock grant)? nameOf;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UnblockCubit, UnblockState>(
      buildWhen: (p, c) => p.active != c.active,
      builder: (context, state) {
        if (state.active.isEmpty) return const SizedBox.shrink();
        final time = localTimeFormat(context);
        final now = DateTime.now();
        final ink2 = context.tokens.ink2;
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.gap),
          child: PanelGroup(
            children: [
              for (final g in state.active)
                _Row(
                  grant: g,
                  name: nameOf?.call(g) ?? g.targetId,
                  until: RuleSummary.clock(g.endMs, now, time: time),
                  ink2: ink2,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.grant,
    required this.name,
    required this.until,
    required this.ink2,
  });

  final TemporaryUnblock grant;
  final String name;
  final String until;
  final Color ink2;

  @override
  Widget build(BuildContext context) {
    void end() =>
        context.read<UnblockCubit>().endEarly(grant.targetType, grant.targetId);
    return GlassListTile(
      // The icon carries the kind.
      leading: Icon(switch (grant.targetType) {
        UnblockTargetType.reel => Icons.smart_display_outlined,
        UnblockTargetType.app => Icons.apps_outlined,
        UnblockTargetType.website => Icons.public,
      }, color: ink2),
      title: name,
      subtitle: 'Allowed until $until',
      // "Block now" alone is ambiguous in a list of them; say which.
      trailing: Semantics(
        label: 'Block $name now',
        button: true,
        excludeSemantics: true,
        onTap: end,
        child: SecondaryButton(label: 'Block now', onPressed: end),
      ),
    );
  }
}
