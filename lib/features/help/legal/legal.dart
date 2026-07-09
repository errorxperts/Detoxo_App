/// Legal sub-feature — the Help → Legal section.
///
/// Surfaces the hosted **Privacy Policy** and **Terms & Conditions** pages
/// inside the app via a single reusable `LegalWebViewScreen`, framed in the
/// app's frosted glass chrome. Canonical URLs live in `AppLegal`
/// (`core/constants/app_constants.dart`).
///
/// The screen is registered in `core/navigation` (the composition root); other
/// features should reach it only through this barrel — never its internals.
library;

export 'presentation/legal_web_view_screen.dart';
