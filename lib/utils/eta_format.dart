import 'package:via_mallorca/localization/generated/app_localizations.dart';

List<({String value, String unit})> etaParts(
    int minutes, AppLocalizations l10n) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return [
    if (hours > 0) (value: '$hours', unit: l10n.hoursUnit),
    if (rest > 0 || hours == 0) (value: '$rest', unit: l10n.minutesUnit),
  ];
}

String formatEtaShort(int minutes, AppLocalizations l10n) {
  if (minutes < 60) return '$minutes ${l10n.minutesUnit}';
  final rest = (minutes % 60).toString().padLeft(2, '0');
  return '${minutes ~/ 60}:$rest ${l10n.hoursUnit}';
}
