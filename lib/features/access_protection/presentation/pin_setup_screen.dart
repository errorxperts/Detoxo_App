import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';
import 'package:detoxo/features/access_protection/domain/entities/pin_config.dart';
import 'package:detoxo/features/access_protection/presentation/pin_cubit.dart';
import 'package:detoxo/features/access_protection/presentation/pin_gate.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Configure (or turn off) the PIN lock, which sections it guards, and
/// biometric unlock. Custom PINs require a matching confirmation. There is no
/// recovery channel — see `PinHelpSheet`.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  /// The scopes this screen can toggle; any others persisted by an older build
  /// (e.g. the retired `planSwitch` or `appLocker`) are pruned on load so they
  /// aren't re-saved.
  static const _supportedScopes = {PinScope.app, PinScope.settings};

  PinType _type = PinType.custom;
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  final Set<PinScope> _scopes = {..._supportedScopes};
  bool _biometric = false;
  bool _biometricAvailable = false;
  AutoLockTimeout _autoLock = AutoLockTimeout.m1;
  bool _secureScreen = false;

  /// Set by the first Save: from then on the inline errors track the fields
  /// live, so each one stays until it is fixed.
  bool _tried = false;
  final _pinErrorKey = GlobalKey();
  final _scopeErrorKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final config = context.read<PinCubit>().state;
    if (config.isConfigured) {
      _type = config.type;
      _scopes
        ..clear()
        ..addAll(config.scopes.where(_supportedScopes.contains));
      _biometric = config.biometricEnabled;
      _autoLock = config.autoLock;
      _secureScreen = config.secureScreen;
    }
    _loadBiometricAvailability();
  }

  Future<void> _loadBiometricAvailability() async {
    final available = await context.read<PinCubit>().canUseBiometrics();
    if (mounted) setState(() => _biometricAvailable = available);
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // "None" removes the lock entirely (the default state).
    if (_type == PinType.none) {
      await _turnOff();
      return;
    }

    setState(() => _tried = true);
    if (_pinError != null || _scopeError != null) {
      // The error sits above the Save button, maybe off screen: bring it in.
      final target = _pinError != null ? _pinErrorKey : _scopeErrorKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final at = target.currentContext;
        if (!mounted || at == null) return;
        Scrollable.ensureVisible(
          at,
          alignment: 0.5,
          duration: context.motion(AppDurations.detail),
          curve: AppCurves.detail,
        );
      });
      return;
    }

    await context.read<PinCubit>().setup(
      type: _type,
      secret: _pinController.text.trim(),
      scopes: _scopes,
      biometricEnabled: _biometric && _biometricAvailable,
      autoLock: _autoLock,
      secureScreen: _secureScreen,
    );
    if (!mounted) return;
    GlassToast.show(context, 'PIN saved');
    Navigator.of(context).pop();
  }

  /// Applies the "None" choice. If a PIN is currently set this confirms
  /// ([confirmPinOff]; the route's `PinGuard` already asked for the PIN)
  /// before disabling; if nothing is configured it just closes (no-op).
  Future<void> _turnOff() async {
    final configured = context.read<PinCubit>().state.isConfigured;
    if (!configured) {
      Navigator.of(context).pop();
      return;
    }
    if (await confirmPinOff(context) && mounted) Navigator.of(context).pop();
  }

  String? get _pinError {
    if (!_tried || _type != PinType.custom) return null;
    final pin = _pinController.text.trim();
    if (pin.length < 4) return 'Use at least 4 digits';
    if (pin != _confirmController.text.trim()) return 'The two PINs differ';
    return null;
  }

  String? get _scopeError =>
      _tried && _scopes.isEmpty ? 'Pick at least one' : null;

  /// Live preview of a clock-derived PIN — same source of truth as the
  /// matcher, so what we show is always what unlocks.
  String _derivedPreview() => PinCubit.derivedPin(_type, DateTime.now()) ?? '';

  /// Picks the PIN type in a glass bottom sheet (consistent with the Settings
  /// pickers), then applies the choice.
  Future<void> _openPinTypeSheet() async {
    final picked = await GlassBottomSheet.show<PinType>(
      context: context,
      title: 'PIN type',
      child: _PinTypePicker(selected: _type),
    );
    if (picked != null && mounted) setState(() => _type = picked);
  }

  Future<void> _openAutoLockSheet() async {
    final picked = await GlassBottomSheet.show<AutoLockTimeout>(
      context: context,
      title: 'Auto-lock',
      child: _AutoLockPicker(selected: _autoLock),
    );
    if (picked != null && mounted) setState(() => _autoLock = picked);
  }

  @override
  Widget build(BuildContext context) {
    final configured = context.watch<PinCubit>().state.isConfigured;
    final ink2 = context.tokens.ink2;
    final derived = _type == PinType.date || _type == PinType.time;
    final pinError = _pinError;
    final scopeError = _scopeError;

    return GlassScaffold(
      appBar: const GlassAppBar(title: Text('PIN lock')),
      // Not a lazy list: Save scrolls an inline error into view, so every
      // section has to be built.
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader('PIN type'),
            FeatureTile(
              icon: Icons.pin_outlined,
              title: 'PIN type',
              subtitle: _pinTypeLabel(_type),
              onTap: _openPinTypeSheet,
            ),
            _Note(
              derived
                  ? '${_pinTypeHint(_type)} Right now that is '
                        '${_derivedPreview()}.'
                  : _pinTypeHint(_type),
            ),
            // None removes the lock, so the PIN, scope and biometric
            // sections are hidden — only the type picker and Save remain.
            if (_type != PinType.none) ...[
              if (_type == PinType.custom) ...[
                const SectionHeader('Your PIN'),
                _pinField(_pinController, 'PIN', hint: 'Enter 4–10 digits'),
                const SizedBox(height: AppSpacing.xs),
                _pinField(_confirmController, 'Confirm PIN'),
                if (pinError != null)
                  _Note(pinError, key: _pinErrorKey, error: true),
              ],
              const SectionHeader('Protect'),
              PanelGroup(
                children: [
                  _scopeTile(
                    PinScope.app,
                    'Opening Detoxo',
                    'Ask for the PIN at launch',
                  ),
                  _scopeTile(
                    PinScope.settings,
                    'Changing protected settings',
                    'Ask before disabling blocking, resetting data or '
                        'changing the PIN',
                  ),
                ],
              ),
              if (scopeError != null)
                _Note(scopeError, key: _scopeErrorKey, error: true),
              if (_scopes.contains(PinScope.app)) ...[
                const SectionHeader('Auto-lock'),
                PanelGroup(
                  children: [
                    FeatureTile(
                      icon: Icons.lock_clock_outlined,
                      title: 'Re-lock after leaving Detoxo',
                      subtitle: _autoLockLabel(_autoLock),
                      onTap: _openAutoLockSheet,
                    ),
                    AppToggleTile(
                      leading: Icon(Icons.visibility_off_outlined, color: ink2),
                      title: 'Hide screen in Recents',
                      subtitle: 'Blanks the app preview and blocks screenshots',
                      value: _secureScreen,
                      onChanged: (v) => setState(() => _secureScreen = v),
                    ),
                  ],
                ),
              ],
              if (_biometricAvailable) ...[
                const SectionHeader('Convenience'),
                AppToggleTile(
                  leading: Icon(Icons.fingerprint, color: ink2),
                  title: 'Unlock with fingerprint or device credential',
                  subtitle:
                      'Use fingerprint / face, or your device PIN, pattern or '
                      'password',
                  value: _biometric,
                  onChanged: (v) => setState(() => _biometric = v),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              const _Note(
                'Detoxo can’t recover a forgotten PIN. Reinstalling clears it '
                'with all settings.',
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: _saveLabel(configured),
              icon: Icons.check_rounded,
              expand: true,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  /// A digits-only themed field. The length cap is a formatter, not
  /// `maxLength`, so no counter shows under it.
  Widget _pinField(
    TextEditingController controller,
    String label, {
    String? hint,
  }) => TextField(
    controller: controller,
    keyboardType: TextInputType.number,
    obscureText: true,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(10),
    ],
    decoration: InputDecoration(labelText: label, hintText: hint),
    onChanged: (_) {
      if (_tried) setState(() {});
    },
  );

  String _saveLabel(bool configured) {
    if (_type == PinType.none) return configured ? 'Turn off PIN lock' : 'Done';
    return 'Save PIN';
  }

  Widget _scopeTile(PinScope scope, String label, String subtitle) =>
      AppToggleTile(
        title: label,
        subtitle: subtitle,
        value: _scopes.contains(scope),
        onChanged: (v) => setState(() {
          if (v) {
            _scopes.add(scope);
          } else {
            _scopes.remove(scope);
          }
        }),
      );
}

/// A subhead line under a section: ink-2 for a hint, ink for an inline
/// [error] (a live region, so TalkBack reads it when it appears).
class _Note extends StatelessWidget {
  const _Note(this.text, {this.error = false, super.key});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, AppSpacing.xs, 4, 0),
      child: Semantics(
        liveRegion: error,
        child: Text(
          text,
          style: AppTypography.subhead.copyWith(color: error ? t.ink : t.ink2),
        ),
      ),
    );
  }
}

/// Human labels & hints for the PIN types, shared by the setup row and the
/// bottom-sheet picker.
String _pinTypeLabel(PinType t) => switch (t) {
  PinType.none => 'None — no lock',
  PinType.custom => 'Custom PIN',
  PinType.date => "Today's date",
  PinType.time => 'Current time',
  _ => 'Unsupported', // wire-compat types; never leak an enum identifier
};

String _pinTypeHint(PinType t) => switch (t) {
  PinType.none => "Detoxo won't ask for a PIN — this is the default.",
  PinType.custom => 'A PIN you choose (4–10 digits).',
  PinType.date => 'Derived from the date (ddMMyyyy) — changes daily.',
  PinType.time => 'Derived from the clock (HHmm) — changes each minute.',
  _ => '',
};

/// Human labels & hints for the auto-lock timeouts, shared by the setup row
/// and the bottom-sheet picker.
String _autoLockLabel(AutoLockTimeout t) => switch (t) {
  AutoLockTimeout.never => 'Never — only on relaunch',
  AutoLockTimeout.immediately => 'Immediately',
  AutoLockTimeout.s15 => 'After 15 seconds',
  AutoLockTimeout.s30 => 'After 30 seconds',
  AutoLockTimeout.m1 => 'After 1 minute',
  AutoLockTimeout.m5 => 'After 5 minutes',
  AutoLockTimeout.screenOff => 'When screen turns off',
};

String _autoLockHint(AutoLockTimeout t) => switch (t) {
  AutoLockTimeout.never => 'Ask again only when Detoxo restarts',
  AutoLockTimeout.immediately => 'Ask every time you leave and come back',
  AutoLockTimeout.screenOff => 'Stay unlocked while the screen stays on',
  _ => 'Ask after this long away from Detoxo',
};

/// Bottom-sheet body: the auto-lock timeouts as option rows (the picked one
/// carries the check). Pops the chosen [AutoLockTimeout] (or nothing if
/// dismissed).
class _AutoLockPicker extends StatelessWidget {
  const _AutoLockPicker({required this.selected});

  final AutoLockTimeout selected;

  @override
  Widget build(BuildContext context) {
    return PanelGroup(
      children: [
        for (final timeout in AutoLockTimeout.values)
          GlassListTile(
            title: _autoLockLabel(timeout),
            subtitle: _autoLockHint(timeout),
            selected: timeout == selected,
            onTap: () => Navigator.of(context).pop(timeout),
          ),
      ],
    );
  }
}

/// Bottom-sheet body: the PIN types as option rows. Pops the chosen [PinType]
/// (or nothing if dismissed).
class _PinTypePicker extends StatelessWidget {
  const _PinTypePicker({required this.selected});

  final PinType selected;

  @override
  Widget build(BuildContext context) {
    return PanelGroup(
      children: [
        for (final type in const [
          PinType.none,
          PinType.custom,
          PinType.date,
          PinType.time,
        ])
          GlassListTile(
            title: _pinTypeLabel(type),
            subtitle: _pinTypeHint(type),
            selected: type == selected,
            onTap: () => Navigator.of(context).pop(type),
          ),
      ],
    );
  }
}
