import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../utils/app_theme.dart';
import '../l10n/l10n.dart';

class PdfViewerScreen extends StatelessWidget {
  final String      patientName;
  final Future<Uint8List> pdfBytes;

  const PdfViewerScreen({
    super.key,
    required this.patientName,
    required this.pdfBytes,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Rapport PDF'.tr),
          Text(patientName,
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: PdfPreview(
        build: (_) => pdfBytes,
        allowSharing: true,
        allowPrinting: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        pdfFileName: 'Rapport_$patientName.pdf',
        loadingWidget: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primary),
              SizedBox(height: 16),
              Text('Génération du rapport…'.tr,
                  style: TextStyle(color: AppTheme.primary)),
            ],
          ),
        ),
        previewPageMargin: const EdgeInsets.all(8),
      ),
    );
  }
}
