import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firebase_service.dart';
import '../utils/app_theme.dart';

const _insulins = [
  'Novorapid (Asparte)',
  'Humalog (Lispro)',
  'Apidra (Glulisine)',
  'Lantus (Glargine)',
  'Levemir (Détémir)',
  'Toujeo (Glargine U-300)',
  'Tresiba (Dégludec)',
  'NovoMix 30',
  'Mixtard',
  'Humulin R',
];

const _pills = [
  'Metformine',
  'Glucophage',
  'Januvia (Sitagliptine)',
  'Galvus (Vildagliptine)',
  'Jardiance (Empagliflozine)',
  'Forxiga (Dapagliflozine)',
  'Victoza (Liraglutide)',
  'Ozempic (Sémaglutide)',
  'Diamicron (Gliclazide)',
  'Amaryl (Glimépiride)',
];

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _pageCtrl = PageController();
  int _step = 0;

  // Étape 1 — infos personnelles
  final _ageCtrl    = TextEditingController();
  final _poidsCtrl  = TextEditingController();
  String _sexe = 'homme';
  String? _errInfos;

  // Étape 2 — type de diabète
  int? _typeDb;

  // Étape 3 — médicaments
  final Set<String> _medicamentsChoisis = {};
  final List<String> _medicamentsCustom  = [];
  bool _saving = false;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _ageCtrl.dispose();
    _poidsCtrl.dispose();
    super.dispose();
  }

  void _allerPage(int page) {
    setState(() => _step = page);
    _pageCtrl.animateToPage(page,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  bool _validerInfos() {
    final age   = int.tryParse(_ageCtrl.text);
    final poids = double.tryParse(_poidsCtrl.text.replaceAll(',', '.'));
    if (age == null || age < 1 || age > 120) {
      setState(() => _errInfos = 'Âge invalide (1–120)'); return false;
    }
    if (poids == null || poids < 20 || poids > 300) {
      setState(() => _errInfos = 'Poids invalide (20–300 kg)'); return false;
    }
    setState(() => _errInfos = null);
    return true;
  }

  Future<void> _terminer() async {
    setState(() => _saving = true);
    try {
      final age   = int.parse(_ageCtrl.text);
      final poids = double.parse(_poidsCtrl.text.replaceAll(',', '.'));

      // Sauvegarder le profil
      await FirebaseService.instance.savePatientProfile(
        age: age, weight: poids, sex: _sexe, diabetesType: _typeDb!,
      );

      // Sauvegarder les médicaments sélectionnés
      final type = _typeDb == 1 ? 'insulin' : 'pill';
      final tous = [..._medicamentsChoisis, ..._medicamentsCustom];
      for (final med in tous) {
        await FirebaseService.instance.addMedication(name: med, medicationType: type);
      }
      // _AuthGate basculera automatiquement vers _RootNav
    } catch (e) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: Column(children: [
          // ── En-tête + indicateur ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 40, height: 40,
                  decoration: BoxDecoration(
                      color: AppTheme.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.favorite_rounded,
                      color: Colors.white, size: 20)),
                const SizedBox(width: 10),
                Text('Configuration du profil',
                    style: AppFonts.bold(color: AppTheme.primary, size: 18)),
              ]),
              const SizedBox(height: 16),
              // Indicateur d'étapes
              Row(children: List.generate(3, (i) {
                final active = i == _step;
                final done   = i < _step;
                return Expanded(child: Row(children: [
                  Expanded(child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 4,
                    decoration: BoxDecoration(
                      color: (active || done) ? AppTheme.primary : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )),
                  if (i < 2) const SizedBox(width: 6),
                ]));
              })),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                _StepLabel('Infos', 0, _step),
                _StepLabel('Diabète', 1, _step),
                _StepLabel('Traitements', 2, _step),
              ]),
            ]),
          ),

          // ── Pages ─────────────────────────────────────────────────────────
          Expanded(child: PageView(
            controller: _pageCtrl,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _PageInfos(
                ageCtrl: _ageCtrl, poidsCtrl: _poidsCtrl,
                sexe: _sexe, erreur: _errInfos,
                onSexe: (s) => setState(() => _sexe = s),
                onSuivant: () {
                  if (_validerInfos()) _allerPage(1);
                },
              ),
              _PageTypeDb(
                selected: _typeDb,
                onSelected: (t) { setState(() => _typeDb = t); _allerPage(2); },
                onRetour: () => _allerPage(0),
              ),
              _PageMedicaments(
                typeDb: _typeDb ?? 1,
                choisis: _medicamentsChoisis,
                custom: _medicamentsCustom,
                saving: _saving,
                onToggle: (m) => setState(() {
                  if (_medicamentsChoisis.contains(m)) _medicamentsChoisis.remove(m);
                  else _medicamentsChoisis.add(m);
                }),
                onAddCustom: (m) => setState(() => _medicamentsCustom.add(m)),
                onRemoveCustom: (m) => setState(() => _medicamentsCustom.remove(m)),
                onRetour: () => _allerPage(1),
                onTerminer: _terminer,
              ),
            ],
          )),
        ]),
      ),
    );
  }
}

// ── Widget indicateur d'étape ─────────────────────────────────────────────────
class _StepLabel extends StatelessWidget {
  final String label;
  final int index, current;
  const _StepLabel(this.label, this.index, this.current);

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    final done   = index < current;
    return Text(label, style: AppFonts.label(
        color: (active || done) ? AppTheme.primary : Colors.grey.shade400,
        size: 11).copyWith(fontWeight: active ? FontWeight.w700 : FontWeight.normal));
  }
}

// ── Page 1 — Infos personnelles ───────────────────────────────────────────────
class _PageInfos extends StatelessWidget {
  final TextEditingController ageCtrl, poidsCtrl;
  final String sexe;
  final String? erreur;
  final ValueChanged<String> onSexe;
  final VoidCallback onSuivant;

  const _PageInfos({
    required this.ageCtrl, required this.poidsCtrl,
    required this.sexe, required this.erreur,
    required this.onSexe, required this.onSuivant,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Vos informations personnelles',
            style: AppFonts.title(size: 16)),
        const SizedBox(height: 6),
        Text('Ces données aident à personnaliser votre suivi.',
            style: AppFonts.body(color: Colors.grey, size: 13)),
        const SizedBox(height: 24),

        // Âge
        TextField(
          controller: ageCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Âge (années)',
            prefixIcon: Icon(Icons.cake_rounded, size: 18),
          ),
        ),
        const SizedBox(height: 14),

        // Poids
        TextField(
          controller: poidsCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d,.]'))],
          decoration: const InputDecoration(
            labelText: 'Poids (kg)',
            prefixIcon: Icon(Icons.monitor_weight_rounded, size: 18),
          ),
        ),
        const SizedBox(height: 20),

        // Sexe
        Text('Sexe', style: AppFonts.label(color: Colors.grey.shade600, size: 12)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8)]),
          child: Row(children: [
            for (final opt in [
              ('homme', Icons.male_rounded, 'Homme'),
              ('femme', Icons.female_rounded, 'Femme'),
              ('autre', Icons.transgender_rounded, 'Autre'),
            ]) Expanded(child: _SexeOption(
              value: opt.$1, icon: opt.$2, label: opt.$3,
              selected: sexe == opt.$1, onTap: () => onSexe(opt.$1),
            )),
          ]),
        ),

        if (erreur != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3))),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppTheme.danger, size: 16),
              const SizedBox(width: 8),
              Text(erreur!, style: AppFonts.body(color: AppTheme.danger, size: 12)),
            ]),
          ),
        ],

        const SizedBox(height: 32),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: onSuivant,
          style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16)),
          child: const Text('Suivant'),
        )),
      ]),
    );
  }
}

class _SexeOption extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _SexeOption({required this.value, required this.icon,
    required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Icon(icon, size: 20,
            color: selected ? Colors.white : Colors.grey.shade400),
        const SizedBox(height: 4),
        Text(label, style: AppFonts.label(
            color: selected ? Colors.white : Colors.grey.shade500,
            size: 11).copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal)),
      ]),
    ),
  );
}

// ── Page 2 — Type de diabète ──────────────────────────────────────────────────
class _PageTypeDb extends StatelessWidget {
  final int? selected;
  final ValueChanged<int> onSelected;
  final VoidCallback onRetour;
  const _PageTypeDb({required this.selected, required this.onSelected,
    required this.onRetour});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Votre type de diabète',
            style: AppFonts.title(size: 16)),
        const SizedBox(height: 6),
        Text('Cela détermine la liste de traitements disponibles.',
            style: AppFonts.body(color: Colors.grey, size: 13)),
        const SizedBox(height: 32),

        _TypeCard(
          type: 1, selected: selected == 1,
          title: 'Diabète de type 1',
          subtitle: 'Insulinodépendant — traitement par injections d\'insuline',
          icon: Icons.medication_liquid_rounded,
          color: AppTheme.primary,
          onTap: () => onSelected(1),
        ),
        const SizedBox(height: 16),
        _TypeCard(
          type: 2, selected: selected == 2,
          title: 'Diabète de type 2',
          subtitle: 'Non-insulinodépendant — traitement par comprimés / injections',
          icon: Icons.medication_rounded,
          color: AppTheme.secondary,
          onTap: () => onSelected(2),
        ),

        const Spacer(),
        TextButton.icon(
          onPressed: onRetour,
          icon: const Icon(Icons.arrow_back_rounded, size: 16),
          label: const Text('Retour'),
        ),
      ]),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final int type;
  final bool selected;
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _TypeCard({required this.type, required this.selected,
    required this.title, required this.subtitle, required this.icon,
    required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : Colors.grey.shade200, width: 2),
          boxShadow: [BoxShadow(
              color: selected ? color.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.04),
              blurRadius: 12, offset: const Offset(0, 4))]),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 26)),
        const SizedBox(width: 16),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Type $type', style: AppFonts.label(color: color, size: 11)
              .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(title, style: AppFonts.title(size: 14)),
          const SizedBox(height: 4),
          Text(subtitle, style: AppFonts.body(color: Colors.grey, size: 12)),
        ])),
        if (selected) Icon(Icons.check_circle_rounded, color: color, size: 22),
      ]),
    ),
  );
}

// ── Page 3 — Médicaments ──────────────────────────────────────────────────────
class _PageMedicaments extends StatelessWidget {
  final int typeDb;
  final Set<String> choisis;
  final List<String> custom;
  final bool saving;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onAddCustom;
  final ValueChanged<String> onRemoveCustom;
  final VoidCallback onRetour, onTerminer;

  const _PageMedicaments({
    required this.typeDb, required this.choisis, required this.custom,
    required this.saving, required this.onToggle, required this.onAddCustom,
    required this.onRemoveCustom, required this.onRetour, required this.onTerminer,
  });

  List<String> get _liste => typeDb == 1 ? _insulins : _pills;
  String get _titre => typeDb == 1 ? 'Insulines' : 'Médicaments (comprimés)';
  String get _label => typeDb == 1 ? 'insuline' : 'médicament';

  Future<void> _ajouterCustom(BuildContext context) async {
    final ctrl = TextEditingController();
    final nom = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Ajouter une $_label', style: AppFonts.title(size: 15)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
              labelText: 'Nom de la $_label',
              prefixIcon: const Icon(Icons.add_rounded, size: 18)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                Navigator.pop(context, ctrl.text.trim());
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    if (nom != null && nom.isNotEmpty) onAddCustom(nom);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_titre, style: AppFonts.title(size: 16)),
          const SizedBox(height: 4),
          Text('Sélectionnez vos traitements actuels (optionnel).',
              style: AppFonts.body(color: Colors.grey, size: 13)),
        ]),
      ),
      const SizedBox(height: 12),
      Expanded(child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          // Liste prédéfinie
          ..._liste.map((med) => CheckboxListTile(
            title: Text(med, style: AppFonts.body(size: 13)),
            value: choisis.contains(med),
            activeColor: AppTheme.primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            onChanged: (_) => onToggle(med),
          )),

          // Médicaments personnalisés ajoutés
          if (custom.isNotEmpty) ...[
            const Divider(height: 24),
            Text('Ajoutés manuellement',
                style: AppFonts.label(color: Colors.grey, size: 11)),
            const SizedBox(height: 8),
            ...custom.map((m) => ListTile(
              title: Text(m, style: AppFonts.body(size: 13)),
              leading: const Icon(Icons.add_circle_rounded,
                  color: AppTheme.success, size: 20),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppTheme.danger, size: 20),
                onPressed: () => onRemoveCustom(m),
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            )),
          ],

          // Bouton ajouter
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _ajouterCustom(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text('Ajouter une autre $_label'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      )),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(children: [
          TextButton.icon(
            onPressed: onRetour,
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Retour'),
          ),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(
            onPressed: saving ? null : onTerminer,
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: saving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Terminer la configuration'),
          )),
        ]),
      ),
    ]);
  }
}
