import 'package:flutter/widgets.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:via_mallorca/apis/warnings_api.dart';

class NewsApi {
  static const int maxNews = 20;

  static Language feedLanguage(Locale locale) =>
      WarningsApi.feedLanguage(locale);

  static Future<List<TransitNews>> fetch(Language language) async {
    final news = await TransitRss.getNews(language);
    return news.take(maxNews).toList();
  }

  static Future<void> loadDetails(TransitNews news) async {
    await NewsScraper.fetchDetails(news);
  }
}
