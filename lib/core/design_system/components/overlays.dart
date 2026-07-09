import 'package:detoxo/core/design_system/components/badges.dart';
import 'package:detoxo/core/design_system/foundations/glass_container.dart';
import 'package:detoxo/core/design_system/theme/app_theme.dart';
import 'package:detoxo/core/design_system/tokens/app_blur.dart';
import 'package:detoxo/core/design_system/tokens/app_motion.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Frosted modal bottom sheet. Use instead of raw `showModalBottomSheet` so
/// every sheet shares the glass chrome, drag handle and radius.
abstract final class GlassBottomSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: GlassContainer(
          blurSigma: AppBlur.sheet,
          borderRadius: AppRadius.xl,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.glass.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (title != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Flexible(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Frosted modal dialog (replaces raw `AlertDialog`).
abstract final class GlassDialog {
  /// Shows the frosted dialog. Set [barrierDismissible] to `false` and
  /// [blocking] to `true` for a mandatory dialog the user cannot dismiss by
  /// tapping outside or pressing back (e.g. a forced app update).
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    bool barrierDismissible = true,
    bool blocking = false,
  }) {
    final dialog = Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      child: GlassContainer(
        blurSigma: AppBlur.sheet,
        borderRadius: AppRadius.xl,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: child,
      ),
    );
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) =>
          blocking ? PopScope(canPop: false, child: dialog) : dialog,
    );
  }
}

/// A floating frosted toast (replaces raw `ScaffoldMessenger` snackbars).
abstract final class GlassToast {
  static void show(
    BuildContext context,
    String message, {
    AppTone tone = AppTone.neutral,
  }) {
    final color = toneColor(context, tone);
    final icon = switch (tone) {
      AppTone.success => Icons.check_circle_outline,
      AppTone.danger => Icons.error_outline,
      AppTone.warning => Icons.warning_amber_outlined,
      _ => Icons.info_outline,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          content:
              GlassContainer(
                    blurSigma: AppBlur.bar,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    borderColor: color.withValues(alpha: 0.4),
                    child: Row(
                      children: [
                        Icon(icon, color: color, size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text(message)),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(duration: AppDurations.normal)
                  .slideY(begin: 0.3, end: 0),
        ),
      );
  }
}
