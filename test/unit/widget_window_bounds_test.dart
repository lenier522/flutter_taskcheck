import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_check/features/desktop_widget/services/widget_window_bounds.dart';
import 'package:task_check/features/settings/data/preferences_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Widget restore reuses the saved position and size', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = PreferencesRepository(
      await SharedPreferences.getInstance(),
    );

    const position = Offset(321, 123);
    const size = Size(420, 610);
    await preferences.saveWidgetPosition(position);
    await preferences.saveWidgetSize(size);

    // Simula un reinicio: una nueva instancia lee el mismo almacenamiento.
    final reopened = PreferencesRepository(
      await SharedPreferences.getInstance(),
    );
    final bounds = await WidgetWindowBounds.restore(reopened);

    expect(bounds.position, position);
    expect(bounds.size, size);
  });

  test('Widget restore centers when no position was saved', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = PreferencesRepository(
      await SharedPreferences.getInstance(),
    );

    final bounds = await WidgetWindowBounds.restore(preferences);

    expect(bounds.position, isNull);
  });
}
