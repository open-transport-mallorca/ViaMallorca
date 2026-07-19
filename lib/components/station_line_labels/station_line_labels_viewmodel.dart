import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/cache/cache_manager.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';

class StationViewModel extends ChangeNotifier {
  final Station station;

  StationViewModel(this.station);

  /// The nearest [StationViewModel] for [station], if an ancestor already
  /// provides one.
  ///
  /// Lets a screen share a single lines fetch between the line labels and
  /// anything else that needs the station's lines, instead of every widget
  /// loading them for itself. Returns null when the ancestor describes a
  /// different station, as the timeline and nearby lists render one set of
  /// labels per station.
  static StationViewModel? maybeOf(BuildContext context, Station station) {
    try {
      final viewModel = Provider.of<StationViewModel>(context);
      return viewModel.station.code == station.code ? viewModel : null;
    } on ProviderNotFoundException {
      return null;
    }
  }

  List<RouteLine>? _cachedLines;

  Map<String, bool> _dischargeOnlyByLine = const {};

  /// Returns the active lines that pass through the station.
  List<RouteLine> get activeLines =>
      (_cachedLines ?? []).where((line) => line.active).toList();

  /// Whether the station is discharge-only - passengers may get off but not
  /// board - on each line serving it, keyed by line code.
  ///
  /// Empty until [loadLines] completes; a missing key means the flag is
  /// unknown for that line.
  Map<String, bool> get dischargeOnlyByLine => _dischargeOnlyByLine;

  /// Returns whether the data has been loaded.
  bool get isDataLoaded => _cachedLines != null;

  /// Loads the lines that pass through the station from the API or cache.
  Future<void> loadLines() async {
    if (_cachedLines != null) return;

    try {
      _cachedLines = await _fetchLines();
      _dischargeOnlyByLine = _computeDischargeOnly(_cachedLines!);
    } finally {
      // notifyListeners() is only called if the object is still valid
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  /// Resolves the station's lines, hitting the network only for what the cache
  /// is missing.
  ///
  /// Once the station's line codes are known, each line is fetched on its own,
  /// so a line already cached from another stop costs nothing. Only a station
  /// whose code list is unknown needs [StationsApi.getLines], which fetches the
  /// stop and then every one of its lines.
  /// Only freshly fetched data is written back, so that revisiting a stop does
  /// not keep pushing the expiry of entries that were never refreshed.
  Future<List<RouteLine>> _fetchLines() async {
    final codes = await CacheManager.getStationLineCodes(station.code);
    if (codes == null) {
      final lines = await StationsApi.getLines(station.code);
      await CacheManager.setLines(station.code, lines);
      return lines;
    }

    final lines = <RouteLine>[];
    for (final code in codes) {
      final cached = await CacheManager.getLine(code);
      if (cached != null) {
        lines.add(cached);
        continue;
      }
      final fetched = await RouteLinesApi.getLine(code);
      await CacheManager.setLine(fetched);
      lines.add(fetched);
    }
    return lines;
  }

  /// The pickup/dropoff flags live on the stops of a line's sublines, which are
  /// direction specific - a stop can be discharge-only one way and a normal
  /// stop the other. A departure only names its line, not its subline, so a
  /// line counts as discharge-only here only when every subline that has an
  /// opinion agrees. Being conservative means we never wrongly tell someone
  /// they cannot board.
  ///
  /// Sublines routinely list the same stop more than once and only some of
  /// those entries carry the flags - on A42, the hidden sublines describe all
  /// 18 restricted stops while the visible ones describe 4. An entry without
  /// either field means "unknown", not "boards normally", so those are dropped
  /// rather than counted as a vote against.
  Map<String, bool> _computeDischargeOnly(List<RouteLine> lines) {
    final result = <String, bool>{};
    for (final line in lines) {
      final stops = (line.sublines ?? const <Subline>[])
          .expand((subline) => subline.stations)
          .where((stop) => stop.id == station.id)
          .where((stop) => stop.pickupType != null || stop.dropoffType != null);
      if (stops.isEmpty) continue;
      result[line.code] = stops.every((stop) => stop.isDischargeOnly);
    }
    return result;
  }

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
