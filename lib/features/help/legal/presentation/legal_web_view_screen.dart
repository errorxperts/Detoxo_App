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

  /// First-load [LoadingState]; cleared once the page finishes (or errors).
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
          LegalPageStatus(loading: _loading, failed: _failed, onRetry: _load),
        ],
      ),
    );
  }
}

/// The page's loading and error states, drawn over the web view: the
/// [LoadingState] while [loading], a calm [EmptyState] with Retry once
/// [failed], otherwise nothing. Public so the states test without a platform
/// web view.
class LegalPageStatus extends StatelessWidget {
  const LegalPageStatus({
    required this.loading,
    required this.failed,
    required this.onRetry,
    super.key,
  });

  final bool loading;
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) return const LoadingState();
    if (!failed) return const SizedBox.shrink();
    return EmptyState(
      icon: Icons.cloud_off_outlined,
      title: "Couldn't load this page",
      subtitle: 'Check your connection and try again.',
      action: PrimaryButton(
        label: 'Retry',
        icon: Icons.refresh,
        flat: true,
        onPressed: onRetry,
      ),
    );
  }
}
