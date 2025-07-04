import 'package:flutter/material.dart';

class ViaSearchBar extends StatelessWidget {
  const ViaSearchBar(
      {super.key,
      required this.controller,
      required this.onClear,
      required this.hintText});

  final TextEditingController controller;
  final VoidCallback onClear;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return SearchBar(
      elevation: WidgetStateProperty.all(2.0),
      controller: controller,
      onTapOutside: (event) => FocusManager.instance.primaryFocus?.unfocus(),
      leading: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: const Icon(Icons.search_rounded),
      ),
      trailing: [
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: onClear,
        ),
      ],
      hintText: hintText,
    );
  }
}
