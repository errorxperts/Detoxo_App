import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';
import 'package:detoxo/features/access_protection/presentation/pin_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Full-screen PIN gate shown at launch when a PIN guards the app.
class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _entry = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    final config = context.read<PinCubit>().state;
    if (config.biometricEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
  }

  Future<void> _tryBiometric() async {
    final ok = await context.read<PinCubit>().authenticateBiometric();
    if (ok && mounted) context.go(Routes.home);
  }

  Future<void> _onKey(String digit) async {
    if (_entry.length >= 10) return;
    setState(() {
      _entry += digit;
      _error = null;
    });
    if (_entry.length >= 4) await _attempt();
  }

  Future<void> _attempt() async {
    final ok = await context.read<PinCubit>().verify(_entry);
    if (!mounted) return;
    if (ok) {
      context.go(Routes.home);
    } else {
      setState(() {
        _error = 'Incorrect PIN';
        _entry = '';
      });
    }
  }

  void _backspace() {
    if (_entry.isNotEmpty) setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  Future<void> _forgotPin() async {
    final email = context.read<PinCubit>().state.verifiedEmail;
    await showDialog<void>(
      context: context,
      builder: (_) => _RecoveryDialog(email: email),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<PinCubit>().state;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 48),
              const SizedBox(height: 16),
              Text(
                'Enter your PIN',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 24),
              _Dots(length: _entry.length),
              const SizedBox(height: 12),
              SizedBox(
                height: 24,
                child: config.isLockedOut
                    ? _LockoutText(until: config.lockedUntil!)
                    : Text(
                        _error ?? '',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              _Keypad(
                enabled: !config.isLockedOut,
                onKey: _onKey,
                onBackspace: _backspace,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _forgotPin,
                child: const Text('Forgot PIN?'),
              ),
              if (config.biometricEnabled)
                TextButton.icon(
                  onPressed: _tryBiometric,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Use biometrics'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.length});
  final int length;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        length.clamp(0, 10),
        (_) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _LockoutText extends StatelessWidget {
  const _LockoutText({required this.until});
  final DateTime until;

  @override
  Widget build(BuildContext context) {
    final remaining = until.difference(DateTime.now());
    return Text(
      'Too many attempts. Try again in ${formatCountdown(remaining)}',
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.enabled,
    required this.onKey,
    required this.onBackspace,
  });

  final bool enabled;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.4,
        children: [
          for (var i = 1; i <= 9; i++)
            _key('$i'),
          const SizedBox.shrink(),
          _key('0'),
          IconButton(
            onPressed: enabled ? onBackspace : null,
            icon: const Icon(Icons.backspace_outlined),
          ),
        ],
      ),
    );
  }

  Widget _key(String digit) => Padding(
        padding: const EdgeInsets.all(6),
        child: OutlinedButton(
          onPressed: enabled ? () => onKey(digit) : null,
          child: Text(digit, style: const TextStyle(fontSize: 22)),
        ),
      );
}

class _RecoveryDialog extends StatefulWidget {
  const _RecoveryDialog({required this.email});
  final String email;

  @override
  State<_RecoveryDialog> createState() => _RecoveryDialogState();
}

class _RecoveryDialogState extends State<_RecoveryDialog> {
  late final TextEditingController _emailController =
      TextEditingController(text: widget.email);
  final _otpController = TextEditingController();
  bool _sent = false;
  String? _message;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Recovery email'),
          ),
          if (_sent)
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Enter code'),
            ),
          if (_message != null) ...[
            const SizedBox(height: 8),
            Text(_message!, style: const TextStyle(fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _sent ? _validate : _send,
          child: Text(_sent ? 'Verify' : 'Send code'),
        ),
      ],
    );
  }

  Future<void> _send() async {
    final ok = await context
        .read<PinCubit>()
        .sendRecoveryOtp(_emailController.text.trim());
    setState(() {
      _sent = ok;
      _message = ok ? 'Code sent (dev build: use 000000).' : 'Invalid email.';
    });
  }

  Future<void> _validate() async {
    final ok = await context
        .read<PinCubit>()
        .validateRecoveryOtp(_emailController.text.trim(), _otpController.text);
    if (!mounted) return;
    if (ok) {
      await context.read<PinCubit>().disable();
      if (mounted) Navigator.of(context).pop();
    } else {
      setState(() => _message = 'Incorrect code.');
    }
  }
}
