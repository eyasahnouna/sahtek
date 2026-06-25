import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/meal_entry.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import 'dose_badge.dart';
import 'metric_input_field.dart';
import 'time_picker_tile.dart';

class MealZoneCard extends StatefulWidget {
  final MealEntry entry;
  final int index;
  const MealZoneCard({super.key, required this.entry, required this.index});
  @override
  State<MealZoneCard> createState() => _MealZoneCardState();
}

class _MealZoneCardState extends State<MealZoneCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _sizeAnim, _fadeAnim;
  bool _expanded = true;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 280), value: 1.0);
    _sizeAnim = CurvedAnimation(parent: _anim, curve: Curves.easeInOut);
    _fadeAnim = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _anim.forward() : _anim.reverse();
  }

  Color get _accent {
    switch (widget.entry.type) {
      case MealType.breakfast: return AppTheme.breakfastColor;
      case MealType.lunch:     return AppTheme.lunchColor;
      case MealType.dinner:    return AppTheme.dinnerColor;
      case MealType.snack:     return AppTheme.snackColor;
      case MealType.mesure:    return const Color(0xFF0B8FAC);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final entry    = widget.entry;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Material(
        elevation: 3,
        shadowColor: _accent.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _Header(
            entry: entry, accent: _accent, expanded: _expanded, onTap: _toggle,
            onDelete: entry.type.isDeletable
                ? () => provider.removeEntry(entry.id) : null,
          ),
          SizeTransition(
            sizeFactor: _sizeAnim,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: _Body(
                entry: entry, accent: _accent, index: widget.index,
                onUpdate: provider.updateEntry,
                onClear:    () => provider.clearEntryData(entry.id),
                onAddSnack: () => provider.addSnack(afterIndex: widget.index),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────
// ── Header ─────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final MealEntry entry;
  final Color accent;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _Header({
    required this.entry,
    required this.accent,
    required this.expanded,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(20),
            bottom: expanded ? Radius.zero : const Radius.circular(20),
          ),
        ),
        child: Row(children: [
          Icon(entry.type.icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.name,
              style: AppFonts.title(color: Colors.white, size: 15),
            ),
          ),
          // Chips résumé
          if (entry.hasGlycemie) ...[
            _HeaderChip(
              icon: Icons.bloodtype_rounded,
              value: '${entry.glycemieAffichee!.toStringAsFixed(1)} Mg/dl',
            ),
            const SizedBox(width: 6),
          ],
          if (entry.hasDose) ...[
            _HeaderChip(
              icon: Icons.medication_rounded,
              value: '${entry.dose!.toStringAsFixed(1)} UI',
            ),
            const SizedBox(width: 6),
          ],
          if (onDelete != null)
            GestureDetector(
              onTap: onDelete,
              child: const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.close_rounded, color: Colors.white70, size: 18),
              ),
            ),
          Icon(
            expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
            color: Colors.white,
          ),
        ]),
      ),
    );
  }
}
class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String value;
  const _HeaderChip({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.22),
          borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: Colors.white),
        const SizedBox(width: 4),
        Text(value, style: AppFonts.label(color: Colors.white, size: 11)),
      ]),
    );
  }
}

// ── Body ───────────────────────────────────────────────────────────────────────
class _Body extends StatelessWidget {
  final MealEntry entry;
  final Color accent;
  final int index;
  final ValueChanged<MealEntry> onUpdate;
  final VoidCallback onClear, onAddSnack;
  const _Body({required this.entry, required this.accent, required this.index,
    required this.onUpdate, required this.onClear, required this.onAddSnack});

  @override
  Widget build(BuildContext context) {
    // Affichage simplifié pour les mesures capteur
    if (entry.type.isSensorOnly) {
      return _SensorBody(
        entry: entry,
        accent: accent,
        onUpdate: onUpdate,
        onClear: onClear,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Horaires ────────────────────────────────────────────
        Row(children: [
          Expanded(child: TimePickerTile(
              label: 'Heure dose', time: entry.doseTime,
              icon: Icons.medication_rounded, color: accent,
              onChanged: (t) => onUpdate(entry.copyWith(doseTime: t)))),
          const SizedBox(width: 10),
          Expanded(child: TimePickerTile(
              label: 'Heure repas', time: entry.mealTime,
              icon: Icons.restaurant_rounded, color: accent,
              onChanged: (t) => onUpdate(entry.copyWith(mealTime: t)))),
        ]),

        const SizedBox(height: 14),

        // ── Mesure + Dose côte à côte ────────────────────────────
        // Toggle mode glycémie
        _GlycemieModeToggle(
          mode: entry.glycemieMode,
          accent: accent,
          onChanged: (m) => onUpdate(entry.copyWith(glycemieMode: m)),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: MetricInputField(
              key: ValueKey('glycemie_${entry.id}_${entry.glycemie}'),
              label: 'Mesure glycémie',
              unit:  'Mg/dl',
              value: entry.glycemie,
              icon: Icons.bloodtype_rounded, accentColor: accent,
              onChanged: (v) => onUpdate(entry.copyWith(glycemie: v)))),
          const SizedBox(width: 12),
          Expanded(child: MetricInputField(
              key: ValueKey('dose_${entry.id}_${entry.dose}'),
              label: 'Dose insuline', unit: 'UI',
              value: entry.dose,
              icon: Icons.medication_liquid_rounded, accentColor: accent,
              onChanged: (v) => onUpdate(entry.copyWith(dose: v)))),
        ]),

        // Badges résultats
        if (entry.hasGlycemie || entry.hasDose) ...[
          const SizedBox(height: 10),
          if (entry.hasGlycemie)
            GlycemieBadge(
              glycemieRaw:  entry.glycemie!,
              glycemieConv: entry.glycemieAffichee!,
              mode:         entry.glycemieMode,
              color: accent,
            ),
          if (entry.hasGlycemie && entry.hasDose)
            const SizedBox(height: 8),
          if (entry.hasDose)
            DoseBadge(dose: entry.dose!, color: accent),
        ],

        const SizedBox(height: 14),

        // ── Section observation ──────────────────────────────────
        _SectionLabel(label: 'Observation', color: accent),
        const SizedBox(height: 8),
        _ObservationField(
          key: ValueKey('obs_${entry.id}'),
          value: entry.observation,
          accent: accent,
          onChanged: (v) => onUpdate(entry.copyWith(observation: v)),
        ),

        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 8),

        // ── Actions ──────────────────────────────────────────────
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          _ActionBtn(icon: Icons.delete_sweep_rounded, label: 'Effacer',
              color: Colors.grey, onTap: onClear),
          const SizedBox(width: 6),
          _ActionBtn(icon: Icons.add_circle_outline_rounded,
              label: 'Ajouter Snack',
              color: AppTheme.snackColor, onTap: onAddSnack),
        ]),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 3, height: 14,
          decoration: BoxDecoration(color: color,
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(label, style: AppFonts.label(color: color, size: 12)
          .copyWith(fontWeight: FontWeight.w600)),
    ]);
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label,
    required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 15, color: color),
    label: Text(label, style: AppFonts.label(color: color, size: 12)),
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );
}

// ── Observation field ─────────────────────────────────────────────────────────
class _ObservationField extends StatefulWidget {
  final String? value;
  final Color accent;
  final ValueChanged<String?> onChanged;

  const _ObservationField({
    super.key,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  @override
  State<_ObservationField> createState() => _ObservationFieldState();
}

class _ObservationFieldState extends State<_ObservationField> {
  late final TextEditingController _ctrl;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value ?? '');
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        final v = _ctrl.text.trim();
        widget.onChanged(v.isEmpty ? null : v);
      }
    });
  }

  @override
  void didUpdateWidget(_ObservationField old) {
    super.didUpdateWidget(old);
    if (!_focusNode.hasFocus) {
      final newText = widget.value ?? '';
      if (_ctrl.text != newText) _ctrl.text = newText;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller:  _ctrl,
      focusNode:   _focusNode,
      maxLines:    3,
      minLines:    2,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      style: AppFonts.body(size: 13),
      decoration: InputDecoration(
        hintText: 'Ex : hypoglycémie légère, repas copieux, sport…',
        hintStyle: AppFonts.body(color: Colors.grey.shade400, size: 12),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 8, top: 10),
          child: Icon(Icons.notes_rounded,
              color: widget.accent.withOpacity(0.6), size: 18),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: widget.accent, width: 2),
        ),
        alignLabelWithHint: true,
      ),
    );
  }
}
// ── Glycémie mode toggle ──────────────────────────────────────────────────────
class _GlycemieModeToggle extends StatelessWidget {
  final GlycemieMode mode;
  final Color accent;
  final ValueChanged<GlycemieMode> onChanged;

  const _GlycemieModeToggle({
    required this.mode,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.18)),
      ),
      child: Row(children: GlycemieMode.values.map((m) {
        final selected = m == mode;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: selected ? accent : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      m == GlycemieMode.directe
                          ? 'Valeur directe'
                          : 'Convertie (×0.18)',
                      style: AppFonts.label(
                        color: selected ? Colors.white : accent.withOpacity(0.7),
                        size: 11,
                      ).copyWith(
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList()),
    );
  }
}

// ── Corps simplifié pour mesure capteur ───────────────────────────────────────
class _SensorBody extends StatelessWidget {
  final MealEntry entry;
  final Color accent;
  final ValueChanged<MealEntry> onUpdate;
  final VoidCallback onClear;

  const _SensorBody({
    required this.entry,
    required this.accent,
    required this.onUpdate,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Toggle mode
        _GlycemieModeToggle(
          mode: entry.glycemieMode,
          accent: accent,
          onChanged: (m) => onUpdate(entry.copyWith(glycemieMode: m)),
        ),
        const SizedBox(height: 12),

        // Champ glycémie uniquement
        MetricInputField(
          key: ValueKey('glycemie_${entry.id}_${entry.glycemie}'),
          label: 'Glycémie mesurée',
          unit: 'Mg/dl',
          value: entry.glycemie,
          icon: Icons.sensors_rounded,
          accentColor: accent,
          onChanged: (v) => onUpdate(entry.copyWith(glycemie: v)),
        ),

        // Badge résultat avec indicateur
        if (entry.hasGlycemie) ...[
          const SizedBox(height: 10),
          GlycemieBadge(
            glycemieRaw:  entry.glycemie!,
            glycemieConv: entry.glycemieAffichee!,
            mode:         entry.glycemieMode,
            color:        accent,
          ),
        ],

        const SizedBox(height: 12),

        // Observation
        _SectionLabel(label: 'Note', color: accent),
        const SizedBox(height: 6),
        _ObservationField(
          key: ValueKey('obs_${entry.id}'),
          value: entry.observation,
          accent: accent,
          onChanged: (v) => onUpdate(entry.copyWith(observation: v)),
        ),

        const SizedBox(height: 10),
        const Divider(height: 1),
        const SizedBox(height: 6),

        // Action effacer
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onClear,
            icon: Icon(Icons.delete_sweep_rounded,
                size: 15, color: Colors.grey.shade400),
            label: Text('Effacer',
                style: AppFonts.label(
                    color: Colors.grey.shade400, size: 12)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ]),
    );
  }
}