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
import 'package:via_mallorca/providers/favorites_provider.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/providers/notifications_provider.dart';
import 'package:via_mallorca/providers/settings_provider.dart';
import 'package:via_mallorca/providers/tracking_provider.dart';
import 'package:via_mallorca/utils/distance_formatter.dart';
import 'package:via_mallorca/utils/line_icon.dart';
import 'package:via_mallorca/utils/station_sort.dart';
import 'package:via_mallorca/utils/stop_restrictions.dart';

class DepartureCard extends StatelessWidget {
  const DepartureCard(
      {super.key,
      required this.departure,
      required this.station,
      this.isHighlighted = false,
      this.restriction,
      this.isTracked = false});

  final Departure departure;
  final Station station;
  final bool isHighlighted;

  /// How boarding this line is restricted at this stop, or null when it is not.
  ///
  /// Either direction matters to a passenger standing here: a drop-off only
  /// stop cannot be boarded, and a pick-up only stop cannot be alighted at.
  final StopRestriction? restriction;

  /// Whether this departure is the trip currently being tracked, which outlines
  /// the card.
  ///
  /// Drawn as the card's own shape rather than a border around it: a wrapping
  /// container sits outside the card's margin, which leaves a gap between the
  /// two and shifts the row when tracking starts.
  final bool isTracked;

  Future<void> handleAddNotification(BuildContext context) async {
    final notificationStatus = await Permission.notification.status;
    final alarmStatus = await Permission.scheduleExactAlarm.status;

    // Check if the user has granted notification permissions
    if (Platform.isAndroid && notificationStatus.isDenied) {
      await Permission.notification.request(); // This only works on Android
    } else if ((notificationStatus.isPermanentlyDenied ||
            (Platform.isIOS && notificationStatus.isDenied)) &&
        context.mounted) {
      showDialog(
        context: context,
        builder: (context) => notificationsDeniedDialog(context),
      );
      return;
    }

    // On Android also hceck if the user has granted alarm permissions
    if (Platform.isAndroid &&
        (alarmStatus.isDenied || alarmStatus.isRestricted)) {
      if (!LocalStorageApi.useInexactNotifications() && context.mounted) {
        bool? result = await offerPreciseNotifications(context);
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
    if (context.mounted) {
      showDialog(
          context: context,
          builder: (context) => DepartureNotification(
                station: station,
                departure: departure,
              ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritesProvider>(
        builder: (context, favoritesProvider, child) {
      return Card(
        color: isHighlighted
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHigh,
        shape: isTracked
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.tertiary,
                  width: 3,
                ),
              )
            : null,
        child: Stack(
          children: [
            if (departure.estimatedArrival
                    .difference(DateTime.now())
                    .inMinutes >=
                6)
              Consumer<NotificationsProvider>(
                  builder: (context, notifications, _) {
                return Positioned(
                    left: 0,
                    top: 0,
                    child: IconButton(
                      iconSize: 20,
                      onPressed: () async =>
                          await handleAddNotification(context),
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
                  getIconFromLineCode(departure.lineCode),

                  // Main content (middle)
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title line
                        Builder(builder: (context) {
                          late Color textColor;

                          if (isHighlighted) {
                            textColor = Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer;
                          } else if (favoritesProvider
                              .isFavoriteRoute(departure.lineCode.toString())) {
                            textColor = Theme.of(context).colorScheme.primary;
                          } else {
                            textColor = Theme.of(context).colorScheme.onSurface;
                          }
                          return Text(
                            "${departure.lineCode}${departure.destination != null ? " - ${departure.destination}" : ""}",
                            style: TextStyle(fontSize: 20, color: textColor),
                          );
                        }),

                        if (restriction != null)
                          _StopRestrictionBadge(restriction!),

                        // Subtitle content
                        Text(
                          departure.name,
                          style: TextStyle(
                              fontSize: 16,
                              color: isHighlighted
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
                                estimatedArrival?.difference(now).inMinutes ??
                                    0;
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
                              scheduledColor = isHighlighted
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSurface;
                            } else {
                              scheduledText =
                                  "${l10n.arrivingIn(minutesToScheduled)} ($scheduledArrivalStr)";
                              scheduledColor = isHighlighted
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
                                if (showEstimated &&
                                    estimatedArrivalStr != null)
                                  Text(
                                    "${l10n.estimated}: ${l10n.arrivingIn(minutesToEstimated).toLowerCase()} ($estimatedArrivalStr)",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                // When the trip reaches its terminus, which is
                                // what says whether this bus gets you there in
                                // time. `endTime` carries no real date, so only
                                // its clock time is meaningful.
                                if (departure.endTime != null &&
                                    departure.destination != null)
                                  Text(
                                    l10n.arrivesAt(
                                        departure.destination!,
                                        DateFormat.Hm()
                                            .format(departure.endTime!)),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isHighlighted
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onPrimaryContainer
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
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
                              : isHighlighted
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
                            color: Theme.of(context)
                                .colorScheme
                                .secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                // Boarding is not possible here, so make sure
                                // the user knows before they follow this bus -
                                // unless they have asked not to be warned.
                                if (restriction ==
                                        StopRestriction.dropOffOnly &&
                                    context
                                        .read<SettingsProvider>()
                                        .showDischargeOnlyWarning) {
                                  final confirmed =
                                      await confirmTrackDischargeOnly(context);
                                  if (confirmed != true) return;
                                }
                                if (!context.mounted) return;
                                final line = await RouteLinesApi.getLine(
                                    departure.lineCode);
                                // Stops are direction-specific, so the subline
                                // containing this boarding station tells us which
                                // way the tracked trip is going. Without this the
                                // map defaults to the outbound way and may show
                                // the wrong direction's route/stops.
                                Way? trackedWay;
                                for (final subline
                                    in line.sublines ?? <Subline>[]) {
                                  if (subline.stations
                                      .any((s) => s.id == station.id)) {
                                    trackedWay = subline.way;
                                    break;
                                  }
                                }
                                if (context.mounted) {
                                  Provider.of<MapProvider>(context,
                                          listen: false)
                                      .viewRoute(line, context,
                                          isTracking: true,
                                          initialWay: trackedWay);
                                  Provider.of<TrackingProvider>(context,
                                          listen: false)
                                      .startTracking(
                                          departure.realTrip!.id,
                                          departure.lineCode,
                                          LatLng(departure.realTrip!.lat,
                                              departure.realTrip!.long),
                                          station.id);
                                  // A new trip always starts followed, even if
                                  // the user had panned away from the last one.
                                  Provider.of<MapProvider>(context,
                                          listen: false)
                                      .setFollowTrackedBus(true);
                                  Provider.of<MapProvider>(context,
                                          listen: false)
                                      .updateLocation(
                                          LatLng(departure.realTrip!.lat,
                                              departure.realTrip!.long),
                                          MapProvider.trackingZoom);
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
                            DistanceFormatter.formatDistance(
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
    });
  }

  /// Asks the user to confirm before tracking a bus they cannot board at this
  /// stop. Resolves to true only if they choose to track it anyway.
  ///
  /// The dialog carries its own "don't show again" checkbox: a suppression that
  /// could only be enabled from the settings page is one nobody would find
  /// while being interrupted by the thing they want to suppress.
  Future<bool?> confirmTrackDischargeOnly(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    bool dontAskAgain = false;
    return showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.dischargeOnlyDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)!.dischargeOnlyDialogSubtitle),
              const SizedBox(height: 12),
              // Deliberately quieter than the warning itself: the whole row is
              // tappable so the target stays comfortable, but the control is
              // sized and coloured as an aside rather than as a second question.
              InkWell(
                onTap: () => setState(() => dontAskAgain = !dontAskAgain),
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: dontAskAgain,
                        onChanged: (value) =>
                            setState(() => dontAskAgain = value ?? false),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.dontShowAgain,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            FilledButton(
              onPressed: () {
                // Only honoured when they go ahead - ticking the box and then
                // cancelling is not agreement to stop being warned.
                if (dontAskAgain) settings.showDischargeOnlyWarning = false;
                Navigator.of(context).pop(true);
              },
              child: Text(AppLocalizations.of(context)!.track),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> offerPreciseNotifications(BuildContext context) {
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

  Widget notificationsDeniedDialog(BuildContext context) {
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
}

/// Marks a departure whose stop only lets passengers off, or only lets them on.
class _StopRestrictionBadge extends StatelessWidget {
  const _StopRestrictionBadge(this.restriction);

  final StopRestriction restriction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final localizations = AppLocalizations.of(context)!;
    final (icon, label) = switch (restriction) {
      StopRestriction.dropOffOnly => (
          Icons.exit_to_app,
          localizations.dropOffOnly
        ),
      StopRestriction.pickUpOnly => (Icons.login, localizations.pickUpOnly),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Icon(icon, size: 14, color: scheme.onTertiaryContainer),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: scheme.onTertiaryContainer),
            ),
          ],
        ),
      ),
    );
  }
}
