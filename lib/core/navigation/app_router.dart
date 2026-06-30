import 'package:detoxo/app/splash_screen.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/features/access_protection/presentation/pin_lock_screen.dart';
import 'package:detoxo/features/access_protection/presentation/pin_setup_screen.dart';
import 'package:detoxo/features/analytics/presentation/analytics_screen.dart';
import 'package:detoxo/features/content_counter/content_counter_core/presentation/content_counter_screen.dart';
import 'package:detoxo/features/dashboard/presentation/home_shell.dart';
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
      path: Routes.contentCounter,
      builder: (_, _) => const ContentCounterScreen(),
    ),
  ],
);
