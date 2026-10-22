import 'package:detoxo/core/design_system/foundations/glass_container.dart';
import 'package:detoxo/core/design_system/foundations/motion.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:detoxo/core/design_system/tokens/app_tokens.dart';
import 'package:flutter/material.dart';

/// The search field, an OPTION pill: the quiet fill, a leading ink-2
/// magnifier, body text in ink over an ink-2 hint, and a trailing clear
/// button that appears only when there's text. It draws the focus ring while
/// it has focus. Replaces bare Material `TextField`s used for search.
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    this.controller,
    this.hintText = 'Search',
    this.onChanged,
    super.key,
  });

  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  TextEditingController? _internal;
  TextEditingController get _controller =>
      widget.controller ?? (_internal ??= TextEditingController());
  bool _focused = false;

  @override
  void dispose() {
    _internal?.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    widget.onChanged?.call(value);
    setState(() {});
  }

  void _clear() {
    _controller.clear();
    _onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = AppTypography.body.copyWith(color: t.ink);
    // Tracks focus anywhere in the field for the ring; never a stop itself.
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (f) => setState(() => _focused = f),
      child: FocusRing(
        visible: _focused,
        radius: AppRadius.brPill,
        child: GlassContainer(
          surface: DxSurface.option,
          color: t.fillQuiet,
          borderRadius: AppRadius.pill,
          // h16; the row's fixed 48 dp height (rather than v12 padding) holds
          // the clear button's 48 dp target, so the first keystroke never
          // grows the field.
          padding: const EdgeInsets.only(left: AppSpacing.md),
          child: SizedBox(
            height: AppSizes.minTapTarget,
            child: Row(
              children: [
                Icon(Icons.search, size: 18, color: t.ink2),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onChanged: _onChanged,
                    textInputAction: TextInputAction.search,
                    style: style,
                    decoration: InputDecoration.collapsed(
                      hintText: widget.hintText,
                      hintStyle: style.copyWith(color: t.ink2),
                    ),
                  ),
                ),
                if (_controller.text.isNotEmpty)
                  AppPressable(
                    onTap: _clear,
                    semanticLabel: 'Clear search',
                    radius: AppRadius.brPill,
                    minTapTarget: AppSizes.minTapTargetSquare,
                    child: Icon(Icons.close, size: 18, color: t.ink2),
                  )
                else
                  const SizedBox(width: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
