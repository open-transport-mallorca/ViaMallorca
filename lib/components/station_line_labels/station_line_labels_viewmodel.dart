import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/cache/cache_manager.dart';
import 'package:via_mallorca/utils/stop_restrictions.dart';
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

  /// Picks this station out of each line's restrictions.
  ///
  /// No [Way] is passed: a departure names its line but not its subline, so
  /// every direction gets a say and a stop restricted in only one of them is
  /// left unreported rather than warned about.
  Map<String, bool> _computeDischargeOnly(List<RouteLine> lines) {
    final result = <String, bool>{};
    for (final line in lines) {
      final restriction = stopRestrictions(line)[station.id];
      if (restriction == null) continue;
      result[line.code] = restriction == StopRestriction.dropOffOnly;
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
