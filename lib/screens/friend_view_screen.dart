import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/day_record.dart';
import '../models/meal_entry.dart';
import '../screens/pdf_viewer_screen.dart';
import '../services/firebase_service.dart';
import '../services/report_service.dart';
import '../utils/app_theme.dart';

/// Écran lecture seule — données d'un collaborateur
class FriendViewScreen extends StatelessWidget {
  final String friendId;
  final String friendName;

  const FriendViewScreen({
    super.key,
    required this.friendId,
    required this.friendName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(friendName),
          const Text('Lecture seule',
              style: TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.visibility_rounded, size: 13, color: Colors.white),
              SizedBox(width: 4),
              Text('Lecture seule',
                  style: TextStyle(color: Colors.white, fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      ),
      body: StreamBuilder<List<DayRecord>>(
        stream: FirebaseService.instance.streamRecords(friendId),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = snap.data ?? [];
          if (records.isEmpty) {
            return Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.no_accounts_outlined,
                  size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text('Aucune donnée disponible',
                  style: AppFonts.title(
                      color: Colors.grey.shade500, size: 16)),
              const SizedBox(height: 6),
              Text('$friendName n\'a pas encore de données.',
                  style: AppFonts.body(
                      color: Colors.grey.shade400, size: 13)),
            ]));
          }
          final sorted = List<DayRecord>.from(records)
            ..sort((a, b) => b.dateKey.compareTo(a.dateKey));
          return _ViewerBody(records: sorted, friendName: friendName);
        },
      ),
      floatingActionButton: StreamBuilder<List<DayRecord>>(
        stream: FirebaseService.instance.streamRecords(friendId),
        builder: (_, snap) {
          final records = snap.data ?? [];
          if (records.isEmpty) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PdfViewerScreen(
                  patientName: friendName,
                  pdfBytes: ReportService.instance.buildPdfBytes(
                    patientName: friendName,
                    records: records,
                  ),
                ),
              ),
            ),
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
            label: const Text('Voir le rapport', style: TextStyle(color: Colors.white)),
            backgroundColor: AppTheme.primary,
          );
        },
      ),
    );
  }
}

class _ViewerBody extends StatefulWidget {
  final List<DayRecord> records;
  final String friendName;
  const _ViewerBody({required this.records, required this.friendName});
  @override
  State<_ViewerBody> createState() => _ViewerBodyState();
}

class _ViewerBodyState extends State<_ViewerBody> {
  int _selectedIdx = 0;

  @override
  Widget build(BuildContext context) {
    final rec = widget.records[_selectedIdx];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _buildCharts(widget.records),
        const SizedBox(height: 16),
        _buildDateSelector(widget.records),
        const SizedBox(height: 12),
        _buildDayDetail(rec),
      ]),
    );
  }

  Widget _buildCharts(List<DayRecord> records) {
    final rev = List<DayRecord>.from(records).reversed.toList();
    final doseSpots = <FlSpot>[];
    final glycSpots = <FlSpot>[];
    for (var i = 0; i < rev.length; i++) {
      if (rev[i].totalDose > 0)
        doseSpots.add(FlSpot(i.toDouble(), rev[i].totalDose));
      if (rev[i].averageGlycemieAffichee > 0)
        glycSpots.add(FlSpot(i.toDouble(), rev[i].averageGlycemieAffichee));
    }
    return Column(children: [
      _MiniChart(title: 'Doses insuline', spots: doseSpots,
          color: AppTheme.primary, unit: 'UI', total: rev.length),
      const SizedBox(height: 12),
      _MiniChart(title: 'Glycémie moyenne', spots: glycSpots,
          color: AppTheme.secondary, unit: 'Mg/dl', total: rev.length),
    ]);
  }

  Widget _buildDateSelector(List<DayRecord> records) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: records.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final parts = records[i].dateKey.split('-');
          final label = parts.length >= 3
              ? '${parts[2]}/${parts[1]}' : records[i].dateKey;
          final sel = i == _selectedIdx;
          return GestureDetector(
            onTap: () => setState(() => _selectedIdx = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? AppTheme.primary : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: sel
                    ? AppTheme.primary : Colors.grey.shade200),
                boxShadow: sel ? [BoxShadow(
                    color: AppTheme.primary.withOpacity(0.25),
                    blurRadius: 8, offset: const Offset(0, 3))] : [],
              ),
              child: Text(label, style: AppFonts.label(
                  color: sel ? Colors.white : Colors.grey.shade600,
                  size: 13).copyWith(
                  fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayDetail(DayRecord rec) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.calendar_today_rounded,
                size: 16, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(rec.dateKey, style: AppFonts.title(
                color: AppTheme.primary, size: 14)),
            const Spacer(),
            if (rec.totalDose > 0) _StatPill(
                label: 'Doses',
                value: rec.totalDose.toStringAsFixed(1),
                unit: 'UI', color: AppTheme.primary),
            const SizedBox(width: 8),
            if (rec.averageGlycemieAffichee > 0) _StatPill(
                label: 'Glycémie moy.',
                value: rec.averageGlycemieAffichee.toStringAsFixed(1),
                unit: 'Mg/dl', color: AppTheme.secondary),
          ]),
          const Divider(height: 20),
          ...rec.entries
              .where((e) => e.hasGlycemie || e.hasDose)
              .map((e) => _EntryRow(entry: e)),
          if (rec.entries.where((e) => e.hasGlycemie || e.hasDose).isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Aucune mesure ce jour',
                  style: AppFonts.body(
                      color: Colors.grey.shade400, size: 13)),
            )),
        ]),
      ),
    );
  }
}

// ── Mini chart ────────────────────────────────────────────────────────────────
class _MiniChart extends StatelessWidget {
  final String title;
  final List<FlSpot> spots;
  final Color color;
  final String unit;
  final int total;

  const _MiniChart({required this.title, required this.spots,
    required this.color, required this.unit, required this.total});

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(title, style: AppFonts.title(size: 13)),
          const Spacer(),
          Text(unit, style: AppFonts.label(color: color, size: 11)
              .copyWith(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        spots.isEmpty
            ? SizedBox(height: 80, child: Center(child: Text(
            'Pas de données',
            style: AppFonts.body(color: Colors.grey.shade400, size: 12))))
            : SizedBox(height: 80, child: LineChart(LineChartData(
          minX: 0,
          maxX: (total - 1).toDouble().clamp(1, double.infinity),
          minY: 0,
          maxY: spots.map((s) => s.y)
              .reduce((a, b) => a > b ? a : b) * 1.3,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(
            topTitles:    AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:  AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles:   AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [LineChartBarData(
            spots: spots, isCurved: true,
            color: color, barWidth: 2.5, isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
                show: true, color: color.withOpacity(0.12)),
          )],
        ))),
      ]),
    ));
  }
}

// ── Ligne d'entrée lecture seule ──────────────────────────────────────────────
class _EntryRow extends StatelessWidget {
  final MealEntry entry;
  const _EntryRow({required this.entry});

  Color get _color {
    switch (entry.type) {
      case MealType.breakfast: return AppTheme.breakfastColor;
      case MealType.lunch:     return AppTheme.lunchColor;
      case MealType.dinner:    return AppTheme.dinnerColor;
      case MealType.snack:     return AppTheme.snackColor;
      case MealType.mesure:    return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = entry.mealTime ?? entry.doseTime;
    final gly = entry.glycemieAffichee;
    final glyColor = gly != null ? AppTheme.glucoseColor(gly) : _color;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        // Heure
        SizedBox(width: 44, child: Text(
          t != null
              ? '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}'
              : '--:--',
          style: AppFonts.bold(color: AppTheme.primary, size: 12)
              .copyWith(letterSpacing: 0.5),
        )),
        // Icône
        Container(width: 32, height: 32,
            decoration: BoxDecoration(
                color: _color.withOpacity(0.1), shape: BoxShape.circle),
           ),
        const SizedBox(width: 10),
        // Nom
        Expanded(child: Text(entry.name,
            style: AppFonts.body(size: 13),
            overflow: TextOverflow.ellipsis)),
        // Glycémie
        if (gly != null) Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: glyColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20)),
            child: Text('${gly.toStringAsFixed(2)} Mg/dl',
                style: AppFonts.label(color: glyColor, size: 10)
                    .copyWith(fontWeight: FontWeight.w700))),
        // Thumbnail Photo
        if (entry.imageUrl != null)
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => Dialog(
                  child: InteractiveViewer(
                    child: Image.network(entry.imageUrl!),
                  ),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              width: 32, height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: NetworkImage(entry.imageUrl!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        // Dose
        if (entry.hasDose) Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: AppTheme.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20)),
            child: Text('${entry.dose!.toStringAsFixed(1)} UI',
                style: AppFonts.label(color: AppTheme.secondary, size: 10)
                    .copyWith(fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

// ── Widgets partagés ──────────────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final String label, value, unit;
  final Color color;
  const _StatPill({required this.label, required this.value,
    required this.unit, required this.color});
  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.end, children: [
    Text(label, style: AppFonts.label(size: 10)),
    RichText(text: TextSpan(children: [
      TextSpan(text: value,
          style: AppFonts.bold(color: color, size: 15)),
      TextSpan(text: ' $unit',
          style: AppFonts.label(
              color: color.withOpacity(0.6), size: 10)),
    ])),
  ]);
}