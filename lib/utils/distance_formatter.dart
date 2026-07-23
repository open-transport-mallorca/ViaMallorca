import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/apis/local_storage.dart';
import 'package:via_mallorca/providers/settings_provider.dart';

class DistanceFormatter {
  static const double _metresPerFoot = 0.3048;
  static const double _metresPerMile = 1609.344;

  /// Below this a distance reads better in the smaller unit.
  static const double _milesThreshold = _metresPerMile / 4;

  /// Formats a distance given in meters, in whichever units the user picked.
  ///
  /// Watches the preference, so every distance on screen switches units as soon
  /// as the setting changes.
  ///
  /// Example: 1500 → "1.5 km" or "0.9 mi", 500 → "500 m" or "1,640 ft"
  static String formatDistance(double meters, BuildContext context) {
    return _format(
        meters, context, context.watch<SettingsProvider>().distanceUnits);
  }

  static String _format(
      double meters, BuildContext context, DistanceUnits units) {
    final locale = Localizations.localeOf(context).toString();
    final formatter = NumberFormat("#,##0.#", locale); // 1 decimal place
    final wholeNumbers = NumberFormat("#,##0", locale);

    switch (units) {
      case DistanceUnits.metric:
        if (meters >= 1000) {
          return '${formatter.format(meters / 1000)} km';
        }
        return '${formatter.format(meters)} m';
      case DistanceUnits.imperial:
        if (meters >= _milesThreshold) {
          return '${formatter.format(meters / _metresPerMile)} mi';
        }
        // Feet are only ever whole here: a fractional foot is below the
        // accuracy of any position this app shows.
        return '${wholeNumbers.format(meters / _metresPerFoot)} ft';
    }
  }
}
