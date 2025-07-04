import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/components/bottom_sheets/station/station_view.dart';
import 'package:via_mallorca/components/search_bar.dart';
import 'package:via_mallorca/providers/favorites_provider.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/providers/navigation_provider.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'stations_viewmodel.dart';

class StationsScreen extends StatelessWidget {
  const StationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritesProvider>(
        builder: (context, favoritesProvider, child) {
      final favoriteStations = favoritesProvider.favoriteStations;
      return ChangeNotifierProvider(
        create: (_) => StationsViewModel(favoritesProvider)..loadStations(),
        child: Consumer<StationsViewModel>(
          builder: (context, viewModel, _) {
            if (viewModel.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (viewModel.onlyFavourites && favoriteStations.isEmpty) {
              viewModel.onlyFavourites = false;
            }

            final stations = viewModel.filteredStations;
            return Column(
              children: [
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: ViaSearchBar(
                      controller: viewModel.searchController,
                      onClear: viewModel.searchController.clear,
                      hintText: AppLocalizations.of(context)!.searchStation),
                ),
                filterChips(context, viewModel, favoriteStations),
                Expanded(
                    child: stations.isEmpty
                        ? Center(
                            child:
                                Text(AppLocalizations.of(context)!.noResults))
                        : ListView.builder(
                            itemCount: stations.length,
                            itemBuilder: (context, index) =>
                                StationTile(station: stations[index]))),
              ],
            );
          },
        ),
      );
    });
  }

  Widget filterChips(BuildContext context, StationsViewModel viewModel,
      List<String> favoriteRoutes) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          ChoiceChip.elevated(
            label: Text(AppLocalizations.of(context)!.all),
            selected: !viewModel.onlyFavourites,
            onSelected: (_) => viewModel.toggleFavouritesFilter(false),
          ),
          const SizedBox(width: 8),
          ChoiceChip.elevated(
            label: Text(AppLocalizations.of(context)!.favourites),
            selected: viewModel.onlyFavourites,
            onSelected: favoriteRoutes.isNotEmpty == true
                ? (_) => viewModel.toggleFavouritesFilter(true)
                : null,
          ),
        ],
      ),
    );
  }
}

class StationTile extends StatelessWidget {
  const StationTile({super.key, required this.station});

  final Station station;

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).colorScheme.surfaceContainerHigh;

    return Consumer<FavoritesProvider>(
        builder: (context, favoritesProvider, child) {
      return Card(
        color: cardColor,
        child: ListTile(
          title: Text(station.name, style: const TextStyle(fontSize: 18)),
          subtitle: Text(station.ref ?? ""),
          trailing: IconButton(
            icon: Icon(
              favoritesProvider.isFavoriteStation(station.code.toString())
                  ? Icons.star
                  : Icons.star_outline,
            ),
            onPressed: () {
              if (favoritesProvider
                  .isFavoriteStation(station.code.toString())) {
                favoritesProvider
                    .removeFavoriteStation(station.code.toString());
              } else {
                favoritesProvider.addFavoriteStation(station.code.toString());
              }
            },
          ),
          onTap: () {
            Provider.of<NavigationProvider>(context, listen: false).setIndex(1);
            showBottomSheet(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(10.0)),
              ),
              context: context,
              builder: (_) => StationSheet(station: station),
            );
            Provider.of<MapProvider>(context, listen: false).updateLocation(
              LatLng(station.lat, station.long),
              18,
            );
          },
        ),
      );
    });
  }
}
