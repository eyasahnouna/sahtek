import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/day_record.dart';
import '../models/meal_entry.dart';

class ReportService {
  ReportService._();
  static final ReportService instance = ReportService._();

  /// Génère le PDF et retourne les bytes (pour affichage avec zoom).
  Future<Uint8List> buildPdfBytes({
    required String patientName,
    required List<DayRecord> records,
  }) async {
    final fontRegular = await PdfGoogleFonts.nunitoRegular();
    final fontBold    = await PdfGoogleFonts.nunitoBold();
    final fontLight   = await PdfGoogleFonts.nunitoLight();

    final theme = pw.ThemeData.withFont(
      base:   fontRegular,
      bold:   fontBold,
      italic: fontLight,
    );

    final validRecords = records.where((r) => r.entries.isNotEmpty).toList();

    // Pré-charger toutes les images en parallèle
    final allEntries = validRecords.expand((r) => r.entries).toList();
    final imageMap   = await _fetchAllImages(allEntries);

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: theme,
        header: (ctx) => _buildHeader(patientName, fontBold, fontRegular),
        build: (context) => [
          pw.SizedBox(height: 8),
          _buildSummary(validRecords, fontBold, fontRegular),
          pw.SizedBox(height: 20),
          ...validRecords.map(
              (r) => _buildDaySection(r, fontBold, fontRegular, imageMap)),
        ],
      ),
    );

    return pdf.save();
  }

  // ── Téléchargement images ─────────────────────────────────────────────────

  Future<Map<String, pw.MemoryImage>> _fetchAllImages(
      List<MealEntry> entries) async {
    final urls = entries
        .where((e) => e.imageUrl != null)
        .map((e) => e.imageUrl!)
        .toSet();

    final results = await Future.wait(
      urls.map((url) async {
        final bytes = await _fetchBytes(url);
        if (bytes != null) return MapEntry(url, pw.MemoryImage(bytes));
        return null;
      }),
    );

    return Map.fromEntries(
        results.whereType<MapEntry<String, pw.MemoryImage>>());
  }

  Future<Uint8List?> _fetchBytes(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (_) {}
    return null;
  }

  // ── En-tête (répété sur chaque page) ─────────────────────────────────────

  pw.Widget _buildHeader(
      String patientName, pw.Font bold, pw.Font regular) {
    final date = DateTime.now().toLocal().toString().split(' ')[0];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Rapport de Suivi Glycemique',
            style: pw.TextStyle(
                font: bold, fontSize: 20, color: PdfColors.teal800)),
        pw.SizedBox(height: 4),
        pw.Row(children: [
          pw.Text('Patient : $patientName',
              style: pw.TextStyle(font: regular, fontSize: 13)),
          pw.Spacer(),
          pw.Text('Genere le : $date',
              style: pw.TextStyle(
                  font: regular, fontSize: 11, color: PdfColors.grey600)),
        ]),
        pw.Divider(color: PdfColors.teal100),
      ],
    );
  }

  // ── Résumé ────────────────────────────────────────────────────────────────

  pw.Widget _buildSummary(List<DayRecord> records,
      pw.Font bold, pw.Font regular) {
    if (records.isEmpty) {
      return pw.Text('Aucune donnee a afficher.',
          style: pw.TextStyle(font: regular));
    }

    double totalInsulin = 0;
    final dayCount = records.length;
    double avgGlycemieSum = 0;
    int glycemieCount = 0;
    int photoCount = 0;

    for (final r in records) {
      totalInsulin += r.totalDose;
      if (r.averageGlycemieAffichee > 0) {
        avgGlycemieSum += r.averageGlycemieAffichee;
        glycemieCount++;
      }
      photoCount += r.entries.where((e) => e.imageUrl != null).length;
    }

    final avgInsulin  = totalInsulin / dayCount;
    final avgGlycemie = glycemieCount > 0
        ? (avgGlycemieSum / glycemieCount) : 0.0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
          color: PdfColors.teal50,
          borderRadius:
              const pw.BorderRadius.all(pw.Radius.circular(8))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _statBox('Jours suivis', '$dayCount', '', bold, regular),
          _statBox('Insuline Moy.',
              avgInsulin.toStringAsFixed(1), 'UI/j', bold, regular),
          _statBox('Glycemie Moy.',
              avgGlycemie.toStringAsFixed(1), 'g/L', bold, regular),
          _statBox('Photos repas', '$photoCount', '', bold, regular),
        ],
      ),
    );
  }

  pw.Widget _statBox(String label, String value, String unit,
      pw.Font bold, pw.Font regular) {
    return pw.Column(children: [
      pw.Text(label,
          style: pw.TextStyle(
              font: regular, fontSize: 10, color: PdfColors.grey700)),
      pw.SizedBox(height: 4),
      pw.Text(unit.isEmpty ? value : '$value $unit',
          style: pw.TextStyle(font: bold, fontSize: 14)),
    ]);
  }

  // ── Section journalière ───────────────────────────────────────────────────

  pw.Widget _buildDaySection(DayRecord r, pw.Font bold, pw.Font regular,
      Map<String, pw.MemoryImage> imageMap) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // En-tête du jour
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: pw.BoxDecoration(
            color: PdfColors.teal800,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Text('Date : ${r.dateKey}',
              style: pw.TextStyle(
                  font: bold, fontSize: 13, color: PdfColors.white)),
        ),
        pw.SizedBox(height: 6),

        // Tableau avec colonne photo intégrée
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: const {
            0: pw.FixedColumnWidth(78),   // Photo
            1: pw.FlexColumnWidth(0.8),   // Heure
            2: pw.FlexColumnWidth(2.4),   // Repas / Type
            3: pw.FlexColumnWidth(1.2),   // Glycémie
            4: pw.FlexColumnWidth(1.2),   // Insuline
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _cellHeader('Photo', bold),
                _cellHeader('Heure', bold),
                _cellHeader('Repas / Type', bold),
                _cellHeader('Glycemie g/L', bold),
                _cellHeader('Insuline UI', bold),
              ],
            ),
            ...r.entries.map((e) => _buildEntryRow(e, bold, regular, imageMap)),
          ],
        ),

        pw.SizedBox(height: 16),
      ],
    );
  }

  pw.TableRow _buildEntryRow(MealEntry e, pw.Font bold, pw.Font regular,
      Map<String, pw.MemoryImage> imageMap) {
    final image = e.imageUrl != null ? imageMap[e.imageUrl] : null;
    final t = e.mealTime ?? e.doseTime;
    final time = t != null
        ? '${t.hour.toString().padLeft(2, '0')}:'
          '${t.minute.toString().padLeft(2, '0')}'
        : '--:--';

    return pw.TableRow(children: [
      // ── Colonne photo ────────────────────────────────────────────────────
      pw.Padding(
        padding: const pw.EdgeInsets.all(3),
        child: image != null
            ? pw.ClipRRect(
                horizontalRadius: 3,
                verticalRadius: 3,
                child: pw.Image(image, width: 72, height: 72,
                    fit: pw.BoxFit.cover),
              )
            : pw.Container(
                width: 72, height: 28,
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
                child: pw.Center(
                  child: pw.Text('—',
                      style: pw.TextStyle(
                          font: regular, fontSize: 9,
                          color: PdfColors.grey400)),
                ),
              ),
      ),
      _cellValue(time, regular),
      _cellValue(e.name, regular),
      _cellValue(e.glycemieAffichee != null
          ? e.glycemieAffichee!.toStringAsFixed(2) : '-', regular),
      _cellValue(e.dose != null
          ? e.dose!.toStringAsFixed(1) : '-', regular),
    ]);
  }

  pw.Widget _cellHeader(String text, pw.Font bold) => pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: pw.Text(text,
            style: pw.TextStyle(font: bold, fontSize: 9)),
      );

  pw.Widget _cellValue(String text, pw.Font regular) => pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: pw.Text(text,
            style: pw.TextStyle(font: regular, fontSize: 9)),
      );
}
