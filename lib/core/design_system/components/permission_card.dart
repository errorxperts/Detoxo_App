import 'package:detoxo/core/design_system/components/badges.dart';
import 'package:detoxo/core/design_system/components/buttons.dart';
import 'package:detoxo/core/design_system/components/cards.dart';
import 'package:detoxo/core/design_system/foundations/glass_container.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:detoxo/core/design_system/tokens/app_tokens.dart';
import 'package:flutter/material.dart';

/// Generic shell for a permission row: a neutral icon badge, the title, a
/// one-line "why", then the status in words — On, Needs access or Checking… —
/// with the grant control beside it. Its own panel only when it is not on a
/// surface already. Feature code (PermissionRow) binds an `AppPermission` to
/// this shell.
class PermissionCard extends StatelessWidget {
  const PermissionCard({
    required this.icon,
    required this.title,
    required this.why,
    required this.granted,
    required this.onGrant,
    this.unknown = false,
    this.permanentlyDenied = false,
    this.actionLabel,
    super.key,
  });

  final IconData icon;
  final String title;
  final String why;
  final bool granted;

  /// The status read didn't answer (channel hiccup) and there is no granted
  /// history to fall back on — render a neutral "Checking…" row, not a red
  /// denied state. Ignored when [granted] is true.
  ///
  /// Pass [actionLabel] alongside this to offer a way out (e.g. "Retry");
  /// without it the row is informational, which is right for the permission
  /// funnel where the next status read fixes itself.
  final bool unknown;

  /// When true the OS won't prompt again, so the action label becomes
  /// "Open settings" (its callback should route to the app's system settings).
  final bool permanentlyDenied;

  /// Overrides the action label — e.g. "Fix this" when the tap opens a help
  /// sheet rather than a system screen.
  final String? actionLabel;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // An unknown state with no way out is a dead end: the permission funnel
    // re-reads on its own, but a screen whose data failed to load needs the
    // user to ask again. Opt-in via [actionLabel] so the funnel's rows, which
    // recover by themselves, stay button-free.
    final action = granted || (unknown && actionLabel == null)
        ? null
        : SecondaryButton(
            label:
                actionLabel ?? (permanentlyDenied ? 'Open settings' : 'Grant'),
            onPressed: onGrant,
          );
    final status = granted
        ? const Pill(label: 'On', tone: AppTone.success)
        : unknown
        ? const Pill(label: 'Checking…')
        : const Pill(label: 'Needs access', tone: AppTone.warning);
    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconBadge(icon: icon),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.label.copyWith(color: t.ink)),
              const SizedBox(height: 2),
              Text(why, style: AppTypography.subhead.copyWith(color: t.ink2)),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: status,
                    ),
                  ),
                  ?action,
                ],
              ),
            ],
          ),
        ),
      ],
    );
    if (GlassContainer.surfaceOf(context) != null) {
      return Padding(padding: AppInsets.card, child: body);
    }
    return GlassContainer(child: body);
  }
}
