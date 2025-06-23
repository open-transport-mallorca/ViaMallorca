import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/standalone.dart';
import 'package:timezone/data/latest_all.dart' as tz;

/// A class that provides methods for managing notifications.
class NotificationApi {
  static final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static void Function(String payload)? onNotificationTap;

  static String? pendingPayload;

  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_notification');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(requestSoundPermission: true);

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null) {
          // If callback is not yet set, store it
          if (onNotificationTap != null) {
            onNotificationTap!(payload);
          } else {
            pendingPayload = payload;
          }
        }
      },
    );

    tz.initializeTimeZones();
  }

  /// Called by your app to handle any stored payload after everything is ready
  static void maybeHandlePendingPayload() {
    if (pendingPayload != null && onNotificationTap != null) {
      onNotificationTap!(pendingPayload!);
      pendingPayload = null;
    }
  }

  /// Schedules a notification with the specified parameters.
  ///
  /// The notification will be shown at the specified [scheduledDateTime].
  static Future<void> scheduleNotification({
    required int id,
    required String channelId,
    required String channel,
    String? channelDescription,
    required String notificationTitle,
    required TZDateTime scheduledDateTime,
    String? notificationBody,
    bool playSound = true,
    bool enableVibration = false,
    String? payload,
    Importance importance = Importance.defaultImportance,
    required bool ongoing,
    List<AndroidNotificationAction> androidActions = const [],
    List<DarwinNotificationAction> iOSActions = const [],
    required AndroidNotificationCategory category,
    AndroidScheduleMode androidScheduleMode =
        AndroidScheduleMode.inexactAllowWhileIdle,
  }) async {
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(channelId, channel,
            channelDescription: channelDescription,
            importance: importance,
            priority: Priority.defaultPriority,
            playSound: playSound,
            enableVibration: enableVibration,
            category: category,
            ongoing: ongoing,
            actions: androidActions);
    DarwinNotificationDetails darwinPlatformChannelSpecifics =
        DarwinNotificationDetails(
            presentSound: true,
            categoryIdentifier: channelId,
            interruptionLevel: InterruptionLevel.active);
    NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: darwinPlatformChannelSpecifics);

    await notificationsPlugin.zonedSchedule(id, notificationTitle,
        notificationBody, scheduledDateTime, platformChannelSpecifics,
        payload: payload, androidScheduleMode: androidScheduleMode);
  }

  /// Retrieves a list of pending notifications.
  static Future<List<PendingNotificationRequest>> pendingNotifications() async {
    return notificationsPlugin.pendingNotificationRequests();
  }

  /// Cancels a scheduled notification with the specified ID.
  static Future<void> cancelNotification(int id) async {
    await notificationsPlugin.cancel(id);
  }

  /// Cancels all scheduled notifications.
  static Future<void> cancelAllNotifications() async {
    await notificationsPlugin.cancelAll();
  }
}

class ViaNotificationPayload {
  final int stationId;
  final int tripId;
  final DateTime scheduledTime;
  ViaNotificationPayload({
    required this.stationId,
    required this.tripId,
    required this.scheduledTime,
  });

  factory ViaNotificationPayload.fromString(String payload) {
    final parts = payload.split(',');
    if (parts.length != 3) {
      throw FormatException('Invalid payload format');
    }
    return ViaNotificationPayload(
      stationId: int.parse(parts[0]),
      tripId: int.parse(parts[1]),
      scheduledTime: DateTime.parse(parts[2]),
    );
  }

  @override
  String toString() {
    return '$stationId,$tripId,${scheduledTime.toIso8601String()}';
  }
}
