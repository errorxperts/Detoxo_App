// Central enums for the detection / blocking domain.
//
// Each enum carries the original wire token (the string used in
// `platforms_config.json` / settings) so JSON (de)serialization is explicit
// and resilient to ordering changes.

/// The user's active high-level blocking strategy.
enum BlockingPlan {
  blockAll('BLOCK_ALL'),
  curious('CURIOUS'),
  oneReel('ONE_REEL'),
  paused('PAUSED');

  const BlockingPlan(this.wire);
  final String wire;

  static BlockingPlan fromWire(String? v) => values.firstWhere(
    (e) => e.wire == v,
    orElse: () => BlockingPlan.blockAll,
  );
}

/// What happens when short content is detected.
enum BlockingMode {
  pressBack('PRESS_BACK'),
  killApp('KILL_APP'),

  /// Locks the offending app behind the user's PIN, app-locker style: the back
  /// press exits the reel and the PIN lock screen is shown; a correct PIN ejects
  /// to Detoxo's home. (Native enforcement is a follow-up; until then the engine
  /// degrades this to a back press.)
  lockApp('LOCK_APP'),

  /// Device-level lock via Device Admin. Retained for wire/config compatibility;
  /// no longer offered in the block-mode picker.
  lockScreen('LOCK_SCREEN'),
  overlay('OVERLAY'),
  none('NONE');

  const BlockingMode(this.wire);
  final String wire;

  static BlockingMode fromWire(String? v) => values.firstWhere(
    (e) => e.wire == v,
    orElse: () => BlockingMode.pressBack,
  );
}

/// How a platform's content is detected.
enum DetectionType {
  legacy('LEGACY'),
  calibration('CALIBRATION'),
  overlay('OVERLAY'),
  manual('MANUAL'),
  none('NONE');

  const DetectionType(this.wire);
  final String wire;

  static DetectionType fromWire(String? v) =>
      values.firstWhere((e) => e.wire == v, orElse: () => DetectionType.legacy);
}

/// The view-matching strategy a detector uses.
enum ViewDetector {
  findById('FINDBYID'),
  viewIdResName('VIEWID_RES_NAME'),
  contentDescription('CONT_DESC'),
  browser('BROWSER');

  const ViewDetector(this.wire);
  final String wire;

  static ViewDetector fromWire(String? v) => values.firstWhere(
    (e) => e.wire == v,
    orElse: () => ViewDetector.findById,
  );
}

/// Website blocklist matching modes.
enum WebMatchType {
  domain('DOMAIN'),
  exact('EXACT'),
  wildcard('WILDCARD');

  const WebMatchType(this.wire);
  final String wire;

  static WebMatchType fromWire(String? v) =>
      values.firstWhere((e) => e.wire == v, orElse: () => WebMatchType.domain);
}

/// What an app-locker enforces when a locked app is opened.
enum AppLockAction {
  overlay('OVERLAY'),
  closeApp('CLOSE_APP'),
  lockScreen('LOCK_SCREEN');

  const AppLockAction(this.wire);
  final String wire;

  static AppLockAction fromWire(String? v) => values.firstWhere(
    (e) => e.wire == v,
    orElse: () => AppLockAction.closeApp,
  );
}

/// PIN credential types.
enum PinType {
  none('NONE'),
  custom('CUSTOM'),
  date('DATE'),
  time('TIME'),
  otp('OTP'),
  deviceDefault('DEVICE_DEFAULT');

  const PinType(this.wire);
  final String wire;

  static PinType fromWire(String? v) =>
      values.firstWhere((e) => e.wire == v, orElse: () => PinType.none);
}

/// Sections that a PIN can guard.
enum PinScope {
  app('DETOXO_APP'),
  settings('SETTINGS_APP'),
  planSwitch('PLAN_SWITCH'),
  detoxoSettings('DETOXO_SETTINGS'),
  appLocker('APP_LOCKER');

  const PinScope(this.wire);
  final String wire;

  static PinScope fromWire(String? v) =>
      values.firstWhere((e) => e.wire == v, orElse: () => PinScope.app);
}

/// App appearance preference. Domain-level (no Flutter dependency); the
/// presentation layer maps this to a Flutter `ThemeMode`.
enum AppThemeMode {
  system('SYSTEM'),
  light('LIGHT'),
  dark('DARK');

  const AppThemeMode(this.wire);
  final String wire;

  static AppThemeMode fromWire(String? v) =>
      values.firstWhere((e) => e.wire == v, orElse: () => AppThemeMode.dark);
}

/// App-background choice. Domain-level (no Flutter dependency); the presentation
/// layer maps this to a design-system `AppBackgroundStyle`, which resolves the
/// dark/light variant for the active theme. [aurora] is the theme-aware default
/// (the built-in ambient glow); [bg1]–[bg3] are SVG gradient backgrounds.
enum AppBackground {
  aurora('AURORA'),
  bg1('BG1'),
  bg2('BG2'),
  bg3('BG3');

  const AppBackground(this.wire);
  final String wire;

  static AppBackground fromWire(String? v) =>
      values.firstWhere((e) => e.wire == v, orElse: () => AppBackground.aurora);
}

/// Phase of a timed session (pause or curious).
enum SessionPhase { active, cooldown, idle }

/// Device form-factor used for calibration selection.
enum DeviceFormFactor {
  mobile('MOBILE'),
  tablet('TABLET'),
  landscape('LANDSCAPE'),
  landscapeTablet('LANDSCAPE_TABLET');

  const DeviceFormFactor(this.wire);
  final String wire;

  static DeviceFormFactor fromWire(String? v) => values.firstWhere(
    (e) => e.wire == v,
    orElse: () => DeviceFormFactor.mobile,
  );
}

/// Status of a single runtime permission in the onboarding funnel.
/// [permanentlyDenied] = the OS won't show the prompt again (don't-ask-again);
/// recovery is only via the app's system settings screen.
enum PermissionState { granted, denied, permanentlyDenied, unknown }

/// Live status of the native accessibility service.
enum ServiceStatus { running, stopped, unknown }
