import 'package:flutter/material.dart';
import 'package:via_mallorca/components/app_bar.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:mallorca_transit_services/mallorca_transit_services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// A screen widget that displays a timetable viewer.
///
/// The [TimetableViewer] widget is a stateful widget that displays a timetable for a specific line code.
/// It provides a download button to save the timetable as a PDF file.
class TimetableViewer extends StatefulWidget {
  /// Creates a [TimetableViewer] widget.
  ///
  /// The [lineCode] parameter is required and specifies the code of the line
  /// for which the timetable is displayed.
  const TimetableViewer({super.key, required this.lineCode});

  /// The code of the line for which the timetable is displayed.
  final String lineCode;

  @override
  State<TimetableViewer> createState() => _TimetableViewerState();
}

class _TimetableViewerState extends State<TimetableViewer> {
  @override
  Widget build(BuildContext context) {
    /// Saves the timetable as a PDF file and launches the download link.
    Future<void> saveFile() async {
      try {
        var downloadLink = await RouteLine.getPdfTimetable(widget.lineCode);
        launchUrl(downloadLink!);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ));
        }
      }
    }

    return Scaffold(
      appBar: ViaAppBar(
        title:
            "${AppLocalizations.of(context)!.timetableViewer} - ${widget.lineCode}",
        actions: [
          IconButton(
              icon: const Icon(Icons.download), onPressed: () => saveFile()),
        ],
      ),
      body: SafeArea(
          child: FutureBuilder<Uri?>(
              future: RouteLine.getPdfTimetable(widget.lineCode),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(strokeWidth: 6));
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text(
                    '${AppLocalizations.of(context)!.error}: ${snapshot.error}',
                    style: TextStyle(
                        fontSize: 24,
                        color: Theme.of(context).colorScheme.error),
                  ));
                }
                return SfPdfViewer.network(snapshot.data.toString());
              })),
    );
  }
}
