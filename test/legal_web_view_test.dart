import 'package:detoxo/core/constants/app_constants.dart';
import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/features/help/legal/presentation/legal_web_view_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the wire values the Legal (Privacy Policy / Terms) tiles depend on.
///
/// The screen itself renders a `webview_flutter` platform view, which can't be
/// exercised in a headless widget test without a brittle platform mock — so we
/// lock the URLs and their fragments (the part most likely to regress), the
/// distinct route paths, and the loading / error layer drawn over the view
/// ([LegalPageStatus]). See `features/help/legal`.
void main() {
  group('AppLegal URLs', () {
    test('privacy and terms point at the hosted SPA fragments', () {
      expect(AppLegal.privacyPolicyUrl, 'https://detoxo.web.app/#privacy');
      expect(AppLegal.termsUrl, 'https://detoxo.web.app/#terms');
    });

    test('both are valid https Uris carrying the routing fragment', () {
      for (final url in [AppLegal.privacyPolicyUrl, AppLegal.termsUrl]) {
        final uri = Uri.parse(url);
        expect(uri.scheme, 'https', reason: url);
        expect(uri.host, 'detoxo.web.app', reason: url);
        // The fragment (#privacy / #terms) is what drives the SPA to the right
        // section — losing it would silently show the wrong page.
        expect(uri.fragment, isNotEmpty, reason: url);
      }
    });

    test('the two documents are distinct', () {
      expect(AppLegal.privacyPolicyUrl, isNot(AppLegal.termsUrl));
      expect(Uri.parse(AppLegal.privacyPolicyUrl).fragment, 'privacy');
      expect(Uri.parse(AppLegal.termsUrl).fragment, 'terms');
    });
  });

  group('LegalPageStatus', () {
    Future<void> pump(
      WidgetTester tester, {
      required bool loading,
      required bool failed,
      VoidCallback? onRetry,
    }) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: LegalPageStatus(
            loading: loading,
            failed: failed,
            onRetry: onRetry ?? () {},
          ),
        ),
      ),
    );

    testWidgets('loading shows the LoadingState', (tester) async {
      await pump(tester, loading: true, failed: false);
      expect(find.byType(LoadingState), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('an error shows Retry, which reloads', (tester) async {
      var retries = 0;
      await pump(
        tester,
        loading: false,
        failed: true,
        onRetry: () => retries++,
      );
      expect(find.byType(LoadingState), findsNothing);
      expect(find.text("Couldn't load this page"), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    });

    testWidgets('a loaded page draws nothing over the view', (tester) async {
      await pump(tester, loading: false, failed: false);
      expect(find.byType(LoadingState), findsNothing);
      expect(find.byType(EmptyState), findsNothing);
    });
  });

  group('Legal routes', () {
    test('are nested under help and distinct', () {
      expect(Routes.privacyPolicy, '/help/legal/privacy');
      expect(Routes.termsConditions, '/help/legal/terms');
      expect(Routes.privacyPolicy, startsWith(Routes.help));
      expect(Routes.termsConditions, startsWith(Routes.help));
      expect(Routes.privacyPolicy, isNot(Routes.termsConditions));
    });
  });
}
