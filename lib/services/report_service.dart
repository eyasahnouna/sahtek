import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/day_record.dart';

class ReportService {
  ReportService._();
  static final ReportService instance = ReportService._();

  Future<void> generateAndPrintReport({
    required String patientName,
    required List<DayRecord> records,
  }) async {
    final pdf = pw.Document();

    // On récupère les records non vides
    final validRecords = records.where((r) => r.entries.isNotEmpty).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _buildHeader(patientName),
          pw.SizedBox(height: 20),
          _buildSummary(validRecords),
          pw.SizedBox(height: 20),
          ...validRecords.map((r) => _buildDaySection(r)),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Rapport_Glycemie_$patientName.pdf',
    );
  }

  pw.Widget _buildHeader(String patientName) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Rapport de Suivi Glycémique',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text('Patient : $patientName',
            style: const pw.TextStyle(fontSize: 16)),
        pw.Text('Généré le : ${DateTime.now().toLocal().toString().split(' ')[0]}',
            style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
        pw.Divider(),
      ],
    );
  }

  pw.Widget _buildSummary(List<DayRecord> records) {
    if (records.isEmpty) {
      return pw.Text('Aucune donnée à afficher.');
    }

    double totalInsulin = 0;
    int dayCount = records.length;
    double avgGlycemieSum = 0;
    int glycemieCount = 0;

    for (var r in records) {
      totalInsulin += r.totalDose;
      if (r.averageGlycemieAffichee > 0) {
        avgGlycemieSum += r.averageGlycemieAffichee;
        glycemieCount++;
      }
    }

    final avgInsulin = totalInsulin / dayCount;
    final globalAvgGlycemie = glycemieCount > 0 ? (avgGlycemieSum / glycemieCount) : 0.0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _statBox('Jours suivis', '$dayCount', ''),
          _statBox('Insuline Moy.', '${avgInsulin.toStringAsFixed(1)}', 'UI/jour'),
          _statBox('Glycémie Moy.', '${globalAvgGlycemie.toStringAsFixed(2)}', 'Mg/dl'),
        ],
      ),
    );
  }

  pw.Widget _statBox(String label, String value, String unit) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.Text('$value $unit', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  pw.Widget _buildDaySection(DayRecord r) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Date : ${r.dateKey}',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(1), // Heure
            1: const pw.FlexColumnWidth(2), // Type
            2: const pw.FlexColumnWidth(1.5), // Glycémie
            3: const pw.FlexColumnWidth(1.5), // Dose
            4: const pw.FlexColumnWidth(2), // Carbs
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _cellHeader('Heure'),
                _cellHeader('Repas/Type'),
                _cellHeader('Glycémie (Mg/dl)'),
                _cellHeader('Insuline (UI)'),
                _cellHeader('Glucides (g)'),
              ],
            ),
            ...r.entries.map((e) {
              final t = e.mealTime ?? e.doseTime;
              final timeStr = t != null ? '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}' : '--:--';
              return pw.TableRow(
                children: [
                  _cellValue(timeStr),
                  _cellValue(e.name),
                  _cellValue(e.glycemieAffichee != null ? e.glycemieAffichee!.toStringAsFixed(2) : '-'),
                  _cellValue(e.dose != null ? e.dose!.toStringAsFixed(1) : '-'),
                  _cellValue(e.hasCarbsG ? e.carbsG!.toStringAsFixed(1) : '-'),
                ],
              );
            }),
          ],
        ),
        pw.SizedBox(height: 16),
      ],
    );
  }

  pw.Widget _cellHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
    );
  }

  pw.Widget _cellValue(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
    );
  }
}
