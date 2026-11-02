import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:task_check/core/config/app_env.dart';
import 'package:task_check/features/ai/application/ai_chat_controller.dart';
import 'package:task_check/features/ai/domain/ai_chat_message.dart';

/// Chat con Gemini que puede consultar y modificar toda la base de datos.
class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  static const List<String> _suggestions = [
    '¿Qué debo hacer hoy?',
    'Resume mis tareas pendientes por prioridad',
    '¿Tengo tareas vencidas?',
    'Crea una tarea para revisar el informe mañana',
  ];

  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = preset ?? _input.text;
    if (text.trim().isEmpty) return;
    if (preset == null) _input.clear();

    await ref.read(aiChatControllerProvider.notifier).send(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(aiChatControllerProvider);
    final hasKey = AppEnv.hasGeminiApiKey;

    ref.listen(aiChatControllerProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          _header(theme, state),
          if (!hasKey) _missingKeyBanner(theme),
          const Divider(height: 1),
          Expanded(
            child: state.messages.isEmpty
                ? _emptyState(theme, hasKey)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(28, 18, 28, 8),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) =>
                        _MessageBubble(message: state.messages[index]),
                  ),
          ),
          if (state.isSending)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 4, 32, 0),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      state.activity ?? 'Pensando…',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _composer(theme, hasKey, state.isSending),
        ],
      ),
    );
  }

  Widget _header(ThemeData theme, AiChatState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 24, 16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: theme.colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Asistente IA',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Pregunta, crea o edita tus tareas conversando con Gemini',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              AppEnv.geminiModel,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: 'Limpiar conversación',
            child: IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: state.messages.isEmpty
                  ? null
                  : () => ref.read(aiChatControllerProvider.notifier).clear(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _missingKeyBanner(ThemeData theme) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(28, 0, 28, 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.key_off_rounded,
                size: 18,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 8),
              Text(
                'Falta la clave de Gemini',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega GEMINI_API_KEY=tu_clave en un archivo .env. Puedes crearlo '
            'en cualquiera de estas rutas:',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          for (final path in AppEnv.searchedPaths)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                path,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: theme.hintColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyState(ThemeData theme, bool hasKey) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 34,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '¿En qué te ayudo?',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Puedo leer y modificar tus tareas, subtareas y categorías.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final suggestion in _suggestions)
                  ActionChip(
                    label: Text(suggestion),
                    onPressed: hasKey ? () => _send(suggestion) : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer(ThemeData theme, bool hasKey, bool isSending) {
    final enabled = hasKey && !isSending;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 10, 28, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              enabled: enabled,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: hasKey
                    ? 'Escribe tu pregunta…'
                    : 'Configura tu clave de Gemini en el archivo .env',
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: enabled ? () => _send() : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size(52, 52),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final AiChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;

    final Color background;
    if (message.isError) {
      background = theme.colorScheme.errorContainer.withValues(alpha: 0.45);
    } else if (isUser) {
      background = theme.colorScheme.primary.withValues(alpha: 0.12);
    } else {
      background = theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.6,
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 760),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isUser
                      ? Icons.person_outline_rounded
                      : message.isError
                      ? Icons.error_outline_rounded
                      : Icons.auto_awesome_rounded,
                  size: 14,
                  color: message.isError
                      ? theme.colorScheme.error
                      : theme.hintColor,
                ),
                const SizedBox(width: 6),
                Text(
                  isUser ? 'Tú' : 'Asistente',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                    color: message.isError
                        ? theme.colorScheme.error
                        : theme.hintColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SelectableText(
              message.text,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
