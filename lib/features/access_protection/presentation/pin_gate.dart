import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/access_protection/presentation/pin_cubit.dart';
import 'package:detoxo/features/access_protection/presentation/pin_lock_screen.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Demands the PIN for [scope] before continuing. Returns `true` immediately
/// when no PIN guards the scope; otherwise pushes a full-screen [PinLockScreen]
/// and resolves to whether the user unlocked (vs. cancelled).
///
/// Use at the trigger of a protected action:
/// ```dart
/// if (await requirePin(context, PinScope.settings)) {
///   // proceed
/// }
/// ```
Future<bool> requirePin(BuildContext context, PinScope scope) async {
  final config = context.read<PinCubit>().state;
  if (!config.isConfigured || !config.guards(scope)) return true;

  final ok = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute<bool>(
      fullscreenDialog: true,
      builder: (ctx) => PinLockScreen(
        scope: scope,
        onUnlocked: () => Navigator.of(ctx).pop(true),
        onCancel: () => Navigator.of(ctx).pop(false),
      ),
    ),
  );
  return ok ?? false;
}

/// The one "Turn off PIN lock?" confirm (Settings' switch and the setup
/// screen's None). A critical [ConfirmSheet]; after the slide it disables the
/// lock and toasts. Resolves to whether the lock is now off. It asks for no
/// PIN itself: callers gate it with [requirePin], or sit behind a [PinGuard].
Future<bool> confirmPinOff(BuildContext context) async {
  final ok = await ConfirmSheet.show(
    context,
    icon: const DetoxoLogo(height: 58),
    title: 'Turn off PIN lock?',
    message: 'Detoxo and its protected settings stop asking for a PIN.',
    action: 'Slide to turn off',
    cancel: 'Keep it on',
    tone: ConfirmTone.critical,
  );
  if (!ok || !context.mounted) return false;
  await context.read<PinCubit>().disable();
  if (context.mounted) GlassToast.show(context, 'PIN lock turned off');
  return true;
}

/// Wraps a screen so it is revealed only after the PIN for [scope] is entered.
/// When the scope isn't guarded the [child] shows immediately; otherwise the
/// lock screen is shown inline and cancelling pops back out of the route.
class PinGuard extends StatefulWidget {
  const PinGuard({required this.scope, required this.child, super.key});

  final PinScope scope;
  final Widget child;

  @override
  State<PinGuard> createState() => _PinGuardState();
}

class _PinGuardState extends State<PinGuard> {
  late bool _unlocked;

  @override
  void initState() {
    super.initState();
    final config = context.read<PinCubit>().state;
    _unlocked = !config.isConfigured || !config.guards(widget.scope);
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return widget.child;
    return PinLockScreen(
      scope: widget.scope,
      onUnlocked: () => setState(() => _unlocked = true),
      onCancel: () => Navigator.of(context).maybePop(),
    );
  }
}
