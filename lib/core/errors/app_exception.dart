/// Base abstract class for all application exceptions
abstract class AppException implements Exception {
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const AppException(this.message, [this.originalError, this.stackTrace]);

  @override
  String toString() => message;
}

/// Thrown when an error occurs during SQLite/Drift database operations
class DatabaseException extends AppException {
  const DatabaseException(
    super.message, [
    super.originalError,
    super.stackTrace,
  ]);
}

/// Thrown when entity validation fails (e.g., empty title, invalid date range)
class ValidationException extends AppException {
  const ValidationException(
    super.message, [
    super.originalError,
    super.stackTrace,
  ]);
}

/// Thrown when an entity (task, subtask, category) cannot be found by ID
class NotFoundException extends AppException {
  const NotFoundException(
    super.message, [
    super.originalError,
    super.stackTrace,
  ]);
}

/// Thrown when JSON import, export, or file operations fail
class StorageException extends AppException {
  const StorageException(
    super.message, [
    super.originalError,
    super.stackTrace,
  ]);
}

/// Thrown when trying to edit or delete a completed task after its 4-hour
/// grace period has expired.
class TaskLockedException extends AppException {
  const TaskLockedException([
    super.message = 'La tarea se completó hace más de 4 horas y ya no puede editarse ni eliminarse.',
    super.originalError,
    super.stackTrace,
  ]);
}
