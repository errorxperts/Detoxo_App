import 'package:equatable/equatable.dart';

/// Base type for recoverable, user-facing error states.
///
/// Repositories convert thrown [AppException]s (see `exceptions.dart`) into
/// [Failure]s so the domain/presentation layers never depend on data-layer
/// implementation details.
sealed class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection.']);
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Something went wrong on the server.']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Could not read local data.']);
}

class PlatformFailure extends Failure {
  const PlatformFailure([super.message = 'A device operation failed.']);
}

class PermissionFailure extends Failure {
  const PermissionFailure([super.message = 'A required permission is missing.']);
}

class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'Invalid input.']);
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'An unexpected error occurred.']);
}
