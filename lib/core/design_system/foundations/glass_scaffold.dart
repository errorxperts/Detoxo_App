import 'package:detoxo/core/design_system/components/buttons.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:detoxo/core/design_system/tokens/app_tokens.dart';
import 'package:flutter/material.dart';

/// The one Frozen Glass ground behind every screen: the vertical `bgTop` →
/// `bgBottom` gradient of the current theme. Static and cheap: one paint, no
/// blur, nothing that moves.
class _Ground extends StatelessWidget {
  const _Ground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.bgTop, t.bgBottom],
        ),
      ),
      child: child,
    );
  }
}

/// Standard screen chrome: a transparent [Scaffold] over the Frozen Glass
/// ground gradient. Every screen returns this instead of a raw Scaffold.
class GlassScaffold extends StatelessWidget {
  const GlassScaffold({
    required this.body,
    this.appBar,
    this.bottomBar,
    this.floatingActionButton,
    this.endDrawer,
    this.scaffoldKey,
    this.drawerScrimColor,
    this.endDrawerEnableOpenDragGesture = true,
    this.extendBody = true,
    this.safeArea = true,
    super.key,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomBar;
  final Widget? floatingActionButton;

  /// An optional right-side ([endDrawer]) panel. Pass [scaffoldKey] so callers
  /// can open it via `scaffoldKey.currentState?.openEndDrawer()`.
  final Widget? endDrawer;
  final Key? scaffoldKey;
  final Color? drawerScrimColor;
  final bool endDrawerEnableOpenDragGesture;

  final bool extendBody;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final hasAppBar = appBar != null;
    // The app bar already clears the status bar, so only inset the top when
    // there's no app bar; the bottom bar handles its own bottom inset.
    final content = safeArea
        ? SafeArea(top: !hasAppBar, bottom: bottomBar == null, child: body)
        : body;
    return _Ground(
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.transparent,
        extendBody: extendBody,
        // extendBodyBehindAppBar stays at its default (false) so the body sits
        // below the frosted app bar instead of being hidden behind it.
        appBar: appBar,
        bottomNavigationBar: bottomBar,
        floatingActionButton: floatingActionButton,
        endDrawer: endDrawer,
        drawerScrimColor: drawerScrimColor,
        endDrawerEnableOpenDragGesture: endDrawerEnableOpenDragGesture,
        body: content,
      ),
    );
  }
}

/// The plain Frozen Glass header: no bar surface, the title in the `title`
/// style, and on a pushed screen a [GlassIconButton] back action. Its static
/// [globalActionsBuilder] appends app-wide actions (the feedback button) after
/// the screen's own [actions].
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({
    this.title,
    this.actions,
    this.leading,
    this.globalActions = true,
    super.key,
  });

  /// Toolbar height: a 44 px glass button with 10 px above and below.
  static const double height = 64;

  final Widget? title;
  final List<Widget>? actions;

  /// Replaces the automatic back button.
  final Widget? leading;

  /// Whether to append the app-wide [globalActionsBuilder] actions (the global
  /// feedback button). Set `false` on screens that provide their own copy of a
  /// global action — e.g. the feature tutorial, which supplies a *keyed*
  /// feedback button so its coach-mark can spotlight it without a duplicate.
  final bool globalActions;

  /// App-wide trailing actions appended to *every* [GlassAppBar] after the
  /// screen's own [actions] (e.g. the global feedback button). Registered once
  /// at startup via a builder so the design system stays decoupled from feature
  /// code — the design system just invokes it; the feature decides what to show.
  static List<Widget> Function(BuildContext context)? globalActionsBuilder;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final globals = globalActions
        ? (globalActionsBuilder?.call(context) ?? const <Widget>[])
        : const <Widget>[];
    // The 48 dp hit box holds the 44 px circle 2 px in: a gutter of 18 puts
    // the visible edge on the 20 px screen gutter.
    const edge = AppSpacing.gutter - 2;
    final back = ModalRoute.of(context)?.impliesAppBarDismissal ?? false
        ? GlassIconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            semanticLabel: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => Navigator.maybePop(context),
          )
        : null;
    final lead = leading ?? back;
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: height,
      automaticallyImplyLeading: false,
      leadingWidth: lead == null ? null : edge + AppSizes.minTapTarget,
      leading: lead == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(left: edge),
              child: Center(child: lead),
            ),
      titleSpacing: lead == null ? AppSpacing.gutter : AppSpacing.sm,
      title: title,
      actions: [
        ...?actions,
        ...globals,
        const SizedBox(width: edge),
      ],
    );
  }
}
