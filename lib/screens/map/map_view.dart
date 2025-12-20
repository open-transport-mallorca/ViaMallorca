import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:via_mallorca/apis/notification.dart';
import 'package:via_mallorca/cache/cache_manager.dart';
import 'package:via_mallorca/components/bottom_sheets/station/station_view.dart';
import 'package:via_mallorca/components/map/bus_info.dart';
import 'package:via_mallorca/components/map/bus_tracker.dart';
import 'package:via_mallorca/components/map/loading_overlay.dart';
import 'package:via_mallorca/components/map/route_way_switcher.dart';
import 'package:via_mallorca/components/map/untrack_buttons.dart';
import 'package:via_mallorca/components/map/update_location_buttons.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/providers/navigation_provider.dart';
import 'package:via_mallorca/providers/notifications_provider.dart';
import 'package:via_mallorca/providers/tracking_provider.dart';
import 'package:via_mallorca/utils/adapt_color.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:via_mallorca/utils/dark_tile_builder.dart';

import 'map_viewmodel.dart';

enum PolylineType { way, back }

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final QuickActions quickActions = QuickActions();
  List<ConnectivityResult> connectivityResults = [];
  late StreamSubscription<List<ConnectivityResult>> connectivitySubscription;

  @override
  void initState() {
    super.initState();

    connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> result) {
      connectivityResults = result;
    });

    NotificationApi.onNotificationTap = (String? payload) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        resolveNotificationPayload(context, payload);
        setState(() {});
      });
    };

    quickActions
        .initialize((String shortcut) => resolveTilePayload(context, shortcut));

    // Handle payload if it came before `onNotificationTap` was set
    NotificationApi.maybeHandlePendingPayload();
  }

  @override
  void dispose() {
    connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> resolveTilePayload(BuildContext context, String? payload) async {
    if (payload == null) return;
    if (payload.startsWith('station_')) {
      try {
        final cachedStations = await CacheManager.getAllStations();

        final stationCode = payload.substring('station_'.length);
        final station = cachedStations.firstWhere(
          (s) => s.code == int.parse(stationCode),
          orElse: () => throw Exception("Station not found"),
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          jumpToStation(station, null);
        });
      } catch (e) {
        debugPrint("Error resolving tile payload: $e");
      }
    }
  }

  Future<void> resolveNotificationPayload(
      BuildContext context, String? payload) async {
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
          jumpToStation(station, viaPayload.tripId);
        });
      } catch (e) {
        debugPrint("Error parsing notification payload: $e");
      }
    }
  }

  void jumpToStation(Station station, int? tripId) {
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
        highlightedDepartureId: tripId,
      ),
    );
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
                      retinaMode: RetinaMode.isHighDensity(context) &&
                          connectivityResults.contains(ConnectivityResult.wifi),
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
                  BusTracker()
                ],
              ),
              // Bus Info Container
              IgnorePointer(child: BusInfo()),

              // Bottom Buttons
              Align(alignment: Alignment.bottomLeft, child: UntrackButtons()),

              // Custom Route Way Switcher
              if ((mapProvider.customRouteDestinations != null &&
                      mapProvider.customRouteDestinations!.isNotEmpty) &&
                  trackingProvider.currentLocation == null)
                Align(
                    alignment: Alignment.bottomLeft, child: RouteWaySwitcher()),

              // Update location button
              Align(
                  alignment: Alignment.bottomRight,
                  child: UpdateLocationButtons()),

              if (mapProvider.loadingProgress < 1) LoadingOverlay()
            ]);
          },
        );
      }),
    );
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
}
