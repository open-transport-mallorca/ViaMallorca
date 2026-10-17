import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:via_mallorca/components/station_line_labels/station_line_labels_view.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';

class TripStops extends StatelessWidget {
  const TripStops({
    super.key,
    required this.stops,
    required this.stations,
    required this.boardingStationId,
    required this.color,
    required this.onStopTap,
  });

  final List<StationOnRoute> stops;
  final List<Station> stations;
  final int? boardingStationId;
  final Color color;
  final void Function(Station station) onStopTap;

  /// Matched on the public code as well as the internal id: the two lists
  /// come from different endpoints, and the code is the stabler key
  Station? _stationFor(StationOnRoute stop) {
    for (final station in stations) {
      if (station.id == stop.stopId || station.code == stop.stopCode) {
        return station;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < stops.length; i++)
          _TripStopRow(
            stop: stops[i],
            station: _stationFor(stops[i]),
            isBoarding: stops[i].stopId == boardingStationId,
            isLast: i == stops.length - 1,
            color: color,
            onTap: onStopTap,
          ),
      ],
    );
  }
}

class _TripStopRow extends StatelessWidget {
  const _TripStopRow({
    required this.stop,
    required this.station,
    required this.isBoarding,
    required this.isLast,
    required this.color,
    required this.onTap,
  });

  final StationOnRoute stop;
  final Station? station;
  final bool isBoarding;
  final bool isLast;
  final Color color;
  final void Function(Station station) onTap;

  static const double _lineWidth = 3;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final station = this.station;
    final arrival = stop.estimatedArrival ?? stop.scheduledArrival;
    final emphasised = isBoarding || isLast;
    final dotColor = isBoarding ? scheme.tertiary : color;
    final dotSize = emphasised ? 16.0 : 11.0;

    return InkWell(
      onTap: station == null ? null : () => onTap(station),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 64,
              child: Center(
                child: Text(
                  DateFormat.Hm().format(arrival),
                  style: TextStyle(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontWeight:
                        emphasised ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  // The line above the first stop runs back to the bus
                  Expanded(child: Container(width: _lineWidth, color: color)),
                  Container(
                    width: dotSize,
                    height: dotSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: emphasised ? dotColor : scheme.surface,
                      border: Border.all(color: dotColor, width: 3),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: _lineWidth,
                      color: isLast ? Colors.transparent : color,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 20, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: [
                    Text(
                      stop.stopName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            emphasised ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    if (isBoarding)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: scheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          l10n.yourStop,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                    if (station != null) StationLineLabels(station: station),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
