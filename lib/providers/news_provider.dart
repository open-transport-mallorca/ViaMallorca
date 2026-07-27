import 'package:flutter/widgets.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:via_mallorca/apis/local_storage.dart';
import 'package:via_mallorca/apis/news_api.dart';
import 'package:via_mallorca/cache/cache_manager.dart';

/// The operator's news, and which items the user has already read.
///
/// The counterpart to `WarningsProvider`, with two differences: news has no
/// per-line data, and its bodies and images are fetched one at a time when an
/// item is opened rather than for the whole list up front.
class NewsProvider extends ChangeNotifier {
  List<TransitNews> _news = const [];
  late Set<String> _seen = LocalStorageApi.getShownNews().toSet();

  /// News published on or before this was already out when the user installed,
  /// so it is not theirs to catch up on. Set on the first load and kept.
  DateTime? _baseline = LocalStorageApi.getNewsBaseline();

  bool _isLoading = false;
  bool _hasFailed = false;

  /// The language the loaded news was fetched in, so a language change refetches
  /// rather than showing the previous one's text.
  Language? _loadedLanguage;

  /// Ids whose details are being fetched, so a rebuild mid-fetch does not start
  /// a second request for the same item.
  final Set<String> _loadingDetails = {};

  List<TransitNews> get news => _news;
  bool get isLoading => _isLoading;
  bool get hasFailed => _hasFailed;

  int get unreadCount => _news.where(isUnread).length;

  /// Unread, and new since the user installed.
  ///
  /// An item read on any device-language counts as read; an item that predates
  /// the install baseline is never unread, so the backlog does not badge. An
  /// item with no publication date is treated as old, since there is no way to
  /// place it after the baseline.
  bool isUnread(TransitNews item) {
    if (_seen.contains(_seenKey(item))) return false;
    final published = item.published;
    final baseline = _baseline;
    return published != null && baseline != null && published.isAfter(baseline);
  }

  /// A read-state key that is the same for one item in every language.
  ///
  /// The id is the item's page URL, which carries the feed language; the slug
  /// after it is shared across languages. See `WarningsProvider`.
  static String _seenKey(TransitNews item) {
    final segments = Uri.tryParse(item.id)?.pathSegments;
    if (segments == null || segments.isEmpty) return item.id;
    return segments.last;
  }

  /// Loads the news for [locale], from cache when it is still fresh.
  Future<void> load(Locale locale, {bool force = false}) async {
    // Stamp the install baseline the first time news is ever loaded, before any
    // early return, so "new since install" is anchored from the user's first
    // encounter with the feed.
    if (_baseline == null) {
      _baseline = DateTime.now();
      await LocalStorageApi.setNewsBaseline(_baseline!);
    }

    final language = NewsApi.feedLanguage(locale);
    if (_isLoading) return;
    if (!force && language == _loadedLanguage && _news.isNotEmpty) return;

    _isLoading = true;
    _hasFailed = false;
    notifyListeners();

    try {
      if (!force) {
        final cached = await CacheManager.getNews(language.name);
        if (cached != null) {
          _news = cached;
          _loadedLanguage = language;
          return;
        }
      }

      final fetched = await NewsApi.fetch(language);
      _news = fetched;
      _loadedLanguage = language;
      await CacheManager.setNews(language.name, fetched);
    } catch (e) {
      debugPrint('Could not load news: $e');
      _hasFailed = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches [item]'s body and image if they are not loaded yet.
  ///
  /// Called when an item is opened. The fetched fields are written onto the
  /// cached model too, so scrolling back to an item already read does not
  /// refetch within the cache's lifetime.
  Future<void> loadDetails(TransitNews item) async {
    if (item.paragraphs != null || _loadingDetails.contains(item.id)) return;
    _loadingDetails.add(item.id);
    try {
      await NewsApi.loadDetails(item);
      if (_loadedLanguage != null) {
        await CacheManager.setNews(_loadedLanguage!.name, _news);
      }
    } catch (e) {
      debugPrint('Could not load news details for ${item.id}: $e');
    } finally {
      _loadingDetails.remove(item.id);
      notifyListeners();
    }
  }

  /// Marks an item as read.
  Future<void> markSeen(TransitNews item) async {
    if (!_seen.add(_seenKey(item))) return;
    await _persistSeen();
    notifyListeners();
  }

  /// Marks everything currently listed as read.
  Future<void> markAllSeen() async {
    final before = _seen.length;
    _seen.addAll(_news.map(_seenKey));
    if (_seen.length == before) return;
    await _persistSeen();
    notifyListeners();
  }

  /// Writes the seen keys back, dropping any no longer in the feed so the set
  /// cannot grow without bound.
  Future<void> _persistSeen() async {
    final live = _news.map(_seenKey).toSet();
    _seen = _seen.where(live.contains).toSet();
    await LocalStorageApi.setShownNews(_seen.toList());
  }
}
