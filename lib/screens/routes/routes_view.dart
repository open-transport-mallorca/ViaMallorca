import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/providers/navigation_provider.dart';
import 'package:via_mallorca/screens/timetable_viewer/timetable_view.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'routes_viewmodel.dart';

class RoutesScreen extends StatelessWidget {
  const RoutesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => RoutesViewModel(),
      child: Consumer<RoutesViewModel>(
        builder: (context, viewModel, _) {
          if (viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final cardColor = Theme.of(context).colorScheme.surfaceContainerHigh;

          final lines = viewModel.filteredLines;
          final searchQuery = viewModel.searchQuery;

          return Column(
            children: [
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.all(8),
                child: SearchBar(
                  elevation: WidgetStateProperty.all(2.0),
                  controller: viewModel.searchController,
                  onTapOutside: (event) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: const Icon(Icons.search_rounded),
                  ),
                  trailing: [
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: viewModel.searchController.clear,
                    ),
                  ],
                  hintText: AppLocalizations.of(context)!.searchLine,
                ),
              ),
              Expanded(
                child: lines.isEmpty && searchQuery.isNotEmpty
                    ? Center(
                        child: Text(AppLocalizations.of(context)!.noResults))
                    : ListView.builder(
                        itemCount: lines.length,
                        itemBuilder: (context, index) {
                          final line = lines[index];
                          final tileIcon = _getIconForLine(line);

                          return Card(
                            color: cardColor,
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              title: Text(line.code,
                                  style: const TextStyle(fontSize: 20)),
                              subtitle: Text(line.name),
                              leading: tileIcon,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => TimetableViewer(
                                            lineCode: line.code),
                                      ),
                                    ),
                                    icon: const Icon(
                                        Icons.access_time_filled_rounded),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_ios),
                                ],
                              ),
                              onTap: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                Provider.of<NavigationProvider>(context,
                                        listen: false)
                                    .setIndex(1);
                                Provider.of<MapProvider>(context, listen: false)
                                    .viewRoute(line, context);
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Icon _getIconForLine(RouteLine line) {
    switch (line.type) {
      case LineType.metro:
        return const Icon(Icons.subway_outlined);
      case LineType.train:
        return const Icon(Icons.train);
      default:
        return line.code.startsWith("A")
            ? const Icon(Icons.airplanemode_active_outlined)
            : const Icon(Icons.directions_bus);
    }
  }
}
