import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:via_mallorca/components/app_bar.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:via_mallorca/providers/news_provider.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NewsProvider>().load(Localizations.localeOf(context));
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Consumer<NewsProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: ViaAppBar(
            title: localizations.news,
            actions: [
              if (provider.unreadCount > 0)
                IconButton(
                  tooltip: localizations.markAllRead,
                  onPressed: provider.markAllSeen,
                  icon: const Icon(Icons.done_all),
                ),
            ],
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () =>
                  provider.load(Localizations.localeOf(context), force: true),
              child: _body(context, provider),
            ),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, NewsProvider provider) {
    final localizations = AppLocalizations.of(context)!;

    if (provider.isLoading && provider.news.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.news.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
          Icon(
            provider.hasFailed ? Icons.cloud_off : Icons.feed_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            provider.hasFailed
                ? localizations.newsFailed
                : localizations.noNews,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: provider.news.length,
      itemBuilder: (context, index) {
        final item = provider.news[index];
        return _NewsCard(
          item: item,
          isUnread: provider.isUnread(item),
          isExpanded: _expanded.contains(item.id),
          onToggle: () {
            final expanding = !_expanded.contains(item.id);
            setState(() {
              if (expanding) {
                _expanded.add(item.id);
              } else {
                _expanded.remove(item.id);
              }
            });
            if (expanding) {
              provider.markSeen(item);
              provider.loadDetails(item);
            }
          },
        );
      },
    );
  }
}

String _newsTitle(TransitNews item) {
  final title = item.title?.trim();
  return (title == null || title.isEmpty) ? item.link : title;
}

/// The feed summary as plain text, or null when there is none.
///
/// The summary is raw feed HTML (`<p><strong>…`); the paragraphs shown when the
/// item is expanded are already clean, but this preview has to strip the tags
/// itself.
String? _summaryText(TransitNews item) {
  final raw = item.summary;
  if (raw == null) return null;
  final text = raw
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return text.isEmpty ? null : text;
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({
    required this.item,
    required this.isUnread,
    required this.isExpanded,
    required this.onToggle,
  });

  final TransitNews item;
  final bool isUnread;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final published = item.published;
    final summary = _summaryText(item);
    return Card(
      color: theme.colorScheme.surfaceContainerHigh,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _newsTitle(item),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight:
                                isUnread ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (published != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            // The package returns UTC; these are local events.
                            DateFormat.yMMMd(
                                    Localizations.localeOf(context).toString())
                                .format(published.toLocal()),
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                        if (summary != null && !isExpanded) ...[
                          const SizedBox(height: 6),
                          Text(
                            summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                sizeCurve: Curves.easeOut,
                crossFadeState: isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox(width: double.infinity),
                secondChild: _NewsBody(item: item, summary: summary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The article's image and body, shown when an item is expanded.
///
/// Whether the body is loaded is decided by the provider; this only renders
/// what is there, plus a spinner while [TransitNews.paragraphs] is still null.
class _NewsBody extends StatelessWidget {
  const _NewsBody({required this.item, required this.summary});

  final TransitNews item;

  /// The cleaned feed summary, shown while the full body is still loading so the
  /// expanded card is not empty.
  final String? summary;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final paragraphs = item.paragraphs;
    final image = item.imageUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        if (image != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              image.toString(),
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => const SizedBox.shrink(),
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Center(child: CircularProgressIndicator()),
                    ),
            ),
          ),
        if (image != null) const SizedBox(height: 12),
        if (paragraphs == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (summary != null)
                  Text(summary!, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
            ),
          )
        else if (paragraphs.isEmpty)
          Text(
            summary ?? localizations.newsDetailUnavailable,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          )
        else
          for (final paragraph in paragraphs) ...[
            Text(paragraph, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 4),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => launchUrl(Uri.parse(item.link),
                mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(localizations.openInBrowser),
          ),
        ),
      ],
    );
  }
}
