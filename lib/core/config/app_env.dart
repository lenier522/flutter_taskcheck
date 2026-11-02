import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Configuración sensible de la aplicación leída desde un archivo `.env`.
///
/// El archivo está excluido de Git (`.gitignore`), de modo que la clave de la
/// API de Gemini nunca se publica en GitHub. Se busca en varias ubicaciones
/// para que funcione igual con `flutter run`, con el bundle generado por
/// `flutter build` y con el paquete `.deb` instalado en `/opt/taskcheck`.
class AppEnv {
  AppEnv._();

  static const String defaultModel = 'gemini-2.5-flash-lite';
  static const String apiKeyVariable = 'GEMINI_API_KEY';
  static const String modelVariable = 'GEMINI_MODEL';

  static String? _apiKey;
  static String _model = defaultModel;
  static String? _sourcePath;
  static List<String> _searchedPaths = const [];

  /// Clave de la API de Gemini (`null` si no está configurada).
  static String? get geminiApiKey => _apiKey;

  static bool get hasGeminiApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  static String get geminiModel => _model;

  /// Ruta del archivo `.env` que se usó, o `null` si no se encontró ninguno.
  static String? get sourcePath => _sourcePath;

  /// Rutas consultadas, en el mismo orden en que se leen.
  static List<String> get searchedPaths => _searchedPaths;

  /// Ubicaciones donde se busca el archivo `.env`, en orden de prioridad.
  static List<String> candidatePaths() {
    final paths = <String>[];

    void add(String? path) {
      if (path == null || path.isEmpty) return;
      final normalized = p.canonicalize(path);
      if (!paths.contains(normalized)) paths.add(normalized);
    }

    final env = Platform.environment;
    final home = env['HOME'];
    final xdgConfig = env['XDG_CONFIG_HOME'];
    final configDir = (xdgConfig != null && xdgConfig.isNotEmpty)
        ? xdgConfig
        : (home != null && home.isNotEmpty ? p.join(home, '.config') : null);

    // Ejecución desde el proyecto (flutter run / flutter test).
    add(p.join(Directory.current.path, '.env'));

    // Junto al ejecutable: bundle de `flutter build` y /opt/taskcheck.
    try {
      final executableDir = p.dirname(Platform.resolvedExecutable);
      add(p.join(executableDir, '.env'));
      add(p.join(executableDir, '..', '..', '.env'));
      add(p.join(executableDir, '..', '..', '..', '.env'));
    } catch (error) {
      debugPrint('No se pudo resolver la ruta del ejecutable: $error');
    }

    // Rutas escribibles por el usuario, útiles cuando la app está instalada
    // como paquete del sistema.
    if (configDir != null) add(p.join(configDir, 'task_check', '.env'));
    if (home != null && home.isNotEmpty) {
      add(p.join(home, '.local', 'share', 'task_check', '.env'));
    }

    return paths;
  }

  /// Lee el primer `.env` disponible y refresca la configuración en memoria.
  ///
  /// Las variables de entorno del sistema tienen prioridad sobre el archivo.
  /// Nunca lanza excepciones: una aplicación sin clave debe abrir normalmente.
  static Future<void> load() async {
    final values = <String, String>{};
    _searchedPaths = candidatePaths();

    String? source;
    for (final path in _searchedPaths) {
      final parsed = await _readFile(path);
      if (parsed == null || parsed.isEmpty) continue;
      values.addAll(parsed);
      source = path;
      break;
    }

    final env = Platform.environment;
    for (final key in const [apiKeyVariable, modelVariable]) {
      final value = env[key];
      if (value != null && value.trim().isNotEmpty) {
        values[key] = value;
      }
    }

    final apiKey = _clean(values[apiKeyVariable]);
    final model = _clean(values[modelVariable]);

    _apiKey = apiKey;
    _model = model ?? defaultModel;
    _sourcePath = source;
  }

  /// Parser del formato `.env`: `CLAVE=valor`, líneas vacías y comentarios
  /// con `#` se ignoran; se aceptan comillas y el prefijo `export`.
  static Map<String, String> parse(String contents) {
    final values = <String, String>{};
    for (final rawLine in contents.split('\n')) {
      var line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (line.startsWith('export ')) line = line.substring(7).trim();

      final separator = line.indexOf('=');
      if (separator <= 0) continue;

      final key = line.substring(0, separator).trim();
      var value = line.substring(separator + 1).trim();
      if (value.length >= 2) {
        final startsDouble = value.startsWith('"') && value.endsWith('"');
        final startsSingle = value.startsWith("'") && value.endsWith("'");
        if (startsDouble || startsSingle) {
          value = value.substring(1, value.length - 1);
        }
      }
      if (key.isEmpty) continue;
      values[key] = value;
    }
    return values;
  }

  static Future<Map<String, String>?> _readFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      return parse(await file.readAsString());
    } catch (error) {
      debugPrint('No se pudo leer $path: $error');
      return null;
    }
  }

  static String? _clean(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Solo para pruebas: fija los valores sin tocar el disco.
  @visibleForTesting
  static void overrideForTesting({String? apiKey, String? model}) {
    _apiKey = _clean(apiKey);
    _model = _clean(model) ?? defaultModel;
    _sourcePath = null;
    _searchedPaths = const [];
  }
}
