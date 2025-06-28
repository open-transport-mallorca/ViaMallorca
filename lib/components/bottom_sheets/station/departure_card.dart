import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/apis/local_storage.dart';
import 'package:via_mallorca/apis/notification.dart';
import 'package:via_mallorca/components/bottom_sheets/station/popup/departure_notification_view.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/providers/notifications_provider.dart';
import 'package:via_mallorca/providers/tracking_provider.dart';
import 'package:via_mallorca/utils/distance_formatter.dart';
import 'package:via_mallorca/utils/station_sort.dart';

class DepartureCard extends StatefulWidget {
  const DepartureCard(
      {super.key,
      required this.departure,
      required this.station,
      this.isHighlighted = false});

  final Departure departure;
  final Station station;
  final bool isHighlighted;

  @override
  State<DepartureCard> createState() => _DepartureCardState();
}

class _DepartureCardState extends State<DepartureCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleNextUpdate();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleNextUpdate() {
    // Cancel any existing timer
    _timer?.cancel();

    // Calculate time until next full minute (00 seconds)
    final now = DateTime.now();
    final nextMinute =
        DateTime(now.year, now.month, now.day, now.hour, now.minute + 1);
    final duration = nextMinute.difference(now);

    // Schedule the timer
    _timer = Timer(duration, () {
      if (mounted) {
        setState(() {});
        _scheduleNextUpdate();
      }
    });
  }

  Future<void> handleAddNotification() async {
    final notificationStatus = await Permission.notification.status;
    final alarmStatus = await Permission.scheduleExactAlarm.status;

    // Check if the user has granted notification permissions
    if (Platform.isAndroid && notificationStatus.isDenied) {
      await Permission.notification.request(); // This only works on Android
    } else if ((notificationStatus.isPermanentlyDenied ||
            (Platform.isIOS && notificationStatus.isDenied)) &&
        mounted) {
      showDialog(
        context: context,
        builder: (context) => notificationsDeniedDialog(),
      );
      return;
    }

    // On Android also hceck if the user has granted alarm permissions
    if (Platform.isAndroid &&
        (alarmStatus.isDenied || alarmStatus.isRestricted)) {
      if (!LocalStorageApi.useInexactNotifications() && mounted) {
        bool? result = await offerPreciseNotifications();
        if (result == true) {
          // User accepted precise notifications, request permission
          await Permission.scheduleExactAlarm.request();
        } else if (result == null) {
          return; // User dismissed the dialog
        } else {
          // User declined precise notifications, use inexact notifications
          await LocalStorageApi.setUseInexactNotifications(true);
        }
      }
    }

    // If the user has granted notification permissions, show the notification dialog
    if (mounted) {
      showDialog(
          context: context,
          builder: (context) => DepartureNotification(
                station: widget.station,
                departure: widget.departure,
              ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final departure = widget.departure;
    final station = widget.station;

    return Card(
      color: widget.isHighlighted
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Stack(
        children: [
          if (departure.estimatedArrival.difference(DateTime.now()).inMinutes >=
              4)
            Consumer<NotificationsProvider>(
                builder: (context, notifications, _) {
              return Positioned(
                  left: 0,
                  top: 0,
                  child: IconButton(
                    iconSize: 20,
                    onPressed: () async => await handleAddNotification(),
                    icon: Icon(Icons.notification_add,
                        color: notifications.pendingNotifications.any((n) =>
                                n.payload != null && n.payload!.isNotEmpty
                                    ? (ViaNotificationPayload.fromString(
                                                n.payload!)
                                            .tripId ==
                                        departure.tripId)
                                    : false)
                            ? Theme.of(context).colorScheme.primary
                            : null),
                  ));
            }),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              spacing: 12,
              children: [
                // Leading icon (left side)
                _getIconForLine(departure.lineCode),

                // Main content (middle)
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title line
                      Text(
                        "${departure.lineCode}${departure.destination != null ? " - ${departure.destination}" : ""}",
                        style: TextStyle(
                            fontSize: 20,
                            color: widget.isHighlighted
                                ? Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer
                                : Theme.of(context).colorScheme.onSurface),
                      ),

                      // Subtitle content
                      Text(
                        departure.name,
                        style: TextStyle(
                            fontSize: 16,
                            color: widget.isHighlighted
                                ? Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer
                                : Theme.of(context).colorScheme.onSurface),
                      ),

                      // Arrival time
                      Builder(
                        builder: (context) {
                          final l10n = AppLocalizations.of(context)!;
                          final now = DateTime.now();

                          final scheduledArrival = departure.estimatedArrival;
                          final scheduledArrivalStr =
                              DateFormat.Hm().format(scheduledArrival);
                          final minutesToScheduled =
                              scheduledArrival.difference(now).inMinutes;

                          final estimatedArrival =
                              departure.realTrip?.estimatedArrival;
                          final minutesToEstimated =
                              estimatedArrival?.difference(now).inMinutes ?? 0;
                          final estimatedArrivalStr = estimatedArrival != null
                              ? DateFormat.Hm().format(estimatedArrival)
                              : null;

                          // Define scheduledText and its color
                          String scheduledText;
                          Color scheduledColor;

                          if (minutesToScheduled < 0) {
                            scheduledText =
                                "$scheduledArrivalStr - ${l10n.arrivingLate}";
                            scheduledColor =
                                Theme.of(context).colorScheme.error;
                          } else if (minutesToScheduled > 59) {
                            scheduledText = scheduledArrivalStr;
                            scheduledColor = widget.isHighlighted
                                ? Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer
                                : Theme.of(context).colorScheme.onSurface;
                          } else {
                            scheduledText =
                                "${l10n.arrivingIn(minutesToScheduled)} ($scheduledArrivalStr)";
                            scheduledColor = widget.isHighlighted
                                ? Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer
                                : Theme.of(context).colorScheme.onSurface;
                          }

                          // Show estimated only if it differs from scheduled and is valid
                          final showEstimated = estimatedArrival != null &&
                              estimatedArrival != scheduledArrival &&
                              minutesToEstimated >= 0 &&
                              minutesToEstimated != minutesToScheduled;

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${l10n.scheduled}: $scheduledText",
                                style: TextStyle(
                                    fontSize: 14, color: scheduledColor),
                              ),
                              if (showEstimated && estimatedArrivalStr != null)
                                Text(
                                  "${l10n.estimated}: ${l10n.arrivingIn(minutesToEstimated).toLowerCase()} ($estimatedArrivalStr)",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                            ],
                          );
                        },
                      )
                    ],
                  ),
                ),

                // Trailing widgets (right side)
                Row(mainAxisSize: MainAxisSize.min, spacing: 12, children: [
                  if (departure.realTrip != null) ...[
                    // Passenger count
                    if (departure.realTrip?.stats != null)
                      Builder(builder: (context) {
                        final color = departure.realTrip!.stats!.passengers >
                                departure.realTrip!.stats!.placesToSit +
                                    departure.realTrip!.stats!.placesToStand
                            ? Theme.of(context).colorScheme.error
                            : widget.isHighlighted
                                ? Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer
                                : Theme.of(context).colorScheme.onSurface;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.people,
                              size: 20,
                              color: color,
                            ),
                            Text(
                              "${departure.realTrip!.stats!.passengers}",
                              style: TextStyle(fontSize: 16, color: color),
                            ),
                          ],
                        );
                      }),

                    // Track button
                    Column(
                      spacing: 2,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Material(
                          color:
                              Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              final line =
                                  await RouteLine.getLine(departure.lineCode);
                              if (context.mounted) {
                                Provider.of<MapProvider>(context, listen: false)
                                    .viewRoute(line, context, true);
                                Provider.of<TrackingProvider>(context,
                                        listen: false)
                                    .startTracking(
                                        departure.realTrip!.id,
                                        departure.lineCode,
                                        LatLng(departure.realTrip!.lat,
                                            departure.realTrip!.long),
                                        station.id);
                                Provider.of<MapProvider>(context, listen: false)
                                    .updateLocation(
                                        LatLng(departure.realTrip!.lat,
                                            departure.realTrip!.long),
                                        15);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                spacing: 4,
                                children: [
                                  const Icon(Icons.location_pin, size: 20),
                                  Text(
                                    AppLocalizations.of(context)!.track,
                                    style: const TextStyle(fontSize: 12),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                        Text(
                          MetricDistanceFormatter.formatDistance(
                              calculateDistance(
                                  lon1: station.long,
                                  lat1: station.lat,
                                  lon2: departure.realTrip!.long,
                                  lat2: departure.realTrip!.lat),
                              context),
                          style: TextStyle(fontSize: 11),
                        )
                      ],
                    ),
                  ],
                ])
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> offerPreciseNotifications() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.remindersDeniedDialogTitle),
        content:
            Text(AppLocalizations.of(context)!.remindersDeniedDialogSubtitle),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: Text(AppLocalizations.of(context)!.useInexact),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            child: Text(AppLocalizations.of(context)!.allowExact),
          ),
        ],
      ),
    );
  }

  Widget notificationsDeniedDialog() {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.notificationDeniedDialogTitle),
      content:
          Text(AppLocalizations.of(context)!.notificationDeniedDialogSubtitle),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
        FilledButton(
          onPressed: () {
            openAppSettings();
            Navigator.of(context).pop();
          },
          child: Text(AppLocalizations.of(context)!.openSettings),
        ),
      ],
    );
  }

  Icon _getIconForLine(String line) {
    if (line.startsWith("M")) {
      return const Icon(Icons.subway_outlined);
    } else if (line.startsWith("T")) {
      return const Icon(Icons.train);
    } else if (line.startsWith("A")) {
      return const Icon(Icons.airplanemode_active_outlined);
    } else {
      return const Icon(Icons.directions_bus);
    }
  }
}
