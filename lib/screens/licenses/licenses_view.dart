import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:via_mallorca/components/app_bar.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';

/// Attribution required by the licenses of the third-party data this app shows,
/// plus the licenses of the app itself and its dependencies.
class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});

  /// The consortium that publishes the transit open data, credited by name
  /// because CC BY 4.0 requires attributing the author.
  static final Uri _openDataPortal = Uri.https(
      'www.tib.org', '/en/sobre-ctm/portal-de-transparencia/dades-obertes');

  static final Uri _ccBy =
      Uri.https('creativecommons.org', '/licenses/by/4.0/');

  static final Uri _osmCopyright =
      Uri.https('www.openstreetmap.org', '/copyright');

  static final Uri _repository =
      Uri.https('github.com', '/open-transport-mallorca/ViaMallorca');

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: ViaAppBar(title: localizations.licenses, actions: const []),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Card.filled(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(child: Text(localizations.notAffiliated)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            _LicenseSection(
              icon: Icons.directions_bus,
              title: localizations.transitDataTitle,
              body: localizations.transitDataBody,
              attribution: localizations.licensedBy(
                  'Consorci de Transports de Mallorca (CTM)',
                  'Creative Commons Attribution 4.0 International (CC BY 4.0)'),
              links: [
                _LinkButton(
                    label: localizations.openDataPortal, uri: _openDataPortal),
                _LinkButton(label: localizations.viewLicense, uri: _ccBy),
              ],
            ),
            _LicenseSection(
              icon: Icons.map_outlined,
              title: localizations.mapDataTitle,
              body: localizations.mapDataBody,
              attribution: localizations.licensedBy('OpenStreetMap',
                  'Open Database License (ODbL) / CC BY-SA 2.0'),
              links: [
                _LinkButton(
                    label: localizations.viewLicense, uri: _osmCopyright),
              ],
            ),
            _LicenseSection(
              icon: Icons.smartphone,
              title: localizations.thisAppTitle,
              body: localizations.thisAppBody,
              attribution: localizations.licensedBy(
                  'Open Transport Mallorca', 'MIT License'),
              links: [
                _LinkButton(
                    label: localizations.sourceCode,
                    // ignore: deprecated_member_use
                    icon: MdiIcons.github,
                    uri: _repository),
              ],
            ),
            const SizedBox(height: 8),
            Card.outlined(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: const Icon(Icons.code),
                title: Text(localizations.openSourceLicenses),
                subtitle: Text(localizations.openSourceLicensesSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Via Mallorca',
                  applicationLegalese: '© 2024-2026 Open Transport Mallorca',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A titled block crediting one source of third-party content.
class _LicenseSection extends StatelessWidget {
  const _LicenseSection({
    required this.icon,
    required this.title,
    required this.body,
    required this.attribution,
    required this.links,
  });

  final IconData icon;
  final String title;
  final String body;
  final String attribution;
  final List<Widget> links;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(body, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(attribution,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic)),
          const SizedBox(height: 4),
          Wrap(spacing: 8, children: links),
        ],
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.uri, this.icon});

  final String label;
  final Uri uri;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => launchUrl(uri, mode: LaunchMode.externalApplication),
      icon: Icon(icon ?? Icons.open_in_new, size: 18),
      label: Text(label),
    );
  }
}
