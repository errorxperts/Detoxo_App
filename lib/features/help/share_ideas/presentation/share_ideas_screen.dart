import 'package:detoxo/core/constants/app_constants.dart';
import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/features/additional_feature/app_feedback/app_feedback.dart';
import 'package:detoxo/features/help/share_ideas/presentation/share_ideas_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Short starter phrases offered as tappable chips to help the user begin.
const _kIdeaPrompts = <({String label, String starter})>[
  (label: 'A new feature', starter: 'I wish Detoxo could '),
  (label: 'Better blocking', starter: 'Blocking would be better if '),
  (label: 'Reel counter', starter: 'For the reel counter, '),
  (label: 'Bubble or widget', starter: 'For the bubble / home widget, '),
];

/// An interactive, message-only suggestion form. Submitting opens the device
/// email composer prefilled to support (as a "Suggestion"); the user just hits
/// send.
class ShareIdeasScreen extends StatelessWidget {
  const ShareIdeasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ShareIdeasCubit(sl<FeedbackRepository>()),
      child: const _ShareIdeasView(),
    );
  }
}

class _ShareIdeasView extends StatefulWidget {
  const _ShareIdeasView();

  @override
  State<_ShareIdeasView> createState() => _ShareIdeasViewState();
}

class _ShareIdeasViewState extends State<_ShareIdeasView> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onState(BuildContext context, ShareIdeasState state) {
    switch (state.status) {
      case ShareStatus.success:
        GlassToast.show(
          context,
          'Your idea is on its way. Thank you.',
          tone: AppTone.success,
        );
        context.pop();
      case ShareStatus.error:
        GlassToast.show(
          context,
          "Couldn't open an email app. Reach us at ${AppSupport.supportEmail}",
          tone: AppTone.danger,
        );
      case ShareStatus.editing:
      case ShareStatus.submitting:
        break;
    }
  }

  /// Prefills (or appends) a starter phrase, moves the caret to the end and
  /// focuses the field so the user can keep typing.
  void _applyPrompt(String starter) {
    final current = _controller.text.trimRight();
    final next = current.isEmpty ? starter : '$current\n$starter';
    _controller
      ..text = next
      ..selection = TextSelection.collapsed(offset: next.length);
    context.read<ShareIdeasCubit>().setMessage(next);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GlassScaffold(
      appBar: const GlassAppBar(title: Text('Share an idea')),
      body: BlocConsumer<ShareIdeasCubit, ShareIdeasState>(
        listenWhen: (prev, curr) => prev.status != curr.status,
        listener: _onState,
        builder: (context, state) {
          final cubit = context.read<ShareIdeasCubit>();
          final sending = state.status == ShareStatus.submitting;
          final body = AppTypography.body.copyWith(color: t.ink);
          final note = AppTypography.subhead.copyWith(color: t.ink2);
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.xs,
              AppSpacing.gutter,
              AppSpacing.xxl,
            ),
            children: [
              Text(
                'Tell us what would make Detoxo better. It goes straight to '
                'the team.',
                style: note,
              ),

              // ── The idea field + live counter, one panel ────────────────
              const SectionHeader('Your idea'),
              ListenableBuilder(
                listenable: _focus,
                builder: (context, panel) => FocusRing(
                  visible: _focus.hasFocus,
                  radius: BorderRadius.circular(AppRadius.row),
                  child: panel!,
                ),
                child: GlassContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _controller,
                        focusNode: _focus,
                        onChanged: cubit.setMessage,
                        minLines: 5,
                        maxLines: null,
                        textInputAction: TextInputAction.newline,
                        keyboardType: TextInputType.multiline,
                        style: body,
                        decoration: InputDecoration.collapsed(
                          hintText: 'What would make Detoxo better?',
                          hintStyle: body.copyWith(color: t.ink2),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          state.message.trim().isEmpty
                              ? 'Every idea helps'
                              : '${state.message.trim().length} characters',
                          style: note,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Starter phrases: one-shot chips ─────────────────────────
              const SectionHeader('Need a nudge?'),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final prompt in _kIdeaPrompts)
                    AppChip(
                      label: prompt.label,
                      selected: false,
                      momentary: true,
                      icon: Icons.add,
                      onSelected: () => _applyPrompt(prompt.starter),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.section),

              // ── Send ─────────────────────────────────────────────────────
              PrimaryButton(
                label: sending ? 'Sending…' : 'Send idea',
                icon: Icons.send_rounded,
                expand: true,
                onPressed: state.canSubmit ? cubit.submit : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Opens your email app, addressed to ${AppSupport.supportEmail}.',
                textAlign: TextAlign.center,
                style: note,
              ),
            ],
          );
        },
      ),
    );
  }
}
