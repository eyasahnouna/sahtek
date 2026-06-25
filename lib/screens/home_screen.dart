import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/meal_entry.dart';
import '../models/day_record.dart';
import '../providers/app_provider.dart';
import '../screens/meal_analysis_screen.dart';
import '../utils/app_theme.dart';
import '../widgets/logout_button.dart';

// ── Slots ─────────────────────────────────────────────────────────────────────
const _kFasting     = 'fasting';
const _kBkfMesure   = 'bkf_mesure';
const _kBkfDose     = 'bkf_dose';
const _kBkfAfter    = 'bkf_after';
const _kLunchMesure = 'lunch_mesure';
const _kLunchDose   = 'lunch_dose';
const _kLunchAfter  = 'lunch_after';
const _kDinerMesure = 'diner_mesure';
const _kDinerDose   = 'diner_dose';
const _kDinerAfter  = 'diner_after';
const _kBedtime     = 'bedtime';

const _kFixedOrder = [
  _kFasting,
  _kBkfMesure, _kBkfDose, _kBkfAfter,
  _kLunchMesure, _kLunchDose, _kLunchAfter,
  _kDinerMesure, _kDinerDose, _kDinerAfter,
  _kBedtime,
];

const _kMetas = {
  _kFasting:     _M('À jeun',               MealType.mesure,    TimeOfDay(hour: 7,  minute: 0)),
  _kBkfMesure:   _M('Petit déj. — mesure',  MealType.breakfast, TimeOfDay(hour: 7,  minute: 30)),
  _kBkfDose:     _M('Petit déj. — dose',    MealType.breakfast, TimeOfDay(hour: 7,  minute: 30)),
  _kBkfAfter:    _M('Après petit déj. 2h',  MealType.mesure,    TimeOfDay(hour: 9,  minute: 30)),
  _kLunchMesure: _M('Déjeuner — mesure',    MealType.lunch,     TimeOfDay(hour: 12, minute: 0)),
  _kLunchDose:   _M('Déjeuner — dose',      MealType.lunch,     TimeOfDay(hour: 12, minute: 0)),
  _kLunchAfter:  _M('Après déjeuner 2h',    MealType.mesure,    TimeOfDay(hour: 14, minute: 0)),
  _kDinerMesure: _M('Dîner — mesure',       MealType.dinner,    TimeOfDay(hour: 19, minute: 0)),
  _kDinerDose:   _M('Dîner — dose',         MealType.dinner,    TimeOfDay(hour: 19, minute: 0)),
  _kDinerAfter:  _M('Après dîner 2h',       MealType.mesure,    TimeOfDay(hour: 21, minute: 0)),
  _kBedtime:     _M('Avant coucher',        MealType.mesure,    TimeOfDay(hour: 22, minute: 30)),
};

class _M {
  final String label; final MealType type; final TimeOfDay time;
  const _M(this.label, this.type, this.time);
}

// ── HomeScreen ────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  void _ensureSlots(AppProvider p) {
    final r = p.currentRecord;
    for (final id in _kFixedOrder) {
      if (!r.entries.any((e) => e.slotId == id)) {
        final m = _kMetas[id]!;
        r.entries.add(MealEntry(
          id: id,
          name: m.label,
          type: m.type,
          slotId: id,
          doseTime: m.time,
          mealTime: m.time,
        ));
      }
    }
    r.entries.sort((a, b) {
      final ai = _kFixedOrder.indexOf(a.slotId ?? '');
      final bi = _kFixedOrder.indexOf(b.slotId ?? '');
      return (ai < 0 ? 999 : ai).compareTo(bi < 0 ? 999 : bi);
    });
  }

  MealEntry _get(DayRecord r, String id) {
    return r.entries.firstWhere(
          (e) => e.slotId == id,
      orElse: () {
        final m = _kMetas[id]!;
        return MealEntry(
          id: id,
          name: m.label,
          type: m.type,
          slotId: id,
          doseTime: m.time,
          mealTime: m.time,
        );
      },
    );
  }

  Future<void> _addMesureDialog(BuildContext ctx, AppProvider p) async {
    final ctrl = TextEditingController();
    TimeOfDay t = TimeOfDay.now();
    await showDialog(context: ctx, builder: (_) => StatefulBuilder(
      builder: (ctx2, set) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(children: [
          Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.add_chart_rounded,
                  color: AppTheme.primary, size: 20)),
          const SizedBox(width: 10),
          Text('Nouvelle mesure', style: AppFonts.title(size: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: ctrl, decoration: const InputDecoration(
              labelText: 'Libellé (optionnel)', hintText: 'Ex: Avant sport…',
              prefixIcon: Icon(Icons.label_outline_rounded, size: 18))),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () async {
              final picked = await showTimePicker(context: ctx2, initialTime: t,
                  builder: (c, child) => Theme(data: Theme.of(c).copyWith(
                      colorScheme: const ColorScheme.light(primary: AppTheme.primary)),
                      child: child!));
              if (picked != null) set(() => t = picked);
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2))),
              child: Row(children: [
                const Icon(Icons.access_time_rounded, color: AppTheme.primary, size: 18),
                const SizedBox(width: 10),
                Text('Heure', style: AppFonts.label(size: 13)),
                const Spacer(),
                Text('${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}',
                    style: AppFonts.bold(color: AppTheme.primary, size: 20)
                        .copyWith(letterSpacing: 1)),
                const SizedBox(width: 6),
                const Icon(Icons.edit_rounded, size: 13, color: AppTheme.primary),
              ]),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx2),
              child: Text('Annuler', style: AppFonts.body(color: Colors.grey))),
          ElevatedButton.icon(
            onPressed: () {
              p.addSensorMeasure(name: ctrl.text.isEmpty ? 'Mesure' : ctrl.text, time: t);
              Navigator.pop(ctx2);
            },
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Ajouter'),
          ),
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (_, p, __) {
      _ensureSlots(p);
      final record = p.currentRecord;
      final date   = p.selectedDate;
      void upd(MealEntry e) => p.updateEntry(e);
      List<MealEntry> snacksFor(String k) =>
          record.entries.where((e) => e.slotId == 'snack_$k').toList();

      return Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        appBar: AppBar(
          title: const Text('Sahtek'),
          actions: [
            if (p.syncing)
              const Padding(padding: EdgeInsets.only(right: 12),
                  child: SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70))),
            const LogoutIconButton(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _addMesureDialog(context, p),
          backgroundColor: AppTheme.primary,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text('Mesure libre', style: AppFonts.label(color: Colors.white, size: 13)
              .copyWith(fontWeight: FontWeight.w600)),
        ),
        body: Column(children: [
          _DateBar(date: date,
              onPrev: () => p.selectDate(date.subtract(const Duration(days: 1))),
              onNext: () => p.selectDate(date.add(const Duration(days: 1)))),
          _SummaryBar(record: record),
          Expanded(child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [

              // À jeun
              _SimpleCard(label: 'À jeun', icon: Icons.water_drop_rounded,
                  color: const Color(0xFF5B8AF0), entry: _get(record, _kFasting), onUpdate: upd),
              _SnackSeparator(sectionKey: 'fasting',
                  onAdd: () => p.addSnack(afterIndex: 0, sectionKey: 'fasting')),
              ...snacksFor('fasting').map((s) => _SnackCard(
                  entry: s, onUpdate: upd, onDelete: () => p.removeEntry(s.id))),

              // Petit déjeuner
              _MealCard(title: 'Petit déjeuner', icon: Icons.free_breakfast_rounded,
                  color: AppTheme.breakfastColor,
                  eMesure: _get(record, _kBkfMesure),
                  eDose:   _get(record, _kBkfDose),
                  eAfter:  _get(record, _kBkfAfter),
                  onUpdate: upd,
                  onCarbsAnalyzed: (g, url) => p.updateCarbsG(_get(record, _kBkfMesure).id, g, url)),
              _SnackSeparator(sectionKey: 'bkf',
                  onAdd: () => p.addSnack(afterIndex: 3, sectionKey: 'bkf')),
              ...snacksFor('bkf').map((s) => _SnackCard(
                  entry: s, onUpdate: upd, onDelete: () => p.removeEntry(s.id))),

              // Déjeuner
              _MealCard(title: 'Déjeuner', icon: Icons.lunch_dining_rounded,
                  color: AppTheme.lunchColor,
                  eMesure: _get(record, _kLunchMesure),
                  eDose:   _get(record, _kLunchDose),
                  eAfter:  _get(record, _kLunchAfter),
                  onUpdate: upd,
                  onCarbsAnalyzed: (g, url) => p.updateCarbsG(_get(record, _kLunchMesure).id, g, url)),
              _SnackSeparator(sectionKey: 'lunch',
                  onAdd: () => p.addSnack(afterIndex: 7, sectionKey: 'lunch')),
              ...snacksFor('lunch').map((s) => _SnackCard(
                  entry: s, onUpdate: upd, onDelete: () => p.removeEntry(s.id))),

              // Dîner
              _MealCard(title: 'Dîner', icon: Icons.dinner_dining_rounded,
                  color: AppTheme.dinnerColor,
                  eMesure: _get(record, _kDinerMesure),
                  eDose:   _get(record, _kDinerDose),
                  eAfter:  _get(record, _kDinerAfter),
                  onUpdate: upd,
                  onCarbsAnalyzed: (g, url) => p.updateCarbsG(_get(record, _kDinerMesure).id, g, url)),
              _SnackSeparator(sectionKey: 'diner',
                  onAdd: () => p.addSnack(afterIndex: 11, sectionKey: 'diner')),
              ...snacksFor('diner').map((s) => _SnackCard(
                  entry: s, onUpdate: upd, onDelete: () => p.removeEntry(s.id))),

              const SizedBox(height: 4),

              // Avant coucher
              _SimpleCard(label: 'Avant coucher', icon: Icons.bedtime_rounded,
                  color: const Color(0xFF42A5F5), entry: _get(record, _kBedtime), onUpdate: upd),
            ],
          )),
        ]),
      );
    });
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Carte repas [mesure avant | heure | dose] + [mesure après 2h | heure]
// ══════════════════════════════════════════════════════════════════════════════
class _MealCard extends StatefulWidget {
  final String title; final IconData icon; final Color color;
  final MealEntry eMesure, eDose, eAfter;
  final ValueChanged<MealEntry> onUpdate;
  final void Function(double carbs, String? imageUrl)? onCarbsAnalyzed;
  const _MealCard({required this.title, required this.icon, required this.color,
    required this.eMesure, required this.eDose, required this.eAfter,
    required this.onUpdate, this.onCarbsAnalyzed});
  @override State<_MealCard> createState() => _MealCardState();
}

class _MealCardState extends State<_MealCard> {
  bool _expanded = true;

  Future<void> _openAnalysis() async {
    final result = await Navigator.of(context).push<(double, String?)>(
      MaterialPageRoute(builder: (_) => const MealAnalysisScreen()),
    );
    if (result != null && widget.onCarbsAnalyzed != null) {
      widget.onCarbsAnalyzed!(result.$1, result.$2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAny = widget.eMesure.hasGlycemie || widget.eAfter.hasGlycemie || widget.eDose.hasDose;
    return _Shell(color: widget.color, mb: 4,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header cliquable ──────────────────────────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Row(children: [
            _Pill(icon: widget.icon, color: widget.color),
            const SizedBox(width: 10),
            Text(widget.title, style: AppFonts.title(color: widget.color, size: 15)
                .copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            if (widget.eMesure.imageUrl != null)
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      child: InteractiveViewer(child: Image.network(widget.eMesure.imageUrl!)),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    image: DecorationImage(
                      image: NetworkImage(widget.eMesure.imageUrl!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            if (widget.eMesure.hasCarbsG)
              _CarbsBadge(carbsG: widget.eMesure.carbsG!, color: widget.color),
            if (hasAny) ...[
              const SizedBox(width: 4),
              _StatusChip(entries: [widget.eMesure, widget.eAfter]),
            ],
            const SizedBox(width: 4),
            // Bouton analyse photo
            GestureDetector(
              onTap: _openAnalysis,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.camera_alt_rounded,
                    color: widget.color.withValues(alpha: 0.55), size: 18),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
              color: widget.color.withValues(alpha: 0.6),
              size: 20,
            ),
          ]),
        ),

        // ── Contenu animé ─────────────────────────────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _expanded
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 14),
            _SectionLabel(label: 'Avant repas', color: widget.color),
            const SizedBox(height: 8),
            _ThreeCol(
              left:   _MesureInput(entry: widget.eMesure, color: widget.color, onUpdate: widget.onUpdate),
              center: _HeureInput(entry: widget.eMesure, color: widget.color, onUpdate: widget.onUpdate),
              right:  _DoseInput(entry: widget.eDose, color: widget.color, onUpdate: widget.onUpdate),
              color:  widget.color,
            ),
            const SizedBox(height: 14),
            _DashedLine(color: widget.color),
            const SizedBox(height: 12),
            _SectionLabel(label: 'Mesure après 2h', color: widget.color),
            const SizedBox(height: 8),
            _TwoCol(
              left:   _MesureInput(entry: widget.eAfter, color: widget.color, onUpdate: widget.onUpdate),
              center: _HeureInput(entry: widget.eAfter, color: widget.color, onUpdate: widget.onUpdate),
              color:  widget.color,
            ),
          ])
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Carte simple (À jeun / Avant coucher)
// ══════════════════════════════════════════════════════════════════════════════
class _SimpleCard extends StatefulWidget {
  final String label; final IconData icon; final Color color;
  final MealEntry entry; final ValueChanged<MealEntry> onUpdate;
  const _SimpleCard({required this.label, required this.icon, required this.color,
    required this.entry, required this.onUpdate});
  @override State<_SimpleCard> createState() => _SimpleCardState();
}

class _SimpleCardState extends State<_SimpleCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return _Shell(color: widget.color, mb: 4,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header cliquable ──────────────────────────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Row(children: [
            _Pill(icon: widget.icon, color: widget.color),
            const SizedBox(width: 10),
            Text(widget.label, style: AppFonts.title(color: widget.color, size: 15)
                .copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            if (widget.entry.hasGlycemie) _StatusChip(entries: [widget.entry]),
            const SizedBox(width: 6),
            Icon(
              _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
              color: widget.color.withValues(alpha: 0.6),
              size: 20,
            ),
          ]),
        ),

        // ── Contenu animé ─────────────────────────────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _expanded
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 14),
            _ThreeCol(
              left:   _MesureInput(entry: widget.entry, color: widget.color, onUpdate: widget.onUpdate),
              center: _HeureInput(entry: widget.entry, color: widget.color, onUpdate: widget.onUpdate),
              right:  _DoseInput(entry: widget.entry, color: widget.color, onUpdate: widget.onUpdate),
              color:  widget.color,
            ),
          ])
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Carte snack
// ══════════════════════════════════════════════════════════════════════════════
class _SnackCard extends StatelessWidget {
  final MealEntry entry; final ValueChanged<MealEntry> onUpdate;
  final VoidCallback onDelete;
  const _SnackCard({required this.entry, required this.onUpdate,
    required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return _Shell(color: AppTheme.snackColor, mb: 8,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _Pill(icon: Icons.cookie_rounded, color: AppTheme.snackColor),
          const SizedBox(width: 10),
          Expanded(child: Text(entry.name,
              style: AppFonts.title(color: AppTheme.snackColor, size: 14)
                  .copyWith(fontWeight: FontWeight.w700))),
          GestureDetector(onTap: onDelete,
              child: Container(padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.close_rounded, size: 14, color: Colors.red.shade300))),
        ]),
        const SizedBox(height: 12),
        _ThreeCol(
          left:   _MesureInput(entry: entry, color: AppTheme.snackColor, onUpdate: onUpdate),
          center: _HeureInput(entry: entry, color: AppTheme.snackColor, onUpdate: onUpdate),
          right:  _DoseInput(entry: entry, color: AppTheme.snackColor, onUpdate: onUpdate),
          color:  AppTheme.snackColor,
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Inputs
// ══════════════════════════════════════════════════════════════════════════════

class _MesureInput extends StatefulWidget {
  final MealEntry entry; final Color color;
  final ValueChanged<MealEntry> onUpdate;
  const _MesureInput({required this.entry, required this.color, required this.onUpdate});
  @override State<_MesureInput> createState() => _MesureInputState();
}

class _MesureInputState extends State<_MesureInput> {
  late TextEditingController _ctrl;
  late FocusNode _focus;

  bool get _conv => widget.entry.glycemieMode == GlycemieMode.convertie;
  double? get _raw  => widget.entry.glycemie;
  double? get _disp => widget.entry.glycemieAffichee;
  String _fmt(double? v) =>
      (v == null || v == 0) ? '' :
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  @override
  void initState() {
    super.initState();
    _ctrl  = TextEditingController(text: _fmt(_raw));
    _focus = FocusNode()..addListener(() { if (!_focus.hasFocus) _save(); });
  }

  void _save() {
    final v = double.tryParse(_ctrl.text.replaceAll(',', '.')) ?? 0;
    widget.onUpdate(widget.entry.copyWith(glycemie: v));
  }

  @override
  void didUpdateWidget(_MesureInput old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus) {
      final t = _fmt(_raw);
      if (_ctrl.text != t) _ctrl.text = t;
    }
  }

  @override
  void dispose() { _ctrl.dispose(); _focus.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final has = (_raw ?? 0) > 0;
    final col = has && _disp != null ? AppTheme.glucoseColor(_disp!) : widget.color;

    return Column(children: [
      GestureDetector(
        onTap: () => widget.onUpdate(widget.entry.copyWith(
            glycemieMode: _conv ? GlycemieMode.directe : GlycemieMode.convertie)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: _conv ? widget.color : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: _conv ? widget.color.withValues(alpha: 0.5) : Colors.grey.shade200)),
          child: Row(mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(_conv ? Icons.sensors_rounded : Icons.straighten_rounded,
                    size: 11, color: _conv ? Colors.white : Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(_conv ? '×0.18' : 'Normal',
                    style: AppFonts.label(
                        color: _conv ? Colors.white : Colors.grey.shade500, size: 10)
                        .copyWith(fontWeight: FontWeight.w700)),
              ]),
        ),
      ),
      const SizedBox(height: 6),
      _NumField(
        ctrl: _ctrl, focus: _focus,
        color: has ? col : widget.color,
        filled: has,
        fillColor: has ? col.withValues(alpha: 0.06) : null,
        borderColor: has ? col.withValues(alpha: 0.3) : Colors.grey.shade200,
        suffix: _conv ? 'mmol/L' : 'g/L',
        onDone: () { _save(); _focus.unfocus(); },
      ),
      if (has && _disp != null) ...[
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: col.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20)),
          child: Text(AppTheme.glucoseLabel(_disp!),
              style: AppFonts.label(color: col, size: 9)
                  .copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
        ),
      ],
    ]);
  }
}

class _DoseInput extends StatefulWidget {
  final MealEntry entry; final Color color;
  final ValueChanged<MealEntry> onUpdate;
  const _DoseInput({required this.entry, required this.color, required this.onUpdate});
  @override State<_DoseInput> createState() => _DoseInputState();
}

class _DoseInputState extends State<_DoseInput> {
  late TextEditingController _ctrl;
  late FocusNode _focus;

  String _fmt(double? v) =>
      (v == null || v == 0) ? '' :
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  @override
  void initState() {
    super.initState();
    _ctrl  = TextEditingController(text: _fmt(widget.entry.dose));
    _focus = FocusNode()..addListener(() {
      if (!_focus.hasFocus) {
        final v = double.tryParse(_ctrl.text.replaceAll(',', '.')) ?? 0;
        widget.onUpdate(widget.entry.copyWith(dose: v));
      }
    });
  }

  @override
  void didUpdateWidget(_DoseInput old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus) {
      final t = _fmt(widget.entry.dose);
      if (_ctrl.text != t) _ctrl.text = t;
    }
  }

  @override
  void dispose() { _ctrl.dispose(); _focus.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final has = (widget.entry.dose ?? 0) > 0;
    const c   = AppTheme.secondary;
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.medication_liquid_rounded, size: 11, color: c),
              const SizedBox(width: 4),
              Text('Insuline', style: AppFonts.label(color: c, size: 10)
                  .copyWith(fontWeight: FontWeight.w700)),
            ]),
      ),
      const SizedBox(height: 6),
      _NumField(
        ctrl: _ctrl, focus: _focus,
        color: has ? c : Colors.grey.shade400,
        filled: has,
        fillColor: has ? c.withValues(alpha: 0.06) : null,
        borderColor: has ? c.withValues(alpha: 0.3) : Colors.grey.shade200,
        suffix: 'UI',
        onDone: () {
          final v = double.tryParse(_ctrl.text.replaceAll(',', '.')) ?? 0;
          widget.onUpdate(widget.entry.copyWith(dose: v));
          _focus.unfocus();
        },
      ),
      if (has) ...[
        const SizedBox(height: 5),
        Text('${widget.entry.dose!.toStringAsFixed(1)} UI',
            style: AppFonts.label(color: c, size: 9)
                .copyWith(fontWeight: FontWeight.w700)),
      ],
    ]);
  }
}

class _HeureInput extends StatelessWidget {
  final MealEntry entry; final Color color;
  final ValueChanged<MealEntry> onUpdate;
  const _HeureInput({required this.entry, required this.color, required this.onUpdate});

  String _fmt(TimeOfDay? t) => t == null ? '--:--'
      : '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final t = await showTimePicker(context: context,
            initialTime: entry.mealTime ?? TimeOfDay.now(),
            builder: (c, child) => Theme(
                data: Theme.of(c).copyWith(
                    colorScheme: ColorScheme.light(primary: color)),
                child: child!));
        if (t != null) onUpdate(entry.copyWith(mealTime: t, doseTime: t));
      },
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.access_time_rounded, size: 11,
                    color: color.withValues(alpha: 0.7)),
                const SizedBox(width: 4),
                Text('Heure', style: AppFonts.label(
                    color: color.withValues(alpha: 0.7), size: 10)
                    .copyWith(fontWeight: FontWeight.w700)),
              ]),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.15))),
          child: Text(_fmt(entry.mealTime),
              textAlign: TextAlign.center,
              style: AppFonts.bold(color: color, size: 16)
                  .copyWith(letterSpacing: 1.5)),
        ),
        const SizedBox(height: 5),
        Text('appuyer', style: AppFonts.label(
            color: Colors.grey.shade400, size: 9)),
      ]),
    );
  }
}

class _NumField extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final Color color;
  final bool filled;
  final Color? fillColor;
  final Color borderColor;
  final String suffix;
  final VoidCallback onDone;
  const _NumField({required this.ctrl, required this.focus, required this.color,
    required this.filled, this.fillColor, required this.borderColor,
    required this.suffix, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl, focusNode: focus,
      textAlign: TextAlign.center,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
      style: AppFonts.bold(color: color, size: 18),
      onEditingComplete: onDone,
      decoration: InputDecoration(
        hintText: '—',
        hintStyle: AppFonts.bold(color: Colors.grey.shade200, size: 18),
        suffixText: suffix,
        suffixStyle: AppFonts.label(color: color.withValues(alpha: 0.5), size: 9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        filled: true,
        fillColor: fillColor ?? Colors.grey.shade50,
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: color, width: 2)),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Helpers UI
// ══════════════════════════════════════════════════════════════════════════════

class _ThreeCol extends StatelessWidget {
  final Widget left, center, right; final Color color;
  const _ThreeCol({required this.left, required this.center,
    required this.right, required this.color});
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: left),
      _VS(color: color),
      SizedBox(width: 80, child: center),
      _VS(color: color),
      Expanded(child: right),
    ]),
  );
}

class _TwoCol extends StatelessWidget {
  final Widget left, center; final Color color;
  const _TwoCol({required this.left, required this.center, required this.color});
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: left),
      _VS(color: color),
      SizedBox(width: 80, child: center),
      const Expanded(child: SizedBox.shrink()),
    ]),
  );
}

class _VS extends StatelessWidget {
  final Color color;
  const _VS({required this.color});
  @override
  Widget build(BuildContext context) => Container(
      width: 1, margin: const EdgeInsets.symmetric(horizontal: 4),
      color: color.withValues(alpha: 0.10));
}

class _Shell extends StatelessWidget {
  final Color color; final Widget child; final double mb;
  const _Shell({required this.color, required this.child, this.mb = 12});
  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.only(bottom: mb),
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: 0.08),
            blurRadius: 16, offset: const Offset(0, 4)),
        BoxShadow(color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4, offset: const Offset(0, 1)),
      ],
    ),
    child: child,
  );
}

class _Pill extends StatelessWidget {
  final IconData icon; final Color color;
  const _Pill({required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: 34, height: 34,
    decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.7)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(10)),
    child: Icon(icon, color: Colors.white, size: 17),
  );
}

class _SectionLabel extends StatelessWidget {
  final String label; final Color color;
  const _SectionLabel({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 3, height: 13,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 7),
    Text(label, style: AppFonts.label(color: color, size: 11)
        .copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.2)),
  ]);
}

class _DashedLine extends StatelessWidget {
  final Color color;
  const _DashedLine({required this.color});
  @override
  Widget build(BuildContext context) => Row(
    children: List.generate(30, (i) => Expanded(child: Container(
      height: 1,
      color: i.isEven ? color.withValues(alpha: 0.12) : Colors.transparent,
    ))),
  );
}

class _StatusChip extends StatelessWidget {
  final List<MealEntry> entries;
  const _StatusChip({required this.entries});
  @override
  Widget build(BuildContext context) {
    final vals = entries.where((e) => e.hasGlycemie)
        .map((e) => e.glycemieAffichee ?? 0).toList();
    if (vals.isEmpty) return const SizedBox.shrink();
    final avg = vals.reduce((a, b) => a + b) / vals.length;
    final col = AppTheme.glucoseColor(avg);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: col.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: col.withValues(alpha: 0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6,
            decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text('${avg.toStringAsFixed(1)} g/L',
            style: AppFonts.label(color: col, size: 10)
                .copyWith(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _CarbsBadge extends StatelessWidget {
  final double carbsG;
  final Color  color;
  const _CarbsBadge({required this.carbsG, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: AppTheme.snackColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.snackColor.withValues(alpha: 0.3))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.grain_rounded, size: 10, color: AppTheme.snackColor),
      const SizedBox(width: 3),
      Text('${carbsG.toStringAsFixed(0)}g',
          style: AppFonts.label(color: AppTheme.snackColor, size: 10)
              .copyWith(fontWeight: FontWeight.w700)),
    ]),
  );
}

class _SnackSeparator extends StatelessWidget {
  final String sectionKey; final VoidCallback onAdd;
  const _SnackSeparator({required this.sectionKey, required this.onAdd});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Expanded(child: Container(height: 1,
          color: AppTheme.snackColor.withValues(alpha: 0.15))),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: onAdd,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
              color: AppTheme.snackColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppTheme.snackColor.withValues(alpha: 0.3))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_rounded, color: AppTheme.snackColor, size: 14),
            const SizedBox(width: 5),
            Text('Snack', style: AppFonts.label(
                color: AppTheme.snackColor, size: 11)
                .copyWith(fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(child: Container(height: 1,
          color: AppTheme.snackColor.withValues(alpha: 0.15))),
    ]),
  );
}

// ── Barre résumé ──────────────────────────────────────────────────────────────
class _SummaryBar extends StatelessWidget {
  final DayRecord record;
  const _SummaryBar({required this.record});
  @override
  Widget build(BuildContext context) {
    final avg = record.averageGlycemieAffichee;
    final glyCol = avg > 0 ? AppTheme.glucoseColor(avg) : Colors.white;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppTheme.primary, AppTheme.secondary],
            begin: Alignment.centerLeft, end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.25),
            blurRadius: 16, offset: const Offset(0, 5))],
      ),
      child: Row(children: [
        _SumItem(icon: Icons.medication_liquid_rounded,
            label: 'Doses totales',
            value: record.totalDose > 0
                ? record.totalDose.toStringAsFixed(1) : '--',
            unit: 'UI', valueColor: Colors.white),
        _SumDivider(),
        _SumItem(icon: Icons.water_drop_rounded,
            label: 'Glycémie moy.',
            value: avg > 0 ? avg.toStringAsFixed(2) : '--',
            unit: 'g/L', valueColor: Colors.white),
        if (avg > 0) ...[
          _SumDivider(),
          Expanded(child: Column(
              mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 6, height: 6,
                        decoration: BoxDecoration(
                            color: glyCol, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Flexible(child: Text(AppTheme.glucoseLabel(avg),
                        style: AppFonts.label(
                            color: Colors.white, size: 10)
                            .copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis)),
                  ]),
            ),
          ])),
        ],
      ]),
    );
  }
}

class _SumItem extends StatelessWidget {
  final IconData icon; final String label, value, unit;
  final Color valueColor;
  const _SumItem({required this.icon, required this.label, required this.value,
    required this.unit, required this.valueColor});
  @override
  Widget build(BuildContext context) => Expanded(child:
  Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(icon, color: Colors.white70, size: 16),
    const SizedBox(height: 2),
    Text(label, style: AppFonts.label(color: Colors.white60, size: 10)),
    const SizedBox(height: 1),
    RichText(text: TextSpan(children: [
      TextSpan(text: value,
          style: AppFonts.bold(color: valueColor, size: 17)),
      if (value != '--') TextSpan(text: ' $unit',
          style: AppFonts.label(color: Colors.white60, size: 10)),
    ])),
  ]),
  );
}

class _SumDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 34, color: Colors.white.withValues(alpha: 0.2),
          margin: const EdgeInsets.symmetric(horizontal: 4));
}

// ── Date bar ──────────────────────────────────────────────────────────────────
class _DateBar extends StatelessWidget {
  final DateTime date; final VoidCallback onPrev, onNext;
  const _DateBar({required this.date, required this.onPrev, required this.onNext});
  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    return Container(
      color: AppTheme.primary,
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
      child: Row(children: [
        IconButton(onPressed: onPrev,
            icon: const Icon(Icons.chevron_left_rounded,
                color: Colors.white, size: 28)),
        Expanded(child: Column(children: [
          Text(isToday ? "Aujourd'hui"
              : DateFormat('EEEE', 'fr_FR').format(date),
              style: AppFonts.label(color: Colors.white60, size: 12)),
          const SizedBox(height: 1),
          Text(DateFormat('d MMMM yyyy', 'fr_FR').format(date),
              style: AppFonts.bold(color: Colors.white, size: 16)),
        ])),
        IconButton(onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded,
                color: Colors.white, size: 28)),
      ]),
    );
  }
}