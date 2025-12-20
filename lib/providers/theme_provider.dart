import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:via_mallorca/apis/local_storage.dart';

final themeProvider =
    NotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);

class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    return LocalStorageApi.getThemeMode();
  }

  void setThemeMode(ThemeMode mode) {
    LocalStorageApi.setThemeMode(mode);
    state = mode;
  }
}
