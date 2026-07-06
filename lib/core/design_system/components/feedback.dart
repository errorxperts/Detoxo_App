import 'dart:math' as math;

import 'package:detoxo/core/design_system/foundations/glass_container.dart';
import 'package:detoxo/core/design_system/theme/app_theme.dart';
import 'package:detoxo/core/design_system/tokens/app_blur.dart';
import 'package:detoxo/core/design_system/tokens/app_colors.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Branded loading indicator (replaces bare `CircularProgressIndicator`).
class LoadingState extends StatelessWidget {
  const LoadingState({this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accent),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(message!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// A shimmering placeholder block for skeleton screens.
class Skeleton extends StatelessWidget {
  const Skeleton({this.width, this.height = 16, this.radius = AppRadius.sm, super.key});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.glass.fillTop,
        borderRadius: BorderRadius.circular(radius),
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(
          duration: 1200.ms,
          color: context.glass.onGlassMuted.withValues(alpha: 0.12),
        );
  }
}

/// A circular progress ring with centred content — used by the pause countdown.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    required this.progress,
    this.size = 220,
    this.strokeWidth = 10,
    this.color = AppColors.accent,
    this.child,
    super.key,
  });

  /// 0..1 remaining fraction.
  final double progress;
  final double size;
  final double strokeWidth;
  final Color color;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          GlassContainer(
            blurSigma: AppBlur.hero,
            borderRadius: size,
            padding: EdgeInsets.zero,
            child: const SizedBox.shrink(),
          ),
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(
              progress: progress.clamp(0, 1),
              strokeWidth: strokeWidth,
              trackColor: context.glass.border,
            ),
          ),
          ?child,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.strokeWidth, required this.trackColor});

  final double progress;
  final double strokeWidth;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width - strokeWidth) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [AppColors.accent, AppColors.seed, AppColors.accent],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas
      ..drawCircle(center, radius, track)
      ..drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        arc,
      );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

/// A glass linear progress bar (daily-limit usage, permissions completion).
class ProgressBar extends StatelessWidget {
  const ProgressBar({required this.progress, this.height = 8, super.key});

  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(
        children: [
          Container(height: height, color: context.glass.border),
          FractionallySizedBox(
            widthFactor: progress.clamp(0, 1),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.accent, AppColors.seed]),
                borderRadius: BorderRadius.circular(height),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
