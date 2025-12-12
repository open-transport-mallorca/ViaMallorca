import 'dart:io';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:via_mallorca/apis/local_storage.dart';
import 'package:via_mallorca/settings/locale_picker.dart';
import 'package:via_mallorca/settings/theme_picker.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';

class SettingsPopup extends StatefulWidget {
  const SettingsPopup({super.key});

  @override
  State<SettingsPopup> createState() => _SettingsPopupState();
}

class _SettingsPopupState extends State<SettingsPopup> {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'theme',
          child: ListTile(
            title: Text(AppLocalizations.of(context)!.theme),
            leading: Icon(Theme.of(context).brightness == Brightness.light
                ? Icons.light_mode
                : Icons.dark_mode),
          ),
        ),
        PopupMenuItem(
          value: 'language',
          child: ListTile(
            title: Text(AppLocalizations.of(context)!.language),
            leading: const Icon(Icons.translate),
          ),
        ),
        if (Platform.isAndroid) ...[
          if (LocalStorageApi.useInexactNotifications())
            PopupMenuItem(
                value: 'precise_notifications',
                child: ListTile(
                  title: Text(AppLocalizations.of(context)!.switchToExact),
                  leading: Icon(Icons.notification_important),
                ))
          else
            PopupMenuItem(
                value: 'inprecise_notifications',
                child: ListTile(
                  title: Text(AppLocalizations.of(context)!.switchToInexact),
                  leading: Icon(Icons.notifications),
                )),
        ],
        PopupMenuItem(
            value: 'github',
            child: ListTile(
              title: const Text("GitHub"),
              leading: Icon(MdiIcons.github),
              trailing: Icon(
                Icons.open_in_new,
                color: Theme.of(context).colorScheme.primary,
              ),
            )),
      ],
      offset: const Offset(0, 60),
      onSelected: (value) async {
        switch (value) {
          case 'theme':
            showModalBottomSheet(
                context: context, builder: (context) => const ThemePicker());
            break;

          case 'language':
            showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (context) => DraggableScrollableSheet(
                    expand: false,
                    builder: (context, index) => const LocalePicker()));
            break;

          case 'precise_notifications':
            await Permission.scheduleExactAlarm.request();
            await LocalStorageApi.setUseInexactNotifications(false);
            break;

          case 'inprecise_notifications':
            await LocalStorageApi.setUseInexactNotifications(true);
            break;

          case 'github':
            launchUrl(
                Uri.https('github.com', 'open-transport-mallorca/ViaMallorca'));
        }
      },
    );
  }
}
