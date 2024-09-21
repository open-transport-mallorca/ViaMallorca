import 'package:geolocator/geolocator.dart';

/// A class that provides methods for interacting with location services.
class LocationApi {
  LocationPermission permission = LocationPermission.denied;

  /// Checks the permission status for accessing the device's location.
  ///
  /// Returns the current permission status.
  Future<LocationPermission> checkPermission() async {
    permission = await Geolocator.checkPermission();
    return permission;
  }

  /// Requests permission to access the device's location.
  ///
  /// Returns `true` if the permission is granted, `false` otherwise.
  Future<bool> requestPermission() async {
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        permission = LocationPermission.deniedForever;
      }
    }

    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Retrieves the current device location.
  ///
  /// Returns the current device position.
  Future<Position> getCurrentLocation() async {
    return await Geolocator.getCurrentPosition();
  }
}
