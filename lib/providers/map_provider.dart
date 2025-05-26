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

  /// The loading progress, represented as a double value.
  ///
  /// The value ranges from 0 to 1.
  double loadingProgress = 1;

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
    notifyListeners();
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
  /// The [isTracking] parameter is an optional boolean value indicating whether tracking is enabled.
  Future<void> viewRoute(RouteLine line, BuildContext context,
      [bool? isTracking]) async {
    customRouteDestinations = [];
    customRoutes = [[], []];

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    if (Provider.of<TrackingProvider>(context, listen: false).currentLocation !=
        null) {
      Provider.of<TrackingProvider>(context, listen: false).stopTracking();
    }

    setMapLoadingProgress(0);

    if (Provider.of<NavigationProvider>(context, listen: false).currentIndex !=
        3) {
      Provider.of<NavigationProvider>(context, listen: false).setIndex(1);
    }
    FocusScope.of(context).unfocus();
    final sublines = await Subline.getSublines(line);

    setMapLoadingProgress(0.3);

    customWay = Way.way;

    for (Subline subline in sublines) {
      List<LatLng> points = [];
      final route = await RoutePath.getPath(subline);
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

    var centerLat =
        (routeStations.first.first.lat + routeStations.first.last.lat) / 2;
    var centerLon =
        (routeStations.first.first.long + routeStations.first.last.long) / 2;
    var centerPoint = LatLng(centerLat, centerLon);

    if (isTracking == null || !isTracking) {
      updateLocation(centerPoint, 11);
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
