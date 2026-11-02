import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_check/core/providers.dart';
import 'package:task_check/shared/widgets/app_scaffold.dart';

void main() {
  testWidgets('AppScaffold renders and collapses without any overflow', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // Set a typical desktop test window size
    tester.view.physicalSize = const Size(1100, 750);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          pendingTasksCountProvider.overrideWithValue(0),
          todayTasksCountProvider.overrideWithValue(0),
          importantTasksCountProvider.overrideWithValue(0),
          inProgressTasksCountProvider.overrideWithValue(0),
          completedTasksCountProvider.overrideWithValue(0),
          archivedTasksCountProvider.overrideWithValue(0),
        ],
        child: const MaterialApp(
          home: AppScaffold(
            currentRoute: '/',
            child: Center(child: Text('Dashboard View')),
          ),
        ),
      ),
    );

    // Initial expanded state check
    expect(find.text('Productividad'), findsOneWidget);
    expect(find.text('Dashboard View'), findsOneWidget);

    // Find and tap the collapse button
    final collapseBtn = find.byTooltip('Colapsar menú lateral');
    expect(collapseBtn, findsOneWidget);
    await tester.tap(collapseBtn);
    await tester.pumpAndSettle();

    // Verify it collapsed without any overflow exceptions
    expect(find.text('Productividad'), findsNothing);
    expect(find.byTooltip('Expandir menú lateral'), findsOneWidget);

    // Tap to expand again
    await tester.tap(find.byTooltip('Expandir menú lateral'));
    await tester.pumpAndSettle();

    // Verify expanded again
    expect(find.text('Productividad'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
  });
}
