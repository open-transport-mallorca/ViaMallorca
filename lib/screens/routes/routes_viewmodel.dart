import 'package:flutter/material.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:via_mallorca/cache/cache_manager.dart';
import 'package:via_mallorca/extensions/remove_punctuation.dart';

class RoutesViewModel extends ChangeNotifier {
  final TextEditingController searchController = TextEditingController();

  List<RouteLine> _cachedLines = [];
  List<RouteLine> _filteredLines = [];
  bool _isLoading = true;

  RoutesViewModel() {
    _initialize();
    searchController.addListener(_onSearchTextChanged);
  }

  List<RouteLine> get filteredLines => _filteredLines;

  bool get isLoading => _isLoading;

  String get searchQuery => searchController.text;

  Future<void> _initialize() async {
    _cachedLines = await CacheManager.getAllLines();
    if (_cachedLines.isEmpty) {
      _cachedLines = await RouteLine.getAllLines();
      CacheManager.setAllLines(_cachedLines);
    }
    _filteredLines = List.from(_cachedLines);
    _isLoading = false;
    notifyListeners();
  }

  void _onSearchTextChanged() {
    final query = searchQuery.toLowerCase().removePunctuation();
    if (query.isEmpty) {
      _filteredLines = List.from(_cachedLines);
    } else {
      _filteredLines = _cachedLines.where((line) {
        final name = line.name.toLowerCase().removePunctuation();
        final code = line.code.toLowerCase().removePunctuation();
        final type = line.type.toString().removePunctuation();
        return name.contains(query) ||
            code.contains(query) ||
            type.contains(query);
      }).toList();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchTextChanged);
    searchController.dispose();
    super.dispose();
  }
}
