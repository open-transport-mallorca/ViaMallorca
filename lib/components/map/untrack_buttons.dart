import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/components/bottom_sheets/timeline/timeline_view.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/providers/tracking_provider.dart';

class UntrackButtons extends StatelessWidget {
  const UntrackButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<TrackingProvider, MapProvider>(
        builder: (context, trackingProvider, mapProvider, _) {
      // While tracking: a grouped control panel (timeline + stop tracking) that
      // mirrors the top-right info panel.
      if (trackingProvider.currentLocation != null) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Material(
              color:
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The socket sends an empty stop list once the bus has
                    // passed them all, which would open an empty timeline.
                    if (trackingProvider.stationsOnRoute?.isNotEmpty ??
                        false) ...[
                      _ControlRow(
                        icon: Icons.timeline,
                        label: AppLocalizations.of(context)!.stationsOnRoute,
                        onTap: () => showBottomSheet(
                          context: context,
                          builder: (context) => const TimelineSheet(),
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                    _ControlRow(
                      icon: Icons.stop,
                      label: AppLocalizations.of(context)!.stopTracking,
                      color: Theme.of(context).colorScheme.error,
                      onTap: () async {
                        await context.read<TrackingProvider>().stopTracking();
                        mapProvider.setCustomPolylines(null);
                        mapProvider.setCustomStations([]);
                        mapProvider.setCustomWay(null);
                        mapProvider.setCustomRouteDestinations(null);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      // While previewing a route (not tracking): the untrack-route button.
      if (mapProvider.customRoutes != null) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 82.0, horizontal: 24.0),
          child: ElevatedButton.icon(
              onPressed: () {
                mapProvider.setCustomPolylines(null);
                mapProvider.setCustomStations([]);
                mapProvider.setCustomWay(null);
                mapProvider.setCustomRouteDestinations(null);
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(
                    Theme.of(context).colorScheme.tertiaryContainer),
              ),
              icon: Icon(
                Icons.stop,
                color: Theme.of(context).colorScheme.onTertiaryContainer,
              ),
              label: Text(
                AppLocalizations.of(context)!.untrackRoute,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onTertiaryContainer),
              )),
        );
      }

      return const SizedBox.shrink();
    });
  }
}

/// A single tappable row (icon + label) inside the tracking control panel.
class _ControlRow extends StatelessWidget {
  const _ControlRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: effectiveColor),
            const SizedBox(width: 10),
            Text(
              label,
              style:
                  TextStyle(color: effectiveColor, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
