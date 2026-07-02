import 'package:detoxo/core/design_system/foundations/ambient_background.dart';
import 'package:detoxo/core/design_system/foundations/background_scope.dart';
import 'package:detoxo/core/design_system/foundations/motion.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/core/navigation/app_router.dart';
import 'package:detoxo/core/theme/app_theme.dart';
import 'package:detoxo/features/access_protection/domain/repositories/pin_repository.dart';
import 'package:detoxo/features/access_protection/presentation/pin_cubit.dart';
import 'package:detoxo/features/additional_feature/app_feedback/app_feedback.dart';
import 'package:detoxo/features/blocking/blocklist/presentation/targets_cubit.dart';
import 'package:detoxo/features/blocking/engine/presentation/service_cubit.dart';
import 'package:detoxo/features/blocking/plans/presentation/conscious_cubit.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/app_settings.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/features/blocking/shared/domain/repositories/blocking_repositories.dart';
import 'package:detoxo/features/blocking/shared/presentation/settings_cubit.dart';
import 'package:detoxo/features/permissions/domain/repositories/permission_repository.dart';
import 'package:detoxo/features/permissions/presentation/permissions_cubit.dart';
import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  await configureDependencies();
  GlassAppBar.globalActionsBuilder = (_) => const [FeedbackActionButton()];
  runApp(const DetoxoApp());
}

class DetoxoApp extends StatelessWidget {
  const DetoxoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ServiceCubit(sl<EngineRepository>())),
        BlocProvider(create: (_) => ConsciousCubit(sl<EngineRepository>())),
        BlocProvider(
          create: (_) => SettingsCubit(sl<SettingsRepository>(), sl<EngineRepository>()),
        ),
        BlocProvider(create: (_) => TargetsCubit(sl<ConfigRepository>(), sl<EngineRepository>())),
        BlocProvider(create: (_) => PermissionsCubit(sl<PermissionRepository>())),
        BlocProvider(create: (_) => PinCubit(sl<PinRepository>())),
      ],
      child: BlocListener<SettingsCubit, AppSettings>(
        listenWhen: (a, b) => a.vibrationEnabled != b.vibrationEnabled,
        listener: (_, state) => AppHaptics.enabled = state.vibrationEnabled,
        child: BlocSelector<SettingsCubit, AppSettings, (AppThemeMode, AppBackground)>(
          selector: (s) => (s.themeMode, s.backgroundId),
          builder: (_, sel) => BackgroundScope(
            style: _bgStyle(sel.$2),
            child: _Router(themeMode: _flutterThemeMode(sel.$1)),
          ),
        ),
      ),
    );
  }
}

/// Maps the domain appearance preference to a Flutter [ThemeMode].
ThemeMode _flutterThemeMode(AppThemeMode mode) => switch (mode) {
  AppThemeMode.system => ThemeMode.system,
  AppThemeMode.light => ThemeMode.light,
  AppThemeMode.dark => ThemeMode.dark,
};

/// Maps the domain background preference to the design-system style enum (which
/// resolves the dark/light SVG variant for the active theme).
AppBackgroundStyle _bgStyle(AppBackground background) => switch (background) {
  AppBackground.aurora => AppBackgroundStyle.aurora,
  AppBackground.bg1 => AppBackgroundStyle.bg1,
  AppBackground.bg2 => AppBackgroundStyle.bg2,
  AppBackground.bg3 => AppBackgroundStyle.bg3,
};

class _Router extends StatefulWidget {
  const _Router({required this.themeMode});

  final ThemeMode themeMode;

  @override
  State<_Router> createState() => _RouterState();
}

class _RouterState extends State<_Router> {
  final _router = buildRouter();

  @override
  Widget build(BuildContext context) {
    return BetterFeedback(
      themeMode: widget.themeMode,
      theme: glassFeedbackTheme(Brightness.light),
      darkTheme: glassFeedbackTheme(Brightness.dark),
      feedbackBuilder: (context, onSubmit, scrollController) =>
          GlassFeedbackForm(onSubmit: onSubmit, scrollController: scrollController),
      child: MaterialApp.router(
        title: 'Detoxo',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: widget.themeMode,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
