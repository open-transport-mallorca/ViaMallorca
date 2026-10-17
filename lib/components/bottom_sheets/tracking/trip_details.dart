import 'package:flutter/material.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/providers/tracking_provider.dart';
import 'package:via_mallorca/utils/line_icon.dart';

class TripDetails extends StatelessWidget {
  const TripDetails({
    super.key,
    required this.tracking,
    required this.map,
    required this.trip,
    required this.color,
  });

  final TrackingProvider tracking;
  final MapProvider map;
  final TripSummary? trip;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final trip = this.trip;

    final destinations = map.customRouteDestinations;
    final destination = trip?.finalStop ??
        (destinations == null || destinations.isEmpty
            ? null
            : destinations[
                map.customWay == Way.back && destinations.length > 1 ? 1 : 0]);

    final details = [
      if (trip?.phase == TripPhase.riding && trip?.nextStop != null)
        l10n.trackingNextStop(trip!.nextStop!),
      if (trip?.phase == TripPhase.approaching && trip?.stopsLeft != null)
        l10n.stopsAway(trip!.stopsLeft!),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Row(
            children: [
              _LineBadge(code: tracking.routeCode, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  destination ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium,
                ),
              ),
            ],
          ),
          if (trip != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.trackingArrivingAt(trip.target),
                style: text.titleMedium,
              ),
            ),
          if (details.isNotEmpty)
            Text(
              details.join('  •  '),
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

class _LineBadge extends StatelessWidget {
  const _LineBadge({required this.code, required this.color});

  final String? code;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Icon(
            code == null
                ? Icons.directions_bus
                : getIconDataFromLineCode(code!),
            size: 18,
            color: onColor,
          ),
          Text(
            code ?? '',
            style: TextStyle(
              color: onColor,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
