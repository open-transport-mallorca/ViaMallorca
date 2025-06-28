import 'package:flutter/foundation.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:via_mallorca/apis/notification.dart';
import 'package:via_mallorca/cache/cache_manager.dart';
import 'package:via_mallorca/components/bottom_sheets/station/station_view.dart';
import 'package:via_mallorca/components/bottom_sheets/timeline/timeline_view.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/providers/navigation_provider.dart';
import 'package:via_mallorca/providers/notifications_provider.dart';
import 'package:via_mallorca/providers/tracking_provider.dart';
import 'package:via_mallorca/utils/adapt_color.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:via_mallorca/utils/dark_tile_builder.dart';

import 'map_viewmodel.dart';

enum PolylineType { way, back }

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final trackingProvider =
        Provider.of<TrackingProvider>(context, listen: false);

    if (state == AppLifecycleState.resumed) {
      trackingProvider.resume();
    } else if (state == AppLifecycleState.paused) {
      trackingProvider.pause();
    }
  }

  @override
  void initState() {
    super.initState();

    NotificationApi.onNotificationTap = (String? payload) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        resolvePayload(context, payload);
      });
    };

    // Handle payload if it came before `onNotificationTap` was set
    NotificationApi.maybeHandlePendingPayload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> resolvePayload(BuildContext context, String? payload) async {
    if (payload != null && payload.contains(',')) {
      try {
        Provider.of<NotificationsProvider>(context, listen: false)
            .reloadNotifications(); // Refreshes the UI
        final viaPayload = ViaNotificationPayload.fromString(payload);

        // We can assume that at this stage the stations are cached
        // as the user had to open the app at least once to plan a reminder
        final cachedStations = await CacheManager.getAllStations();

        final station = cachedStations.firstWhere(
          (s) => s.id == viaPayload.stationId,
          orElse: () => throw Exception("Station not found"),
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          Provider.of<NavigationProvider>(context, listen: false).setIndex(1);
          Provider.of<MapProvider>(context, listen: false).updateLocation(
            LatLng(station.lat, station.long),
            18,
          );
          showBottomSheet(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(10.0)),
            ),
            context: context,
            builder: (_) => StationSheet(
              station: station,
              highlightedDepartureId: viaPayload.tripId,
            ),
          );
        });
      } catch (e) {
        debugPrint("Error parsing notification payload: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MapViewModel()..initialize(context, this),
      child: Consumer2<MapProvider, TrackingProvider>(
          builder: (context, mapProvider, trackingProvider, _) {
        return Consumer<MapViewModel>(
          builder: (context, viewModel, _) {
            if (mapProvider.loadingProgress < 1.0) {
              return Center(
                child: CircularProgressIndicator(
                  value: mapProvider.loadingProgress,
                ),
              );
            }

            return Stack(children: [
              FlutterMap(
                mapController: mapProvider.mapController!.mapController,
                options: MapOptions(
                    interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                    initialZoom: 9,
                    initialCenter: const LatLng(39.607331, 2.983704)),
                children: [
                  TileLayer(
                      retinaMode: !kDebugMode,
                      tileProvider: CancellableNetworkTileProvider(),
                      tileBuilder:
                          Theme.of(context).brightness == Brightness.dark
                              ? (context, tileWidget, tile) =>
                                  monochromeDarkMode(context, tileWidget, tile)
                              : null,
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'es.opentransportmallorca.via'),

                  // Highlighted Route Polylines
                  if (mapProvider.customRoutes != null &&
                      (mapProvider.customRoutes![0].isNotEmpty &&
                          mapProvider.customRoutes![1].isNotEmpty))
                    _highlightedRoutePolylines(context),

                  // Highlighted Route Stations
                  if (mapProvider.customRoutes != null &&
                      mapProvider.customStations.isNotEmpty)
                    _highlightedRouteStations(context),

                  // Stations Markers
                  if (mapProvider.customRoutes == null)
                    _stationsMarkers(context, viewModel),

                  // My Location Marker
                  if (viewModel.locationPermission ==
                          LocationPermission.whileInUse ||
                      viewModel.locationPermission == LocationPermission.always)
                    IgnorePointer(
                      child: CurrentLocationLayer(
                        alignPositionStream:
                            viewModel.alignPositionStreamController.stream,
                        alignPositionOnUpdate: viewModel.alignPositionOnUpdate,
                      ),
                    ),

                  // Bus Tracker Marker
                  _busTracker(context)
                ],
              ),
              // Bus Info Container
              _busInfo(context),

              // Bottom Buttons
              _untrackButtons(context),

              // Custom Route Way Switcher
              if ((mapProvider.customRouteDestinations != null &&
                      mapProvider.customRouteDestinations!.isNotEmpty) &&
                  trackingProvider.currentLocation == null)
                _routeWaySwitcher(context),

              // Update location button
              _updateLocationButtons(context, viewModel),

              if (mapProvider.loadingProgress < 1)
                _loadingOverlay(context, mapProvider)
            ]);
          },
        );
      }),
    );
  }

  Widget _updateLocationButtons(BuildContext context, MapViewModel viewModel) {
    final trackingProvider =
        Provider.of<TrackingProvider>(context, listen: false);

    return Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: [
              if (trackingProvider.currentLocation != null)
                // Move to Bus
                FloatingActionButton(
                    mini: true,
                    onPressed: () {
                      viewModel.moveToLocation(
                          context: context,
                          position: trackingProvider.currentLocation!,
                          zoom: 15);
                    },
                    child: const Icon(Icons.directions_bus)),

              // Move to Current Location
              FloatingActionButton(
                  onPressed: () async =>
                      viewModel.moveToCurrentLocation(context),
                  child: Icon((viewModel.locationPermission ==
                              LocationPermission.whileInUse ||
                          viewModel.locationPermission ==
                              LocationPermission.always)
                      ? Icons.my_location
                      : Icons.location_searching)),
            ],
          ),
        ));
  }

  Widget _stationsMarkers(BuildContext context, MapViewModel viewModel) {
    return MarkerClusterLayerWidget(
      options: MarkerClusterLayerOptions(
        showPolygon: false,
        builder: (context, markers) {
          return Container(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.lightGreen),
            child: Center(
              child: Text(
                markers.length.toString(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
        },
        markers: viewModel.cachedStations
            .map((station) => Marker(
                  width: 50,
                  height: 50,
                  alignment: Alignment.topCenter,
                  point: LatLng(station.lat, station.long),
                  child: GestureDetector(
                    onTap: () {
                      showBottomSheet(
                          shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(10.0))),
                          context: context,
                          builder: (context) => StationSheet(station: station));
                    },
                    child: Image.asset(
                      "assets/stop_icon.png",
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _highlightedRouteStations(BuildContext context) {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    final trackingProvider =
        Provider.of<TrackingProvider>(context, listen: false);
    return MarkerLayer(
        markers: (mapProvider.customStations.length == 1
                ? mapProvider.customStations[0]
                : mapProvider
                    .customStations[mapProvider.customWay == Way.way ? 0 : 1])
            .map((station) => Marker(
                  width: 40,
                  height: 40,
                  alignment: Alignment.topCenter,
                  point: LatLng(station.lat, station.long),
                  child: GestureDetector(
                    onTap: () {
                      showBottomSheet(
                          shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(10.0))),
                          context: context,
                          builder: (context) => StationSheet(station: station));
                    },
                    child: ColorFiltered(
                      colorFilter: ColorFilter.matrix(
                          ColorUtils.createHueShiftMatrix(
                              station.id == trackingProvider.trackingFromStation
                                  ? 100
                                  : 0)),
                      child: Image.asset(
                        "assets/stop_icon.png",
                        height: 50,
                      ),
                    ),
                  ),
                ))
            .toList());
  }

  Widget _highlightedRoutePolylines(BuildContext context) {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    return PolylineLayer(polylines: [
      mapProvider.customRoutes!.length == 1
          ? mapProvider.customRoutes![
              Theme.of(context).colorScheme.brightness == Brightness.light
                  ? 0
                  : 1][0]
          : mapProvider.customRoutes![
                  Theme.of(context).colorScheme.brightness == Brightness.light
                      ? 0
                      : 1][
              (mapProvider.customWay == null ||
                      mapProvider.customWay == Way.way)
                  ? 0
                  : 1]
    ]);
  }

  Widget _routeWaySwitcher(BuildContext context) {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    final trackingProvider =
        Provider.of<TrackingProvider>(context, listen: false);
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color:
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)),
          child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    trackingProvider.routeCode ?? "",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (trackingProvider.currentLocation != null)
                    const SizedBox(width: 10),
                  ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: FittedBox(
                        child: Text(mapProvider.customRouteDestinations != null
                            ? mapProvider.customRouteDestinations![
                                mapProvider.customWay == Way.way ? 0 : 1]
                            : ""),
                      )),
                  const SizedBox(
                    width: 10,
                  ),
                  if (trackingProvider.currentLocation == null &&
                      (mapProvider.customRouteDestinations ?? []).length > 1)
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 300),
                      turns: (mapProvider.customWay ?? Way.way) == Way.way
                          ? 0
                          : 0.5,
                      child: IconButton(
                        onPressed: () {
                          mapProvider.setCustomWay(
                              mapProvider.customWay == Way.way
                                  ? Way.back
                                  : Way.way);
                        },
                        icon: const Icon(Icons.compare_arrows_rounded),
                      ),
                    ),
                ],
              )),
        ),
      ),
    );
  }

  Widget _busTracker(BuildContext context) {
    final trackingProvider =
        Provider.of<TrackingProvider>(context, listen: false);

    return AnimatedMarkerLayer(markers: [
      if (trackingProvider.currentLocation != null)
        AnimatedMarker(
            width: 120,
            height: 120,
            point: LatLng(trackingProvider.currentLocation!.latitude,
                trackingProvider.currentLocation!.longitude),
            builder: (_, animation) {
              return Container(
                  width: 60 * animation.value,
                  height: 60 * animation.value,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context)
                          .colorScheme
                          .tertiaryContainer
                          .withValues(alpha: 0.9)),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.asset(
                        trackingProvider.lineType == LineType.bus ||
                                trackingProvider.lineType == LineType.unknown ||
                                trackingProvider.lineType == null
                            ? "assets/bus.png"
                            : "assets/train.png",
                        height: 50 * animation.value),
                  ));
            })
    ]);
  }

  Widget _busInfo(BuildContext context) {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    final trackingProvider =
        Provider.of<TrackingProvider>(context, listen: false);

    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: trackingProvider.currentLocation == null ? 0 : 1,
        child: Align(
            alignment: Alignment.topRight,
            child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  width: 250,
                  height: 150,
                  decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Builder(builder: (context) {
                      final routeCode = trackingProvider.routeCode;
                      final destinations = mapProvider.customRouteDestinations;
                      final way = mapProvider.customWay;
                      final stationInfo = trackingProvider.routeStationInfo;
                      final speed = trackingProvider.currentSpeed;

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Skeletonizer(
                            enabled: routeCode == null || destinations == null,
                            child: Text(
                              "${routeCode ?? ''} - ${destinations != null ? destinations[way == Way.way ? 0 : 1] : ''}",
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Skeletonizer(
                            enabled: stationInfo == null,
                            child: Text(
                              "${AppLocalizations.of(context)!.passengers}: ${stationInfo?.passangers.inBus ?? '-'} / ${stationInfo?.passangers.totalCapacity ?? '-'}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: (stationInfo != null &&
                                        stationInfo.passangers.inBus <
                                            stationInfo
                                                .passangers.totalCapacity)
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                          Skeletonizer(
                            enabled: speed == null,
                            child: Text(
                                "${AppLocalizations.of(context)!.speed}: ${speed ?? '-'} km/h"),
                          ),
                          Skeletonizer(
                            enabled: stationInfo == null,
                            child: FittedBox(
                              child: Text(
                                "${AppLocalizations.of(context)!.nextStop}: ${stationInfo?.stops.first.stopName ?? ''}",
                              ),
                            ),
                          ),
                          Skeletonizer(
                            enabled: stationInfo == null,
                            child: FittedBox(
                              child: Text(
                                "${AppLocalizations.of(context)!.finalStop}: ${stationInfo?.stops.last.stopName ?? ''}",
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ))),
      ),
    );
  }

  Widget _untrackButtons(BuildContext context) {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    final trackingProvider =
        Provider.of<TrackingProvider>(context, listen: false);
    return Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
            padding: EdgeInsets.symmetric(
                vertical: Provider.of<TrackingProvider>(context, listen: false)
                            .currentLocation !=
                        null
                    ? 24.0
                    : 82.0,
                horizontal: 24.0),
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              // Untrack Route Button
              if (mapProvider.customRoutes != null &&
                  trackingProvider.currentLocation == null)
                ElevatedButton.icon(
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
                          color: Theme.of(context)
                              .colorScheme
                              .onTertiaryContainer),
                    )),

              // Stop Tracking Bus Button
              if (trackingProvider.currentLocation != null)
                ElevatedButton.icon(
                    onPressed: () async {
                      await context.read<TrackingProvider>().stopTracking();
                      mapProvider.setCustomPolylines(null);
                      mapProvider.setCustomStations([]);
                      mapProvider.setCustomWay(null);
                      mapProvider.setCustomRouteDestinations(null);
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(
                          Theme.of(context).colorScheme.errorContainer),
                    ),
                    icon: Icon(Icons.stop,
                        color: Theme.of(context).colorScheme.error),
                    label: Text(
                      AppLocalizations.of(context)!.stopTracking,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    )),

              // Stop Timeline
              if (trackingProvider.stationsOnRoute != null)
                ElevatedButton.icon(
                  label: Text(AppLocalizations.of(context)!.stationsOnRoute),
                  icon: const Icon(Icons.timeline),
                  onPressed: () {
                    showBottomSheet(
                        context: context,
                        builder: (context) => const TimelineSheet());
                  },
                )
            ])));
  }

  Widget _loadingOverlay(BuildContext context, MapProvider mapProvider) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5)),
      child: Center(
          child: SizedBox(
              width: 100,
              height: 100,
              child: Column(
                children: [
                  CircularProgressIndicator(
                    value: mapProvider.loadingProgress,
                    strokeWidth: 5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 8),
                  Text(AppLocalizations.of(context)!.loading),
                ],
              ))),
    );
  }
}
