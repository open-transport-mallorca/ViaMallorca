import 'package:flutter_map/flutter_map.dart';

/// Configures flutter_map's built-in tile cache. Must happen before the map
/// loads its first tile, otherwise the defaults are locked in.
///
/// `overrideFreshAge` is what makes the map usable offline: without it, tiles
/// are only served from disk while the server's own `max-age` holds, and once
/// stale they are re-requested rather than reused. OSM tiles for a single
/// island barely change, so a month of staleness is a fine trade.
///
/// Lives here rather than inline at the call site because clearing the cache
/// destroys the instance, and what replaces it has to be configured the same
/// way or the map quietly reverts to flutter_map's defaults.
BuiltInMapCachingProvider configureMapTileCache() =>
    BuiltInMapCachingProvider.getOrCreateInstance(
      maxCacheSize: 200 * 1024 * 1024,
      overrideFreshAge: const Duration(days: 30),
    );

/// Deletes every cached tile and starts a fresh cache with the same settings.
Future<void> clearMapTileCache() async {
  await BuiltInMapCachingProvider.getOrCreateInstance()
      .destroy(deleteCache: true);
  configureMapTileCache();
}
