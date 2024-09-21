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

  /// Get the expiry date of the cache.
  ///
  /// This method returns the expiry date of the cache.
  /// If the cache is expired, the data should be fetched again.
  /// The expiry date is stored in the cache.
  /// If the expiry date is not set, it is assumed that the cache is expired.
  static Future<DateTime> getExpiry() async {
    final String? expiry = _prefs?.getString('expiry');
    if (expiry != null) {
      return DateTime.parse(expiry);
    }
    return DateTime.now();
  }

  /// Set the expiry date of the cache.
  ///
  /// This method sets the expiry date of the cache.
  /// The expiry date is stored in the cache.
  static Future<void> setExpiry(DateTime expiry) async {
    await _prefs?.setString('expiry', expiry.toIso8601String());
  }

  /// Get all stations from the cache.
  /// Only returns the overview of the stations.
  /// Not the lines that go through them.
  static Future<List<Station>> getAllStations() async {
    List<Station> stations = [];
    if ((await getExpiry()).isBefore(DateTime.now())) {
      return [];
    }
    final List<String>? data = _prefs?.getStringList('stations');
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
    List<String> data = [];
    for (var station in stations) {
      data.add(jsonEncode(Station.toJson(station)));
    }
    await _prefs?.setStringList('stations', data);
    await setExpiry(DateTime.now().add(const Duration(days: 2)));
  }

  /// Get the lines that pass through a station from the cache.
  ///
  /// The [stationCode] is the code of the station.
  /// The stationCode is the `code`, not `id` of the station.
  /// The lines are returned as a list of [RouteLine] objects.
  static Future<List<RouteLine>> getLines(int stationCode) async {
    if ((await getExpiry()).isBefore(DateTime.now())) {
      return [];
    }
    List<RouteLine> lines = [];
    final data = _prefs?.getStringList("lines_$stationCode") ?? [];
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
    List<String> data = [];
    for (var line in lines) {
      data.add(jsonEncode(RouteLine.toJson(line)));
    }
    await _prefs?.setStringList('lines_$stationCode', data);
    await setExpiry(DateTime.now().add(const Duration(days: 2)));
  }

  /// Get all lines from the cache.
  /// Doesn't contain the stations that the lines go through.
  static Future<List<RouteLine>> getAllLines() async {
    if ((await getExpiry()).isBefore(DateTime.now())) {
      return [];
    }
    List<RouteLine> lines = [];
    final List<String>? data = _prefs?.getStringList('lines');
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
    List<String> data = [];
    for (var line in lines) {
      data.add(jsonEncode(RouteLine.toJson(line)));
    }
    await _prefs?.setStringList('lines', data);
  }

  /// Clear the cache. Remove all cached data.
  /// The data will be fetched again when needed.
  ///
  /// Used for debugging purposes. Not recommended for production.
  static clearCache() {
    _prefs?.remove('stations');
    _prefs?.remove('lines');
    _prefs?.remove('expiry');
  }
}
