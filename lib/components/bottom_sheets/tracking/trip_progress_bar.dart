import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:via_mallorca/utils/line_icon.dart';

class TripProgressBar extends StatelessWidget {
  const TripProgressBar({
    super.key,
    required this.progress,
    required this.span,
    required this.busDistance,
    required this.fixInterval,
    required this.color,
    required this.code,
  });

  final double progress;
  final ({double from, double to})? span;

  final ValueListenable<double?> busDistance;
  final Duration fixInterval;
  final Color color;
  final String? code;

  static const double _badge = 24;
  static const double _track = 6;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _badge,
      child: LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        return ValueListenableBuilder<double?>(
          valueListenable: busDistance,
          builder: (context, distance, _) {
            final span = this.span;
            if (span != null && distance != null) {
              final value = (distance - span.from) / (span.to - span.from);
              return _bar(width, value.clamp(0.0, 1.0));
            }
            // Off the route: glide to each new value at the marker's pace
            return TweenAnimationBuilder<double>(
              tween: Tween(end: progress.clamp(0.0, 1.0)),
              duration: fixInterval,
              builder: (context, value, _) => _bar(width, value),
            );
          },
        );
      }),
    );
  }

  Widget _bar(double width, double value) {
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black;
    // The badge stays whole at both ends rather than hanging off
    final x = (width - _badge) * value;

    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        // Sizes the stack to the badge so it isn't clipped
        SizedBox(width: width, height: _badge),
        Container(
          height: _track,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(_track / 2),
          ),
        ),
        Container(
          width: x + _badge / 2,
          height: _track,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(_track / 2),
          ),
        ),
        Positioned(
          right: 0,
          child: Container(
            width: _track + 4,
            height: _track + 4,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        Positioned(
          left: x,
          child: Container(
            width: _badge,
            height: _badge,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(
              code == null
                  ? Icons.directions_bus
                  : getIconDataFromLineCode(code!),
              size: 15,
              color: onColor,
            ),
          ),
        ),
      ],
    );
  }
}
