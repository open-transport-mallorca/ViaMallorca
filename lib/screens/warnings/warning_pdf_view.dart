import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:via_mallorca/components/app_bar.dart';

class WarningPdfScreen extends StatelessWidget {
  const WarningPdfScreen({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ViaAppBar(
        title: title,
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: () =>
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          ),
        ],
      ),
      body: SafeArea(child: SfPdfViewer.network(url)),
    );
  }
}
