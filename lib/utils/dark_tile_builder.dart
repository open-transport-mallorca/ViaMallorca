import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

Widget monochromeDarkMode(
  BuildContext context,
  Widget tileWidget,
  TileImage tile,
) {
  return ColorFiltered(
    colorFilter: const ColorFilter.matrix(<double>[
      -0.2126, -0.7152, -0.0722, 0, 255, // Red channel
      -0.2126, -0.7152, -0.0722, 0, 255, // Green channel
      -0.2126, -0.7152, -0.0722, 0, 255, // Blue channel
      0, 0, 0, 1, 0, // Alpha channel
    ]),
    child: Transform.scale(
        scale: 1.002, // Force 0.2% overlap to hide gaps
        child: tileWidget),
  );
}
