import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';
import 'package:detoxo/features/access_protection/presentation/pin_cubit.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Configure (or turn off) the PIN lock, which sections it guards, the recovery
/// email and biometric unlock. Custom PINs require a matching confirmation.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  // Verified email regex from the reference app (doc §9).
  static final _emailRegex = RegExp(
    r'^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  /// The scopes this screen can toggle; any others persisted by an older build
  /// (e.g. the retired `planSwitch`) are pruned on load so they aren't re-saved.
  static const _supportedScopes = {
    PinScope.app,
    PinScope.settings,
    PinScope.appLocker,
  };

  PinType _type = PinType.custom;
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  final _emailController = TextEditingController();
  final Set<PinScope> _scopes = {..._supportedScopes};
  bool _biometric = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    final config = context.read<PinCubit>().state;
    if (config.isConfigured) {
      _type = config.type;
      _scopes
        ..clear()
        ..addAll(config.scopes.where(_supportedScopes.contains));
      _emailController.text = config.verifiedEmail;
      _biometric = config.biometricEnabled;
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
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final email = _emailController.text.trim();
    if (_type == PinType.custom) {
      final pin = _pinController.text.trim();
      if (pin.length < 4) {
        GlassToast.show(
          context,
          'Enter a PIN of at least 4 digits.',
          tone: AppTone.danger,
        );
        return;
      }
      if (pin != _confirmController.text.trim()) {
        GlassToast.show(context, "PINs don't match.", tone: AppTone.danger);
        return;
      }
    }
    if (_scopes.isEmpty) {
      GlassToast.show(
        context,
        'Pick at least one thing to protect.',
        tone: AppTone.danger,
      );
      return;
    }
    if (email.isNotEmpty && !_emailRegex.hasMatch(email)) {
      GlassToast.show(
        context,
        'Enter a valid recovery email.',
        tone: AppTone.danger,
      );
      return;
    }
    if (_type == PinType.custom && email.isEmpty) {
      GlassToast.show(
        context,
        'Add a recovery email so you can reset your PIN.',
        tone: AppTone.warning,
      );
      return;
    }

    await context.read<PinCubit>().setup(
      type: _type,
      secret: _pinController.text.trim(),
      scopes: _scopes,
      verifiedEmail: email,
      biometricEnabled: _biometric && _biometricAvailable,
    );
    if (!mounted) return;
    GlassToast.show(context, 'PIN saved.', tone: AppTone.success);
    Navigator.of(context).pop();
  }

  Future<void> _confirmDisable() async {
    final ok = await AppDialog.confirm(
      context: context,
      title: 'Turn off PIN lock?',
      message:
          'Detoxo and its protected sections will no longer ask for a PIN.',
      confirmLabel: 'Turn off',
      cancelLabel: 'Keep it on',
      destructive: true,
    );
    if (ok && mounted) {
      await context.read<PinCubit>().disable();
      if (!mounted) return;
      GlassToast.show(context, 'PIN lock turned off.');
      Navigator.of(context).pop();
    }
  }

  String _derivedPreview() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return switch (_type) {
      PinType.date => '${two(now.day)}${two(now.month)}${now.year}',
      PinType.time => '${two(now.hour)}${two(now.minute)}',
      _ => '',
    };
  }

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

  @override
  Widget build(BuildContext context) {
    final configured = context.watch<PinCubit>().state.isConfigured;
    final text = Theme.of(context).textTheme;

    return GlassScaffold(
      appBar: const GlassAppBar(title: Text('PIN lock')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          const SectionHeader('PIN type'),
          FeatureTile(
            icon: Icons.pin_outlined,
            title: 'PIN type',
            subtitle: _pinTypeLabel(_type),
            onTap: _openPinTypeSheet,
          ),
          Text(
            _pinTypeHint(_type),
            style: text.bodySmall?.copyWith(color: context.glass.onGlassMuted),
          ),
          if (_type != PinType.custom) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Right now that is "${_derivedPreview()}".',
              style: text.bodySmall?.copyWith(color: AppColors.accent),
            ),
          ],
          if (_type == PinType.custom) ...[
            const SectionHeader('Your PIN'),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'PIN',
                hintText: 'Enter 4–10 digits',
              ),
            ),
            TextField(
              controller: _confirmController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Confirm PIN'),
            ),
          ],
          const SectionHeader('Protect'),
          _scopeTile(
            PinScope.app,
            'Opening Detoxo',
            'Ask for the PIN at launch',
          ),
          _scopeTile(
            PinScope.settings,
            'Changing protected settings',
            'Ask before disabling blocking or changing the PIN',
          ),
          _scopeTile(
            PinScope.appLocker,
            'App locker',
            'Ask before managing locked apps',
          ),
          const SectionHeader('Recovery email'),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'you@example.com',
              helperText: 'Used to reset your PIN if you forget it',
            ),
          ),
          if (_biometricAvailable) ...[
            const SectionHeader('Convenience'),
            AdaptiveSwitchTile(
              leading: const Icon(Icons.fingerprint, color: AppColors.accent),
              title: 'Allow biometric unlock',
              subtitle: 'Use fingerprint / face to unlock',
              value: _biometric,
              onChanged: (v) => setState(() => _biometric = v),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          AnimatedIconButton(
            label: 'Save PIN',
            icon: AppIcon.check,
            expand: true,
            onPressed: _save,
          ),
          if (configured) ...[
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: GhostButton(
                label: 'Turn off PIN lock',
                onPressed: _confirmDisable,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _scopeTile(PinScope scope, String label, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: AdaptiveSwitchTile(
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
    ),
  );

}

/// Human labels & hints for the PIN types, shared by the setup row and the
/// bottom-sheet picker.
String _pinTypeLabel(PinType t) => switch (t) {
  PinType.custom => 'Custom PIN',
  PinType.date => "Today's date",
  PinType.time => 'Current time',
  _ => t.name,
};

String _pinTypeHint(PinType t) => switch (t) {
  PinType.custom => 'A PIN you choose (4–10 digits).',
  PinType.date => 'Derived from the date (ddMMyyyy) — changes daily.',
  PinType.time => 'Derived from the clock (HHmm) — changes each minute.',
  _ => '',
};

/// Bottom-sheet body: the three PIN types as radio rows. Pops the chosen
/// [PinType] (or nothing if dismissed).
class _PinTypePicker extends StatelessWidget {
  const _PinTypePicker({required this.selected});

  final PinType selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final type in const [PinType.custom, PinType.date, PinType.time])
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: GlassListTile(
              leading: Icon(
                type == selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: type == selected
                    ? AppColors.accent
                    : context.glass.onGlassMuted,
              ),
              title: _pinTypeLabel(type),
              subtitle: _pinTypeHint(type),
              onTap: () => Navigator.of(context).pop(type),
            ),
          ),
      ],
    );
  }
}
