import 'package:detoxo/core/constants/app_constants.dart';
import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// A reusable in-app browser for a single hosted page, framed in the app's
/// frosted [GlassScaffold]. Both the Privacy Policy and Terms & Conditions
/// tiles push this same screen, differing only by [title] and [url] (see
/// [AppLegal] for the canonical URLs).
///
/// The target pages are a single-page site that routes via URL fragments
/// (`#privacy` / `#terms`), so JavaScript must stay enabled for the right
/// section to render.
class LegalWebViewScreen extends StatefulWidget {
  const LegalWebViewScreen({required this.title, required this.url, super.key});

  final String title;
  final String url;

  @override
  State<LegalWebViewScreen> createState() => _LegalWebViewScreenState();
}

class _LegalWebViewScreenState extends State<LegalWebViewScreen> {
  late final WebViewController _controller;

  /// First-load spinner; cleared once the page finishes (or errors).
  bool _loading = true;

  /// Set when the initial load fails so we can offer a retry.
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      // Fragment routing on the hosted SPA needs JS — see the class doc.
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            // Ignore sub-resource failures; only surface a hard failure of the
            // main document (the page itself couldn't load).
            if (error.isForMainFrame == false) return;
            if (mounted) {
              setState(() {
                _loading = false;
                _failed = true;
              });
            }
          },
        ),
      );
    _load();
  }

  void _load() {
    setState(() {
      _loading = true;
      _failed = false;
    });
    _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: GlassAppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          if (!_failed) WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_failed)
            _LoadError(onRetry: _load),
        ],
      ),
    );
  }
}

/// Full-bleed error state shown when the page can't be reached, with a retry.
class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final muted = context.glass.onGlassMuted;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 40, color: muted),
            const SizedBox(height: AppSpacing.md),
            Text(
              "Couldn't load this page",
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Check your connection and try again.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
