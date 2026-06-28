import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/providers/navigation_provider.dart';
import 'package:via_mallorca/providers/tracking_provider.dart';
import 'package:via_mallorca/utils/adapt_color.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';

/// A provider class that manages the map-related functionality.
class MapProvider extends ChangeNotifier {
  AnimatedMapController? mapController;
  List<List<Polyline>>? customRoutes;
  List<List<Station>> customStations = [];
  List<String>? customRouteDestinations;
  Way? customWay;

  /// The currently open station bottom sheet, if any. Tracked so it can be
  /// dismissed when navigating away to the map (e.g. when opening a route or a
  /// direction from the route details screen).
  PersistentBottomSheetController? _stationSheet;

  /// The loading progress, represented as a double value.
  ///
  /// The value ranges from 0 to 1.
  double loadingProgress = 1;

  /// Registers the [controller] of a freshly shown station bottom sheet so it
  /// can later be closed via [closeStationSheet]. Self-clears when the sheet is
  /// dismissed by any other means (drag, back button, tab switch).
  void registerStationSheet(PersistentBottomSheetController controller) {
    _stationSheet = controller;
    controller.closed.whenComplete(() {
      if (_stationSheet == controller) _stationSheet = null;
    });
  }

  /// Closes the open station bottom sheet if there is one; a no-op otherwise.
  void closeStationSheet() {
    _stationSheet?.close();
    _stationSheet = null;
  }

  /// Sets the custom polylines for the map.
  ///
  /// The [polylines] parameter is a list of lists of [Polyline] objects.
  /// Each inner list represents a separate route.
  void setCustomPolylines(List<List<Polyline>>? polylines) {
    customRoutes = polylines;
    notifyListeners();
  }

  /// Sets the custom stations for the map.
  ///
  /// The [stations] parameter is a list of lists of [Station] objects.
  /// Each inner list represents a separate route.
  void setCustomStations(List<List<Station>> stations) {
    customStations = stations;
    notifyListeners();
  }

  /// Sets the map controller.
  ///
  /// The [controller] parameter is an [AnimatedMapController] object.
  void setMapController(AnimatedMapController controller) {
    mapController = controller;
  }

  /// Updates the location on the map.
  ///
  /// The [location] parameter is the new location as a [LatLng] object.
  /// The [zoom] parameter is an optional double value representing the zoom level.
  void updateLocation(LatLng location, [double? zoom]) {
    mapController!.animateTo(
        dest: location, zoom: zoom ?? mapController!.mapController.camera.zoom);
  }

  /// Adjusts the camera view to fit the specified bounds.
  ///
  /// Uses an animated transition to move the camera to the position defined by [cameraFit].
  void fitToBounds(CameraFit cameraFit) {
    mapController!.animatedFitCamera(cameraFit: cameraFit);
  }

  /// Sets the custom way for the map.
  ///
  /// The [way] parameter is a [Way] object representing the custom way.
  void setCustomWay(Way? way) {
    customWay = way;
    notifyListeners();
  }

  /// Sets the custom route destinations for the map.
  ///
  /// The [destinations] parameter is a list of strings representing the destinations of the custom routes.
  void setCustomRouteDestinations(List<String>? destinations) {
    customRouteDestinations = destinations;
    notifyListeners();
  }

  /// Views a route on the map.
  ///
  /// The [line] parameter is a [RouteLine] object representing the route line to be viewed.
  /// The [context] parameter is the build context.
  /// The [isTracking] parameter indicates whether tracking is enabled.
  /// The [initialWay] parameter pre-selects which direction is shown first; the
  /// way switcher can still flip to the other one. Defaults to [Way.way].
  Future<void> viewRoute(RouteLine line, BuildContext context,
      {bool? isTracking, Way? initialWay}) async {
    final trackingProvider =
        Provider.of<TrackingProvider>(context, listen: false);
    final navigationProvider =
        Provider.of<NavigationProvider>(context, listen: false);

    customRouteDestinations = [];
    customRoutes = [[], []];

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    if (trackingProvider.currentLocation != null) {
      trackingProvider.stopTracking();
    }

    setMapLoadingProgress(0);

    if (navigationProvider.currentIndex != 3) {
      navigationProvider.setIndex(1);
    }
    FocusScope.of(context).unfocus();
    final sublines = await RouteLinesApi.getSublines(line);

    setMapLoadingProgress(0.3);

    // Only flip to the back direction when the line actually has more than one
    // subline; a loop has a single polyline at index 0.
    customWay = (sublines.length > 1 ? initialWay : null) ?? Way.way;

    for (Subline subline in sublines) {
      List<LatLng> points = [];
      final route = await RouteLinesApi.getPath(subline);
      for (List<LatLng> routePath in route.paths) {
        for (LatLng point in routePath) {
          points.add(point);
        }
      }

      setMapLoadingProgress(0.6);

      customRouteDestinations!.add(route.subline.name);
      customRoutes![0].add(Polyline(
          points: points,
          strokeWidth: 3,
          color: adaptColor(Color(line.color))[0]));
      customRoutes![1].add(Polyline(
          points: points,
          strokeWidth: 3,
          color: adaptColor(Color(line.color))[1]));
    }

    List<List<Station>> routeStations = [];

    for (Subline subline in sublines) {
      List<Station> currentStations = [];
      for (Station station in subline.stations) {
        currentStations.add(station);
      }
      routeStations.add(currentStations);
    }

    setMapLoadingProgress(0.8);
    setCustomStations(routeStations);

    if (isTracking == null || !isTracking) {
      fitToBounds(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(
            customRoutes![0].expand((polyline) => polyline.points).toList(),
          ),
          padding: const EdgeInsets.all(60.0),
          maxZoom: 18,
        ),
      );
    }

    setMapLoadingProgress(1);

    notifyListeners();
  }

  /// Sets the loading progress of the map.
  ///
  /// The [progress] parameter is a double value representing the loading progress.
  void setMapLoadingProgress(double progress) {
    loadingProgress = progress;
    notifyListeners();
  }
}
