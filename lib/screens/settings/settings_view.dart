import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:locale_names/locale_names.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:via_mallorca/apis/local_storage.dart';
import 'package:via_mallorca/components/app_bar.dart';
import 'package:via_mallorca/extensions/capitalize_string.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:via_mallorca/providers/locale_provider.dart';
import 'package:via_mallorca/screens/licenses/licenses_view.dart';
import 'package:via_mallorca/settings/locale_picker.dart';
import 'package:via_mallorca/settings/theme_picker.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static final Uri _repository =
      Uri.https('github.com', '/open-transport-mallorca/ViaMallorca');

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: ViaAppBar(title: localizations.settings, actions: const []),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _SectionHeader(localizations.appearance),
            ListTile(
              leading: const Icon(Icons.brightness_6),
              title: Text(localizations.theme),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: ThemePicker(),
            ),
            Consumer<LocaleProvider>(
              builder: (context, localeProvider, _) => ListTile(
                leading: const Icon(Icons.translate),
                title: Text(localizations.language),
                subtitle: Text(_localeLabel(context, localeProvider.locale)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (context) => DraggableScrollableSheet(
                    expand: false,
                    builder: (context, _) => const LocalePicker(),
                  ),
                ),
              ),
            ),
            if (Platform.isAndroid) ...[
              _SectionHeader(localizations.notifications),
              const _ExactNotificationsSwitch(),
            ],
            _SectionHeader(localizations.about),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(localizations.licenses),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LicensesScreen()),
              ),
            ),
            ListTile(
              // ignore: deprecated_member_use
              leading: Icon(MdiIcons.github),
              title: const Text('GitHub'),
              subtitle: Text(localizations.sourceCode),
              trailing: Icon(Icons.open_in_new,
                  color: Theme.of(context).colorScheme.primary),
              onTap: () =>
                  launchUrl(_repository, mode: LaunchMode.externalApplication),
            ),
          ],
        ),
      ),
    );
  }

  /// The name of [locale] in its own language, or the system label when the
  /// user has not pinned one.
  static String _localeLabel(BuildContext context, Locale? locale) {
    if (locale == null) return AppLocalizations.of(context)!.system;
    return Locale.fromSubtags(languageCode: locale.languageCode)
        .nativeDisplayLanguage
        .capitalize();
  }
}

/// The label that introduces a group of related settings.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Android only delivers a scheduled notification at the minute it was asked
/// for if the app holds the exact alarm permission, so turning this on has to
/// ask for that permission and stay off when it is refused.
class _ExactNotificationsSwitch extends StatefulWidget {
  const _ExactNotificationsSwitch();

  @override
  State<_ExactNotificationsSwitch> createState() =>
      _ExactNotificationsSwitchState();
}

class _ExactNotificationsSwitchState extends State<_ExactNotificationsSwitch> {
  /// Mirrors the condition the scheduler actually uses, so the switch cannot
  /// claim exact delivery while the permission is missing.
  bool _exact = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentState();
  }

  Future<void> _loadCurrentState() async {
    final granted = await Permission.scheduleExactAlarm.status.isGranted;
    if (!mounted) return;
    setState(
        () => _exact = granted && !LocalStorageApi.useInexactNotifications());
  }

  Future<void> _onChanged(bool value) async {
    if (value && !await Permission.scheduleExactAlarm.request().isGranted) {
      // Android downgrades the alarm without the permission, so leave the
      // setting off rather than promising precision the app cannot deliver.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(AppLocalizations.of(context)!.remindersDeniedDialogSubtitle),
      ));
      return;
    }
    await LocalStorageApi.setUseInexactNotifications(!value);
    if (mounted) setState(() => _exact = value);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return SwitchListTile(
      value: _exact,
      onChanged: _onChanged,
      secondary:
          Icon(_exact ? Icons.notification_important : Icons.notifications),
      title: Text(localizations.exactNotifications),
      subtitle: Text(localizations.exactNotificationsDescription),
    );
  }
}
