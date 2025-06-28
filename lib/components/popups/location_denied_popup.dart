import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';

class LocationDeniedPopup extends StatelessWidget {
  const LocationDeniedPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.locationDeniedForever),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(AppLocalizations.of(context)!.locationDeniedText),
          const SizedBox(height: 8),
          Text(AppLocalizations.of(context)!.locationDeniedAction),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel)),
        TextButton(
            onPressed: () => {openAppSettings(), Navigator.pop(context)},
            child: Text(AppLocalizations.of(context)!.openSettings))
      ],
    );
  }
}
