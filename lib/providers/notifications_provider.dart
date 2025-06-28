import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:via_mallorca/apis/notification.dart';

class NotificationsProvider extends ChangeNotifier {
  List<PendingNotificationRequest> _pendingNotifications = [];

  List<PendingNotificationRequest> get pendingNotifications =>
      _pendingNotifications;

  NotificationsProvider() {
    _loadPendingNotifications();
  }

  Future<void> _loadPendingNotifications() async {
    _pendingNotifications = await NotificationApi.pendingNotifications();
    notifyListeners();
  }

  Future<void> reloadNotifications() async {
    await _loadPendingNotifications();
  }

  Future<void> cancelNotification(int id) async {
    await NotificationApi.cancelNotification(id);
    await _loadPendingNotifications();
  }

  Future<void> cancelAllNotifications() async {
    await NotificationApi.cancelAllNotifications();
    await _loadPendingNotifications();
  }
}
