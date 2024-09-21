import 'package:flutter/material.dart';

class ViaAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ViaAppBar({super.key, required this.title, required this.actions});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: actions,
      elevation: 4,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}
