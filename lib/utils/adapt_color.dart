import 'package:flutter/material.dart';
import 'dart:math' as math;

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

  static List<double> createHueShiftMatrix(double degree) {
    final rad = degree * (math.pi / 180);
    final cosA = math.cos(rad);
    final sinA = math.sin(rad);
    const lumR = 0.213;
    const lumG = 0.715;
    const lumB = 0.072;

    return [
      lumR + cosA * (1 - lumR) + sinA * (-lumR),
      lumG + cosA * (-lumG) + sinA * (-lumG),
      lumB + cosA * (-lumB) + sinA * (1 - lumB),
      0,
      0,
      lumR + cosA * (-lumR) + sinA * 0.143,
      lumG + cosA * (1 - lumG) + sinA * 0.140,
      lumB + cosA * (-lumB) + sinA * -0.283,
      0,
      0,
      lumR + cosA * (-lumR) + sinA * -(1 - lumR),
      lumG + cosA * (-lumG) + sinA * lumG,
      lumB + cosA * (1 - lumB) + sinA * lumB,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }
}
