import 'package:flutter_test/flutter_test.dart';
import 'package:task_check/core/config/app_env.dart';

void main() {
  group('AppEnv.parse', () {
    test('lee clave y modelo ignorando comentarios y líneas vacías', () {
      final values = AppEnv.parse('''
# Comentario
GEMINI_API_KEY=abc123

GEMINI_MODEL=gemini-2.0-flash
''');

      expect(values['GEMINI_API_KEY'], 'abc123');
      expect(values['GEMINI_MODEL'], 'gemini-2.0-flash');
    });

    test('acepta comillas y el prefijo export', () {
      final values = AppEnv.parse('''
export GEMINI_API_KEY="clave-con-espacios finales  "
GEMINI_MODEL='gemini-2.5-flash-lite'
''');

      expect(values['GEMINI_API_KEY'], 'clave-con-espacios finales  ');
      expect(values['GEMINI_MODEL'], 'gemini-2.5-flash-lite');
    });

    test('mantiene valores vacíos y descarta líneas inválidas', () {
      final values = AppEnv.parse('GEMINI_API_KEY=\nesto no es valido\n');

      expect(values.containsKey('GEMINI_API_KEY'), isTrue);
      expect(values['GEMINI_API_KEY'], '');
      expect(values.length, 1);
    });
  });

  test('sin clave configurada la app reporta que no la tiene', () {
    AppEnv.overrideForTesting(apiKey: '   ');

    expect(AppEnv.hasGeminiApiKey, isFalse);
    expect(AppEnv.geminiModel, AppEnv.defaultModel);
  });

  test('overrideForTesting permite fijar la clave y el modelo', () {
    AppEnv.overrideForTesting(apiKey: 'clave', model: 'gemini-2.5-pro');

    expect(AppEnv.hasGeminiApiKey, isTrue);
    expect(AppEnv.geminiApiKey, 'clave');
    expect(AppEnv.geminiModel, 'gemini-2.5-pro');
  });

  test('las rutas de búsqueda incluyen el directorio del proyecto', () {
    final paths = AppEnv.candidatePaths();

    expect(paths, isNotEmpty);
    expect(paths.any((path) => path.endsWith('.env')), isTrue);
  });
}
