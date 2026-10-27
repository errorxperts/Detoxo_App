import 'package:detoxo/core/design_system/components/badges.dart';
import 'package:detoxo/core/design_system/components/buttons.dart';
import 'package:detoxo/core/design_system/components/cards.dart';
import 'package:detoxo/core/design_system/foundations/glass_container.dart';
import 'package:detoxo/core/design_system/tokens/app_motion.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:detoxo/core/design_system/tokens/app_tokens.dart';
import 'package:flutter/material.dart';

/// Generic shell for a permission row, laid out like a list tile: an icon
/// badge, the title over a one-line "why", and one trailing control — the
/// brand accent Grant pill while access is missing, "✓ On" once granted. A
/// granted row drops its "why" and tints its badge, so what is left to do
/// stands out. "Checking…" sits under the text. Past 1.3x text the trailing
/// control drops under the text too. Its own panel only when it is not on a
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
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    // "Open settings" beside a title wrapped at large text squeezes both, so
    // past 1.3x the trailing control drops under the text.
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final label =
        actionLabel ?? (permanentlyDenied ? 'Open settings' : 'Grant');
    // An unknown state with no way out is a dead end: the permission funnel
    // re-reads on its own, but a screen whose data failed to load needs the
    // user to ask again. Opt-in via [actionLabel] so the funnel's rows, which
    // recover by themselves, stay button-free.
    final Widget? trailing = granted
        ? const Pill(
            key: ValueKey('on'),
            label: 'On',
            tone: AppTone.success,
            icon: Icons.check_circle_rounded,
          )
        : unknown && actionLabel == null
        ? null
        : LiquidPill(
            key: ValueKey(label),
            tint: t.brand.main,
            onPressed: onGrant,
            // Names the permission: a list of bare "Grant" buttons is
            // ambiguous to TalkBack.
            semanticLabel: '$label $title',
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          );
    // The status flips while the user is away in system settings; on return
    // the pill swaps in place instead of snapping.
    final control = trailing == null
        ? null
        : AnimatedSwitcher(
            duration: reduce ? Duration.zero : AppDurations.fast,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: ScaleTransition(scale: a, child: child),
            ),
            child: trailing,
          );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.label.copyWith(color: t.ink)),
        if (!granted) ...[
          const SizedBox(height: 2),
          Text(why, style: AppTypography.subhead.copyWith(color: t.ink2)),
        ],
        if (unknown && !granted) ...[
          const SizedBox(height: AppSpacing.xs),
          const Pill(label: 'Checking…'),
        ],
        if (stacked && control != null) ...[
          const SizedBox(height: AppSpacing.xs),
          control,
        ],
      ],
    );
    final body = Row(
      crossAxisAlignment: stacked
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        IconBadge(
          icon: icon,
          color: granted ? toneText(context, AppTone.success) : null,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: AnimatedSize(
            duration: reduce ? Duration.zero : AppDurations.normal,
            curve: AppCurves.standard,
            alignment: AlignmentDirectional.topStart,
            child: text,
          ),
        ),
        if (!stacked && control != null) ...[
          const SizedBox(width: AppSpacing.sm),
          // Not a flex child — that would halve the text column. Room for
          // "Open settings" beside a long title, ellipsized past the cap.
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.4,
            ),
            child: control,
          ),
        ],
      ],
    );
    if (GlassContainer.surfaceOf(context) != null) {
      return Padding(padding: AppInsets.card, child: body);
    }
    return GlassContainer(child: body);
  }
}
