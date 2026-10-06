import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/meal_entry.dart';
import '../widgets/logout_button.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../l10n/l10n.dart';

/// Point de données extrait d'un MealEntry
class _DataPoint {
  final DateTime time;
  final double   value;
  final String   label;
  final Color    color;
  const _DataPoint(this.time, this.value, this.label, this.color);
}

class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});
  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String _period = '7d';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  DateTime get _cutoff {
    final now = DateTime.now();
    switch (_period) {
      case '24h': return now.subtract(const Duration(hours: 24));
      case '30d': return now.subtract(const Duration(days: 30));
      default:    return now.subtract(const Duration(days: 7));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Graphiques'.tr),
        actions: const [LogoutIconButton()],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: [
            Tab(icon: Icon(Icons.water_drop_rounded, size: 18),
                text: 'Glycémie'.tr),
            Tab(icon: Icon(Icons.medication_liquid_rounded, size: 18),
                text: 'Insuline'.tr),
          ],
        ),
      ),
      body: Column(children: [
        _PeriodFilter(
            selected: _period,
            onChanged: (v) => setState(() => _period = v)),
        Expanded(child: TabBarView(
          controller: _tabs,
          children: [
            _GlucoseTab(cutoff: _cutoff),
            _InsulinTab(cutoff: _cutoff),
          ],
        )),
      ]),
    );
  }
}

// ── Filtre période ────────────────────────────────────────────────────────────
class _PeriodFilter extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _PeriodFilter({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final opts = [('24h', '24h'), ('7d', '7 jours'.tr), ('30d', '30 jours'.tr)];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(children: [
        Text('Période :'.tr, style: AppFonts.label(size: 12)),
        const SizedBox(width: 10),
        ...opts.map((o) {
          final sel = selected == o.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(o.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: sel ? AppTheme.primary : AppTheme.bgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel
                      ? AppTheme.primary : Colors.grey.shade200),
                ),
                child: Text(o.$2,
                    style: AppFonts.label(
                        color: sel ? Colors.white : Colors.grey.shade600,
                        size: 12)
                        .copyWith(fontWeight: sel
                        ? FontWeight.w600 : FontWeight.normal)),
              ),
            ),
          );
        }),
      ]),
    );
  }
}

// ── Onglet glycémie ───────────────────────────────────────────────────────────
class _GlucoseTab extends StatelessWidget {
  final DateTime cutoff;
  const _GlucoseTab({required this.cutoff});

  /// Extrait tous les points glycémie depuis AppProvider dans la période
  List<_DataPoint> _extract(AppProvider provider) {
    final points = <_DataPoint>[];
    for (final record in provider.allRecords) {
      // Parser la dateKey pour créer DateTime de base
      final parts = record.dateKey.split('-');
      if (parts.length < 3) continue;
      final baseDate = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      for (final entry in record.entries) {
        if (!entry.hasGlycemie) continue;
        final t = entry.mealTime ?? entry.doseTime;
        final dt = t != null
            ? DateTime(baseDate.year, baseDate.month, baseDate.day,
            t.hour, t.minute)
            : baseDate;
        if (dt.isBefore(cutoff)) continue;
        final gly = entry.glycemieAffichee ?? 0;
        points.add(_DataPoint(
          dt, gly, entry.name.tr,
          AppTheme.glucoseColor(gly),
        ));
      }
    }
    points.sort((a, b) => a.time.compareTo(b.time));
    return points;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final points   = _extract(provider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Courbe
        Card(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Courbe glycémique'.tr, style: AppFonts.title(size: 14)),
            const SizedBox(height: 4),
            Wrap(spacing: 14, runSpacing: 4, children: [
              _LegendDot(color: AppTheme.primary, label: 'Glycémie (Mg/dl)'.tr),
              _LegendDot(color: AppTheme.success,
                  label: 'Zone normale (0.7–1.6)'.tr, dashed: true),
            ]),
            const SizedBox(height: 16),
            points.isEmpty
                ? _EmptyChart(label: 'Aucune mesure sur cette période'.tr)
                : SizedBox(height: 220,
                child: _GlucoseLineChart(points: points)),
          ]),
        )),
        const SizedBox(height: 16),

        // Histogramme
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Historique'.tr, style: AppFonts.title(size: 14)),
            const SizedBox(height: 10),
            points.isEmpty
                ? Text('Aucune mesure'.tr,
                style: AppFonts.body(color: Colors.grey))
                : Column(children: points.reversed.take(20).map((p) =>
                _GlucoseTile(point: p)).toList()),
          ]),
        )),
      ]),
    );
  }
}

class _GlucoseLineChart extends StatelessWidget {
  final List<_DataPoint> points;
  const _GlucoseLineChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final spots = points.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();
    final maxY = ([2.5, ...spots.map((s) => s.y)]
        .reduce((a, b) => a > b ? a : b)) * 1.1;

    return LineChart(LineChartData(
      minX: 0,
      maxX: (points.length - 1).toDouble().clamp(1, double.infinity),
      minY: 0, maxY: maxY,
      clipData: const FlClipData.all(),
      rangeAnnotations: RangeAnnotations(horizontalRangeAnnotations: [
        HorizontalRangeAnnotation(
            y1: 0.7, y2: 1.6,
            color: AppTheme.success.withOpacity(0.08)),
      ]),
      extraLinesData: ExtraLinesData(horizontalLines: [
        HorizontalLine(y: 0.7,
            color: AppTheme.success.withOpacity(0.4),
            strokeWidth: 1, dashArray: [6, 4]),
        HorizontalLine(y: 1.6,
            color: AppTheme.success.withOpacity(0.4),
            strokeWidth: 1, dashArray: [6, 4]),
      ]),
      gridData: FlGridData(
        show: true, drawVerticalLine: false, horizontalInterval: 0.5,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: Colors.grey.shade100, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles:  AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 36, interval: 0.5,
          getTitlesWidget: (v, _) => Text(v.toStringAsFixed(1),
              style: AppFonts.label(
                  color: Colors.grey.shade400, size: 9)),
        )),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 26,
          interval: points.length > 10
              ? (points.length / 5).ceilToDouble() : 1,
          getTitlesWidget: (v, _) {
            final i = v.round().clamp(0, points.length - 1);
            return Padding(padding: const EdgeInsets.only(top: 4),
                child: Text(
                    DateFormat('HH:mm').format(points[i].time),
                    style: AppFonts.label(
                        color: Colors.grey.shade400, size: 8)));
          },
        )),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          tooltipBgColor: const Color(0xFF1A2E3B).withOpacity(0.9),
          getTooltipItems: (touched) => touched.map((s) {
            final i = s.x.round().clamp(0, points.length - 1);
            final p = points[i];
            return LineTooltipItem(
              '${p.value.toStringAsFixed(2)} Mg/dl\n${p.label}',
              AppFonts.bold(color: p.color, size: 11),
              children: [TextSpan(
                text: '\n${AppTheme.glucoseLabel(p.value)}'
                    '  ${DateFormat('dd/MM HH:mm').format(p.time)}',
                style: AppFonts.label(color: Colors.white54, size: 10),
              )],
            );
          }).toList(),
        ),
      ),
      lineBarsData: [LineChartBarData(
        spots: spots, isCurved: true,
        color: AppTheme.primary, barWidth: 2.5, isStrokeCapRound: true,
        dotData: FlDotData(show: true,
            getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 4.5,
                color: AppTheme.glucoseColor(spot.y),
                strokeColor: Colors.white, strokeWidth: 2)),
        belowBarData: BarAreaData(show: true,
            color: AppTheme.primary.withOpacity(0.07)),
      )],
    ));
  }
}

class _GlucoseTile extends StatelessWidget {
  final _DataPoint point;
  const _GlucoseTile({required this.point});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Container(width: 8, height: 8,
          decoration: BoxDecoration(
              color: point.color, shape: BoxShape.circle)),
      const SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(point.label, style: AppFonts.label(size: 12)
              .copyWith(fontWeight: FontWeight.w600,
              color: Colors.grey.shade700)),
          Text(DateFormat('dd/MM/yyyy  HH:mm').format(point.time),
              style: AppFonts.label(size: 10, color: Colors.grey)),
        ],
      )),
      Text('${point.value.toStringAsFixed(2)} Mg/dl',
          style: AppFonts.bold(color: point.color, size: 14)),
    ]),
  );
}

// ── Onglet insuline ───────────────────────────────────────────────────────────
class _InsulinTab extends StatelessWidget {
  final DateTime cutoff;
  const _InsulinTab({required this.cutoff});

  List<_DataPoint> _extract(AppProvider provider) {
    final points = <_DataPoint>[];
    for (final record in provider.allRecords) {
      final parts = record.dateKey.split('-');
      if (parts.length < 3) continue;
      final baseDate = DateTime(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      for (final entry in record.entries) {
        if (!entry.hasDose) continue;
        final t = entry.doseTime ?? entry.mealTime;
        final dt = t != null
            ? DateTime(baseDate.year, baseDate.month, baseDate.day,
            t.hour, t.minute)
            : baseDate;
        if (dt.isBefore(cutoff)) continue;
        points.add(_DataPoint(
            dt, entry.dose!, entry.name.tr, AppTheme.secondary));
      }
    }
    points.sort((a, b) => a.time.compareTo(b.time));
    return points;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final points   = _extract(provider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Card(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Consommation d\'insuline'.tr,
                style: AppFonts.title(size: 14)),
            const SizedBox(height: 4),
            _LegendDot(color: AppTheme.secondary, label: 'Dose insuline (UI)'.tr),
            const SizedBox(height: 16),
            points.isEmpty
                ? _EmptyChart(label: 'Aucune dose sur cette période'.tr)
                : SizedBox(height: 220,
                child: _InsulinLineChart(points: points)),
          ]),
        )),
        const SizedBox(height: 16),
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Historique doses'.tr, style: AppFonts.title(size: 14)),
            const SizedBox(height: 10),
            points.isEmpty
                ? Text('Aucune dose'.tr, style: AppFonts.body(color: Colors.grey))
                : Column(children: points.reversed.take(20).map((p) =>
                _InsulinTile(point: p)).toList()),
          ]),
        )),
      ]),
    );
  }
}

class _InsulinLineChart extends StatelessWidget {
  final List<_DataPoint> points;
  const _InsulinLineChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final spots = points.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList();
    final maxY = (spots.map((s) => s.y).reduce((a, b) => a > b ? a : b)) * 1.3;

    return LineChart(LineChartData(
      minX: 0, maxX: (points.length - 1).toDouble().clamp(1, double.infinity),
      minY: 0, maxY: maxY,
      gridData: FlGridData(
        show: true, drawVerticalLine: false,
        horizontalInterval: maxY / 4,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: Colors.grey.shade100, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles:  AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 36, interval: maxY / 4,
          getTitlesWidget: (v, _) => Text(v.toStringAsFixed(0),
              style: AppFonts.label(
                  color: Colors.grey.shade400, size: 9)),
        )),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 26,
          interval: points.length > 10
              ? (points.length / 5).ceilToDouble() : 1,
          getTitlesWidget: (v, _) {
            final i = v.round().clamp(0, points.length - 1);
            return Padding(padding: const EdgeInsets.only(top: 4),
                child: Text(DateFormat('HH:mm').format(points[i].time),
                    style: AppFonts.label(
                        color: Colors.grey.shade400, size: 8)));
          },
        )),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          tooltipBgColor: AppTheme.secondary.withOpacity(0.9),
          getTooltipItems: (touched) => touched.map((s) {
            final i = s.x.round().clamp(0, points.length - 1);
            return LineTooltipItem(
              '${s.y.toStringAsFixed(1)} UI\n${points[i].label}'
                  '\n${DateFormat('dd/MM HH:mm').format(points[i].time)}',
              AppFonts.bold(color: Colors.white, size: 11),
            );
          }).toList(),
        ),
      ),
      lineBarsData: [LineChartBarData(
        spots: spots, isCurved: true,
        color: AppTheme.secondary, barWidth: 3, isStrokeCapRound: true,
        dotData: FlDotData(show: true,
            getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 4.5, color: AppTheme.secondary,
                strokeColor: Colors.white, strokeWidth: 2)),
        belowBarData: BarAreaData(show: true,
            color: AppTheme.secondary.withOpacity(0.08)),
      )],
    ));
  }
}

class _InsulinTile extends StatelessWidget {
  final _DataPoint point;
  const _InsulinTile({required this.point});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Container(width: 8, height: 8,
          decoration: const BoxDecoration(
              color: AppTheme.secondary, shape: BoxShape.circle)),
      const SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(point.label, style: AppFonts.label(size: 12)
              .copyWith(fontWeight: FontWeight.w600,
              color: Colors.grey.shade700)),
          Text(DateFormat('dd/MM/yyyy  HH:mm').format(point.time),
              style: AppFonts.label(size: 10, color: Colors.grey)),
        ],
      )),
      Text('${point.value.toStringAsFixed(1)} UI',
          style: AppFonts.bold(color: AppTheme.secondary, size: 14)),
    ]),
  );
}

// ── Helpers partagés ──────────────────────────────────────────────────────────
class _EmptyChart extends StatelessWidget {
  final String label;
  const _EmptyChart({required this.label});
  @override
  Widget build(BuildContext context) => SizedBox(height: 120, child: Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.show_chart_rounded,
          color: Colors.grey.shade300, size: 48),
      const SizedBox(height: 8),
      Text(label, style: AppFonts.body(color: Colors.grey, size: 13)),
    ]),
  ));
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;
  const _LegendDot({required this.color, required this.label,
    this.dashed = false});
  @override
  Widget build(BuildContext context) => Row(
      mainAxisSize: MainAxisSize.min, children: [
    dashed
        ? Container(width: 16, height: 2,
        color: color.withOpacity(0.5))
        : Container(width: 10, height: 10,
        decoration: BoxDecoration(
            color: color, shape: BoxShape.circle)),
    const SizedBox(width: 5),
    Text(label, style: AppFonts.label(
        color: Colors.grey.shade600, size: 11)),
  ]);
}