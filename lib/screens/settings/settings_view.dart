import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:locale_names/locale_names.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:via_mallorca/apis/local_storage.dart';
import 'package:via_mallorca/cache/cache_manager.dart';
import 'package:via_mallorca/components/app_bar.dart';
import 'package:via_mallorca/extensions/capitalize_string.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:via_mallorca/providers/locale_provider.dart';
import 'package:via_mallorca/providers/navigation_provider.dart';
import 'package:via_mallorca/providers/settings_provider.dart';
import 'package:via_mallorca/providers/tracking_provider.dart';
import 'package:via_mallorca/screens/licenses/licenses_view.dart';
import 'package:via_mallorca/settings/locale_picker.dart';
import 'package:via_mallorca/settings/theme_picker.dart';
import 'package:via_mallorca/utils/map_tile_cache.dart';

/// Every app-wide preference in one place, so the current value of each one is
/// visible without having to open it.
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
                  builder: (context) => const LocalePicker(),
                ),
              ),
            ),
            _SectionHeader(localizations.general),
            const _StartupTabTile(),
            const _DistanceUnitsTile(),
            const _NearbyStopCountTile(),
            _SectionHeader(localizations.notifications),
            const _ReminderLeadTimeTile(),
            if (Platform.isAndroid) const _ExactNotificationsSwitch(),
            _SectionHeader(localizations.tracking),
            const _DischargeWarningSwitch(),
            const _KeepScreenOnSwitch(),
            _SectionHeader(localizations.storage),
            const _ClearCacheTile(),
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

/// Which tab the app lands on at launch.
class _StartupTabTile extends StatelessWidget {
  const _StartupTabTile();

  /// The bottom navigation bar's destinations, in its own order, so that the
  /// stored index means the same thing in both places.
  static List<({IconData icon, String label})> _tabs(
      AppLocalizations localizations) {
    return [
      (icon: Icons.near_me, label: localizations.nearby),
      (icon: Icons.map, label: localizations.map),
      (icon: Icons.directions_bus, label: localizations.stations),
      (icon: Icons.linear_scale_sharp, label: localizations.routes),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final tabs = _tabs(localizations);
    assert(tabs.length == NavigationProvider.tabCount);

    return Consumer<SettingsProvider>(
      builder: (context, settings, _) => ListTile(
        leading: Icon(tabs[settings.startupTab].icon),
        title: Text(localizations.startupTab),
        subtitle: Text(tabs[settings.startupTab].label),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showModalBottomSheet(
          context: context,
          showDragHandle: true,
          builder: (sheetContext) => SafeArea(
            child: RadioGroup<int>(
              groupValue: settings.startupTab,
              onChanged: (value) {
                if (value != null) settings.startupTab = value;
                Navigator.pop(sheetContext);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < tabs.length; index++)
                    RadioListTile<int>(
                      value: index,
                      secondary: Icon(tabs[index].icon),
                      title: Text(tabs[index].label),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Metric or imperial, for every distance the app shows.
class _DistanceUnitsTile extends StatelessWidget {
  const _DistanceUnitsTile();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    String label(DistanceUnits units) => switch (units) {
          DistanceUnits.metric => localizations.metric,
          DistanceUnits.imperial => localizations.imperial,
        };

    return Consumer<SettingsProvider>(
      builder: (context, settings, _) => ListTile(
        leading: const Icon(Icons.straighten),
        title: Text(localizations.distanceUnits),
        subtitle: Text(label(settings.distanceUnits)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showModalBottomSheet(
          context: context,
          showDragHandle: true,
          builder: (sheetContext) => SafeArea(
            child: RadioGroup<DistanceUnits>(
              groupValue: settings.distanceUnits,
              onChanged: (value) {
                if (value != null) settings.distanceUnits = value;
                Navigator.pop(sheetContext);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final units in DistanceUnits.values)
                    RadioListTile<DistanceUnits>(
                      value: units,
                      title: Text(label(units)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// How many stops the nearby screen lists.
class _NearbyStopCountTile extends StatelessWidget {
  const _NearbyStopCountTile();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) => ListTile(
        leading: const Icon(Icons.near_me),
        title: Text(localizations.nearbyStopCount),
        subtitle:
            Text(localizations.nearbyStopCountValue(settings.nearbyStopCount)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showNumberPicker(
          context: context,
          title: localizations.nearbyStopCount,
          value: settings.nearbyStopCount,
          minValue: SettingsProvider.minNearbyStopCount,
          maxValue: SettingsProvider.maxNearbyStopCount,
          step: 5,
          onChanged: (value) => settings.nearbyStopCount = value,
        ),
      ),
    );
  }
}

/// The default warning a new departure reminder is given.
class _ReminderLeadTimeTile extends StatelessWidget {
  const _ReminderLeadTimeTile();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) => ListTile(
        leading: const Icon(Icons.alarm),
        title: Text(localizations.defaultReminderTime),
        subtitle: Text(
            '${localizations.minutesBeforeValue(settings.notificationLeadTime)}\n'
            '${localizations.defaultReminderTimeDescription}'),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showNumberPicker(
          context: context,
          title: localizations.defaultReminderTime,
          value: settings.notificationLeadTime,
          minValue: SettingsProvider.minNotificationLeadTime,
          maxValue: SettingsProvider.maxNotificationLeadTime,
          onChanged: (value) => settings.notificationLeadTime = value,
        ),
      ),
    );
  }
}

/// Whether tracking a bus from a stop you cannot board at asks first.
class _DischargeWarningSwitch extends StatelessWidget {
  const _DischargeWarningSwitch();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) => SwitchListTile(
        value: settings.showDischargeOnlyWarning,
        onChanged: (value) => settings.showDischargeOnlyWarning = value,
        secondary: const Icon(Icons.exit_to_app),
        title: Text(localizations.warnDropOffOnly),
        subtitle: Text(localizations.warnDropOffOnlyDescription),
      ),
    );
  }
}

/// Whether the display stays awake while a bus is being followed.
class _KeepScreenOnSwitch extends StatelessWidget {
  const _KeepScreenOnSwitch();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) => SwitchListTile(
        value: settings.keepScreenOnWhileTracking,
        onChanged: (value) {
          settings.keepScreenOnWhileTracking = value;
          // Applies to a trip already in progress, not just the next one.
          context.read<TrackingProvider>().refreshWakelock();
        },
        secondary: const Icon(Icons.screen_lock_portrait),
        title: Text(localizations.keepScreenOn),
        subtitle: Text(localizations.keepScreenOnDescription),
      ),
    );
  }
}

/// Deletes the saved stops, lines and map tiles.
class _ClearCacheTile extends StatefulWidget {
  const _ClearCacheTile();

  @override
  State<_ClearCacheTile> createState() => _ClearCacheTileState();
}

class _ClearCacheTileState extends State<_ClearCacheTile> {
  bool _clearing = false;

  Future<void> _confirmAndClear() async {
    final localizations = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.clearCacheDialogTitle),
        content: Text(localizations.clearCacheDialogSubtitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(localizations.clear),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _clearing = true);
    await CacheManager.clearCache();
    await clearMapTileCache();
    if (!mounted) return;
    setState(() => _clearing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(localizations.cacheCleared)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return ListTile(
      leading: const Icon(Icons.cleaning_services),
      title: Text(localizations.clearCache),
      subtitle: Text(localizations.clearCacheDescription),
      trailing: _clearing
          ? const SizedBox(
              width: 24, height: 24, child: CircularProgressIndicator())
          : null,
      onTap: _clearing ? null : _confirmAndClear,
    );
  }
}

/// A bottom sheet holding a single number picker, for the settings that are a
/// count rather than a choice.
Future<void> _showNumberPicker({
  required BuildContext context,
  required String title,
  required int value,
  required int minValue,
  required int maxValue,
  required ValueChanged<int> onChanged,
  int step = 1,
}) {
  var selected = value;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            // Stretch so the title and the confirm button span the sheet
            // rather than huddling in the middle of it.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              // The picker itself is a fixed-width column of numbers, so it
              // has to be centred rather than stretched.
              Center(
                child: NumberPicker(
                  haptics: true,
                  minValue: minValue,
                  maxValue: maxValue,
                  step: step,
                  value: selected,
                  onChanged: (next) => setState(() => selected = next),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  onChanged(selected);
                  Navigator.pop(sheetContext);
                },
                child: Text(MaterialLocalizations.of(context).okButtonLabel),
              ),
            ],
          ),
        ),
      ),
    ),
  );
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
