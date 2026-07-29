import 'package:flutter/material.dart';

/// A Material map pin for a stop: the `location_on` teardrop tinted to [color],
/// with the transport [icon] set in a badge on its head.
///
/// The tip sits at the bottom-centre of the box, so a [Marker] carrying this
/// should keep `alignment: Alignment.topCenter` to land the tip on the stop.
/// Size the enclosing [Marker] to [size] as well, or the pin overflows its box
/// and no longer sits centred over the point.
class StationMarker extends StatelessWidget {
  const StationMarker({
    super.key,
    required this.color,
    required this.onColor,
    this.icon = Icons.directions_bus,
    this.size = defaultSize,
  });

  /// The size used when a caller does not ask for a specific one. Also the box
  /// size those callers should give the enclosing [Marker].
  static const double defaultSize = 60;

  /// The pin's fill colour.
  final Color color;

  /// The colour of the glyph on the pin's head; the `on` pair of [color], so
  /// it stays legible whether [color] is dark or light.
  final Color onColor;

  /// The glyph shown in the pin's head, matching the line icons used elsewhere.
  final IconData icon;

  /// Height and width of the pin, tip included.
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The teardrop, tip at the bottom. A soft shadow lifts it off the
          // map the same way the tracked-bus marker is lifted off its route.
          Icon(
            Icons.location_on,
            size: size,
            color: color,
            shadows: const [
              Shadow(
                blurRadius: 4,
                color: Colors.black38,
                offset: Offset(0, 1),
              ),
            ],
          ),
          // The glyph has a hole through its head; a disc of the same colour
          // fills it so the white icon reads against solid colour rather than
          // the map showing through.
          Positioned(
            top: size * 0.15,
            child: Container(
              width: size * 0.5,
              height: size * 0.5,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              child: Icon(icon, size: size * 0.3, color: onColor),
            ),
          ),
        ],
      ),
    );
  }
}
