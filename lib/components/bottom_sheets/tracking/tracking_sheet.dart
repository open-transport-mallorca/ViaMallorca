import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/cache/cache_manager.dart';
import 'package:via_mallorca/components/bottom_sheets/tracking/bus_stats.dart';
import 'package:via_mallorca/components/bottom_sheets/tracking/collapsed_bar.dart';
import 'package:via_mallorca/components/bottom_sheets/tracking/trip_details.dart';
import 'package:via_mallorca/components/bottom_sheets/tracking/trip_progress_bar.dart';
import 'package:via_mallorca/components/bottom_sheets/tracking/trip_stops.dart';
import 'package:via_mallorca/utils/measure_height.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/providers/tracking_provider.dart';

class TrackingSheet extends StatefulWidget {
  const TrackingSheet({super.key, required this.floating});

  /// Rides on the sheet's top edge
  final Widget floating;

  @override
  State<TrackingSheet> createState() => _TrackingSheetState();
}

class _TrackingSheetState extends State<TrackingSheet> {
  static const double _max = 0.9;

  /// The collapsed bar's height, measured; a guess until the first layout
  double _peekHeight = 96;

  final _controller = DraggableScrollableController();
  final _extent = ValueNotifier<double?>(null);
  final _open = ValueNotifier(false);
  late final Future<List<Station>> _stations = CacheManager.getAllStations();
  double _peek = 0.15;

  /// Down to the end of the bus stats, measured, so the stops start just out
  /// of view
  double? _middleHeight;
  double _sheetHeight = 1;

  double get _middle {
    final measured = _middleHeight;
    if (measured == null) return (_peek + _max) / 2;
    return (measured / _sheetHeight).clamp(_peek + 0.05, _max);
  }

  void _onMiddleMeasured(double height) {
    if (!mounted || height == _middleHeight) return;
    setState(() => _middleHeight = height);
  }

  @override
  void dispose() {
    _controller.dispose();
    _extent.dispose();
    _open.dispose();
    super.dispose();
  }

  void _animateTo(double size) => _controller.animateTo(
        size,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );

  void _toggle() => _animateTo(_open.value ? _peek : _max);

  void _onPeekMeasured(double height) {
    if (!mounted || height == _peekHeight) return;
    final wasCollapsed =
        !_controller.isAttached || _controller.size <= _peek + 0.01;
    setState(() => _peekHeight = height);
    // initialChildSize only applies once, so follow the new peek by hand
    if (!wasCollapsed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.isAttached) _controller.jumpTo(_peek);
    });
  }

  void _showStop(Station station) {
    final map = context.read<MapProvider>();
    map.setFollowTrackedBus(false);
    map.updateLocation(LatLng(station.lat, station.long), 17);
    _animateTo(_peek);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final height = _sheetHeight = constraints.maxHeight;
      _peek = (_peekHeight / height).clamp(0.1, 0.5);
      final middle = _middle;

      return Stack(
        children: [
          ValueListenableBuilder<double?>(
            valueListenable: _extent,
            builder: (context, extent, child) {
              final current = extent ?? _peek;
              // Fades only once there's no room left above the sheet
              final room = height * (1 - current);
              final visibility = ((room - 120) / 60).clamp(0.0, 1.0);
              return Positioned(
                right: 0,
                bottom: current * height,
                child: IgnorePointer(
                  ignoring: visibility == 0,
                  child: Opacity(opacity: visibility, child: child),
                ),
              );
            },
            child: widget.floating,
          ),
          NotificationListener<DraggableScrollableNotification>(
            onNotification: (notification) {
              _extent.value = notification.extent;
              _open.value = notification.extent > _peek + 0.02;
              return false;
            },
            child: DraggableScrollableSheet(
              controller: _controller,
              initialChildSize: _peek,
              minChildSize: _peek,
              maxChildSize: _max,
              snap: true,
              snapSizes: [middle],
              builder: (context, scrollController) => _SheetBody(
                scrollController: scrollController,
                stations: _stations,
                onToggle: _toggle,
                open: _open,
                onStopTap: _showStop,
                onPeekMeasured: _onPeekMeasured,
                onMiddleMeasured: _onMiddleMeasured,
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.scrollController,
    required this.stations,
    required this.onToggle,
    required this.open,
    required this.onStopTap,
    required this.onPeekMeasured,
    required this.onMiddleMeasured,
  });

  final ScrollController scrollController;
  final Future<List<Station>> stations;
  final VoidCallback onToggle;
  final ValueListenable<bool> open;
  final void Function(Station station) onStopTap;
  final ValueChanged<double> onPeekMeasured;
  final ValueChanged<double> onMiddleMeasured;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: scheme.surfaceContainerLow,
      elevation: 3,
      shadowColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Consumer2<TrackingProvider, MapProvider>(
        builder: (context, tracking, map, _) {
          final trip = tracking.tripSummary();
          final lineColor =
              map.basePolyline(scheme.brightness)?.color ?? scheme.primary;
          final stops = tracking.stationsOnRoute;

          return ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              MeasureHeight(
                onChange: onMiddleMeasured,
                child: Column(
                  children: [
                    MeasureHeight(
                      onChange: onPeekMeasured,
                      child: Column(
                        children: [
                          const _DragHandle(),
                          CollapsedBar(
                              tracking: tracking,
                              trip: trip,
                              onToggle: onToggle,
                              open: open),
                          if (trip?.progress != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                              child: TripProgressBar(
                                progress: trip!.progress!,
                                span: trip.progressSpan,
                                busDistance: map.busRouteDistance,
                                fixInterval: tracking.fixInterval,
                                color: scheme.primary,
                                code: tracking.routeCode,
                              ),
                            ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    TripDetails(
                        tracking: tracking,
                        map: map,
                        trip: trip,
                        color: lineColor),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: BusStats(tracking: tracking),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  l10n.stationsOnRoute,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (stops == null)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (stops.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.noStationsOnRoute,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                )
              else
                FutureBuilder<List<Station>>(
                  future: stations,
                  builder: (context, snapshot) => TripStops(
                    stops: stops,
                    stations: snapshot.data ?? const [],
                    boardingStationId: tracking.trackingFromStation,
                    color: lineColor,
                    onStopTap: onStopTap,
                  ),
                ),
              SizedBox(height: 16 + MediaQuery.paddingOf(context).bottom),
            ],
          );
        },
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        width: 32,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(
                alpha: 0.4,
              ),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
