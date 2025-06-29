import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'line_labels_skeleton.dart';

class NearbyCardSkeleton extends StatelessWidget {
  const NearbyCardSkeleton({super.key, required});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
        enabled: true,
        child: Card(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: ListTile(
            title: Text(
              "Station Name",
            ),
            subtitle: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Along street name"),
                LineLabelsSkeleton(),
              ],
            ),
            isThreeLine: false,
            trailing: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 80,
                      height: 25,
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_pin),
                            const SizedBox(width: 5),
                            Text(
                              "100 m",
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.arrow_forward_ios_rounded),
              ],
            ),
          ),
        ));
  }
}
