import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:via_mallorca/components/app_bar.dart';
import 'package:via_mallorca/components/bottom_sheets/station/departure_card.dart';
import 'package:via_mallorca/components/map/station_map_preview.dart';
import 'package:via_mallorca/components/station_line_labels/station_line_labels_view.dart';
import 'package:via_mallorca/components/warnings_summary_chip.dart';
import 'package:via_mallorca/components/station_line_labels/station_line_labels_viewmodel.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:via_mallorca/providers/favorites_provider.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/providers/navigation_provider.dart';
import 'station_details_viewmodel.dart';

class StationDetailsScreen extends StatefulWidget {
  const StationDetailsScreen({super.key, required this.station});

  final Station station;

  @override
  State<StationDetailsScreen> createState() => _StationDetailsScreenState();
}

class _StationDetailsScreenState extends State<StationDetailsScreen> {
  StationDetailsViewModel? _viewModel;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleNextDepartureUpdate();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Refreshes departures aligned to the start of each minute, like the
  /// station bottom sheet does.
  void _scheduleNextDepartureUpdate() {
    _timer?.cancel();
    final now = DateTime.now();
    final nextMinute =
        DateTime(now.year, now.month, now.day, now.hour, now.minute + 1);
    _timer = Timer(nextMinute.difference(now), () async {
      if (mounted) {
        await _viewModel?.fetchDepartures();
        _scheduleNextDepartureUpdate();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final station = widget.station;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => StationDetailsViewModel(station)..initialize(),
        ),
        // Provided above both sections so the lines are fetched once and shared
        // by the labels and the departures list.
        ChangeNotifierProvider(
          create: (_) => StationViewModel(station)..loadLines(),
        ),
      ],
      child: Consumer2<StationDetailsViewModel, FavoritesProvider>(
        builder: (context, viewModel, favorites, _) {
          _viewModel = viewModel;
          final isFavorite =
              favorites.isFavoriteStation(station.code.toString());
          return Scaffold(
            appBar: ViaAppBar(
              title: station.name,
              actions: [
                IconButton(
                  icon: Icon(isFavorite ? Icons.star : Icons.star_outline),
                  onPressed: () => isFavorite
                      ? favorites.removeFavoriteStation(station.code.toString())
                      : favorites.addFavoriteStation(station.code.toString()),
                ),
              ],
            ),
            body: SafeArea(
              child: RefreshIndicator(
                onRefresh: viewModel.initialize,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    _Header(station: station),
                    StationMapPreview(
                      station: station,
                      onTap: () => _viewOnMap(context, station),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _viewOnMap(context, station),
                              icon: const Icon(Icons.map_outlined),
                              label:
                                  Text(AppLocalizations.of(context)!.viewOnMap),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: () => launchUrl(Uri(
                                scheme: "geo",
                                path: "${station.lat},${station.long}",
                                query: "q=${station.lat},${station.long}",
                              )),
                              icon: const Icon(Icons.directions),
                              label: Text(
                                  AppLocalizations.of(context)!.openInMaps),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _LinesSection(station: station),
                    _DeparturesSection(viewModel: viewModel, station: station),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _viewOnMap(BuildContext context, Station station) {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    final navProvider = Provider.of<NavigationProvider>(context, listen: false);
    Navigator.of(context).popUntil((route) => route.isFirst);
    navProvider.setIndex(1);
    mapProvider.updateLocation(LatLng(station.lat, station.long), 18);
  }
}

/// Subtle themed header with a stop icon, name, code and reference.
class _Header extends StatelessWidget {
  const _Header({required this.station});

  final Station station;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitle = <String>[
      station.code,
      if (station.ref != null && station.ref!.isNotEmpty) station.ref!,
    ].join(' · ');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.18),
            scheme.primary.withValues(alpha: 0.03),
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.directions_bus,
                color: scheme.onPrimaryContainer, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  station.name,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style:
                      TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinesSection extends StatelessWidget {
  const _LinesSection({required this.station});

  final Station station;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: AppLocalizations.of(context)!.linesServingStop,
      icon: Icons.linear_scale_sharp,
      child: StationLineLabels(station: station),
    );
  }
}

class _DeparturesSection extends StatelessWidget {
  const _DeparturesSection({required this.viewModel, required this.station});

  final StationDetailsViewModel viewModel;
  final Station station;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final departures = viewModel.departures;

    if (viewModel.departuresError) {
      return _Section(
        title: l10n.departures,
        icon: Icons.schedule,
        child: Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: ListTile(
            title: Text(l10n.info),
            subtitle: Text(
              l10n.noDepartures,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
      );
    }

    final loaded = departures != null;
    final items = loaded ? departures : <Departure?>[null, null, null, null];
    final restrictions = context.watch<StationViewModel>().restrictionByLine;

    return _Section(
      title: l10n.departures,
      icon: Icons.schedule,
      child: Skeletonizer(
        enabled: !loaded,
        child: Column(
          children: [
            WarningsSummaryChip(
                lineCodes: items
                    .whereType<Departure>()
                    .map((d) => d.lineCode)
                    .toList()),
            for (final departure in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: departure == null
                    ? Card(
                        color:
                            Theme.of(context).colorScheme.surfaceContainerHigh,
                        child: const ListTile(
                          leading: Icon(Icons.directions_bus),
                          title: Text('Line - Destination'),
                          subtitle: Text('Scheduled: in 0 minutes'),
                        ),
                      )
                    : DepartureCard(
                        station: station,
                        departure: departure,
                        restriction: restrictions[departure.lineCode],
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A titled, icon-prefixed section, matching the route details screen.
class _Section extends StatelessWidget {
  const _Section(
      {required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
