import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/apis/local_storage.dart';
import 'package:via_mallorca/apis/notification.dart';
import 'package:via_mallorca/components/bottom_sheets/station/popup/departure_notification_viewmodel.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:via_mallorca/providers/notifications_provider.dart';

class DepartureNotification extends StatelessWidget {
  const DepartureNotification(
      {super.key, required this.station, required this.departure});

  final Station station;
  final Departure departure;

  Future<void> handleSchedule(
      BuildContext context, DepartureNotificationViewModel viewModel) async {
    final random = Random();
    final scheduledDateTime = departure.estimatedArrival
        .subtract(Duration(minutes: viewModel.timeBeforeDeparture));
    // Convert DateTime to TZDateTime
    final scheduledDateTime0s = DateTime(
      scheduledDateTime.year,
      scheduledDateTime.month,
      scheduledDateTime.day,
      scheduledDateTime.hour,
      scheduledDateTime.minute,
      0, // set seconds to 0
    );
    final scheduledTime = tz.TZDateTime.from(scheduledDateTime0s, tz.local);
    Navigator.of(context).pop();

    /// Notification channels in Android can't be changed later,
    /// so due to localization, we need to save the Channel first used
    /// all the following notifications will use the same channel
    String? channel = LocalStorageApi.getNotificationChannel();
    if (channel == null) {
      channel = AppLocalizations.of(context)!.notificationChannelName;
      LocalStorageApi.setNotificationChannel(channel);
    }

    final alarmStatus = await Permission.scheduleExactAlarm.status;
    bool useInexactNotifications = Platform.isAndroid &&
        (LocalStorageApi.useInexactNotifications() ||
            alarmStatus.isDenied ||
            alarmStatus.isRestricted);

    if (!context.mounted) return;

    await NotificationApi.scheduleNotification(
        channelId: "bus_departures",
        id: random.nextInt(pow(2, 31).toInt() - 1), // Random ID
        channel: channel,
        notificationTitle:
            AppLocalizations.of(context)!.notificationTitle(departure.lineCode),
        scheduledDateTime: useInexactNotifications
            ? scheduledTime.subtract(Duration(minutes: 2))
            : scheduledTime,
        notificationBody: useInexactNotifications
            ? AppLocalizations.of(context)!
                .notificationBodyApprox(departure.lineCode)
            : AppLocalizations.of(context)!.notificationBody(
                departure.lineCode, viewModel.timeBeforeDeparture),
        ongoing: false,
        playSound: true,
        importance: Importance.high,
        category: AndroidNotificationCategory.reminder,
        payload: ViaNotificationPayload(
                stationId: station.id,
                tripId: departure.tripId,
                scheduledTime: scheduledTime)
            .toString(),
        androidScheduleMode: useInexactNotifications
            ? AndroidScheduleMode.inexactAllowWhileIdle
            : AndroidScheduleMode.exactAllowWhileIdle);

    if (context.mounted) {
      late String message;
      if (Platform.isAndroid && useInexactNotifications) {
        message = AppLocalizations.of(context)!.notificationScheduledApprox(
            departure.lineCode,
            DateFormat.Hm().format(scheduledDateTime.toLocal()));
      } else {
        message = AppLocalizations.of(context)!.notificationScheduled(
            departure.lineCode,
            DateFormat.Hm().format(scheduledDateTime.toLocal()));
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
      Provider.of<NotificationsProvider>(context, listen: false)
          .reloadNotifications(); // To update the UI
    }
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: ChangeNotifierProvider(
        create: (_) => DepartureNotificationViewModel(departure),
        child: Consumer<DepartureNotificationViewModel>(
            builder: (context, viewModel, child) {
          return Consumer<NotificationsProvider>(
              builder: (context, notifications, _) {
            return AlertDialog(
              title: Text(AppLocalizations.of(context)!
                  .notificationDialogTitle(departure.lineCode)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(AppLocalizations.of(context)!.notificationDialogSubtitle,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(AppLocalizations.of(context)!.notifyMe,
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500)),
                      NumberPicker(
                        haptics: true,
                        itemWidth: 60,
                        minValue: 2,
                        maxValue: viewModel.departureInMinutes - 1,
                        value: viewModel.timeBeforeDeparture,
                        onChanged: (value) {
                          viewModel.setTimeBeforeDeparture(value);
                        },
                      ),
                      Text(AppLocalizations.of(context)!.minutesBefore,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  if (notifications.pendingNotifications.any((n) =>
                      n.payload != null && n.payload!.isNotEmpty
                          ? (ViaNotificationPayload.fromString(n.payload!)
                                  .tripId ==
                              departure.tripId)
                          : false))
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        AppLocalizations.of(context)!.alreadyScheduled,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
                FilledButton(
                  onPressed: () async =>
                      await handleSchedule(context, viewModel),
                  child:
                      Text(AppLocalizations.of(context)!.scheduleNotification),
                ),
              ],
            );
          });
        }),
      ),
    );
  }
}
