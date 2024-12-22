import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/components/bottom_sheets/station/station_view.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/providers/navigation_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'stations_viewmodel.dart';

class StationsScreen extends StatelessWidget {
  const StationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => StationsViewModel(),
      child: Consumer<StationsViewModel>(
        builder: (context, viewModel, _) {
          final stations = viewModel.filteredStations;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: SearchBar(
                  controller: viewModel.searchController,
                  leading: const Icon(Icons.search_rounded),
                  onTapOutside: (event) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  trailing: [
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        viewModel.searchController.clear();
                        viewModel.searchStations('');
                      },
                    ),
                  ],
                  hintText: AppLocalizations.of(context)!.searchStation,
                  onChanged: viewModel.searchStations,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    ChoiceChip.elevated(
                      label: const Text("All"),
                      selected: !viewModel.onlyFavourites,
                      onSelected: (_) =>
                          viewModel.toggleFavouritesFilter(false),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip.elevated(
                      label: Text(AppLocalizations.of(context)!.favourites),
                      selected: viewModel.onlyFavourites,
                      onSelected: viewModel.favourites?.isNotEmpty == true
                          ? (_) => viewModel.toggleFavouritesFilter(true)
                          : null,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: stations.isEmpty
                    ? Center(
                        child: Text(AppLocalizations.of(context)!.noResults))
                    : ListView.builder(
                        itemCount: stations.length,
                        itemBuilder: (context, index) {
                          final station = stations[index];
                          return Card(
                            child: ListTile(
                              title: Text(station.name,
                                  style: const TextStyle(fontSize: 18)),
                              subtitle: Text(station.code.toString()),
                              trailing: IconButton(
                                icon: Icon(
                                  viewModel.favourites?.contains(station) ==
                                          true
                                      ? Icons.star
                                      : Icons.star_outline,
                                ),
                                onPressed: () {
                                  if (viewModel.favourites?.contains(station) ==
                                      true) {
                                    viewModel.removeFavourite(station);
                                  } else {
                                    viewModel.addFavourite(station);
                                  }
                                },
                              ),
                              onTap: () {
                                Provider.of<NavigationProvider>(context,
                                        listen: false)
                                    .setIndex(1);
                                showBottomSheet(
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(10.0)),
                                  ),
                                  context: context,
                                  builder: (_) =>
                                      StationSheet(station: station),
                                );
                                Provider.of<MapProvider>(context, listen: false)
                                    .updateLocation(
                                  LatLng(station.lat, station.long),
                                  18,
                                );
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
}
