import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:via_mallorca/providers/map_provider.dart';

class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MapProvider>(builder: (context, mapProvider, _) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.5)),
        child: Center(
            child: SizedBox(
                width: 100,
                height: 100,
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      value: mapProvider.loadingProgress,
                      strokeWidth: 5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(height: 8),
                    Text(AppLocalizations.of(context)!.loading),
                  ],
                ))),
      );
    });
  }
}
