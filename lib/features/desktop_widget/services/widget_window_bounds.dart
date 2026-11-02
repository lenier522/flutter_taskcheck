import 'package:flutter/widgets.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:task_check/core/constants/app_constants.dart';
import 'package:task_check/features/settings/data/preferences_repository.dart';

/// Resuelve el tamaño y la posición iniciales del widget flotante.
///
/// La posición guardada se restaura tal cual cuando sigue siendo visible. Si
/// cambió la configuración de monitores, se coloca en una zona visible para
/// evitar que la ventana quede fuera de pantalla.
class WidgetWindowBounds {
  const WidgetWindowBounds({required this.size, required this.position});

  final Size size;

  /// `null` cuando no hay una posición guardada y la ventana debe centrarse.
  final Offset? position;

  static Future<WidgetWindowBounds> restore(
    PreferencesRepository preferences,
  ) async {
    final savedSize = preferences.getWidgetSize();
    final size = Size(
      _validDimension(
        savedSize?.width,
        AppConstants.widgetWidth,
        AppConstants.widgetMinWidth,
      ),
      _validDimension(
        savedSize?.height,
        AppConstants.widgetHeight,
        AppConstants.widgetMinHeight,
      ),
    );

    final savedPosition = preferences.getWidgetPosition();
    if (savedPosition == null ||
        !savedPosition.dx.isFinite ||
        !savedPosition.dy.isFinite) {
      return WidgetWindowBounds(size: size, position: null);
    }

    return WidgetWindowBounds(
      size: size,
      position: await _ensureVisible(savedPosition, size),
    );
  }

  static double _validDimension(
    double? value,
    double fallback,
    double minimum,
  ) {
    final dimension = value == null || !value.isFinite ? fallback : value;
    return dimension.clamp(minimum, 10000.0).toDouble();
  }

  static Future<Offset> _ensureVisible(Offset desired, Size size) async {
    try {
      final displays = await screenRetriever.getAllDisplays();
      if (displays.isEmpty) return desired;

      final windowRect = desired & size;
      final isVisible = displays.any((display) {
        final visibleArea = windowRect.intersect(_displayRect(display));
        return visibleArea.width >= 48 && visibleArea.height >= 48;
      });
      if (isVisible) return desired;

      final primary = await screenRetriever.getPrimaryDisplay();
      final area = _displayRect(primary);
      final x = (area.right - size.width - 24).clamp(
        area.left,
        area.right - 48,
      );
      final y = (area.top + 72).clamp(area.top, area.bottom - 48);
      return Offset(x.toDouble(), y.toDouble());
    } catch (error) {
      debugPrint('No se pudo validar la posición guardada del widget: $error');
      return desired;
    }
  }

  static Rect _displayRect(Display display) {
    final origin = display.visiblePosition ?? Offset.zero;
    final size = display.visibleSize ?? display.size;
    return Rect.fromLTWH(origin.dx, origin.dy, size.width, size.height);
  }
}
