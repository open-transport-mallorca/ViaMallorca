import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';

/// View model for the route details screen.
///
/// Receives the lightweight [RouteLine] from the routes list and fetches the
/// full line (including sessions, towns, holidays and sublines) via
/// [RouteLinesApi.getLine], which returns richer data than
/// [RouteLinesApi.getAllLines].
class RouteDetailsViewModel extends ChangeNotifier {
  RouteDetailsViewModel(this.initialLine) {
    _loadDetails();
  }

  final RouteLine initialLine;

  /// The full route line, populated once [RouteLinesApi.getLine] completes.
  RouteLine? fullLine;

  bool isLoading = true;
  bool hasError = false;

  /// The shape of the main direction, for the map preview. Empty until it
  /// loads, and left empty if it fails - the preview is then simply not shown,
  /// the "view on map" button still works.
  List<LatLng> previewPoints = const [];

  List<Station> previewStations = const [];
  bool isPreviewLoading = true;

  /// The line to display: the full one if available, otherwise the initial one.
  RouteLine get line => fullLine ?? initialLine;

  Future<void> _loadDetails() async {
    try {
      isLoading = true;
      hasError = false;
      if (!_isDisposed) notifyListeners();

      fullLine = await RouteLinesApi.getLine(initialLine.code);
    } catch (_) {
      hasError = true;
    } finally {
      isLoading = false;
      if (!_isDisposed) notifyListeners();
    }
    if (!hasError) await _loadPreviewShape();
  }

  Future<void> _loadPreviewShape() async {
    final subline = sublines.firstOrNull;
    if (subline == null) {
      isPreviewLoading = false;
      if (!_isDisposed) notifyListeners();
      return;
    }
    try {
      final path = await RouteLinesApi.getPath(subline);
      previewPoints = path.paths.expand((segment) => segment).toList();
      previewStations = subline.stations;
    } catch (_) {
      previewPoints = const [];
      previewStations = const [];
    } finally {
      isPreviewLoading = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  Future<void> retry() {
    previewPoints = const [];
    previewStations = const [];
    isPreviewLoading = true;
    return _loadDetails();
  }

  /// Operating sessions, with the currently active one(s) first.
  List<RouteSession> get sessions {
    final sessions = line.sessions;
    if (sessions == null) return const [];
    return [...sessions]..sort((a, b) {
        if (a.current != b.current) return a.current ? -1 : 1;
        return a.startDate.compareTo(b.startDate);
      });
  }

  /// Holidays affecting the service from today onwards, soonest first.
  List<RouteHoliday> get upcomingHolidays {
    final holidays = line.holidays;
    if (holidays == null) return const [];
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    return holidays.where((h) => !h.date.isBefore(startOfToday)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Sublines (directions), with the main one first.
  List<Subline> get sublines {
    final sublines = line.sublines?.where((s) => s.active).toList();
    if (sublines == null) return const [];
    return [...sublines]..sort((a, b) {
        if ((a.main ?? false) != (b.main ?? false)) {
          return (a.main ?? false) ? -1 : 1;
        }
        return a.way.index.compareTo(b.way.index);
      });
  }

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
