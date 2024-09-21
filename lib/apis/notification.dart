import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/standalone.dart';
import 'package:timezone/data/latest_all.dart' as tz;

/// A class that provides methods for managing notifications.
class NotificationApi {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Initializes the notification plugin.
  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('notification_icon');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _notificationsPlugin.initialize(initializationSettings);
    tz.initializeTimeZones();
  }

  /// Shows a notification with the specified parameters.
  static Future<void> showNotification({
    required int id,
    required String channel,
    required String notificationTitle,
    String? notificationBody,
    String? icon,
    bool playSound = false,
    bool autoCancel = true,
    bool showWhen = true,
    bool enableVibration = false,
    required bool ongoing,
    List<AndroidNotificationAction> actions = const [],
    required AndroidNotificationCategory category,
  }) async {
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails('viamallorca', channel,
            importance: Importance.low,
            priority: Priority.defaultPriority,
            playSound: playSound,
            enableVibration: enableVibration,
            category: category,
            ongoing: ongoing,
            autoCancel: autoCancel,
            showWhen: showWhen,
            icon: icon,
            actions: actions);
    NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await _notificationsPlugin.show(
      id,
      notificationTitle,
      notificationBody,
      platformChannelSpecifics,
    );
  }

  /// Cancels a scheduled notification with the specified ID.
  static Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  /// Schedules a notification with the specified parameters.
  ///
  /// The notification will be shown at the specified [scheduledDateTime].
  static Future<void> scheduleNotification({
    required int id,
    required String channel,
    required String notificationTitle,
    required TZDateTime scheduledDateTime,
    String? notificationBody,
    String? icon,
    bool playSound = false,
    bool enableVibration = false,
    required bool ongoing,
    List<AndroidNotificationAction> actions = const [],
    required AndroidNotificationCategory category,
  }) async {
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails('viamallorca', channel,
            importance: Importance.low,
            priority: Priority.defaultPriority,
            playSound: playSound,
            enableVibration: enableVibration,
            category: category,
            ongoing: ongoing,
            icon: icon,
            actions: actions);
    NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.zonedSchedule(id, notificationTitle,
        notificationBody, scheduledDateTime, platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime);
  }

  /// Retrieves a list of pending notifications.
  static Future<List<PendingNotificationRequest>> pendingNotifications() async {
    return _notificationsPlugin.pendingNotificationRequests();
  }

  /// Requests permission to show notifications.
  static Future requestPermission() async {
    return await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()!
        .requestNotificationsPermission();
  }
}
