import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/limits/unblock/domain/entities/bypass_config.dart';
import 'package:detoxo/features/limits/unblock/presentation/unblock_cubit.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';

/// "Unblock {thing}?" — the caution [ConfirmSheet] over the 5 / 15 / 30 /
/// 60-minute chips.
///
/// One sheet for every target (a website row, an app row, the block-screen
/// wall, an override on a locked rule). It started as the web blocker's
/// per-site pause sheet in EVO-012: a second duration vocabulary would be a
/// second thing to learn for no gain. The smallest chip starts picked.
///
/// Returns the picked window once the user waits and slides, or null when they
/// back out — and backing out grants nothing, which is the whole contract of a
/// friction gate. The caller commits and toasts, since its commit can fail.
Future<Duration?> showUnblockDurationSheet(
  BuildContext context, {
  required String title,
  required AssetGenImage icon,
  String message = 'It gets blocked again when the time is up.',
  String action = 'Slide to unblock',
  String cancel = 'Keep it blocked',

  /// Caps the offered chips, so an override cannot buy more than
  /// `BypassConfig.overrideMaxWindowMs`.
  Duration? maxWindow,

  /// EVO-053: allowances left in the current period, or null when they are not
  /// rationed. Shown BEFORE the choice, not as a refusal after it — a budget
  /// the user only learns about by hitting it is a trap, not a budget. None
  /// left says so up front, with no wait and no slide into a refusal.
  int? remaining,
}) async {
  if (remaining != null && remaining <= 0) {
    GlassToast.show(context, UnblockCubit.noGrantsLeft, tone: AppTone.warning);
    return null;
  }
  final limit = maxWindow?.inMinutes ?? unblockDurationMinutes.last;
  final options = [
    for (final m in unblockDurationMinutes)
      if (m <= limit) m,
  ];
  // A pathologically small cap must still offer something rather than an empty
  // sheet the user cannot act on.
  final chips = options.isEmpty ? [unblockDurationMinutes.first] : options;
  var minutes = chips.first;
  final ok = await ConfirmSheet.show(
    context,
    icon: Icon3d(icon, size: 58),
    title: title,
    message: message,
    content: _DurationChips(
      chips: chips,
      remaining: remaining,
      onChanged: (m) => minutes = m,
    ),
    action: action,
    cancel: cancel,
    tone: ConfirmTone.caution,
  );
  return ok ? Duration(minutes: minutes) : null;
}

class _DurationChips extends StatefulWidget {
  const _DurationChips({
    required this.chips,
    required this.remaining,
    required this.onChanged,
  });

  final List<int> chips;
  final int? remaining;
  final ValueChanged<int> onChanged;

  @override
  State<_DurationChips> createState() => _DurationChipsState();
}

class _DurationChipsState extends State<_DurationChips> {
  late int _picked = widget.chips.first;

  @override
  Widget build(BuildContext context) {
    final left = widget.remaining;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final m in widget.chips)
              AppChip(
                label: '$m min',
                selected: m == _picked,
                onSelected: () {
                  setState(() => _picked = m);
                  widget.onChanged(m);
                },
              ),
          ],
        ),
        if (left != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            left == 1
                ? '1 allowance left in this period.'
                : '$left allowances left in this period.',
            textAlign: TextAlign.center,
            style: AppTypography.subhead.copyWith(color: context.tokens.ink2),
          ),
        ],
      ],
    );
  }
}
