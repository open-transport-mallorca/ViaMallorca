import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'package:via_mallorca/providers/map_provider.dart';
import 'package:via_mallorca/providers/tracking_provider.dart';
import 'package:via_mallorca/utils/distance_formatter.dart';
import 'package:via_mallorca/utils/eta_format.dart';

class CollapsedBar extends StatelessWidget {
  const CollapsedBar({
    super.key,
    required this.tracking,
    required this.trip,
    required this.onToggle,
    required this.open,
  });

  final TrackingProvider tracking;
  final TripSummary? trip;
  final VoidCallback onToggle;
  final ValueListenable<bool> open;

  static const _onTimeLight = Color(0xFF188038);
  static const _onTimeDark = Color(0xFF81C995);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final trip = this.trip;

    final reconnecting =
        tracking.connectionStatus == ConnectionStatus.disconnected;
    final delay = tracking.delayMinutes;
    final late = delay != null && delay > 0;
    final etaColor = late
        ? scheme.error
        : scheme.brightness == Brightness.dark
            ? _onTimeDark
            : _onTimeLight;

    final minutes = trip?.minutes;
    final arrival = trip?.arrival;
    final meters = trip?.metersLeft;
    final distance = meters == null
        ? null
        : DistanceFormatter.formatDistance(meters, context);

    final valueStyle = text.headlineMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: etaColor,
    );
    final unitStyle = text.titleLarge?.copyWith(color: etaColor);

    final Widget headline;
    if (minutes != null && minutes > 0) {
      final parts = etaParts(minutes, l10n);
      headline = Text.rich(TextSpan(children: [
        for (int i = 0; i < parts.length; i++) ...[
          TextSpan(
              text: i == 0 ? parts[i].value : ' ${parts[i].value}',
              style: valueStyle),
          TextSpan(text: ' ${parts[i].unit}', style: unitStyle),
        ],
      ]));
    } else if (minutes == 0) {
      headline = Text(l10n.arrivingIn(0), style: valueStyle);
    } else if (distance != null) {
      headline = Text(distance, style: valueStyle);
    } else {
      headline = Text(
        reconnecting ? l10n.trackingReconnecting : l10n.trackingConnecting,
        style: text.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
      );
    }

    final secondary = text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant);
    final details = <InlineSpan>[
      if (minutes != null && distance != null) TextSpan(text: distance),
      if (arrival != null) TextSpan(text: DateFormat.Hm().format(arrival)),
      if (late)
        TextSpan(
          text: l10n.minutesLate(delay),
          style: TextStyle(color: scheme.error),
        ),
      if (reconnecting && trip != null)
        TextSpan(text: l10n.trackingReconnecting),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton.outlined(
            tooltip: l10n.stopTracking,
            iconSize: 28,
            onPressed: () async {
              final map = context.read<MapProvider>();
              await tracking.stopTracking();
              map.clearRoute();
            },
            icon: const Icon(Icons.close),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                headline,
                if (details.isNotEmpty)
                  Text.rich(
                    TextSpan(children: [
                      for (int i = 0; i < details.length; i++) ...[
                        if (i > 0) const TextSpan(text: '  •  '),
                        details[i],
                      ],
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: secondary,
                  ),
              ],
            ),
          ),
          IconButton.outlined(
            tooltip: l10n.stationsOnRoute,
            iconSize: 28,
            onPressed: onToggle,
            icon: ValueListenableBuilder<bool>(
              valueListenable: open,
              builder: (context, open, _) => AnimatedRotation(
                turns: open ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.expand_less),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
