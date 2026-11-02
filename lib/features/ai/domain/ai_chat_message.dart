/// Autor de un mensaje del chat.
enum AiChatRole { user, assistant }

/// Mensaje visible en la conversación con el asistente.
class AiChatMessage {
  const AiChatMessage({
    required this.role,
    required this.text,
    required this.createdAt,
    this.isError = false,
  });

  final AiChatRole role;
  final String text;
  final DateTime createdAt;
  final bool isError;

  bool get isUser => role == AiChatRole.user;

  factory AiChatMessage.user(String text) => AiChatMessage(
    role: AiChatRole.user,
    text: text,
    createdAt: DateTime.now(),
  );

  factory AiChatMessage.assistant(String text, {bool isError = false}) =>
      AiChatMessage(
        role: AiChatRole.assistant,
        text: text,
        createdAt: DateTime.now(),
        isError: isError,
      );
}
