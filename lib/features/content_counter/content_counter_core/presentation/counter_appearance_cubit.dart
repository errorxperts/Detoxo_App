import 'dart:async';

import 'package:detoxo/features/content_counter/content_counter_bubble/domain/entities/bubble_style.dart';
import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_appearance.dart';
import 'package:detoxo/features/content_counter/content_counter_core/domain/repositories/counter_appearance_repository.dart';
import 'package:detoxo/features/content_counter/home_content_counter/domain/entities/widget_style.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Owns the live-edited counter appearance. Each setter emits immediately (so
/// the on-screen preview tracks the control with no lag) but debounces the
/// native push, so dragging a slider doesn't flood the command channel — only
/// the settled value is persisted / live-rendered on the real bubble & widget.
class CounterAppearanceCubit extends Cubit<CounterAppearance> {
  CounterAppearanceCubit(this._repo)
    : super(const CounterAppearance.defaults()) {
    unawaited(_load());
  }

  final CounterAppearanceRepository _repo;

  Timer? _bubbleDebounce;
  Timer? _widgetDebounce;

  static const Duration _debounce = Duration(milliseconds: 120);

  Future<void> _load() async {
    final loaded = await _repo.current();
    if (!isClosed) emit(loaded);
  }

  void setBubble(BubbleStyle style) {
    emit(state.copyWith(bubble: style));
    _bubbleDebounce?.cancel();
    _bubbleDebounce = Timer(_debounce, () {
      unawaited(_repo.setBubbleStyle(style));
    });
  }

  void setWidget(WidgetStyle style) {
    emit(state.copyWith(widget: style));
    _widgetDebounce?.cancel();
    _widgetDebounce = Timer(_debounce, () {
      unawaited(_repo.setWidgetStyle(style));
    });
  }

  @override
  Future<void> close() {
    _bubbleDebounce?.cancel();
    _widgetDebounce?.cancel();
    return super.close();
  }
}
