import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:task_check/core/config/app_env.dart';

/// Error de comunicación con la IA, con un mensaje listo para mostrar.
class AiException implements Exception {
  const AiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Una función que el modelo pidió ejecutar.
class GeminiFunctionCall {
  const GeminiFunctionCall({required this.name, required this.args});

  final String name;
  final Map<String, dynamic> args;
}

/// Respuesta de una llamada a Gemini: texto y/o funciones a ejecutar.
class GeminiResponse {
  const GeminiResponse({this.text = '', this.calls = const []});

  final String text;
  final List<GeminiFunctionCall> calls;

  bool get hasCalls => calls.isNotEmpty;
}

/// Cliente mínimo de la API REST de Gemini (`generateContent`).
class GeminiClient {
  GeminiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  final http.Client _http;

  Future<GeminiResponse> generate({
    required String systemInstruction,
    required List<Map<String, dynamic>> contents,
    List<Map<String, dynamic>> tools = const [],
    double temperature = 0.4,
  }) async {
    // Se leen de [AppEnv] en cada llamada: recargar el `.env` surte efecto sin
    // reiniciar la aplicación.
    final apiKey = AppEnv.geminiApiKey;
    if (apiKey == null || apiKey.isEmpty) {
      throw const AiException(
        'Falta la clave de Gemini. Agrega GEMINI_API_KEY a tu archivo .env.',
      );
    }
    final model = AppEnv.geminiModel;
    final uri = Uri.parse('$_baseUrl/$model:generateContent');

    final body = <String, dynamic>{
      'systemInstruction': {
        'parts': [
          {'text': systemInstruction},
        ],
      },
      'contents': contents,
      if (tools.isNotEmpty)
        'tools': [
          {'functionDeclarations': tools},
        ],
      'generationConfig': {'temperature': temperature, 'maxOutputTokens': 4096},
    };

    http.Response response;
    try {
      response = await _http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 90));
    } on TimeoutException {
      throw const AiException(
        'La IA tardó demasiado en responder. Inténtalo de nuevo.',
      );
    } catch (error) {
      throw AiException(
        'No se pudo conectar con Gemini. Revisa tu conexión a internet.\n$error',
      );
    }

    if (response.statusCode != 200) {
      throw AiException(_errorMessage(response.statusCode, response.body));
    }

    return _parse(response.body);
  }

  GeminiResponse _parse(String rawBody) {
    dynamic decoded;
    try {
      decoded = jsonDecode(rawBody);
    } catch (_) {
      throw const AiException('Gemini devolvió una respuesta ilegible.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const AiException('Gemini devolvió una respuesta inesperada.');
    }

    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      final feedback = decoded['promptFeedback'];
      final reason = feedback is Map ? feedback['blockReason'] : null;
      throw AiException(
        reason == null
            ? 'La IA no devolvió ninguna respuesta.'
            : 'La IA bloqueó la solicitud ($reason). Reformula tu mensaje.',
      );
    }

    final candidate = candidates.first;
    final content = candidate is Map ? candidate['content'] : null;
    final parts = content is Map ? content['parts'] : null;

    final buffer = StringBuffer();
    final calls = <GeminiFunctionCall>[];

    if (parts is List) {
      for (final part in parts) {
        if (part is! Map) continue;
        final text = part['text'];
        if (text is String && text.isNotEmpty) buffer.write(text);

        final call = part['functionCall'];
        if (call is Map) {
          final name = call['name'];
          if (name is! String || name.isEmpty) continue;
          final rawArgs = call['args'];
          calls.add(
            GeminiFunctionCall(
              name: name,
              args: rawArgs is Map<String, dynamic>
                  ? rawArgs
                  : rawArgs is Map
                  ? rawArgs.map((key, value) => MapEntry('$key', value))
                  : <String, dynamic>{},
            ),
          );
        }
      }
    }

    return GeminiResponse(text: buffer.toString(), calls: calls);
  }

  String _errorMessage(int statusCode, String body) {
    String? detail;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map && error['message'] is String) {
          detail = error['message'] as String;
        }
      }
    } catch (_) {
      // El cuerpo puede no ser JSON; se ignora.
    }
    final suffix = detail == null ? '' : '\n$detail';

    switch (statusCode) {
      case 400:
        return 'Gemini rechazó la solicitud. Revisa la clave y el modelo '
            'configurado.$suffix';
      case 401:
      case 403:
        return 'La clave GEMINI_API_KEY no es válida o no tiene permisos para '
            'este modelo.$suffix';
      case 404:
        return 'El modelo "${AppEnv.geminiModel}" no está disponible para tu '
            'clave. Prueba otro en GEMINI_MODEL.$suffix';
      case 429:
        return 'Alcanzaste el límite gratuito de Gemini. Espera un momento y '
            'vuelve a intentarlo.$suffix';
      default:
        if (statusCode >= 500) {
          return 'Los servidores de Gemini no respondieron correctamente. '
              'Inténtalo de nuevo.$suffix';
        }
        return 'Gemini devolvió un error inesperado ($statusCode).$suffix';
    }
  }
}
