import 'dart:typed_data';

import 'package:detoxo/features/additional_feature/app_feedback/app_feedback.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Lifecycle of a "Share an idea" submission.
enum ShareStatus { editing, submitting, success, error }

class ShareIdeasState extends Equatable {
  const ShareIdeasState({
    this.message = '',
    this.status = ShareStatus.editing,
    this.error,
  });

  final String message;
  final ShareStatus status;
  final String? error;

  /// The Send button is enabled only with non-blank text and no send in flight.
  bool get canSubmit =>
      message.trim().isNotEmpty && status != ShareStatus.submitting;

  @override
  List<Object?> get props => [message, status, error];
}

/// Sends a user's idea as a "Suggestion" through the shared [FeedbackRepository],
/// which opens the device email composer prefilled to support. No screenshot is
/// attached (an empty [Uint8List] is tolerated by the email repository).
class ShareIdeasCubit extends Cubit<ShareIdeasState> {
  ShareIdeasCubit(this._repo) : super(const ShareIdeasState());

  final FeedbackRepository _repo;

  /// Edits reset status to `editing` (clearing any prior error).
  void setMessage(String value) => emit(ShareIdeasState(message: value));

  Future<void> submit() async {
    if (!state.canSubmit) return;
    final message = state.message;
    emit(ShareIdeasState(message: message, status: ShareStatus.submitting));
    try {
      await _repo.send(
        FeedbackReport(
          message: message.trim(),
          category: FeedbackCategory.suggestion,
          rating: 0,
          screenshot: Uint8List(0),
        ),
      );
      emit(ShareIdeasState(message: message, status: ShareStatus.success));
    } catch (e) {
      emit(
        ShareIdeasState(
          message: message,
          status: ShareStatus.error,
          error: e.toString(),
        ),
      );
    }
  }
}
