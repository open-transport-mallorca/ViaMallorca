import 'package:flutter/widgets.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';

/// Fetches the operator's service warnings.
class WarningsApi {
  /// How many warnings to keep. The feed is ordered newest first and anything
  /// past the first screenful is of no practical use to a passenger, while each
  /// one costs a page fetch to learn its details.
  static const int maxWarnings = 20;

  /// How many warning pages to fetch details for at once.
  ///
  /// The affected lines and the full text are only on the warning's own page,
  /// so filling them in means one request each. Kept low to avoid hammering a
  /// server the package's own docs describe as unstable.
  static const int _detailConcurrency = 4;

  /// The feed language closest to [locale].
  ///
  /// The operator publishes in four languages, which is fewer than the app
  /// supports, so French and Ukrainian fall back to English rather than to the
  /// Spanish the package would otherwise default to.
  static Language feedLanguage(Locale locale) {
    return switch (locale.languageCode) {
      'ca' => Language.ca,
      'es' => Language.es,
      'de' => Language.de,
      _ => Language.en,
    };
  }

  /// The current warnings, without the fields that have to be scraped.
  ///
  /// Returned first so the list can be shown immediately; call [withDetails]
  /// to fill in the rest.
  static Future<List<TransitWarning>> fetch(Language language) async {
    final warnings = await TransitRss.getWarnings(language);
    return warnings.take(maxWarnings).toList();
  }

  /// The same warnings with their affected lines and full text filled in.
  ///
  /// One request each, which also means the detail view has nothing left to
  /// fetch. A warning whose page cannot be read keeps its empty details rather
  /// than failing the batch: the warning itself is still worth showing.
  static Future<List<TransitWarning>> withDetails(
      List<TransitWarning> warnings) async {
    for (var start = 0; start < warnings.length; start += _detailConcurrency) {
      final end = (start + _detailConcurrency).clamp(0, warnings.length);
      await Future.wait([
        for (var i = start; i < end; i++) _fillDetails(warnings[i]),
      ]);
    }
    return warnings;
  }

  static Future<void> _fillDetails(TransitWarning warning) async {
    try {
      await TransitWarningScraper.fetchDetails(warning);
    } catch (e) {
      // Only transport failures reach here - the scraper leaves the fields
      // empty rather than throwing when the page layout changes. Either way the
      // warning's title and link are still worth showing.
      debugPrint('Could not load details for ${warning.id}: $e');
    }
  }

  /// Whether [warning] names [lineCode].
  ///
  /// The package normalises the codes on the warning pages - which are printed
  /// with an `L` prefix the rest of the API never uses - so they compare
  /// directly against [Departure.lineCode] and [RouteLine.code].
  static bool affectsLine(TransitWarning warning, String lineCode) =>
      warning.affectedLines?.contains(lineCode) ?? false;
}
