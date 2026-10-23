import 'package:detoxo/core/design_system/components/overlays.dart';
import 'package:detoxo/core/design_system/foundations/glass_container.dart';
import 'package:detoxo/core/design_system/foundations/motion.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:detoxo/core/design_system/tokens/app_tokens.dart';
import 'package:flutter/material.dart';

/// The call to action: the spec soft button (`.dx-cancel`), a 54 px pill on
/// the 145° button gradient with its soft shadow and an ink label. No accent:
/// the live accent stays on the ring, the pill and the tab lens.
/// `expand: true` makes it full-width.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.expand = false,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expand;
  final IconData? icon;

  static const double _height = 54;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget pill = CustomPaint(
      painter: DxSurfacePainter(
        radius: AppRadius.brPill,
        gradient: [t.buttonFrom, t.buttonTo],
        angle: 145,
        shadows: t.shadowButton,
      ),
      child: SizedBox(
        height: _height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Center(
            widthFactor: 1,
            child: _Label(
              label: label,
              leading: icon == null ? null : Icon(icon, size: 20),
              style: AppTypography.button.copyWith(color: t.ink),
            ),
          ),
        ),
      ),
    );
    if (expand) pill = SizedBox(width: double.infinity, child: pill);
    return _Press(
      label: label,
      onPressed: onPressed,
      pressedScale: 0.95,
      child: pill,
    );
  }
}

/// The press, focus and semantics every labelled button here shares: [label]
/// is the whole announcement (the visible Text must not read a second time),
/// and a disabled button fades to .45 but stays one focusable, disabled node.
class _Press extends StatelessWidget {
  const _Press({
    required this.label,
    required this.onPressed,
    required this.pressedScale,
    required this.child,
  });

  final String label;
  final VoidCallback? onPressed;
  final double pressedScale;
  final Widget child;

  @override
  Widget build(BuildContext context) => AppPressable(
    onTap: onPressed ?? () {},
    enabled: onPressed != null,
    pressedScale: pressedScale,
    radius: AppRadius.brPill,
    semanticLabel: label,
    minTapTarget: AppSizes.minTapTargetSquare,
    child: Opacity(
      opacity: onPressed == null ? 0.45 : 1,
      child: ExcludeSemantics(child: child),
    ),
  );
}

/// A label with an optional leading icon on one line. At 2.0x text a long
/// label ("Add to home screen") is wider than its button: it ellipsizes and
/// the icon stays.
class _Label extends StatelessWidget {
  const _Label({required this.label, required this.style, this.leading});

  final String label;
  final TextStyle style;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (leading != null) ...[
        IconTheme.merge(
          data: IconThemeData(color: style.color, size: 20),
          child: leading!,
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
    ],
  );
}

/// The quiet action ("Cancel", "Skip", "Not now"): an ink-2 label with no
/// surface on a 48 dp target. [destructive] sets the label in the `over`
/// accent text ("Delete rule", "Reset app data"), never a red fill.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    this.expand = false,
    this.icon,
    this.destructive = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expand;
  final IconData? icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget content = SizedBox(
      height: AppSizes.minTapTarget,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Center(
          widthFactor: 1,
          child: _Label(
            label: label,
            leading: icon == null ? null : Icon(icon),
            style: AppTypography.label.copyWith(
              color: destructive ? t.accentText(t.over) : t.ink2,
            ),
          ),
        ),
      ),
    );
    if (expand) content = SizedBox(width: double.infinity, child: content);
    return _Press(
      label: label,
      onPressed: onPressed,
      pressedScale: 0.95,
      child: content,
    );
  }
}

/// The spec accent pill (`.dx-pill`): 44 px, [tint] at `kPill` under the
/// pill sheen and edge, with a [tint] glow at `kPillGlow`. The child is set
/// in `label` ink. The block screen's primary action passes
/// `context.accent.main`.
class LiquidPill extends StatelessWidget {
  const LiquidPill({
    required this.child,
    required this.tint,
    required this.onPressed,
    this.expand = false,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final Color tint;
  final VoidCallback? onPressed;
  final bool expand;

  /// The whole announcement, replacing the child's own text. Without one the
  /// child's Text names the button.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget pill = CustomPaint(
      painter: DxSurfacePainter(
        radius: AppRadius.brPill,
        color: tint.withValues(alpha: t.kPill),
        gradient: [t.pillHi, t.pillLo],
        shadows: [
          ...t.pillEdge,
          DxShadow(
            color: tint.withValues(alpha: t.kPillGlow),
            offset: const Offset(0, 10),
            blur: 24,
          ),
        ],
      ),
      child: SizedBox(
        height: AppSizes.controlHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 20, 0),
          child: Center(
            widthFactor: 1,
            child: IconTheme.merge(
              data: IconThemeData(color: t.ink, size: 20),
              child: DefaultTextStyle.merge(
                style: AppTypography.label.copyWith(color: t.ink),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
    if (expand) pill = SizedBox(width: double.infinity, child: pill);
    if (semanticLabel != null) pill = ExcludeSemantics(child: pill);
    return AppPressable(
      onTap: onPressed ?? () {},
      enabled: onPressed != null,
      pressedScale: 0.95,
      radius: AppRadius.brPill,
      semanticLabel: semanticLabel,
      minTapTarget: AppSizes.minTapTargetSquare,
      child: Opacity(opacity: onPressed == null ? 0.45 : 1, child: pill),
    );
  }
}

/// A floating glass pill action ("Add app", "New rule"): [icon] and [label]
/// in ink on [DxSurface.glass]. It grows to 1.06 on press.
class GlassFab extends StatelessWidget {
  const GlassFab({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final Widget icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => _Press(
    label: label,
    onPressed: onPressed,
    pressedScale: 1.06,
    child: GlassContainer(
      surface: DxSurface.glass,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: _Label(
        label: label,
        leading: icon,
        style: AppTypography.label.copyWith(color: context.tokens.ink),
      ),
    ),
  );
}

/// Tap-to-open explainer: a [GlassIconButton] that opens [message] in a
/// sheet, instead of an on-screen paragraph. Typically an app-bar action.
class InfoButton extends StatelessWidget {
  const InfoButton(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => GlassIconButton(
    icon: const Icon(Icons.info_outline_rounded),
    semanticLabel: 'More info',
    onPressed: () => GlassBottomSheet.show<void>(
      context: context,
      child: Builder(
        builder: (sheet) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.message.copyWith(color: sheet.tokens.ink2),
            ),
            const SizedBox(height: AppSpacing.sheetSide),
            PrimaryButton(
              label: 'Got it',
              expand: true,
              onPressed: () => Navigator.of(sheet).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The spec's round glass action: a 44 px [DxSurface.glass] circle holding a
/// 22 px [icon] in `ink`, inside a 48 dp target. It grows to 1.06 on press.
/// Header back, menu, info and feedback actions all use it.
///
/// A [Tooltip] carries [semanticLabel], so long-press shows it and tests can
/// find a back button by its standard tooltip.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    super.key,
  });

  final Widget icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Tooltip(
      message: semanticLabel,
      excludeFromSemantics: true,
      child: AppPressable(
        onTap: onPressed ?? () {},
        enabled: onPressed != null,
        pressedScale: 1.06,
        radius: AppRadius.brPill,
        semanticLabel: semanticLabel,
        minTapTarget: AppSizes.minTapTargetSquare,
        child: SizedBox.square(
          dimension: AppSizes.controlHeight,
          child: GlassContainer(
            surface: DxSurface.glass,
            backdrop: false,
            padding: EdgeInsets.zero,
            child: Center(
              child: IconTheme.merge(
                data: IconThemeData(color: t.ink, size: 22),
                child: ExcludeSemantics(child: icon),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
