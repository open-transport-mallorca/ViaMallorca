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

  /// Bumped whenever a cached model gains fields the app relies on, so that
  /// entries written by an older version are dropped instead of silently
  /// reading back as null until they expire.
  ///
  /// v2: mallorca_transit_services 2.4.0 added `pickupType`/`dropoffType` to
  /// [Station], which the departures list uses to flag discharge-only stops.
  /// v3: line details are stored once under [_linePrefix] and referenced by
  /// station, instead of a full copy per station.
  /// v4: mallorca_transit_services 2.4.1 added `town` to [Station], which the
  /// route timeline groups stops by.
  /// v5: 2.5.0 added `sector`/`startDate`/`entityId` to [RouteLine] and
  /// `description`/`lineId` to [Subline], none of which are in entries written
  /// by earlier versions.
  static const int _schemaVersion = 5;

  static const String _schemaVersionKey = 'cache_schema_version';

  /// A single line, with its sublines and their stops.
  static const String _linePrefix = 'line_';

  /// The line codes serving a station - a reference list, not the lines.
  static const String _stationLinesPrefix = 'station_lines_';

  /// Line composition at a stop changes far less often than the lines
  /// themselves, so the reference list outlives the details it points at.
  static const Duration _stationLinesTtl = Duration(days: 7);

  static const Duration _lineTtl = Duration(days: 2);

  /// Initialize the cache manager.
  ///
  /// This method should be called before any other method in this class.
  /// Usually called in the main method.
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _migrate();
    await _pruneExpired();
  }

  /// Drops the whole cache when it was written under an older schema.
  static Future<void> _migrate() async {
    final prefs = _prefs;
    if (prefs == null) return;
    if ((prefs.getInt(_schemaVersionKey) ?? 1) == _schemaVersion) return;
    await clearCache();
    await prefs.setInt(_schemaVersionKey, _schemaVersion);
  }

  /// Deletes cached lines whose expiry has passed.
  ///
  /// Reads only ever skip expired entries, so without this they would sit in
  /// the preferences file forever - the whole file is parsed into memory on
  /// first access, so dead entries cost startup time on every launch.
  static Future<void> _pruneExpired() async {
    final prefs = _prefs;
    if (prefs == null) return;
    final now = DateTime.now();
    for (final key in prefs.getKeys().toList()) {
      if (!key.startsWith('expiry_$_linePrefix') &&
          !key.startsWith('expiry_$_stationLinesPrefix')) {
        continue;
      }
      final expiry = DateTime.tryParse(prefs.getString(key) ?? '');
      if (expiry == null || expiry.isAfter(now)) continue;
      await prefs.remove(key);
      await prefs.remove(key.substring('expiry_'.length));
    }
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
      try {
        for (var station in data) {
          stations.add(Station.fromJson(jsonDecode(station)));
        }
      } catch (_) {
        // Cached data is incompatible (e.g. station.code migrated from int to
        // String). Clear and force a fresh fetch.
        await _prefs?.remove(resourceName);
        await _prefs?.remove('expiry_$resourceName');
        return [];
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

  /// The codes of the lines that pass through a station, or null when that
  /// list is absent or stale.
  ///
  /// This is only the reference list - call [getLine] for each code to get the
  /// lines themselves. The [stationCode] is the `code` (not `id`) of the
  /// station.
  static Future<List<String>?> getStationLineCodes(String stationCode) async {
    final String resourceName = '$_stationLinesPrefix$stationCode';
    if ((await getExpiry(resourceName)).isBefore(DateTime.now())) {
      return null;
    }
    return _prefs?.getStringList(resourceName);
  }

  /// A single cached line with its sublines, or null when absent or stale.
  ///
  /// Lines are stored once and shared by every station they serve, so a line
  /// cached while viewing one stop is a hit at all the others.
  static Future<RouteLine?> getLine(String lineCode) async {
    final String resourceName = '$_linePrefix$lineCode';
    if ((await getExpiry(resourceName)).isBefore(DateTime.now())) {
      return null;
    }
    final data = _prefs?.getString(resourceName);
    if (data == null) return null;
    try {
      return RouteLine.fromJson(jsonDecode(data));
    } catch (_) {
      // Unreadable entry (e.g. written by an older model). Drop it so the
      // caller refetches instead of failing.
      await _prefs?.remove(resourceName);
      await _prefs?.remove('expiry_$resourceName');
      return null;
    }
  }

  /// Store a single line, shared across every station it serves.
  static Future<void> setLine(RouteLine line) async {
    final String resourceName = '$_linePrefix${line.code}';
    await _prefs?.setString(resourceName, jsonEncode(RouteLine.toJson(line)));
    await setExpiry(resourceName, DateTime.now().add(_lineTtl));
  }

  /// Store the lines that pass through a station.
  ///
  /// Writes one shared copy of each line plus a short list of line codes for
  /// the station, so a line serving many stops is held once rather than once
  /// per stop. The [stationCode] is the `code` (not `id`) of the station.
  static Future<void> setLines(
      String stationCode, List<RouteLine> lines) async {
    for (final line in lines) {
      await setLine(line);
    }
    final String resourceName = '$_stationLinesPrefix$stationCode';
    await _prefs?.setStringList(
        resourceName, lines.map((line) => line.code).toList());
    await setExpiry(resourceName, DateTime.now().add(_stationLinesTtl));
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

    // Remove all line-specific data, including the pre-v3 per-station copies.
    for (final key in keys) {
      if (key.startsWith('lines_') ||
          key.startsWith(_linePrefix) ||
          key.startsWith(_stationLinesPrefix) ||
          key == 'lines' ||
          key.startsWith('expiry_')) {
        await prefs.remove(key);
      }
    }
  }
}
