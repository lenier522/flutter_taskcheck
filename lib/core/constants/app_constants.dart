class AppConstants {
  static const String appName = 'TaskCheck';
  static const String appVersion = '1.0.0';
  static const String appId = 'com.taskcheck.task_check';

  // Desktop window dimensions
  static const double minWindowWidth = 900.0;
  static const double minWindowHeight = 600.0;
  static const double defaultWindowWidth = 1200.0;
  static const double defaultWindowHeight = 780.0;

  // Floating widget dimensions
  static const double widgetWidth = 360.0;
  static const double widgetHeight = 520.0;
  static const double widgetMinWidth = 320.0;
  static const double widgetMinHeight = 400.0;

  // SharedPreferences keys
  static const String prefThemeMode = 'pref_theme_mode';
  static const String prefWidgetPosX = 'pref_widget_pos_x';
  static const String prefWidgetPosY = 'pref_widget_pos_y';
  static const String prefWidgetWidth = 'pref_widget_width';
  static const String prefWidgetHeight = 'pref_widget_height';
  static const String prefWidgetAutoStart = 'pref_widget_auto_start';
  static const String prefAutoCompleteParent = 'pref_auto_complete_parent';
  static const String prefNotificationsEnabled = 'pref_notifications_enabled';
  static const String prefNotifyDueDates = 'pref_notify_due_dates';
  static const String prefNotifyPriority = 'pref_notify_priority';

  // Legacy widget bounds keys kept for migration from 1.0.0 builds.
  static const String legacyWidgetPosX = 'widget_x';
  static const String legacyWidgetPosY = 'widget_y';
  static const String legacyWidgetWidth = 'widget_w';
  static const String legacyWidgetHeight = 'widget_h';
}
