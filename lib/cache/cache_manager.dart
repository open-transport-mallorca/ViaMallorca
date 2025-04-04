import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';

/// Cache manager for the app.
///
/// This class is used to cache data in the app.
/// as some data is not updated frequently, it is better to cache it.
/// Spanish servers are notoriously unstable and slow, so caching data
/// is a good idea.
class CacheManager {
  static SharedPreferences? _prefs;

  /// Initialize the cache manager.
  ///
  /// This method should be called before any other method in this class.
  /// Usually called in the main method.
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Get the expiry date for a specific resource.
  ///
  /// This method returns the expiry date of the specific resource cache.
  /// If the cache is expired, the data should be fetched again.
  /// If the expiry date is not set, it is assumed that the cache is expired.
  ///
  /// [resourceName] is the name of the resource, e.g., 'stations', 'lines', or 'lines_123'.
  static Future<DateTime> getExpiry(String resourceName) async {
    final String? expiry = _prefs?.getString('expiry_$resourceName');
    if (expiry != null) {
      return DateTime.parse(expiry);
    }
    return DateTime.now().subtract(
        const Duration(days: 1)); // Return a past date to force refresh
  }

  /// Set the expiry date for a specific resource.
  ///
  /// This method sets the expiry date of the specific resource cache.
  ///
  /// [resourceName] is the name of the resource, e.g., 'stations', 'lines', or 'lines_123'.
  /// [expiry] is the DateTime when the cache should expire.
  static Future<void> setExpiry(String resourceName, DateTime expiry) async {
    await _prefs?.setString('expiry_$resourceName', expiry.toIso8601String());
  }

  /// Get all stations from the cache.
  /// Only returns the overview of the stations.
  /// Not the lines that go through them.
  static Future<List<Station>> getAllStations() async {
    List<Station> stations = [];
    const String resourceName = 'stations';
    bool shouldRefresh =
        (await getExpiry(resourceName)).isBefore(DateTime.now());
    if (shouldRefresh) {
      return [];
    }
    final List<String>? data = _prefs?.getStringList(resourceName);
    if (data != null) {
      for (var station in data) {
        stations.add(Station.fromJson(jsonDecode(station)));
      }
    }
    return stations;
  }

  /// Set all stations in the cache.
  /// Only the overview of the stations.
  static Future<void> setAllStations(List<Station> stations) async {
    const String resourceName = 'stations';
    List<String> data = [];
    for (var station in stations) {
      data.add(jsonEncode(Station.toJson(station)));
    }
    await _prefs?.setStringList(resourceName, data);
    DateTime expiry = DateTime.now().add(const Duration(days: 2));
    await setExpiry(resourceName, expiry);
  }

  /// Get the lines that pass through a station from the cache.
  ///
  /// The [stationCode] is the code of the station.
  /// The stationCode is the `code`, not `id` of the station.
  /// The lines are returned as a list of [RouteLine] objects.
  static Future<List<RouteLine>> getLines(int stationCode) async {
    final String resourceName = 'lines_$stationCode';
    bool shouldRefresh =
        (await getExpiry(resourceName)).isBefore(DateTime.now());
    if (shouldRefresh) {
      return [];
    }
    List<RouteLine> lines = [];
    final data = _prefs?.getStringList(resourceName) ?? [];
    for (var line in data) {
      lines.add(RouteLine.fromJson(jsonDecode(line)));
    }
    return lines;
  }

  /// Set the lines that pass through a station in the cache.
  ///
  /// The [stationCode] is the code of the station.
  /// The stationCode is the `code`, not `id` of the station.
  /// The [lines] are the lines that pass through the station.
  /// The lines are a list of [RouteLine] objects.
  static Future<void> setLines(int stationCode, List<RouteLine> lines) async {
    final String resourceName = 'lines_$stationCode';
    List<String> data = [];
    for (var line in lines) {
      data.add(jsonEncode(RouteLine.toJson(line)));
    }
    await _prefs?.setStringList(resourceName, data);
    DateTime expiry = DateTime.now().add(const Duration(days: 2));
    await setExpiry(resourceName, expiry);
  }

  /// Get all lines from the cache.
  /// Doesn't contain the stations that the lines go through.
  static Future<List<RouteLine>> getAllLines() async {
    const String resourceName = 'lines';
    if ((await getExpiry(resourceName)).isBefore(DateTime.now())) {
      return [];
    }
    List<RouteLine> lines = [];
    final List<String>? data = _prefs?.getStringList(resourceName);
    if (data != null) {
      for (var line in data) {
        lines.add(RouteLine.fromJson(jsonDecode(line)));
      }
    }
    return lines;
  }

  /// Set all lines in the cache.
  /// Doesn't contain the stations that the lines go through.
  static Future<void> setAllLines(List<RouteLine> lines) async {
    const String resourceName = 'lines';
    List<String> data = [];
    for (var line in lines) {
      data.add(jsonEncode(RouteLine.toJson(line)));
    }
    await _prefs?.setStringList(resourceName, data);
    DateTime expiry = DateTime.now().add(const Duration(days: 2));
    await setExpiry(resourceName, expiry);
  }

  /// Clear the cache. Remove all cached data.
  /// The data will be fetched again when needed.
  ///
  /// Used for debugging purposes. Not recommended for production.
  static Future<void> clearCache() async {
    final prefs = _prefs;
    if (prefs == null) return;

    // Get all keys
    final keys = prefs.getKeys();

    // Remove all stations and lines data
    await prefs.remove('stations');

    // Remove all line-specific data
    for (final key in keys) {
      if (key.startsWith('lines_') ||
          key == 'lines' ||
          key.startsWith('expiry_')) {
        await prefs.remove(key);
      }
    }
  }
}
