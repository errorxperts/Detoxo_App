import 'package:detoxo/core/design_system/foundations/motion.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:detoxo/core/design_system/tokens/app_tokens.dart';
import 'package:flutter/material.dart';

/// Semantic tone shared by status labels, badges and toasts.
enum AppTone { neutral, accent, success, warning, danger }

/// A tone's colour for dots and fills. [AppTone.neutral] has none of its own
/// (a neutral status shows the word only) and falls back to ink-2 where a
/// fill is unavoidable.
Color toneColor(BuildContext context, AppTone tone) {
  final t = context.tokens;
  return switch (tone) {
    AppTone.neutral => t.ink2,
    AppTone.accent => t.brand.main,
    AppTone.success => t.statusOn,
    AppTone.warning => t.statusSetup,
    AppTone.danger => t.over.main,
  };
}

/// A tone's colour for text and icons: [toneColor] darkened in Light so it
/// reads at 4.5:1 ([AppTokenText.accentText] / [AppTokenText.statusText]).
Color toneText(BuildContext context, AppTone tone) {
  final t = context.tokens;
  return switch (tone) {
    AppTone.neutral => t.ink2,
    AppTone.accent => t.accentText(t.brand),
    AppTone.success => t.statusText(t.statusOn),
    AppTone.warning => t.statusText(t.statusSetup),
    AppTone.danger => t.accentText(t.over),
  };
}

/// A status label (spec `.dx-status`): an 8 px dot in [toneColor] (or
/// [dotColor]) or an [icon] in [toneText], 7 px, then the word in subhead
/// ink-2. No fill or border; a neutral tone shows the word alone. The word
/// carries the status, so the dot is decoration.
class Pill extends StatelessWidget {
  const Pill({
    required this.label,
    this.tone = AppTone.neutral,
    this.icon,
    this.dotColor,
    super.key,
  });

  final String label;
  final AppTone tone;
  final IconData? icon;

  /// A dot outside the tone table, e.g. `statusPaused`.
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final dot =
        dotColor ?? (tone == AppTone.neutral ? null : toneColor(context, tone));
    final lead = icon != null
        ? Icon(icon, size: 14, color: toneText(context, tone))
        : dot == null
        ? null
        : StatusDot(color: dot);
    return ConstrainedBox(
      // A label lives in trailing slots that are NOT flex children (see
      // GlassListTile — making one squeezes the title's Expanded instead), so
      // it has to bound itself: a long word ("Needs usage access") at large
      // system font scale otherwise overflows the row it sits in. Ellipsis
      // beats overflow, and no status is legitimately this wide.
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.4,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (lead != null) ...[lead, const SizedBox(width: 7)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.subhead.copyWith(color: context.tokens.ink2),
            ),
          ),
        ],
      ),
    );
  }
}

/// A count or trend marker (spec `.dx-more`, the "+3" after an icon stack):
/// a 24 px quiet-fill pill with a caption in ink-2. Named to avoid clashing
/// with Material's own `Badge`.
class AppBadge extends StatelessWidget {
  const AppBadge.label(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.fillQuiet,
        borderRadius: AppRadius.brPill,
      ),
      child: Text(label, style: AppTypography.caption.copyWith(color: t.ink2)),
    );
  }
}
