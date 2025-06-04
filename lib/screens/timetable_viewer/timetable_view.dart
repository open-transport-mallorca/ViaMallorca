import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:via_mallorca/components/app_bar.dart';
import 'package:via_mallorca/localization/generated/app_localizations.dart';
import 'timetable_viewmodel.dart';

class TimetableViewer extends StatelessWidget {
  const TimetableViewer({super.key, required this.lineCode});

  final String lineCode;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TimetableViewModel(lineCode),
      child: Consumer<TimetableViewModel>(
        builder: (context, viewModel, _) {
          return Scaffold(
            appBar: ViaAppBar(
              title:
                  "${AppLocalizations.of(context)!.timetableViewer} - $lineCode",
              actions: [
                IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () => viewModel.saveFile(context),
                ),
              ],
            ),
            body: SafeArea(
              child: viewModel.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 6),
                    )
                  : viewModel.errorMessage != null
                      ? Center(
                          child: Text(
                            '${AppLocalizations.of(context)!.error}: ${viewModel.errorMessage}',
                            style: TextStyle(
                              fontSize: 24,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        )
                      : SfPdfViewer.network(viewModel.timetableUri.toString()),
            ),
          );
        },
      ),
    );
  }
}
