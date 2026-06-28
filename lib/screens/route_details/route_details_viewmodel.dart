import 'package:flutter/material.dart';
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

  /// The route as it came from the list. Used for the header while the full
  /// details are still loading.
  final RouteLine initialLine;

  /// The full route line, populated once [RouteLinesApi.getLine] completes.
  RouteLine? fullLine;

  bool isLoading = true;
  bool hasError = false;

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
  }

  Future<void> retry() => _loadDetails();

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
