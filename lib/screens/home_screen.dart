import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/meal_entry.dart';
import '../models/day_record.dart';
import '../providers/app_provider.dart';
import '../services/firebase_service.dart';
import '../services/image_storage_service.dart';
import '../utils/app_theme.dart';
import '../widgets/logout_button.dart';
import '../widgets/sahtek_logo.dart';

// ── Palette locale ────────────────────────────────────────────────────────────
const _kInk         = Color(0xFF1A2E3B);
const _kMuted       = Color(0xFF8A9BA8);
const _kLine        = Color(0xFFE6ECF1);
const _kSpontColor  = Color(0xFF5B6CF0);

// ── Slots ─────────────────────────────────────────────────────────────────────
const _kFasting     = 'fasting';   // ancien créneau, fusionné dans _kBkfMesure
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
  _kBkfMesure, _kBkfDose, _kBkfAfter,
  _kLunchMesure, _kLunchDose, _kLunchAfter,
  _kDinerMesure, _kDinerDose, _kDinerAfter,
  _kBedtime,
];

const _kMetas = {
  _kBkfMesure:   _M('À jeun — petit déj.',  MealType.breakfast, TimeOfDay(hour: 7,  minute: 0)),
  _kBkfDose:     _M('Petit déj. — dose',    MealType.breakfast, TimeOfDay(hour: 7,  minute: 0)),
  _kBkfAfter:    _M('Après petit déj. 2h',  MealType.mesure,    TimeOfDay(hour: 9,  minute: 0)),
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

String _fmtTime(TimeOfDay? t) => t == null ? '--:--'
    : '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';

int _minutes(TimeOfDay? t) => t == null ? 0 : t.hour * 60 + t.minute;

/// Mesure spontanée = ajoutée via le bouton (ou ancienne mesure libre sans slot)
bool _isSpontaneous(MealEntry e) =>
    e.slotId == AppProvider.spontaneousSlot ||
    (e.slotId == null && e.type == MealType.mesure);

/// 0 = matin, 1 = midi, 2 = soir, 3 = nuit
int _period(TimeOfDay? t) {
  final m = _minutes(t);
  if (m < 12 * 60) return 0;
  if (m < 19 * 60) return 1;
  if (m < 22 * 60 + 30) return 2;
  return 3;
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
    if (_mergeFasting(r)) p.saveCurrentRecord();
    r.entries.sort((a, b) {
      final ai = _kFixedOrder.indexOf(a.slotId ?? '');
      final bi = _kFixedOrder.indexOf(b.slotId ?? '');
      return (ai < 0 ? 999 : ai).compareTo(bi < 0 ? 999 : bi);
    });
  }

  /// Fusionne l'ancienne carte « À jeun » dans la mesure avant petit déjeuner.
  /// Si les deux contiennent déjà une glycémie, l'ancienne valeur à jeun est
  /// conservée comme mesure spontanée pour ne rien perdre.
  bool _mergeFasting(DayRecord r) {
    final i = r.entries.indexWhere((e) => e.slotId == _kFasting);
    if (i == -1) return false;
    final f  = r.entries.removeAt(i);
    final mi = r.entries.indexWhere((e) => e.slotId == _kBkfMesure);
    final m  = r.entries[mi];

    if (f.hasGlycemie && m.hasGlycemie) {
      r.entries.add(MealEntry(
        id: f.id, name: 'À jeun', type: MealType.mesure,
        slotId: AppProvider.spontaneousSlot,
        glycemie: f.glycemie, glycemieMode: f.glycemieMode,
        dose: f.dose, mealTime: f.mealTime, doseTime: f.doseTime,
        observation: f.observation, imageUrl: f.imageUrl,
      ));
      return true;
    }
    if (f.hasGlycemie) {
      r.entries[mi] = m.copyWith(glycemie: f.glycemie,
          glycemieMode: f.glycemieMode, mealTime: f.mealTime, doseTime: f.doseTime);
    }
    if (f.imageUrl != null && r.entries[mi].imageUrl == null) {
      r.entries[mi] = r.entries[mi].copyWith(imageUrl: f.imageUrl);
    }
    if (f.hasDose) {
      final di = r.entries.indexWhere((e) => e.slotId == _kBkfDose);
      if (!r.entries[di].hasDose) {
        r.entries[di] = r.entries[di].copyWith(dose: f.dose);
      }
    }
    return true;
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

  Future<void> _addMesureSheet(BuildContext ctx, AppProvider p) async {
    final added = await showModalBottomSheet<TimeOfDay>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SpontaneousSheet(
        onSave: (name, time, value, mode) => p.addSensorMeasure(
            name: name, time: time, glycemie: value, glycemieMode: mode),
      ),
    );
    if (added != null && ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Text('Mesure spontanée ajoutée à ${_fmtTime(added)}'),
        ]),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (_, p, __) {
      _ensureSlots(p);
      final record = p.currentRecord;
      final date   = p.selectedDate;
      // dateKey au format 'yyyy-MM-dd' identique à AppProvider._key()
      final dk = '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
      void upd(MealEntry e) => p.updateEntry(e);

      List<Widget> snacks(List<String> keys) => [
        for (final k in keys)
          for (final s in record.entries.where((e) => e.slotId == 'snack_$k'))
            _SnackCard(entry: s, dateKey: dk, onUpdate: upd,
                onDelete: () => p.removeEntry(s.id)),
      ];

      final spont = record.entries.where(_isSpontaneous).toList()
        ..sort((a, b) => _minutes(a.mealTime).compareTo(_minutes(b.mealTime)));
      List<Widget> spontFor(int period) => [
        for (final s in spont.where((e) => _period(e.mealTime) == period))
          _SnackCard(entry: s, dateKey: dk, onUpdate: upd,
              color: _kSpontColor, icon: Icons.bolt_rounded,
              badge: 'Spontanée',
              onDelete: () => p.removeEntry(s.id)),
      ];

      return Scaffold(
        backgroundColor: AppTheme.bgColor,
        floatingActionButton: _SpontaneousFab(
            onTap: () => _addMesureSheet(context, p)),
        body: Column(children: [
          _Header(provider: p, record: record),
          Expanded(child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            children: [
              const _PeriodHeader(label: 'Matin', icon: Icons.wb_twilight_rounded),
              _MealCard(title: 'Petit déjeuner', icon: Icons.free_breakfast_rounded,
                  color: AppTheme.breakfastColor,
                  beforeLabel: 'À jeun · avant le repas',
                  eMesure: _get(record, _kBkfMesure),
                  eDose:   _get(record, _kBkfDose),
                  eAfter:  _get(record, _kBkfAfter),
                  dateKey: dk,
                  onUpdate: upd),
              ...snacks(['fasting', 'bkf']),
              ...spontFor(0),
              _SnackSeparator(sectionKey: 'bkf',
                  onAdd: () => p.addSnack(afterIndex: 2, sectionKey: 'bkf')),

              const _PeriodHeader(label: 'Midi', icon: Icons.wb_sunny_rounded),
              _MealCard(title: 'Déjeuner', icon: Icons.lunch_dining_rounded,
                  color: AppTheme.lunchColor,
                  eMesure: _get(record, _kLunchMesure),
                  eDose:   _get(record, _kLunchDose),
                  eAfter:  _get(record, _kLunchAfter),
                  dateKey: dk,
                  onUpdate: upd),
              ...snacks(['lunch']),
              ...spontFor(1),
              _SnackSeparator(sectionKey: 'lunch',
                  onAdd: () => p.addSnack(afterIndex: 5, sectionKey: 'lunch')),

              const _PeriodHeader(label: 'Soir', icon: Icons.wb_cloudy_rounded),
              _MealCard(title: 'Dîner', icon: Icons.dinner_dining_rounded,
                  color: AppTheme.dinnerColor,
                  eMesure: _get(record, _kDinerMesure),
                  eDose:   _get(record, _kDinerDose),
                  eAfter:  _get(record, _kDinerAfter),
                  dateKey: dk,
                  onUpdate: upd),
              ...snacks(['diner']),
              ...spontFor(2),
              _SnackSeparator(sectionKey: 'diner',
                  onAdd: () => p.addSnack(afterIndex: 8, sectionKey: 'diner')),

              const _PeriodHeader(label: 'Nuit', icon: Icons.nights_stay_rounded),
              _SimpleCard(label: 'Avant coucher', icon: Icons.bedtime_rounded,
                  color: const Color(0xFF3F7FD9), entry: _get(record, _kBedtime),
                  dateKey: dk, onUpdate: upd),
              ...spontFor(3),
            ],
          )),
        ]),
      );
    });
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Bouton flottant « Mesure spontanée »
// ══════════════════════════════════════════════════════════════════════════════
class _SpontaneousFab extends StatelessWidget {
  final VoidCallback onTap;
  const _SpontaneousFab({required this.onTap});
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.secondary],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(30),
      boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.35),
          blurRadius: 18, offset: const Offset(0, 8))],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('Mesure spontanée', style: AppFonts.label(
                color: Colors.white, size: 14).copyWith(fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  Feuille d'ajout d'une mesure spontanée
// ══════════════════════════════════════════════════════════════════════════════
class _SpontaneousSheet extends StatefulWidget {
  final void Function(String name, TimeOfDay time, double? value,
      GlycemieMode mode) onSave;
  const _SpontaneousSheet({required this.onSave});
  @override State<_SpontaneousSheet> createState() => _SpontaneousSheetState();
}

class _SpontaneousSheetState extends State<_SpontaneousSheet> {
  final _value = TextEditingController();
  final _label = TextEditingController();
  TimeOfDay _time = TimeOfDay.now();
  GlycemieMode _mode = GlycemieMode.directe;

  double? get _parsed {
    final v = double.tryParse(_value.text.replaceAll(',', '.'));
    return (v == null || v <= 0) ? null : v;
  }

  @override
  void dispose() { _value.dispose(); _label.dispose(); super.dispose(); }

  void _save() {
    widget.onSave(_label.text, _time, _parsed, _mode);
    Navigator.pop(context, _time);
  }

  @override
  Widget build(BuildContext context) {
    final v    = _parsed;
    final disp = v == null ? null
        : (_mode == GlycemieMode.convertie ? v * 0.18 : v);
    final col  = disp != null ? AppTheme.glucoseColor(disp) : _kSpontColor;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: _kLine,
                      borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 18),
              Row(children: [
                const _Pill(icon: Icons.bolt_rounded, color: _kSpontColor),
                const SizedBox(width: 12),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Mesure spontanée', style: AppFonts.title(size: 17)),
                  Text('Une glycémie prise en dehors des repas',
                      style: AppFonts.body(color: _kMuted, size: 12)),
                ])),
              ]),
              const SizedBox(height: 22),

              // ── Valeur ──────────────────────────────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: col.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: col.withValues(alpha: 0.25)),
                ),
                child: Row(children: [
                  Expanded(child: TextField(
                    controller: _value,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                    onChanged: (_) => setState(() {}),
                    style: AppFonts.bold(color: disp != null ? col : _kInk, size: 32),
                    decoration: InputDecoration(
                      hintText: '0,00',
                      hintStyle: AppFonts.bold(color: _kLine, size: 32),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  )),
                  _UnitToggle(mode: _mode,
                      onChanged: (m) => setState(() => _mode = m)),
                ]),
              ),
              const SizedBox(height: 8),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: disp != null ? 1 : 0,
                child: Row(children: [
                  Container(width: 7, height: 7,
                      decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(disp != null
                      ? '${AppTheme.glucoseLabel(disp)} · ${disp.toStringAsFixed(2)} g/L'
                      : '',
                      style: AppFonts.label(color: col, size: 12)
                          .copyWith(fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(height: 14),

              // ── Heure + libellé ─────────────────────────────────────────────
              Row(children: [
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: _time);
                    if (t != null) setState(() => _time = t);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4F8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(children: [
                      const Icon(Icons.schedule_rounded, size: 18, color: _kSpontColor),
                      const SizedBox(width: 8),
                      Text(_fmtTime(_time), style: AppFonts.bold(color: _kInk, size: 15)
                          .copyWith(letterSpacing: 0.8)),
                    ]),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: TextField(
                  controller: _label,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Libellé (ex : avant sport)',
                    prefixIcon: Icon(Icons.edit_note_rounded, size: 20),
                    contentPadding: EdgeInsets.symmetric(vertical: 13),
                  ),
                )),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Enregistrer la mesure'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _UnitToggle extends StatelessWidget {
  final GlycemieMode mode;
  final ValueChanged<GlycemieMode> onChanged;
  const _UnitToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, GlycemieMode m) {
      final sel = mode == m;
      return GestureDetector(
        onTap: () => onChanged(m),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: sel ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: sel ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 6, offset: const Offset(0, 2))] : null,
          ),
          child: Text(label, style: AppFonts.label(
              color: sel ? _kInk : _kMuted, size: 12)
              .copyWith(fontWeight: FontWeight.w600)),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: const Color(0xFFEFF3F6),
          borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('g/L', GlycemieMode.directe),
        seg('mmol/L', GlycemieMode.convertie),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Titre de période (Matin / Midi / Soir / Nuit)
// ══════════════════════════════════════════════════════════════════════════════
class _PeriodHeader extends StatelessWidget {
  final String label; final IconData icon;
  const _PeriodHeader({required this.label, required this.icon});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
    child: Row(children: [
      Icon(icon, size: 15, color: _kMuted),
      const SizedBox(width: 8),
      Text(label.toUpperCase(), style: AppFonts.label(color: _kMuted, size: 11)
          .copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.6)),
      const SizedBox(width: 12),
      Expanded(child: Container(height: 1, color: _kLine)),
    ]),
  );
}


// ══════════════════════════════════════════════════════════════════════════════
//  Carte repas [mesure avant | heure | dose] + [mesure après 2h | heure]
// ══════════════════════════════════════════════════════════════════════════════
class _MealCard extends StatefulWidget {
  final String title; final IconData icon; final Color color;
  final String beforeLabel;
  final MealEntry eMesure, eDose, eAfter;
  final String dateKey;
  final ValueChanged<MealEntry> onUpdate;
  const _MealCard({required this.title, required this.icon, required this.color,
    this.beforeLabel = 'Avant le repas',
    required this.eMesure, required this.eDose, required this.eAfter,
    required this.dateKey,
    required this.onUpdate});
  @override State<_MealCard> createState() => _MealCardState();
}

class _MealCardState extends State<_MealCard>
    with SingleTickerProviderStateMixin {
  bool _expanded  = true;
  bool _uploading = false;
  late AnimationController _enterCtrl;
  late Animation<double>   _enterFade;
  late Animation<Offset>   _enterSlide;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _enterFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut));
    _enterSlide = Tween<Offset>(
      begin: const Offset(0, 0.18), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut));
    _enterCtrl.forward();
  }

  @override
  void dispose() { _enterCtrl.dispose(); super.dispose(); }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppTheme.danger,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _showPhotoSheet() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PhotoBottomSheet(
        hasImage: widget.eMesure.imageUrl != null,
        onView: widget.eMesure.imageUrl != null
            ? () => _viewImage(widget.eMesure.imageUrl!)
            : null,
        onPickSource: (source) async {
          Navigator.pop(context);
          await _pickAndSave(source);
        },
        onDelete: widget.eMesure.imageUrl != null
            ? () async {
                Navigator.pop(context);
                await ImageStorageService.instance
                    .deleteImage(widget.eMesure.imageUrl!);
                widget.onUpdate(widget.eMesure.copyWith(
                    clearImageUrl: true));
              }
            : null,
      ),
    );
  }

  Future<void> _pickAndSave(ImageSource source) async {
    final uid = FirebaseService.instance.currentUid;
    if (uid == null) return;
    if (!mounted) return;
    setState(() => _uploading = true);
    try {
      final url = await ImageStorageService.instance.pickAndUpload(
        uid: uid,
        dateKey: widget.dateKey,
        entryId: widget.eMesure.id,
        source: source,
      );
      if (url != null && mounted) {
        widget.onUpdate(widget.eMesure.copyWith(imageUrl: url));
      }
    } on ImageUploadException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Erreur lors de l\'envoi de l\'image.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // Affiche le dialog de visualisation (sans pop — appelé depuis le header)
  void _showImageDialog(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain)),
      ),
    );
  }

  // Utilisé depuis le bottom sheet (le pop ferme le sheet avant d'ouvrir le dialog)
  void _viewImage(String url) {
    Navigator.pop(context);
    _showImageDialog(url);
  }

  @override
  Widget build(BuildContext context) {
    final hasAny = widget.eMesure.hasGlycemie || widget.eAfter.hasGlycemie || widget.eDose.hasDose;
    final hasPhoto = widget.eMesure.imageUrl != null;
    return FadeTransition(
      opacity: _enterFade,
      child: SlideTransition(
        position: _enterSlide,
        child: _Shell(color: widget.color, mb: 10,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header cliquable ──────────────────────────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Row(children: [
            _Pill(icon: widget.icon, color: widget.color),
            const SizedBox(width: 12),
            Expanded(child: _CardTitle(title: widget.title,
                subtitle: _fmtTime(widget.eMesure.mealTime))),
            // Miniature si photo enregistrée (ouvre dialog directement, sans pop)
            if (hasPhoto)
              GestureDetector(
                onTap: () => _showImageDialog(widget.eMesure.imageUrl!),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: widget.color.withValues(alpha: 0.4)),
                    image: DecorationImage(
                      image: NetworkImage(widget.eMesure.imageUrl!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            if (hasAny) ...[
              const SizedBox(width: 4),
              _StatusChip(entries: [widget.eMesure, widget.eAfter]),
            ],
            const SizedBox(width: 4),
            // Spinner upload OU bouton photo / analyse
            if (_uploading)
              SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.color.withValues(alpha: 0.7)))
            else
            GestureDetector(
              onTap: _showPhotoSheet,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  hasPhoto ? Icons.photo_camera_rounded : Icons.camera_alt_rounded,
                  color: hasPhoto
                      ? widget.color
                      : widget.color.withValues(alpha: 0.45),
                  size: 18,
                ),
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
            _SectionLabel(label: widget.beforeLabel, color: widget.color),
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
            _SectionLabel(label: '2 h après le repas', color: widget.color),
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
        ),  // _Shell
      ),    // SlideTransition
    );      // FadeTransition
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Carte simple (À jeun / Avant coucher)
// ══════════════════════════════════════════════════════════════════════════════
class _SimpleCard extends StatefulWidget {
  final String label; final IconData icon; final Color color;
  final MealEntry entry;
  final String dateKey;
  final ValueChanged<MealEntry> onUpdate;
  const _SimpleCard({required this.label, required this.icon, required this.color,
    required this.entry, required this.dateKey, required this.onUpdate});
  @override State<_SimpleCard> createState() => _SimpleCardState();
}

class _SimpleCardState extends State<_SimpleCard>
    with SingleTickerProviderStateMixin {
  bool _expanded  = true;
  bool _uploading = false;
  late AnimationController _enterCtrl;
  late Animation<double>   _enterFade;
  late Animation<Offset>   _enterSlide;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _enterFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut));
    _enterSlide = Tween<Offset>(
      begin: const Offset(0, 0.18), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut));
    _enterCtrl.forward();
  }

  @override
  void dispose() { _enterCtrl.dispose(); super.dispose(); }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppTheme.danger,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _togglePhoto() async {
    if (widget.entry.imageUrl != null) {
      await showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => _PhotoBottomSheet(
          hasImage: true,
          onView: () {
            Navigator.pop(context);
            showDialog(
              context: context,
              builder: (_) => Dialog(
                backgroundColor: Colors.black,
                child: InteractiveViewer(
                    child: Image.network(widget.entry.imageUrl!,
                        fit: BoxFit.contain)),
              ),
            );
          },
          onPickSource: (source) async {
            Navigator.pop(context);
            await _uploadPhoto(source);
          },
          onDelete: () async {
            Navigator.pop(context);
            await ImageStorageService.instance
                .deleteImage(widget.entry.imageUrl!);
            widget.onUpdate(widget.entry.copyWith(clearImageUrl: true));
          },
        ),
      );
    } else {
      await showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => _PhotoBottomSheet(
          hasImage: false,
          onPickSource: (source) async {
            Navigator.pop(context);
            await _uploadPhoto(source);
          },
        ),
      );
    }
  }

  Future<void> _uploadPhoto(ImageSource source) async {
    final uid = FirebaseService.instance.currentUid;
    if (uid == null) return;
    if (!mounted) return;
    setState(() => _uploading = true);
    try {
      final url = await ImageStorageService.instance.pickAndUpload(
        uid: uid,
        dateKey: widget.dateKey,
        entryId: widget.entry.id,
        source: source,
      );
      if (url != null && mounted) {
        widget.onUpdate(widget.entry.copyWith(imageUrl: url));
      }
    } on ImageUploadException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Erreur lors de l\'envoi de l\'image.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = widget.entry.imageUrl != null;
    return FadeTransition(
      opacity: _enterFade,
      child: SlideTransition(
        position: _enterSlide,
        child: _Shell(color: widget.color, mb: 10,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Header cliquable ──────────────────────────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Row(children: [
              _Pill(icon: widget.icon, color: widget.color),
              const SizedBox(width: 12),
            Expanded(child: _CardTitle(title: widget.label,
                subtitle: _fmtTime(widget.entry.mealTime))),
            if (hasPhoto)
              GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    backgroundColor: Colors.black,
                    child: InteractiveViewer(
                        child: Image.network(widget.entry.imageUrl!,
                            fit: BoxFit.contain)),
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: widget.color.withValues(alpha: 0.4)),
                    image: DecorationImage(
                      image: NetworkImage(widget.entry.imageUrl!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            if (widget.entry.hasGlycemie) _StatusChip(entries: [widget.entry]),
            const SizedBox(width: 4),
            if (_uploading)
              SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.color.withValues(alpha: 0.7)))
            else
              GestureDetector(
                onTap: _togglePhoto,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.camera_alt_rounded,
                      color: hasPhoto
                          ? widget.color
                          : widget.color.withValues(alpha: 0.35),
                      size: 16),
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
            _ThreeCol(
              left:   _MesureInput(entry: widget.entry, color: widget.color, onUpdate: widget.onUpdate),
              center: _HeureInput(entry: widget.entry, color: widget.color, onUpdate: widget.onUpdate),
              right:  _DoseInput(entry: widget.entry, color: widget.color, onUpdate: widget.onUpdate),
              color:  widget.color,
            ),
          ])
              : const SizedBox.shrink(),
        ),
        ]),   // Column
        ),    // _Shell
      ),      // SlideTransition
    );        // FadeTransition
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Carte snack
// ══════════════════════════════════════════════════════════════════════════════
class _SnackCard extends StatefulWidget {
  final MealEntry entry;
  final String dateKey;
  final ValueChanged<MealEntry> onUpdate;
  final VoidCallback onDelete;
  final Color color;
  final IconData icon;
  final String? badge;
  const _SnackCard({required this.entry, required this.dateKey,
    required this.onUpdate, required this.onDelete,
    this.color = AppTheme.snackColor, this.icon = Icons.cookie_rounded,
    this.badge});
  @override State<_SnackCard> createState() => _SnackCardState();
}

class _SnackCardState extends State<_SnackCard> {
  bool _uploading = false;

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppTheme.danger,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _doUpload(ImageSource source) async {
    final uid = FirebaseService.instance.currentUid;
    if (uid == null) return;
    setState(() => _uploading = true);
    try {
      final url = await ImageStorageService.instance.pickAndUpload(
        uid: uid,
        dateKey: widget.dateKey,
        entryId: widget.entry.id,
        source: source,
      );
      if (url != null && mounted) {
        widget.onUpdate(widget.entry.copyWith(imageUrl: url));
      }
    } on ImageUploadException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Erreur lors de l\'envoi de l\'image.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _togglePhoto() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PhotoBottomSheet(
        hasImage: widget.entry.imageUrl != null,
        onView: widget.entry.imageUrl != null
            ? () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    backgroundColor: Colors.black,
                    child: InteractiveViewer(
                        child: Image.network(widget.entry.imageUrl!,
                            fit: BoxFit.contain)),
                  ),
                );
              }
            : null,
        onPickSource: (source) async {
          Navigator.pop(context);
          await _doUpload(source);
        },
        onDelete: widget.entry.imageUrl != null
            ? () async {
                Navigator.pop(context);
                await ImageStorageService.instance
                    .deleteImage(widget.entry.imageUrl!);
                if (mounted) widget.onUpdate(widget.entry.copyWith(clearImageUrl: true));
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = widget.entry.imageUrl != null;
    return _Shell(color: widget.color, mb: 10,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _Pill(icon: widget.icon, color: widget.color),
          const SizedBox(width: 12),
          Expanded(child: _CardTitle(title: widget.entry.name,
              subtitle: _fmtTime(widget.entry.mealTime), badge: widget.badge,
              badgeColor: widget.color)),
          if (hasPhoto)
            GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (_) => Dialog(
                  backgroundColor: Colors.black,
                  child: InteractiveViewer(
                      child: Image.network(widget.entry.imageUrl!,
                          fit: BoxFit.contain)),
                ),
              ),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                width: 26, height: 26,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: widget.color.withValues(alpha: 0.4)),
                  image: DecorationImage(
                    image: NetworkImage(widget.entry.imageUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          if (_uploading)
            SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2,
                    color: widget.color))
          else
            GestureDetector(
              onTap: _togglePhoto,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Icon(Icons.camera_alt_rounded,
                    color: hasPhoto
                        ? widget.color
                        : widget.color.withValues(alpha: 0.35),
                    size: 16),
              ),
            ),
          IconButton(
            onPressed: widget.onDelete,
            tooltip: 'Supprimer',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline_rounded, size: 19, color: _kMuted),
          ),
        ]),
        const SizedBox(height: 12),
        _ThreeCol(
          left:   _MesureInput(entry: widget.entry, color: widget.color, onUpdate: widget.onUpdate),
          center: _HeureInput(entry: widget.entry, color: widget.color, onUpdate: widget.onUpdate),
          right:  _DoseInput(entry: widget.entry, color: widget.color, onUpdate: widget.onUpdate),
          color:  widget.color,
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Bottom sheet photo
// ══════════════════════════════════════════════════════════════════════════════

class _PhotoBottomSheet extends StatelessWidget {
  final bool           hasImage;
  final VoidCallback?  onView;
  final VoidCallback?  onDelete;
  final void Function(ImageSource)? onPickSource;

  const _PhotoBottomSheet({
    required this.hasImage,
    this.onView,
    this.onDelete,
    this.onPickSource,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Photo du repas',
              style: AppFonts.title(size: 16)
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _SheetTile(
            icon: Icons.camera_alt_rounded,
            color: AppTheme.secondary,
            label: 'Prendre une photo',
            sub: 'Appareil photo',
            onTap: () => onPickSource?.call(ImageSource.camera),
          ),
          _SheetTile(
            icon: Icons.photo_library_rounded,
            color: Colors.blueGrey,
            label: 'Choisir depuis la galerie',
            sub: 'Photos et fichiers',
            onTap: () => onPickSource?.call(ImageSource.gallery),
          ),
          if (hasImage && onView != null)
            _SheetTile(
              icon: Icons.zoom_in_rounded,
              color: Colors.indigo,
              label: 'Voir la photo',
              onTap: onView!,
            ),
          if (hasImage && onDelete != null)
            _SheetTile(
              icon: Icons.delete_outline_rounded,
              color: Colors.red.shade400,
              label: 'Supprimer la photo',
              onTap: onDelete!,
            ),
        ]),
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   label;
  final String?  sub;
  final VoidCallback onTap;
  const _SheetTile({required this.icon, required this.color,
    required this.label, this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: color, size: 20),
    ),
    title: Text(label, style: AppFonts.body(size: 14)
        .copyWith(fontWeight: FontWeight.w600)),
    subtitle: sub != null
        ? Text(sub!, style: AppFonts.label(
            color: Colors.grey.shade500, size: 11))
        : null,
  );
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
    padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _kLine),
      boxShadow: [
        BoxShadow(color: const Color(0xFF1A2E3B).withValues(alpha: 0.04),
            blurRadius: 18, offset: const Offset(0, 6)),
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
    width: 38, height: 38,
    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12)),
    child: Icon(icon, color: color, size: 19),
  );
}

/// Titre de carte : nom en encre sombre + heure (et badge optionnel) dessous.
class _CardTitle extends StatelessWidget {
  final String title, subtitle;
  final String? badge;
  final Color? badgeColor;
  const _CardTitle({required this.title, required this.subtitle,
    this.badge, this.badgeColor});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: AppFonts.title(color: _kInk, size: 15)),
      const SizedBox(height: 1),
      Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.schedule_rounded, size: 12, color: _kMuted),
        const SizedBox(width: 4),
        Text(subtitle, style: AppFonts.label(color: _kMuted, size: 11)),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
                color: (badgeColor ?? _kMuted).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6)),
            child: Text(badge!, style: AppFonts.label(
                color: badgeColor ?? _kMuted, size: 10)
                .copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ]),
    ],
  );
}

class _SectionLabel extends StatelessWidget {
  final String label; final Color color;
  const _SectionLabel({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 6, height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 8),
    Text(label, style: AppFonts.label(color: _kInk.withValues(alpha: 0.7), size: 12)
        .copyWith(fontWeight: FontWeight.w600)),
  ]);
}

class _DashedLine extends StatelessWidget {
  final Color color;
  const _DashedLine({required this.color});
  @override
  Widget build(BuildContext context) => Container(height: 1, color: _kLine);
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
          color: col.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6,
            decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text('${avg.toStringAsFixed(2)} g/L',
            style: AppFonts.label(color: col, size: 11)
                .copyWith(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// Lien discret « + Ajouter un snack » sous chaque repas.
class _SnackSeparator extends StatelessWidget {
  final String sectionKey; final VoidCallback onAdd;
  const _SnackSeparator({required this.sectionKey, required this.onAdd});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: onAdd,
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.snackColor,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        visualDensity: VisualDensity.compact,
      ),
      icon: const Icon(Icons.add_circle_outline_rounded, size: 17),
      label: Text('Ajouter un snack', style: AppFonts.label(
          color: AppTheme.snackColor, size: 12)
          .copyWith(fontWeight: FontWeight.w600)),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  En-tête : logo, navigation de date et résumé du jour
// ══════════════════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final AppProvider provider;
  final DayRecord record;
  const _Header({required this.provider, required this.record});

  Future<void> _pickDate(BuildContext context) async {
    final d = await showDatePicker(
      context: context,
      initialDate: provider.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) provider.selectDate(d);
  }

  @override
  Widget build(BuildContext context) {
    final date    = provider.selectedDate;
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    final avg     = record.averageGlycemieAffichee;
    final count   = record.entries.where((e) => e.hasGlycemie).length;
    final weekday = DateFormat('EEEE', 'fr_FR').format(date);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF07748C), AppTheme.primary, Color(0xFF0AA89C)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.22),
            blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 8, 18),
          child: Column(children: [
            // ── Barre supérieure ──────────────────────────────────────────────
            Row(children: [
              const SahtekLogo(size: 30, animate: false),
              const SizedBox(width: 10),
              Text('Sahtek', style: AppFonts.title(color: Colors.white, size: 20)
                  .copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.4)),
              const Spacer(),
              if (provider.syncing)
                const Padding(padding: EdgeInsets.only(right: 4),
                    child: SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white70))),
              const LogoutIconButton(),
            ]),
            const SizedBox(height: 10),

            // ── Navigation de date ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Row(children: [
                _HeaderBtn(icon: Icons.chevron_left_rounded,
                    onTap: () => provider.selectDate(
                        date.subtract(const Duration(days: 1)))),
                Expanded(child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _pickDate(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(children: [
                      Text(isToday ? "Aujourd'hui"
                          : '${weekday[0].toUpperCase()}${weekday.substring(1)}',
                          style: AppFonts.label(color: Colors.white70, size: 12)),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(DateFormat('d MMMM yyyy', 'fr_FR').format(date),
                            style: AppFonts.bold(color: Colors.white, size: 17)),
                        const SizedBox(width: 6),
                        const Icon(Icons.calendar_month_rounded,
                            size: 15, color: Colors.white70),
                      ]),
                    ]),
                  ),
                )),
                _HeaderBtn(icon: Icons.chevron_right_rounded,
                    onTap: () => provider.selectDate(
                        date.add(const Duration(days: 1)))),
              ]),
            ),
            if (!isToday)
              TextButton(
                onPressed: () => provider.selectDate(DateTime.now()),
                style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact),
                child: Text("Revenir à aujourd'hui", style: AppFonts.label(
                    color: Colors.white, size: 12)
                    .copyWith(decoration: TextDecoration.underline,
                        decorationColor: Colors.white70)),
              ),
            const SizedBox(height: 12),

            // ── Résumé du jour ────────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Row(children: [
                _SumItem(label: 'Glycémie moy.',
                    value: avg > 0 ? avg.toStringAsFixed(2) : '--', unit: 'g/L',
                    dot: avg > 0 ? AppTheme.glucoseColor(avg) : null,
                    caption: avg > 0 ? AppTheme.glucoseLabel(avg) : null),
                const _SumDivider(),
                _SumItem(label: 'Insuline',
                    value: record.totalDose > 0
                        ? record.totalDose.toStringAsFixed(1) : '--',
                    unit: 'UI'),
                const _SumDivider(),
                _SumItem(label: 'Mesures',
                    value: count > 0 ? '$count' : '--', unit: ''),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _HeaderBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: 0.14),
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(6),
          child: Icon(icon, color: Colors.white, size: 24)),
    ),
  );
}

class _SumItem extends StatelessWidget {
  final String label, value, unit;
  final Color? dot;
  final String? caption;
  const _SumItem({required this.label, required this.value,
    required this.unit, this.dot, this.caption});
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(label, style: AppFonts.label(color: Colors.white70, size: 11)),
    const SizedBox(height: 2),
    RichText(text: TextSpan(children: [
      TextSpan(text: value, style: AppFonts.bold(color: Colors.white, size: 19)),
      if (value != '--' && unit.isNotEmpty) TextSpan(text: ' $unit',
          style: AppFonts.label(color: Colors.white70, size: 11)),
    ])),
    if (caption != null)
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(
            color: dot, shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1))),
        const SizedBox(width: 4),
        Flexible(child: Text(caption!, overflow: TextOverflow.ellipsis,
            style: AppFonts.label(color: Colors.white, size: 10))),
      ]),
  ]));
}

class _SumDivider extends StatelessWidget {
  const _SumDivider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.2));
}
