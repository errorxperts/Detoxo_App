import 'package:cupertino_native/cupertino_native.dart';
import 'package:detoxo/core/design_system/adaptive/platform_adaptive.dart';
import 'package:detoxo/core/design_system/foundations/motion.dart';
import 'package:detoxo/core/design_system/tokens/app_colors.dart';
import 'package:flutter/material.dart';

/// This is the ONLY file that imports `cupertino_native`. Every adaptive
/// control renders a native `CN*` widget on iOS/macOS and a hand-built Material
/// widget on Android (true Material, not the package's Cupertino fallback).
/// Native controls do NOT inherit `ColorScheme`, so we always feed `AppColors`
/// into their `color`/`tint`. `CNIcon` is never used — it has no Android
/// fallback and would crash; [AdaptiveIcon] is a plain Material `Icon`.

/// Native `UISwitch` on iOS, Material `Switch` on Android.
class AdaptiveSwitch extends StatelessWidget {
  const AdaptiveSwitch({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.activeColor = AppColors.accent,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final on = enabled && onChanged != null;
    if (PlatformAdaptive.useCupertino) {
      return CNSwitch(
        value: value,
        enabled: on,
        color: activeColor,
        onChanged: on ? onChanged! : (_) {},
      );
    }
    return Switch(
      value: value,
      onChanged: on ? onChanged : null,
      activeTrackColor: activeColor,
    );
  }
}

/// Native segmented control on iOS, Material `SegmentedButton` on Android.
class AdaptiveSegmentedControl extends StatelessWidget {
  const AdaptiveSegmentedControl({
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.enabled = true,
    this.tint = AppColors.seed,
    super.key,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final bool enabled;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    if (PlatformAdaptive.useCupertino) {
      return CNSegmentedControl(
        labels: labels,
        selectedIndex: selectedIndex,
        enabled: enabled,
        color: tint,
        onValueChanged: enabled ? onChanged : (_) {},
      );
    }
    return SegmentedButton<int>(
      segments: [
        for (var i = 0; i < labels.length; i++)
          ButtonSegment<int>(value: i, label: Text(labels[i])),
      ],
      selected: {selectedIndex.clamp(0, labels.length - 1)},
      showSelectedIcon: false,
      onSelectionChanged: enabled ? (sel) => onChanged(sel.first) : null,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? tint.withValues(alpha: 0.25)
              : Colors.transparent,
        ),
      ),
    );
  }
}

/// Native slider on iOS, Material `Slider` on Android.
class AdaptiveSlider extends StatelessWidget {
  const AdaptiveSlider({
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.enabled = true,
    this.color = AppColors.accent,
    super.key,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;
  final bool enabled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final on = enabled && onChanged != null;
    if (PlatformAdaptive.useCupertino) {
      final step = divisions != null && divisions! > 0 ? (max - min) / divisions! : null;
      return CNSlider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        step: step,
        enabled: on,
        color: color,
        onChanged: on ? onChanged! : (_) {},
      );
    }
    return Slider(
      value: value.clamp(min, max),
      min: min,
      max: max,
      divisions: divisions,
      activeColor: color,
      onChanged: on ? onChanged : null,
    );
  }
}

/// Visual emphasis for [AdaptiveButton].
enum AdaptiveButtonVariant { filled, tinted, plain }

/// Native `CNButton` on iOS, Material button on Android. Higher-level CTAs use
/// the `PrimaryButton` / `SecondaryButton` / `GhostButton` wrappers.
class AdaptiveButton extends StatelessWidget {
  const AdaptiveButton({
    required this.label,
    required this.onPressed,
    this.variant = AdaptiveButtonVariant.filled,
    this.tint = AppColors.seed,
    this.expand = false,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AdaptiveButtonVariant variant;
  final Color tint;
  final bool expand;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    Widget button;
    if (PlatformAdaptive.useCupertino) {
      button = CNButton(
        label: label,
        tint: tint,
        height: 44,
        shrinkWrap: !expand,
        style: switch (variant) {
          AdaptiveButtonVariant.filled => CNButtonStyle.glass,
          AdaptiveButtonVariant.tinted => CNButtonStyle.tinted,
          AdaptiveButtonVariant.plain => CNButtonStyle.plain,
        },
        onPressed: onPressed,
      );
    } else {
      final child = icon == null ? Text(label) : null;
      // Min HEIGHT of 44 for a comfortable tap target, with Material's default
      // min width (64). NB: `Size.fromHeight(44)` is `Size(infinity, 44)` —
      // its infinite min width crashes in any unbounded-width parent (e.g. a
      // dialog actions Row). Full-width is expressed via `expand` below, not here.
      const minSize = Size(64, 44);
      button = switch (variant) {
        AdaptiveButtonVariant.filled => icon == null
            ? FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: tint,
                  minimumSize: minSize,
                ),
                child: Text(label),
              )
            : FilledButton.icon(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: tint,
                  minimumSize: minSize,
                ),
                icon: Icon(icon),
                label: Text(label),
              ),
        AdaptiveButtonVariant.tinted => FilledButton.tonal(
            onPressed: onPressed,
            style: FilledButton.styleFrom(minimumSize: minSize),
            child: child ?? Text(label),
          ),
        AdaptiveButtonVariant.plain => TextButton(
            onPressed: onPressed,
            child: child ?? Text(label),
          ),
      };
    }
    final sized = expand ? SizedBox(width: double.infinity, child: button) : button;
    // iOS CNButton animates natively; add a Material press-squish on Android.
    return PlatformAdaptive.useCupertino ? sized : PressScale(child: sized);
  }
}

/// Always a Material `Icon` — `CNIcon` has no Android fallback. [sfSymbol] is
/// reserved for a future native-icon path and currently ignored.
class AdaptiveIcon extends StatelessWidget {
  const AdaptiveIcon({required this.icon, this.sfSymbol, this.size, this.color, super.key});

  final IconData icon;
  final String? sfSymbol;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Icon(icon, size: size, color: color);
}

/// One destination in an [AdaptiveTabBar].
class AdaptiveTabItem {
  const AdaptiveTabItem({
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.sfSymbol,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;

  /// SF Symbol name used for the native iOS tab bar (optional).
  final String? sfSymbol;
}

/// Native `CNTabBar` on iOS, Material `NavigationBar` on Android.
class AdaptiveTabBar extends StatelessWidget {
  const AdaptiveTabBar({
    required this.items,
    required this.currentIndex,
    required this.onChanged,
    this.tint = AppColors.accent,
    super.key,
  });

  final List<AdaptiveTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    if (PlatformAdaptive.useCupertino) {
      return CNTabBar(
        currentIndex: currentIndex,
        onTap: onChanged,
        tint: tint,
        items: [
          for (final item in items)
            CNTabBarItem(
              label: item.label,
              icon: item.sfSymbol != null ? CNSymbol(item.sfSymbol!) : null,
            ),
        ],
      );
    }
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onChanged,
      backgroundColor: Colors.transparent,
      destinations: [
        for (final item in items)
          NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon ?? item.icon),
            label: item.label,
          ),
      ],
    );
  }
}
