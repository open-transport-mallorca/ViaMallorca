import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/providers/tracking_provider.dart';
import 'package:via_mallorca/utils/line_icon.dart';

/// Compact status panel shown at the top-right while tracking a bus. Reads as
/// an ongoing status (not a dismissible modal): line + destination header, then
/// left-aligned live stats (occupancy, speed) and next/final stop.
class BusInfo extends StatelessWidget {
  const BusInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<TrackingProvider, MapProvider>(
        builder: (context, tracking, map, _) {
      return AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: tracking.currentLocation == null ? 0 : 1,
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _StatusPanel(tracking: tracking, map: map),
          ),
        ),
      );
    });
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.tracking, required this.map});

  final TrackingProvider tracking;
  final MapProvider map;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final routeCode = tracking.routeCode;
    final destinations = map.customRouteDestinations;
    final way = map.customWay;
    final stationInfo = tracking.routeStationInfo;
    final speed = tracking.currentSpeed;
    final delay = tracking.delayMinutes;
    final hasBusPosition = tracking.hasBusPosition;
    final hasStationInfo = tracking.hasStationInfo;
    final hasStops = stationInfo != null && stationInfo.stops.isNotEmpty;

    final destination = destinations == null || destinations.isEmpty
        ? ''
        : destinations[(way == Way.back && destinations.length > 1) ? 1 : 0];

    final occupancyOk = stationInfo != null &&
        stationInfo.passangers.inBus < stationInfo.passangers.totalCapacity;

    return Container(
      width: 230,
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: line + destination.
          Skeletonizer(
            enabled: routeCode == null || destinations == null,
            child: Row(
              children: [
                if (routeCode != null)
                  IconTheme(
                    data: IconThemeData(color: scheme.primary, size: 20),
                    child: getIconFromLineCode(routeCode),
                  ),
                const SizedBox(width: 6),
                Text(
                  routeCode ?? '000',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_right_alt, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    destination.isEmpty ? 'Destination' : destination,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 12),
          // Occupancy + speed.
          Skeletonizer(
            enabled: !hasStationInfo,
            child: _Stat(
              icon: Icons.people,
              text:
                  "${stationInfo?.passangers.inBus ?? '-'} / ${stationInfo?.passangers.totalCapacity ?? '-'}",
              color: hasStationInfo && !occupancyOk ? scheme.error : null,
            ),
          ),
          const SizedBox(height: 4),
          Skeletonizer(
            enabled: !hasBusPosition,
            child: _Stat(
              icon: Icons.speed,
              text: "${speed ?? '-'} km/h",
            ),
          ),
          // Only once the bus has reached a stop, and only when it was actually
          // behind: "on time" is the assumption, so saying so adds a row
          // without adding information.
          if (delay != null && delay > 0) ...[
            const SizedBox(height: 4),
            _Stat(
              icon: Icons.schedule,
              text: AppLocalizations.of(context)!.minutesLate(delay),
              color: scheme.error,
            ),
          ],
          const SizedBox(height: 4),
          // Next + final stop, the final one with the time it gets there.
          Skeletonizer(
            enabled: !hasStationInfo,
            child: _Stat(
              icon: Icons.location_on,
              text: hasStops ? stationInfo.stops.first.stopName : '-',
            ),
          ),
          const SizedBox(height: 4),
          Skeletonizer(
            enabled: !hasStationInfo,
            child: _Stat(
              icon: Icons.flag,
              text: hasStops ? _finalStopLabel(stationInfo.stops.last) : '-',
            ),
          ),
        ],
      ),
    );
  }
}

/// The final stop with the time the bus reaches it.
///
/// Prefers the live estimate over the timetable, and shows the name alone if
/// neither is usable. `scheduledArrival` carries a placeholder date, so only
/// its time of day means anything.
String _finalStopLabel(StationOnRoute stop) {
  final arrival = stop.estimatedArrival ?? stop.scheduledArrival;
  return "${stop.stopName} · ${DateFormat.Hm().format(arrival)}";
}

/// A single icon + text stat line used inside the status panel.
class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: effectiveColor),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: effectiveColor),
          ),
        ),
      ],
    );
  }
}
