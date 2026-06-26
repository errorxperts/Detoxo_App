import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// One option in a [ModeToggle].
class ModeOption {
  const ModeOption({required this.icon, required this.label});

  final AppIcon icon;
  final String label;
}

/// The hero's integrated segmented control. Each cell is a vertical icon+label;
/// the active cell fills with a primary→secondary gradient pill and its glyph
/// re-morphs on selection. Mirrors the dashboard's old plan selector lock:
/// while [enabled] is false (curious cooldown) taps are ignored.
class ModeToggle extends StatelessWidget {
  const ModeToggle({
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
    this.enabled = true,
    this.cellBuilder,
    super.key,
  });

  final List<ModeOption> options;

  /// Active cell, or -1 when the current plan isn't represented here.
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final bool enabled;

  /// Optional decorator applied to each cell, given its index and built widget.
  /// Lets a caller wrap individual cells (e.g. with a feature-showcase target)
  /// without coupling this widget to that feature. Identity when null.
  final Widget Function(int index, Widget child)? cellBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: context.glass.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: _decorate(
                i,
                _ModeCell(
                  option: options[i],
                  selected: i == selectedIndex,
                  enabled: enabled,
                  onTap: () => onChanged(i),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Applies [cellBuilder] to a cell when provided; otherwise returns it as-is.
  Widget _decorate(int index, Widget cell) =>
      cellBuilder?.call(index, cell) ?? cell;
}

class _ModeCell extends StatefulWidget {
  const _ModeCell({
    required this.option,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final ModeOption option;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_ModeCell> createState() => _ModeCellState();
}

class _ModeCellState extends State<_ModeCell> {
  final AnimatedIconController _controller = AnimatedIconController();

  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void didUpdateWidget(_ModeCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected && !_reduceMotion) {
      _controller.animate();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap() {
    AppHaptics.selection();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fg = widget.selected
        ? scheme.onPrimary
        : scheme.onSurfaceVariant.withValues(alpha: widget.enabled ? 0.7 : 0.35);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? _onTap : null,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        curve: AppCurves.standard,
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          gradient: widget.selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [scheme.primary, scheme.secondary],
                )
              : null,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: widget.selected
              ? [
                  BoxShadow(
                    color: scheme.secondary.withValues(alpha: 0.30),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAnimatedIcon(
              icon: widget.option.icon,
              size: 20,
              color: fg,
              controller: _controller,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              widget.option.label,
              style: text.labelSmall?.copyWith(
                color: fg,
                fontSize: 11,
                fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
