import 'package:flutter/material.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:via_mallorca/screens/station_details/station_details_view.dart';
import 'package:via_mallorca/utils/stop_restrictions.dart';

/// The stops of one direction of a line, in order, as a timeline.
///
/// Hand-rolled rather than built on the `timelines` package so that the row
/// height follows its content: stops carrying a boarding restriction are taller
/// than plain ones, and the connector has to stretch to match.
class RouteStopsTimeline extends StatelessWidget {
  const RouteStopsTimeline({
    super.key,
    required this.stations,
    required this.color,
    this.restrictions = const {},
  });

  final List<Station> stations;

  /// The line's colour, already adapted for the current theme.
  final Color color;

  /// Boarding restrictions by stop id, from [stopRestrictions].
  ///
  /// Passed in rather than read off each [Station] because the subline being
  /// drawn usually does not carry the flags itself.
  final Map<int, StopRestriction> restrictions;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < stations.length; i++) ...[
          // A header whenever the locality changes rather than one per distinct
          // town: a route can leave a town and come back to it, and the stops
          // should stay in running order when it does.
          if (stations[i].town != null &&
              (i == 0 || stations[i - 1].town != stations[i].town))
            _TownHeader(name: stations[i].town!, color: color),
          _StopRow(
            station: stations[i],
            color: color,
            restriction: restrictions[stations[i].id],
            isFirst: i == 0,
            isLast: i == stations.length - 1,
          ),
        ],
      ],
    );
  }
}

/// The locality a run of stops sits in.
class _TownHeader extends StatelessWidget {
  const _TownHeader({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Keeps the line running through the header, so the route reads as
        // continuous rather than broken into blocks.
        SizedBox(
          width: _Connector.width,
          child: Center(
            child: Container(
              width: _Connector.lineWidth,
              height: 28,
              color: color,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(
              name.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.station,
    required this.color,
    required this.restriction,
    required this.isFirst,
    required this.isLast,
  });

  final Station station;
  final Color color;
  final StopRestriction? restriction;
  final bool isFirst;
  final bool isLast;

  /// Both ends of the line get a larger, filled marker.
  bool get _isTerminus => isFirst || isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Connector(
            color: color,
            isFirst: isFirst,
            isLast: isLast,
            isTerminus: _isTerminus,
          ),
          Expanded(
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StationDetailsScreen(station: station),
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      station.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            _isTerminus ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    if (restriction != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: _RestrictionChip(
                          label: restriction == StopRestriction.dropOffOnly
                              ? l10n.dropOffOnly
                              : l10n.pickUpOnly,
                          icon: restriction == StopRestriction.dropOffOnly
                              ? Icons.exit_to_app
                              : Icons.login,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Center(
              child: Text(
                station.code,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The dot and the line segments above and below it.
class _Connector extends StatelessWidget {
  const _Connector({
    required this.color,
    required this.isFirst,
    required this.isLast,
    required this.isTerminus,
  });

  final Color color;
  final bool isFirst;
  final bool isLast;
  final bool isTerminus;

  /// Shared with [_TownHeader] so the line stays in one column.
  static const double width = 32;
  static const double lineWidth = 3;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dotSize = isTerminus ? 16.0 : 11.0;

    return SizedBox(
      width: width,
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: lineWidth,
              color: isFirst ? Colors.transparent : color,
            ),
          ),
          Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // Termini read as solid endpoints; intermediate stops as beads
              // threaded onto the line.
              color: isTerminus ? color : scheme.surface,
              border: Border.all(color: color, width: 3),
            ),
          ),
          Expanded(
            child: Container(
              width: lineWidth,
              color: isLast ? Colors.transparent : color,
            ),
          ),
        ],
      ),
    );
  }
}

class _RestrictionChip extends StatelessWidget {
  const _RestrictionChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Icon(icon, size: 13, color: scheme.onTertiaryContainer),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: scheme.onTertiaryContainer),
          ),
        ],
      ),
    );
  }
}
