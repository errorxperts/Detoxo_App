import 'package:detoxo/core/design_system/foundations/glass_container.dart';
import 'package:detoxo/core/design_system/theme/app_theme.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:flutter/material.dart';

/// A compact, pill-shaped search field — a slim translucent row with a leading
/// magnifier and a trailing clear button that appears only when there's text.
/// Replaces bare Material `TextField`s used for search.
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
    final muted = context.glass.onGlassMuted;
    return GlassContainer(
      enableBlur: false,
      borderRadius: AppRadius.pill,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: muted),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: InputDecoration.collapsed(
                hintText: widget.hintText,
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted),
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            GestureDetector(
              onTap: _clear,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: Icon(Icons.close, size: 18, color: muted),
              ),
            ),
        ],
      ),
    );
  }
}
