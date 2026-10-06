import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sahtek/providers/glucose_provider.dart';
import '../models/glucose_reading.dart';
import '../models/insulin_dose.dart';
import '../providers/insulin_provider.dart';
import '../services/notification_service.dart';
import '../services/ocr_service.dart';
import '../utils/app_theme.dart';
import '../l10n/l10n.dart';

/// Bottom sheet pour ajouter une mesure glycémie ou une dose insuline
class AddReadingSheet extends StatefulWidget {
  const AddReadingSheet({super.key});
  @override
  State<AddReadingSheet> createState() => _AddReadingSheetState();
}

class _AddReadingSheetState extends State<AddReadingSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // Glycémie
  final _glycCtrl      = TextEditingController();
  bool   _isConverted  = false;
  String _mealContext  = 'before_meal';
  final _glucNoteCtrl  = TextEditingController();

  // Insuline
  final _unitsCtrl     = TextEditingController();
  String _insulinType  = 'rapid';
  final _insuNoteCtrl  = TextEditingController();

  bool _saving   = false;
  bool _scanning = false; // OCR en cours
  String? _ocrMessage; // Feedback OCR

  double? get _rawValue =>
      double.tryParse(_glycCtrl.text.replaceAll(',', '.'));

  double? get _displayValue {
    final v = _rawValue;
    if (v == null) return null;
    return _isConverted ? double.parse((v * 0.18).toStringAsFixed(2)) : v;
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _glycCtrl.dispose(); _glucNoteCtrl.dispose();
    _unitsCtrl.dispose(); _insuNoteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 4),
          width: 40, height: 4,
          decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2)),
        ),
        // Tabs
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          decoration: BoxDecoration(
              color: AppTheme.bgColor, borderRadius: BorderRadius.circular(12)),
          child: TabBar(
            controller: _tabs,
            indicator: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(10)),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            dividerColor: Colors.transparent,
            tabs: [
              Tab(icon: Icon(Icons.water_drop_rounded, size: 18),
                  text: 'Glycémie'.tr),
              Tab(icon: Icon(Icons.medication_liquid_rounded, size: 18),
                  text: 'Insuline'.tr),
            ],
          ),
        ),
        SizedBox(
          height: 380,
          child: TabBarView(controller: _tabs, children: [
            _GlucoseForm(
              ctrl: _glycCtrl, noteCtrl: _glucNoteCtrl,
              isConverted: _isConverted, displayValue: _displayValue,
              mealContext: _mealContext,
              onConvertedChanged: (v) => setState(() => _isConverted = v),
              onMealContextChanged: (v) => setState(() => _mealContext = v),
              scanning: _scanning,
              ocrMessage: _ocrMessage,
              onScanPhoto: () => _scanGlucometer(fromGallery: false),
              onScanGallery: () => _scanGlucometer(fromGallery: true),
            ),
            _InsulinForm(
              ctrl: _unitsCtrl, noteCtrl: _insuNoteCtrl,
              insulinType: _insulinType,
              onTypeChanged: (v) => setState(() => _insulinType = v),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
          child: Row(children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler'.tr,
                  style: AppFonts.body(color: Colors.grey)),
            ),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : Text('Enregistrer'.tr),
            )),
          ]),
        ),
      ]),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (_tabs.index == 0) {
        // ── Glycémie ────────────────────────────────────────────────────────
        final v = _rawValue;
        if (v == null || v <= 0) return;
        final now = DateTime.now();
        await context.read<GlucoseProvider>().addReading(
          GlucoseReading(
            value: v, isConverted: _isConverted,
            timestamp: now,
            note: _glucNoteCtrl.text.isEmpty ? null : _glucNoteCtrl.text,
            mealContext: _mealContext,
          ),
        );
        // Valeur en g/L pour comparer aux seuils
        final display = _displayValue ?? v;
        if (display < 0.7) {
          // Hypoglycémie → refaire la mesure dans 15 min
          await NotificationService.instance.scheduleHypoglycemiaRecheck();
        } else if (display > 1.9) {
          // Hyperglycémie → rappels hydratation toutes les 30 min (×3)
          await NotificationService.instance.scheduleHyperglycemiaWaterReminders();
        } else {
          // Glycémie normale → annuler les rappels eau en cours
          await NotificationService.instance.cancelHyperglycemiaReminders();
        }
      } else {
        // ── Insuline ────────────────────────────────────────────────────────
        final u = double.tryParse(_unitsCtrl.text.replaceAll(',', '.'));
        if (u == null || u <= 0) return;
        final now = DateTime.now();
        await context.read<InsulinProvider>().addDose(InsulinDose(
          units: u, insulinType: _insulinType, timestamp: now,
          note: _insuNoteCtrl.text.isEmpty ? null : _insuNoteCtrl.text,
        ));
        // Dose enregistrée → mesurer la glycémie dans 2h
        await NotificationService.instance.schedulePostInsulinMeasure(now);
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Déclenche l'OCR : ouvre caméra ou galerie, analyse l'image, injecte la valeur
  Future<void> _scanGlucometer({required bool fromGallery}) async {
    setState(() { _scanning = true; _ocrMessage = null; });
    try {
      final result = await OcrService.instance.pickAndRecognize(
          fromGallery: fromGallery);
      if (!mounted) return;

      if (result == null) {
        // Annulé par l'utilisateur
        setState(() => _scanning = false);
        return;
      }

      if (result.hasValue) {
        _glycCtrl.text = result.value!.toStringAsFixed(
            result.value! < 35 ? 1 : 0);
        setState(() {
          _scanning = false;
          _ocrMessage = '✓ Valeur détectée : {v}'.trp({'v': _glycCtrl.text});
        });
      } else {
        setState(() {
          _scanning = false;
          _ocrMessage = result.errorMessage ?? 'Valeur non reconnue'.tr;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _scanning = false;
        _ocrMessage = 'Erreur : {e}'.trp({'e': e});
      });
    }
  }
}

// ── Formulaire glycémie ───────────────────────────────────────────────────────
class _GlucoseForm extends StatelessWidget {
  final TextEditingController ctrl, noteCtrl;
  final bool isConverted;
  final double? displayValue;
  final String mealContext;
  final ValueChanged<bool>   onConvertedChanged;
  final ValueChanged<String> onMealContextChanged;
  // OCR
  final bool scanning;
  final String? ocrMessage;
  final VoidCallback onScanPhoto;
  final VoidCallback onScanGallery;

  const _GlucoseForm({
    required this.ctrl, required this.noteCtrl,
    required this.isConverted, required this.displayValue,
    required this.mealContext,
    required this.onConvertedChanged, required this.onMealContextChanged,
    required this.scanning, this.ocrMessage,
    required this.onScanPhoto, required this.onScanGallery,
  });

  @override
  Widget build(BuildContext context) {
    final color = displayValue != null
        ? AppTheme.glucoseColor(displayValue!) : AppTheme.primary;
    final ocrSuccess = ocrMessage != null && ocrMessage!.startsWith('✓');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Toggle valeur directe / convertie
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              color: AppTheme.bgColor,
              borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [false, true].map((conv) {
              final sel = isConverted == conv;
              return Expanded(child: GestureDetector(
                onTap: () => onConvertedChanged(conv),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                      color: sel ? AppTheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(9)),
                  child: Text(conv ? 'Convertie (×0.18)'.tr : 'Valeur directe'.tr,
                      textAlign: TextAlign.center,
                      style: AppFonts.label(
                          color: sel ? Colors.white : Colors.grey, size: 12)
                          .copyWith(
                          fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
                ),
              ));
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // ── Champ valeur + bouton photo ──────────────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
              style: AppFonts.bold(size: 18),
              decoration: InputDecoration(
                labelText: 'Valeur glycémie'.tr,
                suffixText: isConverted ? 'mmol/L' : 'Mg/dl',
                suffixStyle: AppFonts.bold(color: AppTheme.primary, size: 13),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Bouton photo OCR
          Column(children: [
            const SizedBox(height: 6),
            _OcrButton(
              scanning: scanning,
              onCamera: onScanPhoto,
              onGallery: onScanGallery,
            ),
          ]),
        ]),

        // ── Feedback OCR ─────────────────────────────────────────────────
        if (scanning) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.primary)),
              const SizedBox(width: 10),
              Text('Analyse en cours…'.tr,
                  style: AppFonts.label(color: AppTheme.primary, size: 13)),
            ]),
          ),
        ] else if (ocrMessage != null) ...[
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: (ocrSuccess ? AppTheme.success : AppTheme.danger)
                    .withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: (ocrSuccess ? AppTheme.success : AppTheme.danger)
                        .withOpacity(0.25))),
            child: Row(children: [
              Icon(
                ocrSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                color: ocrSuccess ? AppTheme.success : AppTheme.danger,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(ocrMessage!,
                  style: AppFonts.label(
                      color: ocrSuccess ? AppTheme.success : AppTheme.danger,
                      size: 12))),
            ]),
          ),
        ],

        if (displayValue != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.25))),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, color: color, size: 14),
              const SizedBox(width: 8),
              Text(
                isConverted
                    ? '${displayValue!.toStringAsFixed(2)} Mg/dl'
                    : '${displayValue!.toStringAsFixed(2)} Mg/dl',
                style: AppFonts.label(color: color, size: 12)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Text('— ${AppTheme.glucose(displayValue!)}',
                  style: AppFonts.label(color: color.withOpacity(0.7), size: 11)),
            ]),
          ),
        ],
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: mealContext,
          decoration: InputDecoration(labelText: 'Contexte'.tr),
          items: [
            DropdownMenuItem(value: 'fasting',     child: Text('À jeun'.tr)),
            DropdownMenuItem(value: 'before_meal', child: Text('Avant repas'.tr)),
            DropdownMenuItem(value: 'after_meal',  child: Text('Après repas (2h)'.tr)),
            DropdownMenuItem(value: 'bedtime',     child: Text('Avant coucher'.tr)),
            DropdownMenuItem(value: 'sensor',      child: Text('Capteur CGM'.tr)),
          ],
          onChanged: (v) { if (v != null) onMealContextChanged(v); },
        ),
        const SizedBox(height: 10),
        TextField(
          controller: noteCtrl,
          decoration: InputDecoration(
              labelText: 'Note (optionnel)'.tr,
              prefixIcon: Icon(Icons.notes_rounded, size: 18)),
        ),
      ]),
    );
  }
}

// ── Bouton OCR avec popup camera/galerie ──────────────────────────────────────
class _OcrButton extends StatelessWidget {
  final bool scanning;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const _OcrButton({
    required this.scanning,
    required this.onCamera,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Photographier le glucomètre'.tr,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: scanning ? null : () => _showSourceDialog(context),
          child: Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              gradient: scanning
                  ? null
                  : const LinearGradient(
                      colors: [AppTheme.primary, AppTheme.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
              color: scanning ? Colors.grey.shade200 : null,
              borderRadius: BorderRadius.circular(14),
              boxShadow: scanning ? null : [
                BoxShadow(
                    color: AppTheme.primary.withOpacity(0.25),
                    blurRadius: 8, offset: const Offset(0, 3)),
              ],
            ),
            child: scanning
                ? const Center(child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primary)))
                : const Icon(Icons.camera_alt_rounded,
                    color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }

  void _showSourceDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 38, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Lire le glucomètre'.tr,
                style: AppFonts.title(size: 16)),
            const SizedBox(height: 6),
            Text('Photographiez l\'écran de votre appareil.'.tr,
                style: AppFonts.body(color: Colors.grey, size: 13)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: _SourceTile(
                icon: Icons.camera_alt_rounded,
                label: 'Prendre une\nphoto'.tr,
                color: AppTheme.primary,
                onTap: () { Navigator.pop(context); onCamera(); },
              )),
              const SizedBox(width: 12),
              Expanded(child: _SourceTile(
                icon: Icons.photo_library_rounded,
                label: 'Depuis la\ngalerie'.tr,
                color: AppTheme.secondary,
                onTap: () { Navigator.pop(context); onGallery(); },
              )),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SourceTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2))),
        child: Column(children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 8),
          Text(label,
              textAlign: TextAlign.center,
              style: AppFonts.label(color: color, size: 12)
                  .copyWith(fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}



// ── Formulaire insuline ───────────────────────────────────────────────────────
class _InsulinForm extends StatelessWidget {
  final TextEditingController ctrl, noteCtrl;
  final String insulinType;
  final ValueChanged<String> onTypeChanged;
  const _InsulinForm({required this.ctrl, required this.noteCtrl,
    required this.insulinType, required this.onTypeChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
          style: AppFonts.bold(size: 18),
          decoration: InputDecoration(
              labelText: 'Dose d\'insuline'.tr, suffixText: 'UI'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: insulinType,
          decoration: InputDecoration(labelText: 'Type d\'insuline'.tr),
          items: [
            DropdownMenuItem(value: 'rapid', child: Text('Rapide (bolus)'.tr)),
            DropdownMenuItem(value: 'slow',  child: Text('Lente (basal)'.tr)),
            DropdownMenuItem(value: 'mixed', child: Text('Mixte'.tr)),
          ],
          onChanged: (v) { if (v != null) onTypeChanged(v); },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: noteCtrl,
          decoration: InputDecoration(
              labelText: 'Note (optionnel)'.tr,
              prefixIcon: Icon(Icons.notes_rounded, size: 18)),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withOpacity(0.15))),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded,
                color: AppTheme.primary, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'La dose est enregistrée telle quelle en unités internationales (UI).'.tr,
              style: AppFonts.label(color: AppTheme.primary, size: 11),
            )),
          ]),
        ),
      ]),
    );
  }
}