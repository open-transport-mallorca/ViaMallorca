import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:via_mallorca/components/app_bar.dart';
import 'package:via_mallorca/components/map/route_map_preview.dart';
import 'package:via_mallorca/components/route_stops_timeline.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:via_mallorca/providers/favorites_provider.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/providers/navigation_provider.dart';
import 'package:via_mallorca/screens/timetable_viewer/timetable_view.dart';
import 'package:via_mallorca/utils/adapt_color.dart';
import 'package:via_mallorca/utils/distance_formatter.dart';
import 'package:via_mallorca/utils/line_icon.dart';
import 'package:via_mallorca/utils/stop_restrictions.dart';
import 'route_details_viewmodel.dart';

class RouteDetailsScreen extends StatelessWidget {
  const RouteDetailsScreen({super.key, required this.route});

  final RouteLine route;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RouteDetailsViewModel(route),
      child: Consumer2<RouteDetailsViewModel, FavoritesProvider>(
        builder: (context, viewModel, favorites, _) {
          final line = viewModel.line;
          final isFavorite = favorites.isFavoriteRoute(line.code);
          return Scaffold(
            appBar: ViaAppBar(
              title: line.code,
              actions: [
                IconButton(
                  icon: Icon(isFavorite ? Icons.star : Icons.star_outline),
                  onPressed: () => isFavorite
                      ? favorites.removeFavoriteRoute(line.code)
                      : favorites.addFavoriteRoute(line.code),
                ),
              ],
            ),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _Header(line: line),
                  if (viewModel.isPreviewLoading)
                    const RouteMapPreviewPlaceholder()
                  else if (viewModel.previewPoints.isNotEmpty)
                    RouteMapPreview(
                      points: viewModel.previewPoints,
                      stations: viewModel.previewStations,
                      color: Color(line.color),
                      onTap: () => _openOnMap(context, line),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _openOnMap(context, line),
                            icon: const Icon(Icons.map_outlined),
                            label:
                                Text(AppLocalizations.of(context)!.viewOnMap),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TimetableViewer(
                                    lineCode: line.code, lineId: line.id),
                              ),
                            ),
                            icon: const Icon(Icons.access_time_filled_rounded),
                            label:
                                Text(AppLocalizations.of(context)!.timetable),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (viewModel.isLoading)
                    const _DetailsSkeleton()
                  else if (viewModel.hasError)
                    _ErrorRetry(onRetry: viewModel.retry)
                  else
                    ..._buildDetailSections(context, viewModel),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildDetailSections(
      BuildContext context, RouteDetailsViewModel viewModel) {
    final l10n = AppLocalizations.of(context)!;
    return [
      if (viewModel.sublines.isNotEmpty)
        _Section(
          title: l10n.directions,
          icon: Icons.alt_route,
          child: Column(
            children: viewModel.sublines
                .map((s) => _SublineTile(
                      subline: s,
                      // A single direction is a loop - don't label it
                      // outbound/return.
                      showWayLabel: viewModel.sublines.length > 1,
                    ))
                .toList(),
          ),
        ),
      if (viewModel.sessions.isNotEmpty)
        _Section(
          title: l10n.operatingPeriod,
          icon: Icons.event_available,
          child: Column(
            children: viewModel.sessions
                .map((s) => _SessionTile(session: s))
                .toList(),
          ),
        ),
      if (viewModel.upcomingHolidays.isNotEmpty)
        _Section(
          title: l10n.serviceHolidays,
          icon: Icons.beach_access,
          child: Column(
            children: viewModel.upcomingHolidays
                .map((h) => _HolidayTile(holiday: h))
                .toList(),
          ),
        ),
    ];
  }
}

/// Shows [line] on the map tab, optionally with [initialWay] pre-selected.
///
/// The tab is switched first because `viewRoute` only auto-switches when not
/// already on the routes tab (index 3), which is where this screen sits. It
/// closes any open station sheet itself.
void _openOnMap(BuildContext context, RouteLine line, {Way? initialWay}) {
  Provider.of<NavigationProvider>(context, listen: false).setIndex(1);
  Provider.of<MapProvider>(context, listen: false)
      .viewRoute(line, context, initialWay: initialWay);
}

/// Header with a subtle line-colored tint, a colored badge for the line and
/// status chips. The line color is used only as an accent (circle + faint
/// gradient), not as a full background.
class _Header extends StatelessWidget {
  const _Header({required this.line});

  final RouteLine line;

  @override
  Widget build(BuildContext context) {
    final accent = Color(line.color);
    final onAccent =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
            ? Colors.white
            : Colors.black;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.22),
            accent.withValues(alpha: 0.04),
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconTheme(
                  data: IconThemeData(color: onAccent, size: 28),
                  child: Center(child: getIconForRouteLine(line)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.code,
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      line.name,
                      style: TextStyle(
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (line.onDemand == true || line.summerOnly == true) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (line.onDemand == true)
                  _HeaderBadge(
                    icon: Icons.touch_app,
                    label: AppLocalizations.of(context)!.onDemand,
                    color: Colors.amber.shade700,
                  ),
                if (line.summerOnly == true)
                  _HeaderBadge(
                    icon: Icons.wb_sunny,
                    label: AppLocalizations.of(context)!.summerOnly,
                    color: Colors.orange.shade700,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge(
      {required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// A titled, icon-prefixed section card.
class _Section extends StatelessWidget {
  const _Section(
      {required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _SublineTile extends StatelessWidget {
  const _SublineTile({required this.subline, required this.showWayLabel});

  final Subline subline;

  /// Whether to show the outbound/return label. False for loop lines that only
  /// have a single direction.
  final bool showWayLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final details = <String>[
      l10n.stopCount(subline.stations.length),
      if (subline.distance != null)
        DistanceFormatter.formatDistance(subline.distance!, context),
    ].join(' · ');

    final IconData leadingIcon = !showWayLabel
        ? Icons.loop
        : subline.way == Way.way
            ? Icons.arrow_forward
            : Icons.arrow_back;

    Widget? trailing;
    if (showWayLabel) {
      final wayLabel = subline.way == Way.way ? l10n.outbound : l10n.inbound;
      trailing = Text(wayLabel, style: Theme.of(context).textTheme.labelMedium);
    }

    final lineColour = adaptColor(Color(subline.parentLine.color))[
        Theme.of(context).colorScheme.brightness == Brightness.light ? 0 : 1];

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        leading: Icon(leadingIcon),
        title: Text(subline.name),
        subtitle: Text(details),
        // The way label sits next to the expand arrow rather than replacing it,
        // so it stays clear the direction opens up.
        trailing: trailing == null
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [trailing, const Icon(Icons.expand_more)],
              ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: RouteStopsTimeline(
              stations: subline.stations,
              color: lineColour,
              restrictions:
                  stopRestrictions(subline.parentLine, way: subline.way),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.map_outlined),
                label: Text(l10n.viewOnMap),
                // Load the full line (keeping the way switcher) but pre-select
                // the tapped direction.
                onPressed: () => _openOnMap(context, subline.parentLine,
                    initialWay: subline.way),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

  final RouteSession session;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    // A session spanning Jan 1 - Dec 31 is year-round; show a label instead of
    // the confusing full date range.
    final isAllYear = session.startDate.month == 1 &&
        session.startDate.day == 1 &&
        session.endDate.month == 12 &&
        session.endDate.day == 31;
    // The API returns a placeholder year (1972), so only month/day is shown.
    final dateFormat = DateFormat.MMMd(locale);
    final range = isAllYear
        ? AppLocalizations.of(context)!.allYear
        : '${dateFormat.format(session.startDate)} - ${dateFormat.format(session.endDate)}';

    return Card(
      color: session.current
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surfaceContainerHigh,
      child: ListTile(
        title: Text(session.name),
        subtitle: Text(range),
        trailing: session.current
            ? Icon(Icons.check_circle,
                color: Theme.of(context).colorScheme.primary)
            : null,
      ),
    );
  }
}

class _HolidayTile extends StatelessWidget {
  const _HolidayTile({required this.holiday});

  final RouteHoliday holiday;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.calendar_today, size: 20),
        title: Text(holiday.name),
        trailing: Text(DateFormat.MMMEd(locale).format(holiday.date)),
      ),
    );
  }
}

/// Placeholder shown while the full route details load, mirroring the real
/// section layout so the transition is smooth.
class _DetailsSkeleton extends StatelessWidget {
  const _DetailsSkeleton();

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).colorScheme.surfaceContainerHigh;
    return Skeletonizer(
      enabled: true,
      child: Column(
        children: [
          _Section(
            title: 'Directions',
            icon: Icons.alt_route,
            child: Column(
              children: List.generate(
                2,
                (_) => Card(
                  color: cardColor,
                  child: const ListTile(
                    leading: Icon(Icons.arrow_forward),
                    title: Text('Direction placeholder name'),
                    subtitle: Text('00 stops · 0.0 km'),
                    trailing: Text('Outbound'),
                  ),
                ),
              ),
            ),
          ),
          _Section(
            title: 'Operating period',
            icon: Icons.event_available,
            child: Card(
              color: cardColor,
              child: const ListTile(
                title: Text('Session placeholder'),
                subtitle: Text('Jan 0 - Dec 00'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          Icon(Icons.error_outline,
              size: 40, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Text(AppLocalizations.of(context)!.error),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(MaterialLocalizations.of(context)
                .refreshIndicatorSemanticLabel),
          ),
        ],
      ),
    );
  }
}
