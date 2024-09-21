import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/cache/cache_manager.dart';
import 'package:via_mallorca/extensions/remove_punctuation.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/providers/navigation_provider.dart';
import 'package:via_mallorca/screens/timetable_viewer.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class LinesScreen extends StatefulWidget {
  const LinesScreen({super.key});

  @override
  State<LinesScreen> createState() => _LinesScreenState();
}

class _LinesScreenState extends State<LinesScreen> {
  TextEditingController controller = TextEditingController();

  List<RouteLine> cachedLines = [];

  @override
  void initState() {
    super.initState();
    CacheManager.getAllLines().then((value) {
      setState(() {
        cachedLines = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: SearchBar(
            controller: controller,
            leading: const Icon(Icons.search_rounded),
            trailing: [
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  setState(() {
                    controller.clear();
                  });
                },
              ),
            ],
            hintText: AppLocalizations.of(context)!.searchLine,
            onChanged: (value) {
              setState(() {});
            },
          ),
        ),
        Expanded(
          child: FutureBuilder<List<RouteLine>>(
              future: cachedLines.isEmpty
                  ? RouteLine.getAllLines()
                  : Future.value(cachedLines),
              builder: (context, snapshot) {
                if (cachedLines.isEmpty &&
                    snapshot.data != null &&
                    snapshot.data!.isNotEmpty &&
                    controller.text.isEmpty) {
                  cachedLines = snapshot.data!;
                  CacheManager.setAllLines(snapshot.data!);
                }
                List<RouteLine> lines = List.from(cachedLines);
                List<RouteLine> searchResults = [];
                if (controller.text.isNotEmpty) {
                  searchResults = lines
                      .where((line) =>
                          line.name.toLowerCase().removePunctuation().contains(controller.text.toLowerCase().removePunctuation()) ||
                          line.code.toLowerCase().removePunctuation().contains(
                              controller.text
                                  .toLowerCase()
                                  .removePunctuation()) ||
                          line.type.toString().removePunctuation().contains(
                              controller.text
                                  .toLowerCase()
                                  .removePunctuation()))
                      .toList();
                }
                int? itemCount;

                if (searchResults.isNotEmpty) {
                  lines.removeWhere((item) => !searchResults.contains(item));
                }

                if (searchResults.isEmpty && controller.text.isNotEmpty) {
                  itemCount = 1;
                } else if (lines.isEmpty) {
                  itemCount = 10;
                } else {
                  itemCount = lines.length;
                }
                return ListView.builder(
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      if (searchResults.isEmpty && controller.text.isNotEmpty) {
                        return Card(
                          child: ListTile(
                            title:
                                Text(AppLocalizations.of(context)!.noResults),
                          ),
                        );
                      }
                      final line = lines.isEmpty ? null : lines[index];
                      Icon? tileIcon;
                      if (lines.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      switch (line!.type) {
                        case LineType.metro:
                          tileIcon = const Icon(Icons.subway_outlined);
                          break;
                        case LineType.train:
                          tileIcon = const Icon(Icons.train);
                          break;
                        case LineType.bus || LineType.unknown:
                          tileIcon = const Icon(Icons.directions_bus);
                          break;
                      }

                      // Lines that start with "A" are airport lines
                      if (line.code.startsWith("A")) {
                        tileIcon =
                            const Icon(Icons.airplanemode_active_outlined);
                      }
                      return Card(
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
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
                                              lineCode: line.code))),
                                  icon: const Icon(
                                      Icons.access_time_filled_rounded)),
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
                    });
              }),
        )
      ],
    );
  }
}
