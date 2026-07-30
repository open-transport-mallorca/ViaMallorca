import 'package:flutter/material.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:via_mallorca/screens/route_details/route_details_view.dart';
import 'station_line_labels_viewmodel.dart';

class StationLineLabels extends StatelessWidget {
  const StationLineLabels({super.key, required this.station});

  final Station station;

  @override
  Widget build(BuildContext context) {
    // Reuse the lines an ancestor already loaded for this station when there
    // is one, so a screen showing both the labels and the departures fetches
    // them once.
    final shared = StationViewModel.maybeOf(context, station);
    if (shared != null) return _buildLabels(context, shared);

    return ChangeNotifierProvider(
      create: (_) => StationViewModel(station)..loadLines(),
      child: Consumer<StationViewModel>(
        builder: (context, viewModel, child) =>
            _buildLabels(context, viewModel),
      ),
    );
  }

  Widget _buildLabels(BuildContext context, StationViewModel viewModel) {
    if (!viewModel.isDataLoaded) {
      return Skeletonizer(
        enabled: true,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            AppLocalizations.of(context)!.loading,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    final activeLines = viewModel.activeLines;

    if (activeLines.isEmpty) {
      return Padding(padding: const EdgeInsets.all(8.0), child: Container());
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: 100),
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: activeLines.map((line) {
            return Material(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RouteDetailsScreen(route: line),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        line.code,
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (line.summerOnly == true) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.wb_sunny,
                            size: 14, color: Colors.orange.shade700),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
