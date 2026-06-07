/// Data-layer exceptions. Thrown by datasources, caught by repositories and
/// mapped to `Failure`s.
class ServerException implements Exception {
  ServerException([this.message = 'Server error']);
  final String message;
  @override
  String toString() => 'ServerException: $message';
}

class NetworkException implements Exception {
  NetworkException([this.message = 'Network error']);
  final String message;
  @override
  String toString() => 'NetworkException: $message';
}

class CacheException implements Exception {
  CacheException([this.message = 'Cache error']);
  final String message;
  @override
  String toString() => 'CacheException: $message';
}

class PlatformChannelException implements Exception {
  PlatformChannelException([this.message = 'Platform channel error']);
  final String message;
  @override
  String toString() => 'PlatformChannelException: $message';
}
