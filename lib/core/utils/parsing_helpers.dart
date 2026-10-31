import '../errors/failures.dart';

/// Safe numeric and DateTime parsing utilities for database and JSON contracts.
class ParsingHelpers {
  ParsingHelpers._();

  /// Safely converts dynamic numeric value (int, double, String, num, null) to double.
  static double parseDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) {
      final String trimmed = value.trim();
      if (trimmed.isEmpty) return defaultValue;
      final parsed = double.tryParse(trimmed);
      if (parsed != null) return parsed;
    }
    return defaultValue;
  }

  /// Safely converts dynamic numeric value (int, double, String, num, null) to int.
  static int parseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) {
      final String trimmed = value.trim();
      if (trimmed.isEmpty) return defaultValue;
      final parsed = int.tryParse(trimmed);
      if (parsed != null) return parsed;
      final parsedDouble = double.tryParse(trimmed);
      if (parsedDouble != null) return parsedDouble.toInt();
    }
    return defaultValue;
  }

  /// Safely converts dynamic timestamp value (String, DateTime, null) to DateTime.
  /// Throws [ValidationFailure] if required is true and value is invalid/null.
  static DateTime? parseDateTime(dynamic value, {bool required = false}) {
    if (value == null) {
      if (required) {
        throw const ValidationFailure(message: 'Required timestamp field is missing or null.');
      }
      return null;
    }
    if (value is DateTime) return value;
    if (value is String) {
      final String trimmed = value.trim();
      if (trimmed.isEmpty) {
        if (required) {
          throw const ValidationFailure(message: 'Required timestamp field is empty.');
        }
        return null;
      }
      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) return parsed;
    }

    if (required) {
      throw ValidationFailure(message: 'Invalid timestamp format: $value');
    }
    return null;
  }

  /// Safely formats DateTime to ISO-8601 string for database columns.
  static String? toIsoString(DateTime? dateTime) {
    return dateTime?.toUtc().toIso8601String();
  }
}
