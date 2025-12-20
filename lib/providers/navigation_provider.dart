import 'package:hooks_riverpod/hooks_riverpod.dart';

final navigationProvider =
    NotifierProvider<NavigationNotifier, int>(NavigationNotifier.new);

class NavigationNotifier extends Notifier<int> {
  @override
  int build() {
    return 0;
  }

  void setIndex(int index) {
    state = index;
  }
}
