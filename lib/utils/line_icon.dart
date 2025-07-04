import 'package:flutter/material.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';

Icon getIconForRouteLine(RouteLine line) {
  switch (line.type) {
    case LineType.metro:
      return const Icon(Icons.subway_outlined);
    case LineType.train:
      return const Icon(Icons.train);
    default:
      return line.code.startsWith("A")
          ? const Icon(Icons.airplanemode_active_outlined)
          : const Icon(Icons.directions_bus);
  }
}

Icon getIconFromLineCode(String line) {
  if (line.startsWith("M")) {
    return const Icon(Icons.subway_outlined);
  } else if (line.startsWith("T")) {
    return const Icon(Icons.train);
  } else if (line.startsWith("A")) {
    return const Icon(Icons.airplanemode_active_outlined);
  } else {
    return const Icon(Icons.directions_bus);
  }
}
