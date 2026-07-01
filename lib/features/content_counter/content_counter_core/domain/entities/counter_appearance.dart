import 'package:detoxo/features/content_counter/content_counter_bubble/domain/entities/bubble_style.dart';
import 'package:detoxo/features/content_counter/home_content_counter/domain/entities/widget_style.dart';
import 'package:equatable/equatable.dart';

/// The combined appearance of both counter surfaces (bubble + home widget).
///
/// This is an in-memory carrier for `CounterAppearanceCubit` and a one-shot
/// snapshot from the repository; it has no wire form of its own — each surface
/// is persisted/pushed independently via [BubbleStyle.toWire] / [WidgetStyle.toWire].
class CounterAppearance extends Equatable {
  const CounterAppearance({required this.bubble, required this.widget});

  const CounterAppearance.defaults()
    : bubble = const BubbleStyle.defaults(),
      widget = const WidgetStyle.defaults();

  final BubbleStyle bubble;
  final WidgetStyle widget;

  CounterAppearance copyWith({BubbleStyle? bubble, WidgetStyle? widget}) {
    return CounterAppearance(
      bubble: bubble ?? this.bubble,
      widget: widget ?? this.widget,
    );
  }

  @override
  List<Object?> get props => [bubble, widget];
}
