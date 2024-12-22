import 'package:flutter/material.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:url_launcher/url_launcher.dart';

class TimetableViewModel extends ChangeNotifier {
  final String lineCode;
  Uri? _timetableUri;
  bool _isLoading = true;
  String? _errorMessage;

  TimetableViewModel(this.lineCode) {
    _fetchTimetable();
  }

  Uri? get timetableUri => _timetableUri;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> _fetchTimetable() async {
    try {
      _timetableUri = await RouteLine.getPdfTimetable(lineCode);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveFile(BuildContext context) async {
    try {
      if (_timetableUri == null) return;
      await launchUrl(_timetableUri!);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    }
  }
}
