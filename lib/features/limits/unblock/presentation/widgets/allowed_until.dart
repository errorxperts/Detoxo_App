import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/utils/clock_format.dart';
import 'package:detoxo/features/limits/rules/domain/usecases/rule_summary.dart';
import 'package:detoxo/features/limits/unblock/domain/entities/temporary_unblock.dart';
import 'package:flutter/material.dart';

/// A live grant's status line on an App Blocker or Web Blocker row (spec
/// `.dx-status`): the paused dot, then "Allowed until 11:37 PM" in subhead
/// ink-2, with the weekday when the window ends tomorrow
/// ([RuleSummary.clock]) on the device's 12/24-hour clock.
///
/// Not a [Pill]: its 0.4x width cap ellipsised the clock, the one datum this
/// line carries, at 360 dp. The rows select [grant] off `UnblockCubit`'s
/// derived `active` list, so the line goes when the grant lapses.
class AllowedUntil extends StatelessWidget {
  const AllowedUntil(this.grant, {super.key});

  final TemporaryUnblock grant;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final until = RuleSummary.clock(
      grant.endMs,
      DateTime.now(),
      time: (m) => formatLocalTime(context, m),
    );
    return Row(
      children: [
        StatusDot(color: t.statusPaused),
        // The dot-to-word gap of [Pill].
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            'Allowed until $until',
            style: AppTypography.subhead.copyWith(color: t.ink2),
          ),
        ),
      ],
    );
  }
}
