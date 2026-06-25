import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/day_record.dart';
import '../widgets/logout_button.dart';
import '../models/meal_entry.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';

// ── Indicateur glycémie (extrait de dose_badge pour éviter la dépendance) ─────
class _GlyIndicator {
  final Color color;
  final String label;
  final IconData icon;
  const _GlyIndicator(this.color, this.label, this.icon);

  static _GlyIndicator of(double v) {
    if (v < 0.7)  return const _GlyIndicator(Color(0xFFE53935), 'Hypoglycémie', Icons.arrow_downward_rounded);
    if (v <= 1.6) return const _GlyIndicator(Color(0xFF16A34A), 'Normale',       Icons.check_circle_rounded);
    if (v <= 1.9) return const _GlyIndicator(Color(0xFFFF9A3C), 'Élevée',        Icons.warning_rounded);
    return         const _GlyIndicator(Color(0xFFE53935), 'Hyperglycémie',  Icons.arrow_upward_rounded);
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (context, provider, _) {
      final records = provider.allRecords;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard'),
          actions: const [LogoutIconButton()],
          bottom: TabBar(
            controller: _tabs,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle: AppFonts.label(size: 13)
                .copyWith(fontWeight: FontWeight.w600),
            unselectedLabelStyle: AppFonts.label(size: 13),
            tabs: const [
              Tab(icon: Icon(Icons.today_rounded, size: 18),
                  text: 'Par journée'),
              Tab(icon: Icon(Icons.calendar_month_rounded, size: 18),
                  text: 'Par mois'),
            ],
          ),
        ),
        body: records.isEmpty
            ? const _EmptyState()
            : TabBarView(
          controller: _tabs,
          children: [
            _DayTab(records: records),
            _MonthTab(records: records),
          ],
        ),
      );
    });
  }
}

// ════════════════════════════════════════════════════════
//  ONGLET PAR JOURNÉE
// ════════════════════════════════════════════════════════
class _DayTab extends StatefulWidget {
  final List<DayRecord> records;
  const _DayTab({required this.records});
  @override
  State<_DayTab> createState() => _DayTabState();
}

class _DayTabState extends State<_DayTab> {
  DateTime _selectedDate = DateTime.now();

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final selectedKey = _key(_selectedDate);
    final dayRecord = widget.records.firstWhere(
          (r) => r.dateKey == selectedKey,
      orElse: () => DayRecord(dateKey: selectedKey),
    );

    // Toutes les mesures de la journée (glycémie convertie)
    final allMeasures = dayRecord.entries
        .where((e) => e.hasGlycemie)
        .map((e) => e.glycemieAffichee ?? 0.0)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Sélecteur de date
        _DateSelector(
          selectedDate: _selectedDate,
          onChanged: (d) => setState(() => _selectedDate = d),
        ),
        const SizedBox(height: 16),

        // Courbe de la journée avec zone verte
        if (allMeasures.isNotEmpty) ...[
          _DayChartCard(entries: dayRecord.entries),
          const SizedBox(height: 16),
        ],

        // Tableau
        _DayTable(record: dayRecord),
        const SizedBox(height: 12),

        // Légende
        _IndicatorLegend(),
        const SizedBox(height: 24),
      ]),
    );
  }
}

// ── Sélecteur de date ─────────────────────────────────────────────────────────
class _DateSelector extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onChanged;
  const _DateSelector({required this.selectedDate, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(selectedDate, DateTime.now());
    return Row(children: [
      Text(isToday ? "Aujourd'hui"
          : DateFormat('d MMMM yyyy', 'fr_FR').format(selectedDate),
          style: AppFonts.title(size: 15)),
      const Spacer(),
      GestureDetector(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: selectedDate,
            firstDate: DateTime(2020),
            lastDate: DateTime.now().add(const Duration(days: 1)),
            builder: (ctx, child) => Theme(
              data: Theme.of(ctx).copyWith(
                  colorScheme: const ColorScheme.light(
                      primary: AppTheme.primary)),
              child: child!,
            ),
          );
          if (picked != null) onChanged(picked);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.calendar_today_rounded,
                size: 14, color: AppTheme.primary),
            const SizedBox(width: 6),
            Text('Changer',
                style: AppFonts.label(color: AppTheme.primary, size: 12)
                    .copyWith(fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    ]);
  }
}

// ── Courbe journée avec zone verte ────────────────────────────────────────────
class _DayChartCard extends StatelessWidget {
  final List<MealEntry> entries;
  const _DayChartCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    final measured = entries.where((e) => e.hasGlycemie).toList();
    final spots = measured.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(),
        e.value.glycemieAffichee ?? 0))
        .toList();

    final maxY = ([
      2.2,
      ...spots.map((s) => s.y)
    ].reduce((a, b) => a > b ? a : b)) * 1.15;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Mesures de la journée', style: AppFonts.title(size: 14)),
          const SizedBox(height: 6),
          Wrap(spacing: 12, runSpacing: 4, children: [
            _LegendDot(color: AppTheme.primary, label: 'Glycémie'),
            _LegendDot(color: const Color(0xFF16A34A),
                label: 'Zone normale (0.7–1.6)', dashed: true),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (measured.length - 1).toDouble().clamp(1, double.infinity),
                minY: 0,
                maxY: maxY,
                clipData: const FlClipData.all(),

                // Zone verte 0.7 – 1.6
                rangeAnnotations: RangeAnnotations(
                  horizontalRangeAnnotations: [
                    HorizontalRangeAnnotation(
                      y1: 0.7, y2: 1.6,
                      color: const Color(0xFF16A34A).withOpacity(0.10),
                    ),
                  ],
                ),

                extraLinesData: ExtraLinesData(horizontalLines: [
                  HorizontalLine(y: 0.7,
                      color: const Color(0xFF16A34A).withOpacity(0.5),
                      strokeWidth: 1.2,
                      dashArray: [6, 4],
                      label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          labelResolver: (_) => '0.7',
                          style: AppFonts.label(
                              color: const Color(0xFF16A34A), size: 10))),
                  HorizontalLine(y: 1.6,
                      color: const Color(0xFF16A34A).withOpacity(0.5),
                      strokeWidth: 1.2,
                      dashArray: [6, 4],
                      label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          labelResolver: (_) => '1.6',
                          style: AppFonts.label(
                              color: const Color(0xFF16A34A), size: 10))),
                ]),

                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 0.5,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true, reservedSize: 36,
                    interval: 0.5,
                    getTitlesWidget: (v, _) => Text(v.toStringAsFixed(1),
                        style: AppFonts.label(
                            color: Colors.grey.shade400, size: 10)),
                  )),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true, reservedSize: 28,
                    getTitlesWidget: (v, _) {
                      final i = v.round();
                      if (i < 0 || i >= measured.length) {
                        return const SizedBox();
                      }
                      final entry = measured[i];
                      final time  = entry.mealTime ?? entry.doseTime;
                      final label = time != null
                          ? '${time.hour.toString().padLeft(2, '0')}h'
                          : entry.name.substring(0, 3);
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(label, style: AppFonts.label(
                            color: Colors.grey.shade400, size: 9)),
                      );
                    },
                  )),
                ),

                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: AppTheme.primary.withOpacity(0.9),
                    getTooltipItems: (spots) => spots.map((s) {
                      final i = s.x.round();
                      final entry = i < measured.length ? measured[i] : null;
                      final ind = _GlyIndicator.of(s.y);
                      return LineTooltipItem(
                        '${s.y.toStringAsFixed(2)} Mg/dl\n${entry?.name ?? ''}',
                        AppFonts.bold(color: Colors.white, size: 11),
                        children: [
                          TextSpan(
                            text: '\n${ind.label}',
                            style: AppFonts.label(
                                color: Colors.white70, size: 10),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),

                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppTheme.primary,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, ___) {
                        final ind = _GlyIndicator.of(spot.y);
                        return FlDotCirclePainter(
                          radius: 5,
                          color: ind.color,
                          strokeColor: Colors.white,
                          strokeWidth: 2,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.primary.withOpacity(0.15),
                          AppTheme.primary.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Tableau journée ────────────────────────────────────────────────────────────
class _DayTable extends StatelessWidget {
  final DayRecord record;
  const _DayTable({required this.record});

  @override
  Widget build(BuildContext context) {
    final entries = record.entries
        .where((e) => e.hasGlycemie || e.hasDose)
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tableau des valeurs',
              style: AppFonts.title(size: 14)),
          const SizedBox(height: 12),

          entries.isEmpty
              ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('Aucune mesure pour cette journée',
                  style: AppFonts.body(
                      color: Colors.grey.shade400, size: 13))))
              : Column(children: [
            _TableHeader(),
            const SizedBox(height: 6),
            const Divider(height: 1, thickness: 1),
            const SizedBox(height: 6),
            ...entries.asMap().entries.map((e) =>
                _TableRow(entry: e.value, isEven: e.key.isEven)),
            const Divider(height: 1, thickness: 1),
            const SizedBox(height: 6),
            _TableFooter(record: record),
          ]),
        ]),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const s = TextStyle(fontSize: 11, fontWeight: FontWeight.w700);
    return Row(children: [
      Expanded(flex: 3, child: Text('Repas',
          style: s.copyWith(color: Colors.grey.shade500))),
      Expanded(flex: 2, child: Text('Glycémie',
          textAlign: TextAlign.center,
          style: s.copyWith(color: Colors.grey.shade500))),
      Expanded(flex: 2, child: Text('Dose UI',
          textAlign: TextAlign.center,
          style: s.copyWith(color: Colors.grey.shade500))),
      Expanded(flex: 2, child: Text('Statut',
          textAlign: TextAlign.center,
          style: s.copyWith(color: Colors.grey.shade500))),
    ]);
  }
}

class _TableRow extends StatelessWidget {
  final MealEntry entry;
  final bool isEven;
  const _TableRow({required this.entry, required this.isEven});

  Color get _mealColor {
    switch (entry.type) {
      case MealType.breakfast: return AppTheme.breakfastColor;
      case MealType.lunch:     return AppTheme.lunchColor;
      case MealType.dinner:    return AppTheme.dinnerColor;
      case MealType.snack:     return AppTheme.snackColor;
      case MealType.mesure:    return AppTheme.primary;
    }
  }

  String _shortLabel(String l) {
    if (l.contains('sévère')) return 'Hypogly.';
    if (l.contains('Hyper'))  return 'Hypergly.';
    if (l.contains('élevée')) return 'Élevée';
    return 'Normal';
  }

  @override
  Widget build(BuildContext context) {
    final glycConv  = entry.glycemieAffichee;
    final indicator = glycConv != null ? _GlyIndicator.of(glycConv) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isEven ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(children: [
        Expanded(flex: 3, child: Row(children: [
          Container(width: 6, height: 6,
              decoration: BoxDecoration(
                  color: _mealColor, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.name,
                  style: AppFonts.label(size: 12)
                      .copyWith(fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800),
                  overflow: TextOverflow.ellipsis),
              if (entry.doseTime != null)
                Text(
                    '${entry.doseTime!.hour.toString().padLeft(2, '0')}:'
                        '${entry.doseTime!.minute.toString().padLeft(2, '0')}',
                    style: AppFonts.label(
                        color: Colors.grey.shade400, size: 10)),
            ],
          )),
        ])),

        Expanded(flex: 2, child: Center(child: glycConv != null
            ? Text(glycConv.toStringAsFixed(2),
            style: AppFonts.bold(color: indicator!.color, size: 13))
            : Text('--', style: AppFonts.label(
            color: Colors.grey.shade300, size: 13)))),

        Expanded(flex: 2, child: Center(child: entry.hasDose
            ? Text(entry.dose!.toStringAsFixed(1),
            style: AppFonts.bold(color: AppTheme.primary, size: 13))
            : Text('--', style: AppFonts.label(
            color: Colors.grey.shade300, size: 13)))),

        Expanded(flex: 2, child: Center(child: indicator != null
            ? Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 5, vertical: 3),
          decoration: BoxDecoration(
            color: indicator.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(indicator.icon, size: 9, color: indicator.color),
            const SizedBox(width: 2),
            Flexible(child: Text(_shortLabel(indicator.label),
                style: AppFonts.label(color: indicator.color, size: 8)
                    .copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
                maxLines: 1)),
          ]),
        )
            : Text('--', style: AppFonts.label(
            color: Colors.grey.shade300, size: 12)))),
      ]),
    );
  }
}

class _TableFooter extends StatelessWidget {
  final DayRecord record;
  const _TableFooter({required this.record});

  @override
  Widget build(BuildContext context) {
    final avgGly  = record.averageGlycemieAffichee;
    final ind     = avgGly > 0 ? _GlyIndicator.of(avgGly) : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppTheme.primary, AppTheme.secondary],
            begin: Alignment.centerLeft, end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Expanded(flex: 3, child: Text('TOTAL / MOY.',
            style: AppFonts.label(color: Colors.white70, size: 11)
                .copyWith(fontWeight: FontWeight.w700))),
        Expanded(flex: 2, child: Center(child: Text(
            avgGly > 0 ? avgGly.toStringAsFixed(2) : '--',
            style: AppFonts.bold(color: Colors.white, size: 13)))),
        Expanded(flex: 2, child: Center(child: Text(
            record.totalDose > 0
                ? record.totalDose.toStringAsFixed(1) : '--',
            style: AppFonts.bold(color: Colors.white, size: 13)))),
        Expanded(flex: 2, child: Center(child: ind != null
            ? Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 5, vertical: 3),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(ind.icon, size: 9, color: Colors.white),
              const SizedBox(width: 2),
              Text('Moy.', style: AppFonts.label(
                  color: Colors.white, size: 8)
                  .copyWith(fontWeight: FontWeight.w600)),
            ]))
            : const SizedBox())),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════
//  ONGLET PAR MOIS
// ════════════════════════════════════════════════════════
class _MonthTab extends StatefulWidget {
  final List<DayRecord> records;
  const _MonthTab({required this.records});
  @override
  State<_MonthTab> createState() => _MonthTabState();
}

class _MonthTabState extends State<_MonthTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  List<DayRecord> get _monthRecords => widget.records.where((r) {
    final parts = r.dateKey.split('-');
    return int.parse(parts[0]) == _month.year &&
        int.parse(parts[1]) == _month.month;
  }).toList();

  void _prevMonth() => setState(() =>
  _month = DateTime(_month.year, _month.month - 1));
  void _nextMonth() {
    final next = DateTime(_month.year, _month.month + 1);
    if (next.isBefore(DateTime(DateTime.now().year,
        DateTime.now().month + 1))) {
      setState(() => _month = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = _monthRecords;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Navigateur de mois
        _MonthNavigator(
            month: _month, onPrev: _prevMonth, onNext: _nextMonth),
        const SizedBox(height: 16),

        // Résumé du mois
        _MonthSummary(records: records),
        const SizedBox(height: 16),

        // Courbe double (doses + glycémie)
        _MonthChart(records: records, month: _month),
        const SizedBox(height: 16),

        // Légende
        _IndicatorLegend(),
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _MonthNavigator extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev, onNext;
  const _MonthNavigator(
      {required this.month, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left_rounded, size: 26),
          color: AppTheme.primary),
      Expanded(child: Text(
          DateFormat('MMMM yyyy', 'fr_FR').format(month),
          textAlign: TextAlign.center,
          style: AppFonts.title(size: 16)
              .copyWith(color: AppTheme.primary))),
      IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded, size: 26),
          color: AppTheme.primary),
    ]);
  }
}

class _MonthSummary extends StatelessWidget {
  final List<DayRecord> records;
  const _MonthSummary({required this.records});

  @override
  Widget build(BuildContext context) {
    final doseRec = records.where((r) => r.totalDose > 0);
    final glycRec = records.where((r) => r.averageGlycemieAffichee > 0);
    final totalDose = doseRec.fold(0.0, (s, r) => s + r.totalDose);
    final avgDose   = doseRec.isEmpty ? 0.0 : totalDose / doseRec.length;
    final avgGly    = glycRec.isEmpty ? 0.0
        : glycRec.fold(0.0, (s, r) => s + r.averageGlycemieAffichee) /
        glycRec.length;
    final ind = avgGly > 0 ? _GlyIndicator.of(avgGly) : null;

    return Row(children: [
      Expanded(child: _SummaryTile(
          icon: Icons.medication_liquid_rounded,
          label: 'Dose totale mois',
          value: totalDose > 0 ? totalDose.toStringAsFixed(1) : '--',
          unit: 'UI', color: AppTheme.primary)),
      const SizedBox(width: 10),
      Expanded(child: _SummaryTile(
          icon: Icons.medication_rounded,
          label: 'Dose moy./jour',
          value: avgDose > 0 ? avgDose.toStringAsFixed(1) : '--',
          unit: 'UI', color: AppTheme.secondary)),
      const SizedBox(width: 10),
      Expanded(child: _SummaryTile(
          icon: Icons.bloodtype_rounded,
          label: 'Glycémie moy.',
          value: avgGly > 0 ? avgGly.toStringAsFixed(2) : '--',
          unit: 'Mg/dl',
          color: ind?.color ?? Colors.grey,
          indicatorIcon: ind?.icon)),
    ]);
  }
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String label, value, unit;
  final Color color;
  final IconData? indicatorIcon;
  const _SummaryTile({required this.icon, required this.label,
    required this.value, required this.unit, required this.color,
    this.indicatorIcon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withOpacity(0.12),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 16),
          if (indicatorIcon != null) ...[
            const SizedBox(width: 4),
            Icon(indicatorIcon!, color: color, size: 14),
          ],
        ]),
        const SizedBox(height: 6),
        Text(label, style: AppFonts.label(size: 10),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        FittedBox(child: RichText(text: TextSpan(children: [
          TextSpan(text: value,
              style: AppFonts.bold(color: color, size: 18)),
          if (value != '--') TextSpan(text: ' $unit',
              style: AppFonts.label(size: 10)),
        ]))),
      ]),
    );
  }
}

// ── Courbe mensuelle double ────────────────────────────────────────────────────
class _MonthChart extends StatelessWidget {
  final List<DayRecord> records;
  final DateTime month;
  const _MonthChart({required this.records, required this.month});

  @override
  Widget build(BuildContext context) {
    // Données par jour du mois
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final doseSpots  = <FlSpot>[];
    final glycSpots  = <FlSpot>[];

    for (var d = 1; d <= daysInMonth; d++) {
      final key = '${month.year}-${month.month.toString().padLeft(2, '0')}'
          '-${d.toString().padLeft(2, '0')}';
      final rec = records.firstWhere((r) => r.dateKey == key,
          orElse: () => DayRecord(dateKey: key));

      if (rec.totalDose > 0)
        doseSpots.add(FlSpot((d - 1).toDouble(), rec.totalDose));
      if (rec.averageGlycemieAffichee > 0)
        glycSpots.add(FlSpot((d - 1).toDouble(), rec.averageGlycemieAffichee));
    }

    final allValues = [
      ...doseSpots.map((s) => s.y),
      ...glycSpots.map((s) => s.y),
      2.0,
    ];
    final maxY = allValues.reduce((a, b) => a > b ? a : b) * 1.2;

    return Card(child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Doses & glycémie du mois',
            style: AppFonts.title(size: 14)),
        const SizedBox(height: 6),
        Wrap(spacing: 12, runSpacing: 6, children: [
          _LegendDot(color: AppTheme.primary, label: 'Dose (UI)'),
          _LegendDot(color: AppTheme.secondary, label: 'Glycémie (Mg/dl)'),
          _LegendDot(color: const Color(0xFF16A34A),
              label: 'Zone normale', dashed: true),
        ]),
        const SizedBox(height: 16),

        doseSpots.isEmpty && glycSpots.isEmpty
            ? SizedBox(height: 100, child: Center(
            child: Text('Aucune donnée ce mois',
                style: AppFonts.body(
                    color: Colors.grey.shade400, size: 13))))
            : SizedBox(height: 220, child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (daysInMonth - 1).toDouble(),
            minY: 0,
            maxY: maxY,
            clipData: const FlClipData.all(),

            // Zone verte 0.7 – 1.6
            rangeAnnotations: RangeAnnotations(
              horizontalRangeAnnotations: [
                HorizontalRangeAnnotation(
                  y1: 0.7, y2: 1.6,
                  color: const Color(0xFF16A34A).withOpacity(0.08),
                ),
              ],
            ),
            extraLinesData: ExtraLinesData(horizontalLines: [
              HorizontalLine(y: 0.7,
                  color: const Color(0xFF16A34A).withOpacity(0.4),
                  strokeWidth: 1, dashArray: [5, 4]),
              HorizontalLine(y: 1.6,
                  color: const Color(0xFF16A34A).withOpacity(0.4),
                  strokeWidth: 1, dashArray: [5, 4]),
            ]),

            gridData: FlGridData(
              show: true, drawVerticalLine: false,
              horizontalInterval: maxY / 5,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: Colors.grey.shade100, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),

            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 36,
                interval: maxY / 5,
                getTitlesWidget: (v, _) => Text(
                    v.toStringAsFixed(1),
                    style: AppFonts.label(
                        color: Colors.grey.shade400, size: 9)),
              )),
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 24,
                interval: 4,
                getTitlesWidget: (v, _) => Text(
                    '${v.toInt() + 1}',
                    style: AppFonts.label(
                        color: Colors.grey.shade400, size: 9)),
              )),
            ),

            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                tooltipBgColor: const Color(0xFF1A2E3B).withOpacity(0.9),
                getTooltipItems: (touchedSpots) =>
                    touchedSpots.map((s) {
                      final isGly = s.barIndex == 1;
                      final day   = s.x.toInt() + 1;
                      return LineTooltipItem(
                        '${isGly ? "Glycémie" : "Dose"}: '
                            '${s.y.toStringAsFixed(2)}'
                            '${isGly ? " Mg/dl" : " UI"}\nJour $day',
                        AppFonts.bold(color: Colors.white, size: 11),
                      );
                    }).toList(),
              ),
            ),

            lineBarsData: [
              // Doses
              if (doseSpots.isNotEmpty)
                LineChartBarData(
                  spots: doseSpots,
                  isCurved: true,
                  color: AppTheme.primary,
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: doseSpots.length < 15,
                      getDotPainter: (_, __, ___, ____) =>
                          FlDotCirclePainter(radius: 3,
                              color: AppTheme.primary,
                              strokeColor: Colors.white,
                              strokeWidth: 1.5)),
                  belowBarData: BarAreaData(show: true,
                      color: AppTheme.primary.withOpacity(0.06)),
                ),
              // Glycémie
              if (glycSpots.isNotEmpty)
                LineChartBarData(
                  spots: glycSpots,
                  isCurved: true,
                  color: AppTheme.secondary,
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: glycSpots.length < 15,
                      getDotPainter: (spot, __, ___, ____) {
                        final ind = _GlyIndicator.of(spot.y);
                        return FlDotCirclePainter(radius: 4,
                            color: ind.color,
                            strokeColor: Colors.white,
                            strokeWidth: 1.5);
                      }),
                  belowBarData: BarAreaData(show: true,
                      color: AppTheme.secondary.withOpacity(0.06)),
                ),
            ],
          ),
        )),
      ]),
    ));
  }
}

// ── Légende point ──────────────────────────────────────────────────────────────
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;
  const _LegendDot(
      {required this.color, required this.label, this.dashed = false});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      dashed
          ? Container(
          width: 16, height: 2,
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(
                  color: color, width: 2,
                  style: BorderStyle.solid))))
          : Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
              color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label,
          style: AppFonts.label(color: Colors.grey.shade600, size: 11)),
    ]);
  }
}

// ── Légende indicateurs ────────────────────────────────────────────────────────
class _IndicatorLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const items = [
      (color: Color(0xFFE53935), label: '< 0.7', desc: 'Hypoglycémie sévère'),
      (color: Color(0xFF16A34A), label: '0.7 – 1.6', desc: 'Normale'),
      (color: Color(0xFFFF9A3C), label: '1.6 – 1.9', desc: 'Légèrement élevée'),
      (color: Color(0xFFE53935), label: '> 1.9', desc: 'Hyperglycémie'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.info_outline_rounded,
                size: 14, color: AppTheme.primary),
            const SizedBox(width: 6),
            Text('Indicateurs glycémie (Mg/dl)',
                style: AppFonts.label(color: AppTheme.primary, size: 12)
                    .copyWith(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8,
              children: items.map((item) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: item.color.withOpacity(0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 8, height: 8,
                      decoration: BoxDecoration(
                          color: item.color, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('${item.label}  –  ${item.desc}',
                      style: AppFonts.label(color: item.color, size: 11)
                          .copyWith(fontWeight: FontWeight.w600)),
                ]),
              )).toList()),
        ]),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.insert_chart_outlined_rounded,
          size: 90, color: Colors.grey.shade300),
      const SizedBox(height: 16),
      Text('Aucune donnée disponible',
          style: AppFonts.title(color: Colors.grey.shade500, size: 18)),
      const SizedBox(height: 8),
      Text('Enregistrez vos mesures dans l\'onglet Journée.',
          textAlign: TextAlign.center,
          style: AppFonts.body(color: Colors.grey.shade400, size: 14)),
    ],
  ));
}