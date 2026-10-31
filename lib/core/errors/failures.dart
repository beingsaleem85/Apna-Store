import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Base class for all application failures.
abstract class Failure implements Exception {
  final String message;
  final String? code;
  final dynamic originalException;
  final StackTrace? stackTrace;
  final bool isRetryable;

  const Failure({
    required this.message,
    this.code,
    this.originalException,
    this.stackTrace,
    this.isRetryable = false,
  });

  @override
  String toString() => '$runtimeType: $message${code != null ? " (Code: $code)" : ""}';
}

/// Authentication failures (e.g. invalid credentials, session expired).
class AuthenticationFailure extends Failure {
  const AuthenticationFailure({
    required super.message,
    super.code,
    super.originalException,
    super.stackTrace,
    super.isRetryable = false,
  });
}

/// Authorization failures (e.g. insufficient role privileges).
class AuthorizationFailure extends Failure {
  const AuthorizationFailure({
    required super.message,
    super.code,
    super.originalException,
    super.stackTrace,
    super.isRetryable = false,
  });
}

/// Validation failures (e.g. invalid input format, missing required field).
class ValidationFailure extends Failure {
  const ValidationFailure({
    required super.message,
    super.code,
    super.originalException,
    super.stackTrace,
    super.isRetryable = false,
  });
}

/// Network failures (e.g. device offline, request timeout).
class NetworkFailure extends Failure {
  const NetworkFailure({
    required super.message,
    super.code,
    super.originalException,
    super.stackTrace,
    super.isRetryable = true,
  });
}

/// Database failures (e.g. PostgREST query errors, schema violations).
class DatabaseFailure extends Failure {
  const DatabaseFailure({
    required super.message,
    super.code,
    super.originalException,
    super.stackTrace,
    super.isRetryable = false,
  });
}

/// Payment failures.
class PaymentFailure extends Failure {
  const PaymentFailure({
    required super.message,
    super.code,
    super.originalException,
    super.stackTrace,
    super.isRetryable = false,
  });
}

/// Configuration failures.
class ConfigurationFailure extends Failure {
  const ConfigurationFailure({
    required super.message,
    super.code,
    super.originalException,
    super.stackTrace,
    super.isRetryable = false,
  });
}

/// Resource not found failures.
class NotFoundFailure extends Failure {
  const NotFoundFailure({
    required super.message,
    super.code,
    super.originalException,
    super.stackTrace,
    super.isRetryable = false,
  });
}

/// Conflict / duplicate entry failures.
class ConflictFailure extends Failure {
  const ConflictFailure({
    required super.message,
    super.code,
    super.originalException,
    super.stackTrace,
    super.isRetryable = false,
  });
}

/// Catch-all unknown failures.
class UnknownFailure extends Failure {
  const UnknownFailure({
    required super.message,
    super.code,
    super.originalException,
    super.stackTrace,
    super.isRetryable = false,
  });
}

/// Exception mapper utility to convert exceptions into typed Failures securely.
class FailureMapper {
  FailureMapper._();

  static Failure mapException(dynamic exception, [StackTrace? stackTrace]) {
    if (exception is Failure) {
      return exception;
    }

    if (exception is AuthException) {
      return AuthenticationFailure(
        message: exception.message,
        code: exception.statusCode,
        originalException: exception,
        stackTrace: stackTrace,
      );
    }

    if (exception is PostgrestException) {
      return DatabaseFailure(
        message: exception.message,
        code: exception.code,
        originalException: exception,
        stackTrace: stackTrace,
      );
    }

    final String errStr = exception.toString().toLowerCase();
    if (errStr.contains('socketexception') || errStr.contains('connection failed') || errStr.contains('timeout')) {
      return NetworkFailure(
        message: 'Network connection error. Please check your connection and retry.',
        originalException: exception,
        stackTrace: stackTrace,
      );
    }

    if (errStr.contains('format-exception') || errStr.contains('typeerror') || errStr.contains('typecast')) {
      return ValidationFailure(
        message: 'Data parsing or type validation error.',
        originalException: exception,
        stackTrace: stackTrace,
      );
    }

    if (kDebugMode) {
      debugPrint('Unmapped exception encountered: $exception');
    }

    return UnknownFailure(
      message: 'An unexpected error occurred. Please try again.',
      originalException: exception,
      stackTrace: stackTrace,
    );
  }
}
