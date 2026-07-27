import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:via_mallorca/apis/local_storage.dart';

/// Deletes the leftovers of the two map tile caches this app used before
/// switching to flutter_map's built-in caching.
///
/// Both mechanisms are gone from the dependencies, so their data can only be
/// removed by deleting the files directly. Runs once and then records itself in
/// local storage, since after the first successful pass there is nothing left
/// to delete.
Future<void> clearLegacyMapCaches() async {
  if (LocalStorageApi.legacyMapCachesCleared()) return;

  try {
    /// 'flutter_map_tile_caching' with the ObjectBox backend, which put its
    /// database in an 'fmtc' directory inside the documents directory.
    final documents = await getApplicationDocumentsDirectory();
    final fmtc = Directory('${documents.path}/fmtc');
    if (fmtc.existsSync()) await fmtc.delete(recursive: true);

    /// 'flutter_map_cache' backed by a Hive box in the temporary directory.
    final temporary = await getTemporaryDirectory();
    for (final name in const [
      'HiveCacheStore.hive',
      'HiveCacheStore.lock',
    ]) {
      final file = File('${temporary.path}/$name');
      if (file.existsSync()) await file.delete();
    }

    await LocalStorageApi.setLegacyMapCachesCleared(true);
  } catch (e) {
    /// Not worth retrying aggressively - the flag stays unset so the next
    /// launch tries again.
    debugPrint('Error deleting legacy map caches: $e');
  }
}
