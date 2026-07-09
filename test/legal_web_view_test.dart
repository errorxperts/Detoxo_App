import 'package:detoxo/core/constants/app_constants.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the wire values the Legal (Privacy Policy / Terms) tiles depend on.
///
/// The screen itself renders a `webview_flutter` platform view, which can't be
/// exercised in a headless widget test without a brittle platform mock — so we
/// lock the URLs and their fragments (the part most likely to regress) and the
/// distinct route paths instead. See `features/help/legal`.
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
