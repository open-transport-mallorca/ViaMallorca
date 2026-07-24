import 'package:flutter/widgets.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:via_mallorca/apis/local_storage.dart';
import 'package:via_mallorca/apis/warnings_api.dart';
import 'package:via_mallorca/cache/cache_manager.dart';

/// The operator's current service warnings, and which of them the user has
/// already read.
class WarningsProvider extends ChangeNotifier {
  List<TransitWarning> _warnings = const [];
  late Set<String> _seen = LocalStorageApi.getShownWarnings().toSet();

  bool _isLoading = false;
  bool _hasFailed = false;

  /// The language the loaded warnings were fetched in, so that changing the
  /// app's language refetches rather than showing the previous one's text.
  Language? _loadedLanguage;

  List<TransitWarning> get warnings => _warnings;
  bool get isLoading => _isLoading;

  /// Whether the last attempt failed. The warnings list is advisory, so a
  /// failure is reported in place rather than thrown.
  bool get hasFailed => _hasFailed;

  /// How many warnings the user has not opened yet.
  int get unreadCount =>
      _warnings.where((warning) => !_seen.contains(_seenKey(warning))).length;

  bool isUnread(TransitWarning warning) => !_seen.contains(_seenKey(warning));

  /// A read-state key that is the same for one warning in every language.
  ///
  /// A warning's [TransitWarning.id] is its page URL, which carries the feed
  /// language - `/en/w/avis-obres`, `/es/w/avis-obres` - so keying on it would
  /// forget a warning had been read the moment the app language changed. The
  /// slug after the language segment is identical across languages, so it is
  /// what identifies the warning. Falls back to the full id if the URL is not
  /// shaped as expected, which at worst restores the old per-language behaviour.
  static String _seenKey(TransitWarning warning) {
    final segments = Uri.tryParse(warning.id)?.pathSegments;
    if (segments == null || segments.isEmpty) return warning.id;
    return segments.last;
  }

  /// The warnings naming [lineCode], newest first.
  List<TransitWarning> forLine(String lineCode) => forLines([lineCode]);

  /// The warnings naming any of [lineCodes], newest first.
  List<TransitWarning> forLines(Iterable<String> lineCodes) {
    final wanted = lineCodes.toSet();
    if (wanted.isEmpty) return const [];
    return _warnings
        .where((warning) =>
            wanted.any((code) => WarningsApi.affectsLine(warning, code)))
        .toList();
  }

  /// Which of [lineCodes] have a warning against them, in the order given.
  List<String> warnedLines(Iterable<String> lineCodes) => lineCodes
      .toSet()
      .where((code) =>
          _warnings.any((warning) => WarningsApi.affectsLine(warning, code)))
      .toList();

  /// Whether [warning] is unread and concerns one of [lineCodes].
  ///
  /// What the list highlights, for the same reason the badge counts it.
  bool isHighlighted(TransitWarning warning, Iterable<String> lineCodes) =>
      isUnread(warning) &&
      lineCodes.any((code) => WarningsApi.affectsLine(warning, code));

  /// How many unread warnings name any of [lineCodes].
  ///
  /// What the app bar badge counts. Restricting it to the user's own lines is
  /// the difference between a useful nudge and a permanent unread marker: the
  /// operator publishes disruptions for the whole island, most of which will
  /// never concern any one passenger.
  int unreadCountForLines(Iterable<String> lineCodes) =>
      forLines(lineCodes).where(isUnread).length;

  /// Loads the warnings for [locale], from cache when it is still fresh.
  ///
  /// Safe to call on every build of the screens that show warnings: it returns
  /// immediately unless the language changed or [force] is set.
  Future<void> load(Locale locale, {bool force = false}) async {
    final language = WarningsApi.feedLanguage(locale);
    if (_isLoading) return;
    if (!force && language == _loadedLanguage && _warnings.isNotEmpty) return;

    _isLoading = true;
    _hasFailed = false;
    notifyListeners();

    try {
      if (!force) {
        final cached = await CacheManager.getWarnings(language.name);
        if (cached != null) {
          _warnings = cached;
          _loadedLanguage = language;
          return;
        }
      }

      // Show the list as soon as the feed lands; the details each cost a page
      // fetch, which is too slow to make the user wait for.
      final fetched = await WarningsApi.fetch(language);
      _warnings = fetched;
      _loadedLanguage = language;
      notifyListeners();

      final detailed = await WarningsApi.withDetails(fetched);
      _warnings = detailed;
      await CacheManager.setWarnings(language.name, detailed);
    } catch (e) {
      debugPrint('Could not load service warnings: $e');
      _hasFailed = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markSeen(TransitWarning warning) async {
    if (!_seen.add(_seenKey(warning))) return;
    await _persistSeen();
    notifyListeners();
  }

  Future<void> markAllSeen() async {
    final before = _seen.length;
    _seen.addAll(_warnings.map(_seenKey));
    if (_seen.length == before) return;
    await _persistSeen();
    notifyListeners();
  }

  /// Writes the seen keys back, dropping any that are no longer in the feed so
  /// the list cannot grow without bound as warnings are lifted.
  Future<void> _persistSeen() async {
    final live = _warnings.map(_seenKey).toSet();
    _seen = _seen.where(live.contains).toSet();
    await LocalStorageApi.setShownWarnings(_seen.toList());
  }
}
