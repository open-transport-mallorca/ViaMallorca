import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:live_activity_kit/live_activity_kit.dart';
import 'package:permission_handler/permission_handler.dart';

/// What the live tracking notification says, already localized
@immutable
class TrackingNotificationContent {
  const TrackingNotificationContent({
    required this.title,
    this.body,
    this.subtitle,
    this.chip,
    this.progress,
  });

  final String title;
  final String? body;
  final String? subtitle;
  final String? chip;
  final double? progress;

  @override
  bool operator ==(Object other) =>
      other is TrackingNotificationContent &&
      other.title == title &&
      other.body == body &&
      other.subtitle == subtitle &&
      other.chip == chip &&
      other.progress == progress;

  @override
  int get hashCode => Object.hash(title, body, subtitle, chip, progress);
}

/// Shows the tracked bus outside the app; on Android also runs the foreground
/// service that keeps the app alive in the background
class TrackingNotificationApi {
  static const _channel =
      MethodChannel('es.opentransportmallorca.via/tracking_notification');

  static const _activityId = 'tracking';
  static const _staleAfter = Duration(minutes: 2);

  static void setHandlers({
    required VoidCallback onStopRequested,
    required VoidCallback onDismissed,
  }) {
    if (!Platform.isAndroid) return;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onStopRequested':
          onStopRequested();
        case 'onDismissed':
          onDismissed();
      }
    });
  }

  /// Must be called from the foreground: Android won't start a foreground
  /// service from the background
  static Future<void> start(
    TrackingNotificationContent content, {
    required String stopLabel,
    required String channelName,
    required String channelDescription,
  }) async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('start', {
          ..._toMap(content),
          'stopLabel': stopLabel,
          'channelName': channelName,
          'channelDescription': channelDescription,
        });
        _labels = (stopLabel, channelName, channelDescription);
        // After starting: the service works without the permission, so
        // tracking shouldn't wait on the dialog
        if (await Permission.notification.isDenied) {
          await Permission.notification.request();
        }
      } else if (Platform.isIOS) {
        final support = await LiveActivity.support();
        if (!support.canStart) return;
        await LiveActivity.show(
          id: _activityId,
          staleAfter: _staleAfter,
          lockScreen: _iosLockScreen(content),
          expanded: _iosLockScreen(content),
          compactLeading: _iosBus,
          compactTrailing: _iosChip(content),
          minimal: _iosBus,
        );
      }
    } catch (e) {
      debugPrint('Tracking notification failed to start: $e');
    }
  }

  static (String, String, String)? _labels;

  static Future<void> update(TrackingNotificationContent content) async {
    try {
      if (Platform.isAndroid) {
        final labels = _labels;
        if (labels == null) return;
        await _channel.invokeMethod('update', {
          ..._toMap(content),
          'stopLabel': labels.$1,
          'channelName': labels.$2,
          'channelDescription': labels.$3,
        });
      } else if (Platform.isIOS) {
        if (!await LiveActivity.isRunning(_activityId)) return;
        await LiveActivity.update(
          id: _activityId,
          staleAfter: _staleAfter,
          lockScreen: _iosLockScreen(content),
          expanded: _iosLockScreen(content),
          compactTrailing: _iosChip(content),
        );
      }
    } catch (e) {
      debugPrint('Tracking notification failed to update: $e');
    }
  }

  /// [finalContent] stays on the iOS Lock Screen for a few minutes
  static Future<void> stop({TrackingNotificationContent? finalContent}) async {
    try {
      if (Platform.isAndroid) {
        _labels = null;
        await _channel.invokeMethod('stop');
      } else if (Platform.isIOS) {
        if (!await LiveActivity.isRunning(_activityId)) return;
        if (finalContent == null) {
          await LiveActivity.end(
            id: _activityId,
            policy: const LiveActivityEndPolicy.immediate(),
          );
        } else {
          await LiveActivity.end(
            id: _activityId,
            lockScreen: _iosLockScreen(finalContent),
            policy: LiveActivityEndPolicy.after(
              DateTime.now().add(const Duration(minutes: 5)),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Tracking notification failed to stop: $e');
    }
  }

  static Map<String, Object?> _toMap(TrackingNotificationContent content) => {
        'title': content.title,
        'body': content.body,
        'subtitle': content.subtitle,
        'chip': content.chip,
        'progress': content.progress,
      };

  // Untested: needs `dart run live_activity_kit:setup` on a Mac

  static final LANode _iosBus = LA.symbol('bus.fill');

  static LANode _iosChip(TrackingNotificationContent content) =>
      LA.text(content.chip ?? '', weight: FontWeight.w600);

  static LANode _iosLockScreen(TrackingNotificationContent content) {
    return LA.column([
      LA.row([
        LA.symbol('bus.fill', size: 14),
        if (content.subtitle != null)
          LA.text(content.subtitle!, size: 13, maxLines: 1, opacity: 0.8),
        LA.spacer(),
        if (content.chip != null)
          LA.text(content.chip!, size: 13, weight: FontWeight.w600),
      ], spacing: 6),
      LA.text(content.title, size: 18, weight: FontWeight.bold, maxLines: 1),
      if (content.body != null) LA.text(content.body!, size: 14, maxLines: 2),
      if (content.progress != null) LA.progress(content.progress!),
    ], spacing: 6);
  }
}
