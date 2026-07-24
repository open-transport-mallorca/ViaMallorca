import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:via_mallorca/components/app_bar.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:via_mallorca/providers/favorites_provider.dart';
import 'package:via_mallorca/providers/warnings_provider.dart';
import 'package:via_mallorca/screens/warnings/warning_pdf_view.dart';

class WarningsScreen extends StatefulWidget {
  const WarningsScreen({super.key, this.lineFilter});

  final List<String>? lineFilter;

  @override
  State<WarningsScreen> createState() => _WarningsScreenState();
}

class _WarningsScreenState extends State<WarningsScreen> {
  /// Per-warning overrides on top of [_expandedByDefault].
  final Map<String, bool> _expanded = {};

  bool get _expandedByDefault => widget.lineFilter != null;

  bool _isExpanded(TransitWarning warning) =>
      _expanded[warning.id] ?? _expandedByDefault;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<WarningsProvider>().load(Localizations.localeOf(context));
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final filter = widget.lineFilter;
    return Consumer<WarningsProvider>(
      builder: (context, provider, _) {
        final warnings =
            filter == null ? provider.warnings : provider.forLines(filter);
        return Scaffold(
          appBar: ViaAppBar(
            title: filter == null
                ? localizations.warnings
                : localizations.warningsForLine(filter.join(', ')),
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
              child: _body(context, provider, warnings),
            ),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, WarningsProvider provider,
      List<TransitWarning> warnings) {
    final localizations = AppLocalizations.of(context)!;

    if (provider.isLoading && warnings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (warnings.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
          Icon(
            provider.hasFailed ? Icons.cloud_off : Icons.check_circle_outline,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            provider.hasFailed
                ? localizations.warningsFailed
                : localizations.noWarnings,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      );
    }

    final favourites =
        context.watch<FavoritesProvider>().favoriteRoutes.toSet();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: warnings.length,
      itemBuilder: (context, index) {
        final warning = warnings[index];
        return _WarningCard(
          warning: warning,
          isHighlighted: provider.isHighlighted(warning, favourites),
          isExpanded: _isExpanded(warning),
          onToggle: () {
            final expanding = !_isExpanded(warning);
            if (expanding) provider.markSeen(warning);
            setState(() => _expanded[warning.id] = expanding);
          },
        );
      },
    );
  }
}

String _warningTitle(TransitWarning warning) {
  final title = warning.title?.trim();
  return (title == null || title.isEmpty) ? warning.link : title;
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({
    required this.warning,
    required this.isHighlighted,
    required this.isExpanded,
    required this.onToggle,
  });

  final TransitWarning warning;

  final bool isHighlighted;

  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final published = warning.published;
    final affected = warning.affectedLines ?? const <String>[];
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
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 10),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: isHighlighted
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _warningTitle(warning),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: isHighlighted
                                ? FontWeight.bold
                                : FontWeight.normal,
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
                        if (affected.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final line in affected) _LineChip(line)
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
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
                secondChild: _WarningBody(warning: warning),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WarningBody extends StatefulWidget {
  const _WarningBody({required this.warning});

  final TransitWarning warning;

  @override
  State<_WarningBody> createState() => _WarningBodyState();
}

class _WarningBodyState extends State<_WarningBody> {
  late final Future<String?> _description = widget.warning.description != null
      ? Future.value(widget.warning.description)
      : TransitWarningScraper.description(widget.warning.link);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Divider(height: 1, color: theme.colorScheme.outlineVariant),
        const SizedBox(height: 12),
        FutureBuilder<String?>(
          future: _description,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              );
            }
            final text = snapshot.data;
            if (snapshot.hasError || text == null || text.isEmpty) {
              // The text is scraped, so it is the first thing to break when the
              // operator changes their pages. The link still works.
              return Text(
                localizations.warningDetailUnavailable,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              );
            }
            return Text(text, style: theme.textTheme.bodyMedium);
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            // Most warnings attach a notice PDF - often a stop map - which is
            // the part the description text cannot convey.
            if (widget.warning.documentUrl != null)
              FilledButton.tonalIcon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WarningPdfScreen(
                      title: _warningTitle(widget.warning),
                      url: widget.warning.documentUrl!,
                    ),
                  ),
                ),
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: Text(localizations.viewNotice),
              ),
            TextButton.icon(
              onPressed: () => launchUrl(Uri.parse(widget.warning.link),
                  mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(localizations.openInBrowser),
            ),
          ],
        ),
      ],
    );
  }
}

class _LineChip extends StatelessWidget {
  const _LineChip(this.line);

  final String line;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        line,
        style: TextStyle(fontSize: 12, color: scheme.onSecondaryContainer),
      ),
    );
  }
}
