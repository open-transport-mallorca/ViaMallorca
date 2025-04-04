import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MetricDistanceFormatter {
  /// Formats distance (given in meters) in metric units (m/km).
  /// Example: 1500 → "1.5 km", 500 → "500 m"
  static String formatDistance(double meters, BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final formatter = NumberFormat("#,##0.#", locale); // 1 decimal place

    if (meters >= 1000) {
      return '${formatter.format(meters / 1000)} km';
    } else {
      return '${formatter.format(meters)} m';
    }
  }
}
