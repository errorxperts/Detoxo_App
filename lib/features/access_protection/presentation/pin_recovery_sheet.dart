import 'dart:async';

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/access_protection/presentation/pin_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// "Forgot PIN" recovery: verify ownership of the recovery email via an OTP,
/// then set a brand-new PIN (the lock is reset, never silently disabled).
///
/// Backend is a documented dev stub — any send succeeds and the code `000000`
/// validates — until a real OTP endpoint is wired behind [PinCubit].
abstract final class PinRecoverySheet {
  static Future<void> show(
    BuildContext context, {
    required VoidCallback onRecovered,
  }) async {
    final recovered = await GlassBottomSheet.show<bool>(
      context: context,
      title: 'Reset your PIN',
      child: const _RecoveryFlow(),
    );
    if ((recovered ?? false) && context.mounted) onRecovered();
  }
}

enum _Step { email, code, newPin }

/// Masks an email for display: `john.doe@example.com` → `j•••@e•••.com`.
String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 0 || at == email.length - 1) return email;
  final local = email.substring(0, at);
  final domain = email.substring(at + 1);
  final dot = domain.lastIndexOf('.');
  final name = dot > 0 ? domain.substring(0, dot) : domain;
  final tld = dot > 0 ? domain.substring(dot) : '';
  String hide(String s) => s.isEmpty ? s : '${s[0]}•••';
  return '${hide(local)}@${hide(name)}$tld';
}

class _RecoveryFlow extends StatefulWidget {
  const _RecoveryFlow();

  @override
  State<_RecoveryFlow> createState() => _RecoveryFlowState();
}

class _RecoveryFlowState extends State<_RecoveryFlow> {
  static const _cooldownSeconds = 30;

  late final TextEditingController _emailController;
  final _codeController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();

  late final bool _emailLocked; // a verified email is already on file
  _Step _step = _Step.email;
  int _cooldown = 0;
  Timer? _cooldownTimer;
  bool _busy = false;

  PinCubit get _pin => context.read<PinCubit>();

  @override
  void initState() {
    super.initState();
    final stored = _pin.state.verifiedEmail;
    _emailLocked = stored.isNotEmpty;
    _emailController = TextEditingController(text: stored);
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = _cooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    final ok = await _pin.sendRecoveryOtp(_emailController.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      setState(() => _step = _Step.code);
      _startCooldown();
      GlassToast.show(
        context,
        'Code sent. Dev build: use 000000.',
        tone: AppTone.success,
      );
    } else {
      GlassToast.show(
        context,
        'Enter a valid email address.',
        tone: AppTone.danger,
      );
    }
  }

  Future<void> _resend() async {
    if (_cooldown > 0) return;
    final ok = await _pin.sendRecoveryOtp(_emailController.text.trim());
    if (!mounted) return;
    if (ok) {
      _startCooldown();
      GlassToast.show(context, 'New code sent.', tone: AppTone.success);
    }
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    final ok = await _pin.validateRecoveryOtp(
      _emailController.text.trim(),
      _codeController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      setState(() => _step = _Step.newPin);
    } else {
      GlassToast.show(context, 'Incorrect code.', tone: AppTone.danger);
    }
  }

  Future<void> _setNewPin() async {
    final pin = _pinController.text.trim();
    final confirm = _confirmController.text.trim();
    if (pin.length < 4) {
      GlassToast.show(context, 'Use at least 4 digits.', tone: AppTone.danger);
      return;
    }
    if (pin != confirm) {
      GlassToast.show(context, "PINs don't match.", tone: AppTone.danger);
      return;
    }
    await _pin.resetSecretAfterRecovery(pin);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      _Step.email => _emailStep(),
      _Step.code => _codeStep(),
      _Step.newPin => _newPinStep(),
    };
  }

  Widget _emailStep() {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _emailLocked
              ? 'We’ll send a code to your recovery email.'
              : 'Enter your recovery email to receive a code.',
          style: text.bodyMedium?.copyWith(color: context.glass.onGlassMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_emailLocked)
          _ReadOnlyField(value: maskEmail(_emailController.text.trim()))
        else
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Recovery email',
              hintText: 'you@example.com',
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: _busy ? 'Sending…' : 'Send code',
          expand: true,
          onPressed: _busy ? null : _send,
        ),
      ],
    );
  }

  Widget _codeStep() {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter the 6-digit code sent to ${maskEmail(_emailController.text.trim())}.',
          style: text.bodyMedium?.copyWith(color: context.glass.onGlassMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Verification code'),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _cooldown > 0 ? null : _resend,
            child: Text(
              _cooldown > 0 ? 'Resend in ${_cooldown}s' : 'Resend code',
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        PrimaryButton(
          label: _busy ? 'Verifying…' : 'Verify',
          expand: true,
          onPressed: _busy ? null : _verify,
        ),
      ],
    );
  }

  Widget _newPinStep() {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Set a new PIN (4–10 digits).',
          style: text.bodyMedium?.copyWith(color: context.glass.onGlassMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 10,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'New PIN'),
        ),
        TextField(
          controller: _confirmController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 10,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Confirm new PIN'),
        ),
        const SizedBox(height: AppSpacing.sm),
        PrimaryButton(
          label: 'Set new PIN',
          expand: true,
          onPressed: _setNewPin,
        ),
      ],
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      enableBlur: false,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.mail_outline, size: 18, color: context.glass.onGlassMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.titleMedium),
          ),
        ],
      ),
    );
  }
}
