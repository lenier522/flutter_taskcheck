import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:task_check/core/config/app_env.dart';
import 'package:task_check/core/errors/error_handler.dart';
import 'package:task_check/core/providers.dart';
import 'package:task_check/core/services/app_notification_service.dart';
import 'package:task_check/features/backup/data/backup_service.dart';
import 'package:task_check/features/desktop_widget/services/widget_autostart_service.dart';
import 'package:task_check/features/desktop_widget/services/widget_launcher.dart';
import 'package:task_check/features/settings/data/preferences_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final themeNotifier = ref.read(themeModeProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings_rounded,
                  size: 28,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Configuración',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Theme Section
            _buildSection(
              context,
              title: 'Apariencia',
              icon: Icons.palette_outlined,
              children: [
                _buildSettingCard(
                  context,
                  title: 'Tema de la aplicación',
                  subtitle: 'Selecciona el tema visual preferido',
                  trailing: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_rounded, size: 16),
                        label: Text('Claro'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_rounded, size: 16),
                        label: Text('Sistema'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_rounded, size: 16),
                        label: Text('Oscuro'),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (Set<ThemeMode> newMode) {
                      themeNotifier.setThemeMode(newMode.first);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Notifications Section
            _buildSection(
              context,
              title: 'Notificaciones',
              icon: Icons.notifications_active_outlined,
              children: const [_NotificationSettingsCard()],
            ),
            const SizedBox(height: 20),

            // AI Assistant Section
            _buildSection(
              context,
              title: 'Asistente IA',
              icon: Icons.auto_awesome_rounded,
              children: const [_AiSettingsCard()],
            ),
            const SizedBox(height: 20),

            // Floating widget Section
            _buildSection(
              context,
              title: 'Widget flotante',
              icon: Icons.picture_in_picture_alt_rounded,
              children: const [_WidgetAutostartCard()],
            ),
            const SizedBox(height: 20),

            // Keyboard Shortcuts Section
            _buildSection(
              context,
              title: 'Atajos de Teclado',
              icon: Icons.keyboard_outlined,
              children: [
                _buildShortcutCard(context, 'Ctrl+N', 'Crear nueva tarea'),
                _buildShortcutCard(context, 'Ctrl+F', 'Enfocar buscador'),
                _buildShortcutCard(context, 'Ctrl+,', 'Abrir Configuración'),
                _buildShortcutCard(context, 'Ctrl+Enter', 'Guardar formulario'),
                _buildShortcutCard(context, 'Esc', 'Cerrar diálogo activo'),
                _buildShortcutCard(
                  context,
                  'Delete',
                  'Eliminar (con confirmación)',
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Backup Section
            _buildSection(
              context,
              title: 'Copia de seguridad',
              icon: Icons.backup_outlined,
              children: const [_BackupCard()],
            ),
            const SizedBox(height: 20),

            // Data Section
            _buildSection(
              context,
              title: 'Datos de la aplicación',
              icon: Icons.storage_rounded,
              children: const [_ClearDataCard()],
            ),
            const SizedBox(height: 20),

            // About Section
            _buildSection(
              context,
              title: 'Acerca de TaskCheck',
              icon: Icons.info_outline_rounded,
              children: [
                _buildSettingCard(
                  context,
                  title: 'Versión',
                  subtitle: '1.0.8',
                  trailing: null,
                ),
                _buildSettingCard(
                  context,
                  title: 'Plataforma',
                  subtitle: 'Linux Desktop (Flutter 3.x, Dart 3.x)',
                  trailing: null,
                ),
                _buildSettingCard(
                  context,
                  title: 'Persistencia',
                  subtitle: 'SQLite (Drift) — local y offline',
                  trailing: null,
                ),
                _buildSettingCard(
                  context,
                  title: 'Datos del usuario',
                  subtitle: '~/.local/share/task_check/ (Linux)\nUbicación obtenida con path_provider',
                  trailing: null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(child: Column(children: children)),
      ],
    );
  }

  Widget _buildSettingCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget? trailing,
  }) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: trailing,
    );
  }

  Widget _buildShortcutCard(
    BuildContext context,
    String shortcut,
    String description,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              shortcut,
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(description, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Interruptores de las notificaciones del sistema.
class _NotificationSettingsCard extends ConsumerStatefulWidget {
  const _NotificationSettingsCard();

  @override
  ConsumerState<_NotificationSettingsCard> createState() =>
      _NotificationSettingsCardState();
}

class _NotificationSettingsCardState
    extends ConsumerState<_NotificationSettingsCard> {
  late final PreferencesRepository _preferences;
  late bool _enabled;
  late bool _dueDates;
  late bool _priority;
  bool _sendingTest = false;

  @override
  void initState() {
    super.initState();
    _preferences = ref.read(preferencesRepositoryProvider);
    _enabled = _preferences.notificationsEnabled;
    _dueDates = _preferences.notifyDueDates;
    _priority = _preferences.notifyPriority;
  }

  Future<void> _sendTest() async {
    setState(() => _sendingTest = true);
    final shown = await AppNotificationService.instance.showTest();
    if (!mounted) return;
    setState(() => _sendingTest = false);

    if (shown) {
      ErrorHandler.showSuccessSnackBar(
        context,
        'Notificación enviada al sistema',
      );
    } else {
      ErrorHandler.showErrorSnackBar(
        context,
        'El escritorio no permitió mostrar la notificación',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          title: const Text(
            'Notificaciones del sistema',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Avisos del escritorio cuando una tarea está por vencer o lleva '
            'mucho tiempo pendiente',
          ),
          value: _enabled,
          onChanged: (value) async {
            setState(() => _enabled = value);
            await _preferences.setNotificationsEnabled(value);
          },
        ),
        const Divider(height: 1),
        SwitchListTile(
          title: const Text('Tareas próximas a vencer y vencidas'),
          subtitle: const Text(
            'Avisa 24 h antes del vencimiento y cuando la tarea ya venció',
          ),
          value: _dueDates,
          onChanged: _enabled
              ? (value) async {
                  setState(() => _dueDates = value);
                  await _preferences.setNotifyDueDates(value);
                }
              : null,
        ),
        SwitchListTile(
          title: const Text('Recordatorios de prioridad alta'),
          subtitle: const Text(
            'Sugiere terminar las tareas de prioridad alta o urgente que '
            'siguen pendientes',
          ),
          value: _priority,
          onChanged: _enabled
              ? (value) async {
                  setState(() => _priority = value);
                  await _preferences.setNotifyPriority(value);
                }
              : null,
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.notifications_active_outlined, size: 18),
              label: Text(_sendingTest ? 'Enviando…' : 'Probar notificación'),
              onPressed: _enabled && !_sendingTest ? _sendTest : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// Estado de la clave de Gemini leída desde el archivo `.env`.
class _AiSettingsCard extends StatefulWidget {
  const _AiSettingsCard();

  @override
  State<_AiSettingsCard> createState() => _AiSettingsCardState();
}

class _AiSettingsCardState extends State<_AiSettingsCard> {
  bool _reloading = false;

  Future<void> _reload() async {
    setState(() => _reloading = true);
    await AppEnv.load();
    if (!mounted) return;
    setState(() => _reloading = false);

    if (AppEnv.hasGeminiApiKey) {
      ErrorHandler.showSuccessSnackBar(
        context,
        'Clave de Gemini cargada correctamente',
      );
    } else {
      ErrorHandler.showErrorSnackBar(
        context,
        'No se encontró GEMINI_API_KEY en el archivo .env',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasKey = AppEnv.hasGeminiApiKey;

    return Column(
      children: [
        ListTile(
          leading: Icon(
            hasKey ? Icons.verified_rounded : Icons.key_off_rounded,
            color: hasKey ? Colors.green.shade600 : Colors.orange.shade700,
          ),
          title: const Text(
            'Clave de la API',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            hasKey
                ? 'Configurada: GEMINI_API_KEY detectada en el archivo .env'
                : 'No configurada: agrega GEMINI_API_KEY a tu archivo .env ',
          ),
          trailing: _reloading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : TextButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Recargar'),
                ),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.description_outlined, size: 20),
          title: const Text('Archivo .env'),
          subtitle: Text(
            AppEnv.sourcePath ??
                'No encontrado. Rutas buscadas:\n'
                    '${AppEnv.searchedPaths.join('\n')}',
          ),
          isThreeLine: true,
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.memory_rounded, size: 20),
          title: const Text('Modelo'),
          subtitle: Text(AppEnv.geminiModel),
        ),
        const Divider(height: 1),
        ListTile(
          leading: Icon(
            Icons.lock_outline_rounded,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          title: const Text('Privacidad'),
          subtitle: const Text(
            'El archivo .env está excluido de Git (.gitignore), así que tu '
            'clave nunca se publica en GitHub.',
          ),
          isThreeLine: true,
        ),
      ],
    );
  }
}

/// Activa o desactiva el arranque del widget al iniciar sesión.
class _WidgetAutostartCard extends ConsumerStatefulWidget {
  const _WidgetAutostartCard();

  @override
  ConsumerState<_WidgetAutostartCard> createState() =>
      _WidgetAutostartCardState();
}

class _WidgetAutostartCardState extends ConsumerState<_WidgetAutostartCard> {
  late final PreferencesRepository _preferences;
  late bool _enabled;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _preferences = ref.read(preferencesRepositoryProvider);
    _enabled = _preferences.isWidgetAutoStartEnabled;
  }

  Future<void> _toggle(bool value) async {
    setState(() {
      _enabled = value;
      _busy = true;
    });

    await _preferences.setWidgetAutoStartEnabled(value);
    final registered = await WidgetAutostartService.setEnabled(value);

    if (value) {
      await WidgetLauncher.launch();
    }

    if (!mounted) return;
    setState(() => _busy = false);

    if (!registered) {
      ErrorHandler.showErrorSnackBar(
        context,
        'No se pudo registrar el widget para iniciar con el equipo',
      );
      return;
    }

    ErrorHandler.showSuccessSnackBar(
      context,
      value
          ? 'El widget se abrirá automáticamente al encender el equipo'
          : 'El widget ya no se abrirá automáticamente',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          title: const Text(
            'Abrir el widget al iniciar sesión',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Mantiene el widget flotante activo cada vez que enciendes o '
            'reinicias el equipo, sin abrir la aplicación principal',
          ),
          value: _enabled,
          onChanged: _busy ? null : _toggle,
        ),
        const Divider(height: 1),
        const ListTile(
          leading: Icon(Icons.info_outline_rounded, size: 20),
          title: Text('Requisito'),
          subtitle: Text(
            'Disponible en Linux: TaskCheck crea una entrada de inicio '
            'automático en ~/.config/autostart',
          ),
        ),
      ],
    );
  }
}

/// Guarda y restaura todas las tareas en un archivo JSON.
class _BackupCard extends ConsumerStatefulWidget {
  const _BackupCard();

  @override
  ConsumerState<_BackupCard> createState() => _BackupCardState();
}

class _BackupCardState extends ConsumerState<_BackupCard> {
  bool _working = false;

  Future<void> _export() async {
    String? path;
    try {
      path = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar copia de seguridad de TaskCheck',
        fileName: BackupService.suggestedFileName(),
        type: FileType.custom,
        allowedExtensions: const [BackupService.fileExtension],
        lockParentWindow: true,
      );
    } catch (error) {
      if (!mounted) return;
      ErrorHandler.showErrorSnackBar(
        context,
        'No se pudo abrir el diálogo para guardar la copia: $error',
      );
      return;
    }
    if (path == null || path.isEmpty || !mounted) return;

    // El diálogo devuelve la ruta elegida; si el usuario la escribió sin
    // extensión, se añade para que el archivo se reconozca después.
    if (!path.toLowerCase().endsWith('.${BackupService.fileExtension}')) {
      path = '$path.${BackupService.fileExtension}';
    }

    setState(() => _working = true);
    try {
      final result = await ref.read(backupServiceProvider).exportTo(path);
      if (!mounted) return;
      ErrorHandler.showSuccessSnackBar(
        context,
        'Copia guardada con ${result.summary}',
      );
    } catch (error) {
      if (!mounted) return;
      ErrorHandler.showErrorSnackBar(context, error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _restore() async {
    FilePickerResult? selection;
    try {
      selection = await FilePicker.platform.pickFiles(
        dialogTitle: 'Elegir copia de seguridad de TaskCheck',
        type: FileType.custom,
        allowedExtensions: const [BackupService.fileExtension],
        allowMultiple: false,
        lockParentWindow: true,
      );
    } catch (error) {
      if (!mounted) return;
      ErrorHandler.showErrorSnackBar(
        context,
        'No se pudo abrir el diálogo para elegir la copia: $error',
      );
      return;
    }
    final path = selection?.files.single.path;
    if (path == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.settings_backup_restore_rounded),
        title: const Text('¿Restaurar la copia de seguridad?'),
        content: Text(
          'Se reemplazarán todas las tareas, subtareas y categorías actuales '
          'por las del archivo:\n\n$path\n\n'
          'Los datos actuales se perderán. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _working = true);
    try {
      final result = await ref.read(backupServiceProvider).restoreFrom(path);
      if (!mounted) return;
      ErrorHandler.showSuccessSnackBar(
        context,
        'Copia restaurada: ${result.summary}',
      );
    } catch (error) {
      if (!mounted) return;
      ErrorHandler.showErrorSnackBar(context, error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_working) const LinearProgressIndicator(minHeight: 2),
        ListTile(
          leading: const Icon(Icons.save_alt_rounded, size: 20),
          title: const Text(
            'Crear copia de seguridad',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Guarda todas las tareas, subtareas y categorías en un archivo JSON '
            'que puedes conservar o copiar a otro equipo',
          ),
          trailing: FilledButton.tonalIcon(
            icon: const Icon(Icons.save_alt_rounded, size: 18),
            label: const Text('Exportar'),
            onPressed: _working ? null : _export,
          ),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.settings_backup_restore_rounded, size: 20),
          title: const Text(
            'Restaurar copia de seguridad',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Reemplaza las tareas actuales por las del archivo de copia '
            'seleccionado',
          ),
          trailing: OutlinedButton.icon(
            icon: const Icon(Icons.restore_rounded, size: 18),
            label: const Text('Restaurar'),
            onPressed: _working ? null : _restore,
          ),
        ),
      ],
    );
  }
}

/// Borra todas las tareas, subtareas y categorías del usuario.
class _ClearDataCard extends ConsumerStatefulWidget {
  const _ClearDataCard();

  @override
  ConsumerState<_ClearDataCard> createState() => _ClearDataCardState();
}

class _ClearDataCardState extends ConsumerState<_ClearDataCard> {
  bool _deleting = false;

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.red),
        title: const Text('¿Borrar todos los datos?'),
        content: const Text(
          'Se eliminarán permanentemente todas las tareas, subtareas y '
          'categorías, incluidas las archivadas. Las categorías por defecto '
          'se vuelven a crear.\n\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Borrar todo'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(appDatabaseProvider).clearAllData();
      if (!mounted) return;
      ErrorHandler.showSuccessSnackBar(
        context,
        'Todos los datos fueron eliminados',
      );
    } catch (error) {
      if (!mounted) return;
      ErrorHandler.showErrorSnackBar(context, error);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(Icons.delete_forever_rounded, color: Colors.red.shade600),
      title: Text(
        'Borrar todos los datos',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
      subtitle: const Text(
        'Elimina todas las tareas, subtareas y categorías de la aplicación',
      ),
      trailing: _deleting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red.shade700,
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Borrar'),
              onPressed: _deleting ? null : _confirmAndDelete,
            ),
    );
  }
}
