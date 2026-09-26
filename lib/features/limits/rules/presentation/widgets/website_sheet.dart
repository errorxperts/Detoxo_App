import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/limits/rules/presentation/widgets/removable_chips.dart';
import 'package:detoxo/features/limits/web_blocker/domain/entities/popular_site.dart';
import 'package:detoxo/features/limits/web_blocker/domain/utils/domain_validator.dart';
import 'package:flutter/material.dart';

/// Popular-site chips plus a custom host field (validated by the web
/// blocker's `DomainValidator`); pops the chosen hosts.
class WebsiteSheet extends StatefulWidget {
  const WebsiteSheet({required this.initial, super.key});

  final List<String> initial;

  static Future<List<String>?> show(
    BuildContext context, {
    required List<String> initial,
  }) => GlassBottomSheet.show<List<String>>(
    context: context,
    title: 'Websites',
    child: WebsiteSheet(initial: initial),
  );

  @override
  State<WebsiteSheet> createState() => _WebsiteSheetState();
}

class _WebsiteSheetState extends State<WebsiteSheet> {
  late final List<String> _hosts = [...widget.initial];
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// False when the text in the field is present but invalid — the caller stays
  /// open and shows [_error] rather than dropping what the user typed.
  bool _add() {
    final (:host, :error) = DomainValidator.check(_controller.text, _hosts);
    if (host == null) {
      setState(() => _error = error);
      return false;
    }
    setState(() {
      _hosts.add(host);
      _controller.clear();
      _error = null;
    });
    return true;
  }

  /// "Done" commits a host typed but not yet added. Losing it silently is the
  /// one thing a save button must not do.
  void _done() {
    if (_controller.text.trim().isNotEmpty && !_add()) return;
    Navigator.of(context).pop(_hosts);
  }

  @override
  Widget build(BuildContext context) {
    final customs = [
      for (final h in _hosts)
        if (!PopularSites.all.any((s) => s.primaryDomain == h)) h,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final site in PopularSites.all)
              AppChip(
                label: site.name,
                icon: site.icon,
                selected: _hosts.contains(site.primaryDomain),
                onSelected: () => setState(() {
                  _hosts.contains(site.primaryDomain)
                      ? _hosts.remove(site.primaryDomain)
                      : _hosts.add(site.primaryDomain);
                }),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _controller,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          onSubmitted: (_) => _add(),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          decoration: InputDecoration(
            hintText: 'e.g. news.example.com',
            errorText: _error,
            prefixIcon: const Icon(Icons.public),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add website',
              onPressed: _add,
            ),
          ),
        ),
        if (customs.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          RemovableChips(
            items: customs,
            onRemove: (h) => setState(() => _hosts.remove(h)),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(label: 'Done', expand: true, onPressed: _done),
      ],
    );
  }
}
