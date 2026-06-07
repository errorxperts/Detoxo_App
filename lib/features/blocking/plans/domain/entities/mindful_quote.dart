import 'package:equatable/equatable.dart';

/// A motivational quote shown on the mindful countdown.
class MindfulQuote extends Equatable {
  const MindfulQuote(this.text);
  final String text;
  @override
  List<Object?> get props => [text];
}
