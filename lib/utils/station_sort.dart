import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';

class StationSort {
  static List<Station> sortByDistance(
      List<Station> stations, Position locationData) {
    // Calculate distance for each station using a custom comparator
    stations.sort((a, b) {
      // Calculate distances using the Haversine formula for accuracy
      final double distanceToStationA = calculateDistance(
        lon1: locationData.longitude,
        lat1: locationData.latitude,
        lon2: a.long,
        lat2: a.lat,
      );

      final double distanceToStationB = calculateDistance(
        lon1: locationData.longitude,
        lat1: locationData.latitude,
        lon2: b.long,
        lat2: b.lat,
      );

      // Return a comparison for sorting
      return distanceToStationA.compareTo(distanceToStationB);
    });

    return stations;
  }
}

/// Calculate distance using Haversine formula
double calculateDistance(
    {required double lon1,
    required double lat1,
    required double lon2,
    required double lat2}) {
  const double R = 6371e3; // Earth radius in meters
  final double dLat = _toRadians(lat2 - lat1);
  final double dLon = _toRadians(lon2 - lon1);
  final double a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(lat1)) *
          cos(_toRadians(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);
  final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
  final double distance = R * c;
  return distance;
}

double _toRadians(double degrees) {
  return degrees * pi / 180;
}
