/// Extension method to capitalize the first letter of a string.
extension StringExtension on String {
  /// Capitalizes the first letter of the string and converts
  /// the rest of the string to lowercase.
  ///
  /// Returns the capitalized string.
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
