import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../l10n/l10n.dart';
import '../models/meal_entry.dart';
import '../providers/app_provider.dart';
import '../services/voice_entry_parser.dart';
import '../utils/app_theme.dart';

const _kInk   = Color(0xFF1A2E3B);
const _kMuted = Color(0xFF8A9BA8);
const _kLine  = Color(0xFFE6ECF1);

// Langues de dictée : code → (nom affiché, locales préférées du moteur vocal)
const _kLangs = <String, (String, List<String>)>{
  'fr': ('Français', ['fr_FR']),
  'ar': ('العربية', ['ar_TN', 'ar_SA', 'ar_EG']),
  'en': ('English', ['en_US', 'en_GB']),
};

const _kSlotLabels = <String, String>{
  VoiceSlots.bkfMesure:   'À jeun — petit déj.',
  VoiceSlots.bkfDose:     'Petit déj. — dose',
  VoiceSlots.bkfAfter:    'Après petit déj. 2h',
  VoiceSlots.lunchMesure: 'Déjeuner — mesure',
  VoiceSlots.lunchDose:   'Déjeuner — dose',
  VoiceSlots.lunchAfter:  'Après déjeuner 2h',
  VoiceSlots.dinerMesure: 'Dîner — mesure',
  VoiceSlots.dinerDose:   'Dîner — dose',
  VoiceSlots.dinerAfter:  'Après dîner 2h',
  VoiceSlots.bedtime:     'Avant coucher',
  VoiceSlots.spontaneous: 'Mesure spontanée',
};

String _fmtTime(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String _fmtNum(double v) =>
    v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

/// Saisie vocale : le patient dicte ses mesures et ses doses, l'application
/// propose où les ranger, puis les enregistre après confirmation.
/// Renvoie le nombre de valeurs enregistrées.
class VoiceEntrySheet extends StatefulWidget {
  const VoiceEntrySheet({super.key});
  @override
  State<VoiceEntrySheet> createState() => _VoiceEntrySheetState();
}

class _VoiceEntrySheetState extends State<VoiceEntrySheet> {
  final _speech = SpeechToText();
  final _text   = TextEditingController();

  String  _lang      = L10n.isArabic ? 'ar' : 'fr';
  bool    _ready     = false;
  bool    _listening = false;
  String? _error;
  String  _committed = '';   // texte déjà acquis avant l'écoute en cours
  String  _parsed    = '';
  List<VoiceItem> _items = [];

  @override
  void initState() {
    super.initState();
    _text.addListener(_reparse);
  }

  @override
  void dispose() {
    _speech.cancel();
    _text.dispose();
    super.dispose();
  }

  void _reparse() {
    final t = _text.text.trim();
    if (t == _parsed) return;
    _parsed = t;
    setState(() => _items = VoiceEntryParser.parse(t));
  }

  Future<void> _toggle() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    setState(() => _error = null);
    try {
      _ready = _ready ||
          await _speech.initialize(onStatus: _onStatus, onError: _onError);
    } catch (_) {
      _ready = false;
    }
    if (!mounted) return;
    if (!_ready) {
      setState(() => _error =
          'Reconnaissance vocale indisponible. Vérifiez l\'autorisation du micro.'.tr);
      return;
    }

    FocusScope.of(context).unfocus();
    _committed = _text.text.trim();
    setState(() => _listening = true);
    await _speech.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        localeId: await _localeId(),
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 8),
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  /// Locale installée sur l'appareil pour la langue choisie.
  Future<String> _localeId() async {
    final wanted = _kLangs[_lang]!.$2;
    try {
      final ids = (await _speech.locales())
          .map((l) => l.localeId.replaceAll('-', '_'))
          .toList();
      for (final w in wanted) {
        if (ids.contains(w)) return w;
      }
      return ids.firstWhere((id) => id.startsWith(_lang),
          orElse: () => wanted.first);
    } catch (_) {
      return wanted.first;
    }
  }

  void _onResult(SpeechRecognitionResult r) {
    if (!mounted) return;
    final words = r.recognizedWords.trim();
    final full  = [_committed, words].where((s) => s.isNotEmpty).join(' ');
    _text.value = TextEditingValue(
        text: full, selection: TextSelection.collapsed(offset: full.length));
    if (r.finalResult) _committed = full;
  }

  void _onStatus(String status) {
    if (!mounted) return;
    if (status == SpeechToText.doneStatus ||
        status == SpeechToText.notListeningStatus) {
      setState(() => _listening = false);
    }
  }

  void _onError(SpeechRecognitionError e) {
    if (!mounted) return;
    // Silence ou rien de reconnu : simple fin d'écoute, pas une erreur
    const benign = {'error_no_match', 'error_speech_timeout'};
    setState(() {
      _listening = false;
      if (!benign.contains(e.errorMsg)) {
        _error = 'Erreur : {e}'.trp({'e': e.errorMsg});
      }
    });
  }

  Future<void> _pickTime(VoiceItem it) async {
    final t = await showTimePicker(
        context: context, initialTime: it.time ?? TimeOfDay.now());
    if (t != null) setState(() => it.time = t);
  }

  void _save() {
    context.read<AppProvider>().applyVoiceItems(_items);
    Navigator.pop(context, _items.length);
  }

  @override
  Widget build(BuildContext context) {
    final entries = context.read<AppProvider>().currentRecord.entries;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: _kLine,
                      borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 18),
              Text('Saisie vocale'.tr, style: AppFonts.title(size: 17)),
              Text('Dictez vos mesures et vos doses'.tr,
                  style: AppFonts.body(color: _kMuted, size: 12)),
              const SizedBox(height: 16),

              // ── Langue de dictée ────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: const Color(0xFFEFF3F6),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  for (final l in _kLangs.entries)
                    Expanded(child: GestureDetector(
                      onTap: _listening ? null
                          : () => setState(() => _lang = l.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _lang == l.key
                              ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(l.value.$1, textAlign: TextAlign.center,
                            style: AppFonts.label(
                                color: _lang == l.key ? _kInk : _kMuted,
                                size: 13)
                                .copyWith(fontWeight: FontWeight.w600)),
                      ),
                    )),
                ]),
              ),
              const SizedBox(height: 20),

              // ── Micro ───────────────────────────────────────────────────────
              Center(child: _MicButton(listening: _listening, onTap: _toggle)),
              const SizedBox(height: 10),
              Center(child: Text(
                _listening
                    ? 'Je vous écoute…'.tr
                    : _text.text.isEmpty
                        ? 'Appuyez sur le micro et parlez'.tr
                        : 'Appuyez à nouveau pour continuer la dictée'.tr,
                textAlign: TextAlign.center,
                style: AppFonts.label(
                    color: _listening ? AppTheme.danger : _kMuted, size: 12),
              )),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: AppFonts.label(
                    color: AppTheme.danger, size: 12)),
              ],
              const SizedBox(height: 16),

              // ── Texte reconnu ───────────────────────────────────────────────
              TextField(
                controller: _text,
                minLines: 2,
                maxLines: 5,
                readOnly: _listening,
                textDirection: _lang == 'ar'
                    ? TextDirection.rtl : TextDirection.ltr,
                style: AppFonts.body(color: _kInk, size: 14),
                decoration: InputDecoration(
                  labelText: 'Texte reconnu (modifiable)'.tr,
                  alignLabelWithHint: true,
                  hintText: 'Ex : à 7h30 à jeun 1,10, petit déjeuner dose 12 unités, 2 heures après 1,60'.tr,
                  hintMaxLines: 3,
                  hintStyle: AppFonts.body(color: _kMuted, size: 12),
                ),
              ),
              const SizedBox(height: 16),

              // ── Valeurs détectées ───────────────────────────────────────────
              if (_items.isEmpty)
                Text('Aucune valeur détectée pour le moment.'.tr,
                    style: AppFonts.label(color: _kMuted, size: 12))
              else ...[
                Text('Valeurs détectées'.tr, style: AppFonts.label(
                    color: _kInk, size: 12)
                    .copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                for (final it in _items)
                  _ItemRow(
                    item: it,
                    existing: entries
                        .where((e) => e.slotId == it.slotId)
                        .firstOrNull,
                    onSlot: (s) => setState(() => it.slotId = s),
                    onTime: () => _pickTime(it),
                    onRemove: () => setState(() => _items.remove(it)),
                  ),
              ],
              const SizedBox(height: 16),
              Row(children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Annuler'.tr,
                      style: AppFonts.body(color: Colors.grey)),
                ),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton.icon(
                  onPressed: _items.isEmpty || _listening ? null : _save,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text('Enregistrer ({n})'.trp({'n': _items.length})),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                )),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  final bool listening;
  final VoidCallback onTap;
  const _MicButton({required this.listening, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = listening ? AppTheme.danger : AppTheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 84, height: 84,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(
              color: color.withValues(alpha: listening ? 0.45 : 0.3),
              blurRadius: listening ? 28 : 16,
              spreadRadius: listening ? 6 : 0)],
        ),
        child: Icon(listening ? Icons.stop_rounded : Icons.mic_rounded,
            color: Colors.white, size: 38),
      ),
    );
  }
}

/// Une valeur détectée : [valeur + heure] [créneau] [retirer]
class _ItemRow extends StatelessWidget {
  final VoiceItem item;
  final MealEntry? existing;
  final ValueChanged<String> onSlot;
  final VoidCallback onTime;
  final VoidCallback onRemove;
  const _ItemRow({required this.item, required this.existing,
    required this.onSlot, required this.onTime, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final isDose = item.field == VoiceField.dose;
    final v      = item.value;
    final disp   = v == null || isDose ? null
        : (item.mode == GlycemieMode.convertie ? v * 0.18 : v);
    final color  = isDose ? AppTheme.secondary
        : disp != null ? AppTheme.glucoseColor(disp) : AppTheme.primary;
    final unit   = isDose ? 'UI'
        : item.mode == GlycemieMode.convertie ? 'mmol/L' : 'g/L';

    // Valeur déjà présente dans le créneau, qui sera remplacée
    final old = v == null || item.slotId == VoiceSlots.spontaneous ? null
        : isDose ? existing?.dose : existing?.glycemie;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(children: [
        Icon(isDose ? Icons.medication_liquid_rounded : Icons.water_drop_rounded,
            color: color, size: 20),
        const SizedBox(width: 10),
        SizedBox(width: 82, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v == null ? 'Heure seule'.tr : '${_fmtNum(v)} $unit',
              style: AppFonts.bold(color: color, size: v == null ? 12 : 15)),
          InkWell(
            onTap: onTime,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.schedule_rounded, size: 12, color: _kMuted),
              const SizedBox(width: 3),
              Text(item.time == null ? '--:--' : _fmtTime(item.time!),
                  style: AppFonts.label(color: _kMuted, size: 11)),
            ]),
          ),
        ])),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          DropdownButton<String>(
            value: item.slotId,
            isExpanded: true,
            isDense: true,
            underline: const SizedBox.shrink(),
            style: AppFonts.label(color: _kInk, size: 12),
            items: [
              for (final s in isDose ? VoiceSlots.dose : VoiceSlots.glycemie)
                DropdownMenuItem(value: s, child: Text(_kSlotLabels[s]!.tr,
                    overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (s) { if (s != null) onSlot(s); },
          ),
          if ((old ?? 0) > 0 && old != v)
            Text('Remplace {v}'.trp({'v': _fmtNum(old!)}),
                style: AppFonts.label(color: AppTheme.warning, size: 10)),
        ])),
        IconButton(
          onPressed: onRemove,
          tooltip: 'Supprimer'.tr,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.close_rounded, size: 18, color: _kMuted),
        ),
      ]),
    );
  }
}
