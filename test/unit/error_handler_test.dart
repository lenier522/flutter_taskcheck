import 'package:flutter_test/flutter_test.dart';
import 'package:task_check/core/errors/app_exception.dart';
import 'package:task_check/core/errors/error_handler.dart';

void main() {
  group('ErrorHandler and AppException Tests', () {
    test('AppException subclasses preserve message and string formatting', () {
      const dbEx = DatabaseException('Error de base de datos');
      expect(dbEx.message, 'Error de base de datos');
      expect(dbEx.toString(), 'Error de base de datos');

      const valEx = ValidationException('Título no puede estar vacío');
      expect(valEx.message, 'Título no puede estar vacío');

      const notFoundEx = NotFoundException('Tarea no encontrada');
      expect(notFoundEx.message, 'Tarea no encontrada');

      const storageEx = StorageException('Error al exportar archivo');
      expect(storageEx.message, 'Error al exportar archivo');
    });

    test('ErrorHandler returns user-friendly string from exceptions', () {
      expect(
        ErrorHandler.getErrorMessage(const DatabaseException('Fallo SQLite')),
        'Fallo SQLite',
      );
      expect(
        ErrorHandler.getErrorMessage('Mensaje directo'),
        'Mensaje directo',
      );
      expect(
        ErrorHandler.getErrorMessage(Exception('Genérico'))
            .contains('Ocurrió un error inesperado'),
        isTrue,
      );
    });
  });
}
