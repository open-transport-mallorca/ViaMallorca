import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart' hide Consumer, Provider;
import 'package:provider/provider.dart';
import 'package:via_mallorca/components/search_bar.dart';
import 'package:via_mallorca/providers/favorites_provider.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/providers/navigation_provider.dart';
import 'package:via_mallorca/screens/timetable_viewer/timetable_view.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:via_mallorca/utils/line_icon.dart';
import 'routes_viewmodel.dart';

class RoutesScreen extends StatelessWidget {
  const RoutesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritesProvider>(
        builder: (context, favoritesProvider, child) {
      final favoriteRoutes = favoritesProvider.favoriteRoutes;
      return ChangeNotifierProvider(
        create: (context) => RoutesViewModel(favoritesProvider),
        child: Consumer<RoutesViewModel>(
          builder: (context, viewModel, _) {
            if (viewModel.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (viewModel.onlyFavourites && favoriteRoutes.isEmpty) {
              viewModel.onlyFavourites = false;
            }

            final routes = viewModel.filteredRoutes;
            final searchQuery = viewModel.searchQuery;

            return Column(
              children: [
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: ViaSearchBar(
                      controller: viewModel.searchController,
                      onClear: viewModel.searchController.clear,
                      hintText: AppLocalizations.of(context)!.searchLine),
                ),
                filterChips(context, viewModel, favoriteRoutes),
                Expanded(
                  child: routes.isEmpty && searchQuery.isNotEmpty
                      ? Center(
                          child: Text(AppLocalizations.of(context)!.noResults))
                      : ListView.builder(
                          itemCount: routes.length,
                          itemBuilder: (context, index) =>
                              RouteTile(route: routes[index])),
                ),
              ],
            );
          },
        ),
      );
    });
  }

  Widget filterChips(BuildContext context, RoutesViewModel viewModel,
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

class RouteTile extends ConsumerWidget {
  const RouteTile({
    super.key,
    required this.route,
  });

  final RouteLine route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardColor = Theme.of(context).colorScheme.surfaceContainerHigh;
    final tileIcon = getIconForRouteLine(route);
    return Consumer<FavoritesProvider>(
        builder: (context, favoritesProvider, child) {
      return Card(
        color: cardColor,
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          title: Text(route.code, style: const TextStyle(fontSize: 20)),
          subtitle: Text(route.name),
          leading: tileIcon,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TimetableViewer(lineCode: route.code),
                  ),
                ),
                icon: const Icon(Icons.access_time_filled_rounded),
              ),
              IconButton(
                icon: Icon(
                  favoritesProvider.isFavoriteRoute(route.code.toString())
                      ? Icons.star
                      : Icons.star_outline,
                ),
                onPressed: () {
                  if (favoritesProvider
                      .isFavoriteRoute(route.code.toString())) {
                    favoritesProvider
                        .removeFavoriteRoute(route.code.toString());
                  } else {
                    favoritesProvider.addFavoriteRoute(route.code.toString());
                  }
                },
              ),
            ],
          ),
          onTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
            ref.read(navigationProvider.notifier).setIndex(1);
            Provider.of<MapProvider>(context, listen: false)
                .viewRoute(context, ref, line: route);
          },
        ),
      );
    });
  }
}
