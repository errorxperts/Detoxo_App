import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// A sheet of toggle rows over `(id, label)` options; pops the chosen ids.
class ReelFeedSheet extends StatefulWidget {
  const ReelFeedSheet({
    required this.options,
    required this.selected,
    super.key,
  });

  final List<({String id, String label})> options;
  final Set<String> selected;

  static Future<Set<String>?> show(
    BuildContext context, {
    required String title,
    required List<({String id, String label})> options,
    required Set<String> selected,
  }) => GlassBottomSheet.show<Set<String>>(
    context: context,
    title: title,
    child: ReelFeedSheet(options: options, selected: selected),
  );

  @override
  State<ReelFeedSheet> createState() => _ReelFeedSheetState();
}

class _ReelFeedSheetState extends State<ReelFeedSheet> {
  late final Set<String> _picked = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.options.isEmpty)
          const EmptyState(
            icon: Icons.play_disabled,
            title: 'No reel feeds found',
            subtitle: 'Install a supported app to pick its feed.',
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.5,
            ),
            // Flat switch rows on the sheet, split by hairlines.
            child: SingleChildScrollView(
              child: PanelGroup(
                children: [
                  for (final o in widget.options)
                    AppToggleTile(
                      title: o.label,
                      value: _picked.contains(o.id),
                      onChanged: (on) => setState(() {
                        on ? _picked.add(o.id) : _picked.remove(o.id);
                      }),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
          label: 'Done',
          expand: true,
          onPressed: () => Navigator.of(context).pop(_picked),
        ),
      ],
    );
  }
}
