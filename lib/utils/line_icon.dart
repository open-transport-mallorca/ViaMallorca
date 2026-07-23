import 'package:flutter/material.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';

IconData getIconDataForRouteLine(RouteLine line) {
  switch (line.type) {
    case LineType.metro:
      return Icons.subway_outlined;
    case LineType.train:
      return Icons.train;
    default:
      return line.code.startsWith("A")
          ? Icons.airplanemode_active_outlined
          : Icons.directions_bus;
  }
}

IconData getIconDataFromLineCode(String line) {
  if (line.startsWith("M")) {
    return Icons.subway_outlined;
  } else if (line.startsWith("T")) {
    return Icons.train;
  } else if (line.startsWith("A")) {
    return Icons.airplanemode_active_outlined;
  } else {
    return Icons.directions_bus;
  }
}

Icon getIconForRouteLine(RouteLine line) => Icon(getIconDataForRouteLine(line));

Icon getIconFromLineCode(String line) => Icon(getIconDataFromLineCode(line));
