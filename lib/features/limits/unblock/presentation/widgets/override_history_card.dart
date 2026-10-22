import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/limits/unblock/domain/entities/bypass_config.dart';
import 'package:detoxo/features/limits/unblock/domain/usecases/unblock_quota.dart';
import 'package:detoxo/features/limits/unblock/presentation/unblock_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The last row on Insights (EVO-052): how many overrides are left this
/// period, as one standalone row. Shown once an override was spent this
/// period, and never the spent count or the reasons: what is left is the
/// useful number, and a tally of lapses reads as a verdict.
class OverrideHistoryCard extends StatelessWidget {
  const OverrideHistoryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UnblockCubit, UnblockState>(
      // No `buildWhen`: the builder reads the clock and `overridesLeft`, and
      // the resume / timer resync re-derives `overridesLeft` on an unchanged
      // ledger — a ledger-only guard filtered out exactly the emit that would
      // correct "1 left" after the period rolled over.
      builder: (context, state) {
        final spent = UnblockQuota.overrideSummary(
          state.ledger,
          state.config,
          DateTime.now().millisecondsSinceEpoch,
        ).count;
        if (spent == 0) return const SizedBox.shrink();
        final left = switch (state.overridesLeft) {
          0 => 'No overrides',
          1 => '1 override',
          final n => '$n overrides',
        };
        final period = state.config.overridePeriod == BypassPeriod.day
            ? 'today'
            : 'this week';
        return Padding(
          // The section gap rides with the row, so it goes when the row does.
          padding: const EdgeInsets.only(top: AppSpacing.section),
          child: GlassListTile(
            leading: Icon(
              Icons.lock_open,
              size: 24,
              color: context.tokens.ink2,
            ),
            title: '$left left $period',
          ),
        );
      },
    );
  }
}
