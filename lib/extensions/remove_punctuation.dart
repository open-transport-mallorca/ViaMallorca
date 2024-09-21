/// Extension method to remove all punctuation from a string.
extension RemovePunctuation on String {
  /// Removes all punctuation from the string.
  ///
  /// Returns the string with all punctuation removed.
  String removePunctuation() {
    return replaceAll(RegExp(r'[^\w\s]'), '');
  }
}
