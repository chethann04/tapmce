/// Exceptions thrown by the Data Layer (e.g., Supabase, Network).
/// These should be caught and mapped to Failures before reaching the UI.
sealed class AppException implements Exception {
  final String message;
  final String? code;
  const AppException(this.message, {this.code});

  @override
  String toString() => '$runtimeType: $message (Code: $code)';
}

class ServerException extends AppException {
  const ServerException(super.message, {super.code});
}

class NetworkException extends AppException {
  const NetworkException(super.message) : super(code: 'NETWORK_ERROR');
}

class AuthException extends AppException {
  const AuthException(super.message, {super.code});
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'Session expired or invalid']) : super(code: 'UNAUTHORIZED');
}

class CacheException extends AppException {
  const CacheException(super.message) : super(code: 'CACHE_ERROR');
}