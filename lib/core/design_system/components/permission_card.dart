import 'package:detoxo/core/design_system/components/badges.dart';
import 'package:detoxo/core/design_system/components/buttons.dart';
import 'package:detoxo/core/design_system/components/cards.dart';
import 'package:detoxo/core/design_system/components/toggle.dart';
import 'package:detoxo/core/design_system/foundations/glass_container.dart';
import 'package:detoxo/core/design_system/tokens/app_motion.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:detoxo/core/design_system/tokens/app_tokens.dart';
import 'package:flutter/material.dart';

/// Generic shell for a permission row, laid out like a list tile: an icon
/// badge, the title over a one-line "why", and one trailing control — an
/// [AppToggle] that is off while access is missing (flip it to grant) and on
/// once granted. A named [actionLabel] ("Fix this", "Retry") is not an on/off
/// and stays a brand accent pill. A granted row drops its "why" and tints its
/// badge, so what is left to do stands out. "Checking…" sits under the text.
/// Past 1.3x text a pill drops under the text too. Its own panel only when it
/// is not on a surface already. Feature code (PermissionRow) binds an
/// `AppPermission` to this shell.
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

  /// When true the OS won't prompt again: the toggle then opens the app's
  /// system settings (its callback should route there), and says so to
  /// TalkBack.
  final bool permanentlyDenied;

  /// A named action in place of the toggle — e.g. "Fix this" when the tap
  /// opens a help sheet rather than a system screen.
  final String? actionLabel;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final pill = actionLabel != null && !granted;
    // A pill's label beside a title wrapped at large text squeezes both, so
    // past 1.3x it drops under the text. The toggle is narrow enough to stay.
    final stacked = pill && MediaQuery.textScalerOf(context).scale(1) > 1.3;
    // An unknown state with no way out is a dead end: the permission funnel
    // re-reads on its own, but a screen whose data failed to load needs the
    // user to ask again. Opt-in via [actionLabel] so the funnel's rows, which
    // recover by themselves, stay control-free.
    final trailing = pill
        ? LiquidPill(
            key: ValueKey(actionLabel),
            tint: t.brand.main,
            onPressed: onGrant,
            // Names the permission: a list of bare "Fix this" buttons is
            // ambiguous to TalkBack.
            semanticLabel: '$actionLabel $title',
            child: Text(
              actionLabel!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          )
        : unknown && !granted
        ? null
        // Off asks for the grant. On is Android's to undo, not ours: it holds
        // still at full strength, and TalkBack hears a switch it cannot flip.
        // One keyed node either way, so a grant landing slides the thumb.
        : Semantics(
            key: const ValueKey('toggle'),
            excludeSemantics: true,
            toggled: granted,
            label: title,
            hint: !granted && permanentlyDenied
                ? 'Opens Android settings'
                : null,
            onTap: granted ? null : onGrant,
            child: IgnorePointer(
              ignoring: granted,
              child: AppToggle(
                value: granted,
                onChanged: (_) {
                  if (!granted) onGrant();
                },
              ),
            ),
          );
    // The status flips while the user is away in system settings; on return
    // the control swaps or slides in place instead of snapping.
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
