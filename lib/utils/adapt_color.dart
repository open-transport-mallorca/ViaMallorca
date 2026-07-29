import 'package:flutter/material.dart';

/// Returns a list of two colors that adapt the given [color] based on its brightness.
/// If the brightness of the [color] is dark, the list will contain the [color]
/// itself and a lightened version of it.
///
/// If the brightness of the [color] is light, the list will contain
///  darkened version of the [color] and the [color] itself.
List<Color> adaptColor(Color color) =>
    ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? [color, ColorUtils.lighten(color, 0.15)]
        : [ColorUtils.darken(color, 0.15), color];

class ColorUtils {
  /// Darkens the given [color] by the specified [amount].
  /// The [amount] should be a value between 0 and 1,
  /// where 0 represents no change and 1 represents full darkness.
  static Color darken(Color color, [double amount = .1]) {
    assert(amount >= 0 && amount <= 1);

    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));

    return hslDark.toColor();
  }

  /// Lightens the given [color] by the specified [amount].
  /// The [amount] should be a value between 0 and 1,
  /// where 0 represents no change and 1 represents full lightness.
  static Color lighten(Color color, [double amount = .1]) {
    assert(amount >= 0 && amount <= 1);

    final hsl = HSLColor.fromColor(color);
    final hslLight =
        hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));

    return hslLight.toColor();
  }

  /// Saturates the given [color] by the specified [amount].
  /// The [amount] should be a value between 0 and 1,
  /// where 0 represents no change and 1 represents fully saturated.
  static Color saturate(Color color, [double amount = .1]) {
    assert(amount >= 0 && amount <= 1);

    final hsl = HSLColor.fromColor(color);
    final hslSaturated =
        hsl.withSaturation((hsl.saturation + amount).clamp(0.0, 1.0));

    return hslSaturated.toColor();
  }
}
