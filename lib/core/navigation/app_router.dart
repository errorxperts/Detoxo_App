import 'package:detoxo/app/splash_screen.dart';
import 'package:detoxo/core/constants/app_constants.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/core/services/firebase/firebase.dart';
import 'package:detoxo/features/access_protection/presentation/pin_lock_screen.dart';
import 'package:detoxo/features/access_protection/presentation/pin_setup_screen.dart';
import 'package:detoxo/features/additional_feature/appearance/presentation/appearance_screen.dart';
import 'package:detoxo/features/analytics/presentation/analytics_screen.dart';
import 'package:detoxo/features/content_counter/content_counter_appearance/presentation/bubble_style_screen.dart';
import 'package:detoxo/features/content_counter/content_counter_appearance/presentation/home_widget_screen.dart';
import 'package:detoxo/features/dashboard/presentation/home_shell.dart';
import 'package:detoxo/features/help/faq/presentation/faq_screen.dart';
import 'package:detoxo/features/help/feature_tutorial/presentation/feature_tutorial_screen.dart';
import 'package:detoxo/features/help/legal/presentation/legal_web_view_screen.dart';
import 'package:detoxo/features/help/presentation/help_screen.dart';
import 'package:detoxo/features/help/share_ideas/presentation/share_ideas_screen.dart';
import 'package:detoxo/features/limits/app_blocker/presentation/app_block_screen.dart';
import 'package:detoxo/features/limits/daily_limit/presentation/daily_limit_screen.dart';
import 'package:detoxo/features/limits/web_blocker/presentation/web_block_screen.dart';
import 'package:detoxo/features/onboarding/presentation/onboarding_screen.dart';
import 'package:detoxo/features/permissions/presentation/permissions_screen.dart';
import 'package:detoxo/features/settings/presentation/settings_screen.dart';
import 'package:go_router/go_router.dart';

/// App navigation graph. Gating (onboarding / PIN / permissions) is performed
/// imperatively from the splash screen after state is loaded.
GoRouter buildRouter() => GoRouter(
  initialLocation: Routes.splash,
  // Logs `screen_view` on every route push (in-shell tabs log manually).
  observers: [sl<AnalyticsService>().navigatorObserver],
  routes: [
    GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
    GoRoute(
      path: Routes.onboarding,
      builder: (_, _) => const OnboardingScreen(),
    ),
    GoRoute(
      path: Routes.permissions,
      builder: (_, _) => const PermissionsScreen(),
    ),
    GoRoute(path: Routes.home, builder: (_, _) => const HomeShell()),
    GoRoute(path: Routes.blocklist, builder: (_, _) => const HomeShell()),
    GoRoute(path: Routes.pinSetup, builder: (_, _) => const PinSetupScreen()),
    GoRoute(path: Routes.pinLock, builder: (_, _) => const PinLockScreen()),
    GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen()),
    GoRoute(path: Routes.webBlock, builder: (_, _) => const WebBlockScreen()),
    GoRoute(
      path: Routes.appBlock,
      builder: (_, _) => const AppBlockScreen(),
    ),
    GoRoute(
      path: Routes.dailyLimit,
      builder: (_, _) => const DailyLimitScreen(),
    ),
    GoRoute(path: Routes.analytics, builder: (_, _) => const AnalyticsScreen()),
    GoRoute(
      path: Routes.appearance,
      builder: (_, _) => const AppearanceScreen(),
    ),
    GoRoute(
      path: Routes.bubbleStyle,
      builder: (_, _) => const BubbleStyleScreen(),
    ),
    GoRoute(
      path: Routes.homeWidget,
      builder: (_, _) => const HomeWidgetScreen(),
    ),
    GoRoute(path: Routes.help, builder: (_, _) => const HelpScreen()),
    GoRoute(path: Routes.helpFaq, builder: (_, _) => const FaqScreen()),
    GoRoute(
      path: Routes.featureTutorial,
      builder: (_, _) => const FeatureTutorialScreen(),
    ),
    GoRoute(
      path: Routes.shareIdeas,
      builder: (_, _) => const ShareIdeasScreen(),
    ),
    GoRoute(
      path: Routes.privacyPolicy,
      builder: (_, _) => const LegalWebViewScreen(
        title: 'Privacy Policy',
        url: AppLegal.privacyPolicyUrl,
      ),
    ),
    GoRoute(
      path: Routes.termsConditions,
      builder: (_, _) => const LegalWebViewScreen(
        title: 'Terms & Conditions',
        url: AppLegal.termsUrl,
      ),
    ),
  ],
);
