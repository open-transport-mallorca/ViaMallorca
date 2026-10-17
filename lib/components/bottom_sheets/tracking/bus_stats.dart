import 'package:flutter/material.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:via_mallorca/providers/tracking_provider.dart';

class BusStats extends StatelessWidget {
  const BusStats({super.key, required this.tracking});

  final TrackingProvider tracking;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final passengers = tracking.routeStationInfo?.passangers;
    final speed = tracking.currentSpeed;
    final full =
        passengers != null && passengers.inBus >= passengers.totalCapacity;
    // The API now sometimes reports 0 / 0, which says nothing
    // see: https://github.com/open-transport-mallorca/mallorca_transit_services/issues/15
    final noCount = passengers != null &&
        passengers.inBus == 0 &&
        passengers.totalCapacity == 0;

    return Row(
      spacing: 12,
      children: [
        if (!noCount)
          Expanded(
            child: _StatTile(
              icon: Icons.people,
              label: l10n.passengers,
              value: passengers == null
                  ? '-'
                  : '${passengers.inBus} / ${passengers.totalCapacity}',
              color: full ? scheme.error : null,
            ),
          ),
        Expanded(
          child: _StatTile(
            icon: Icons.speed,
            label: l10n.speed,
            value: speed == null ? '-' : '$speed km/h',
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final foreground = color ?? scheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        spacing: 12,
        children: [
          Icon(icon, color: color ?? scheme.onSurfaceVariant),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(color: foreground),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
