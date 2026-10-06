import 'package:flutter/material.dart';
import '../models/meal_entry.dart';
import '../utils/app_theme.dart';
import '../l10n/l10n.dart';

// ── Indicateur couleur glycémie ───────────────────────────────────────────────

class GlycemieIndicator {
  final Color color;
  final String label;
  final IconData icon;

  const GlycemieIndicator({
    required this.color,
    required this.label,
    required this.icon,
  });

  static GlycemieIndicator of(double value) {
    if (value < 0.7) {
      return const GlycemieIndicator(
        color: Color(0xFFE53935),
        label: 'Hypoglycémie sévère',
        icon: Icons.arrow_downward_rounded,
      );
    } else if (value <= 1.6) {
      return const GlycemieIndicator(
        color: Color(0xFF16A34A),
        label: 'Valeur normale',
        icon: Icons.check_circle_rounded,
      );
    } else if (value <= 1.9) {
      return const GlycemieIndicator(
        color: Color(0xFFFF9A3C),
        label: 'Légèrement élevée',
        icon: Icons.warning_rounded,
      );
    } else {
      return const GlycemieIndicator(
        color: Color(0xFFE53935),
        label: 'Hyperglycémie',
        icon: Icons.arrow_upward_rounded,
      );
    }
  }
}

// ── GlycemieBadge ─────────────────────────────────────────────────────────────

class GlycemieBadge extends StatelessWidget {
  final double glycemieRaw;
  final double glycemieConv;
  final GlycemieMode mode;
  final Color color;

  const GlycemieBadge({
    super.key,
    required this.glycemieRaw,
    required this.glycemieConv,
    required this.mode,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bool converti = mode == GlycemieMode.convertie;
    final String note   = converti
        ? '${glycemieRaw.toStringAsFixed(1)} × 0.18'
        : 'Valeur directe'.tr;

    final indicator = GlycemieIndicator.of(glycemieConv);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: indicator.color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: indicator.color.withOpacity(0.3)),
      ),
      child: Row(children: [
        // Icône indicateur colorée
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
              color: indicator.color.withOpacity(0.15),
              shape: BoxShape.circle),
          child: Icon(indicator.icon, color: indicator.color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label indicateur
            Row(children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                    color: indicator.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(indicator.label.tr,
                  style: AppFonts.label(
                      color: indicator.color, size: 11)
                      .copyWith(fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 2),
            // Valeur + note
            Row(children: [
              RichText(text: TextSpan(children: [
                TextSpan(text: glycemieConv.toString(),
                    style: AppFonts.bold(
                        color: indicator.color, size: 18)),
                TextSpan(text: '  Mg/dl',
                    style: AppFonts.unit(
                        color: indicator.color.withOpacity(0.7))),
              ])),
              const SizedBox(width: 8),
              Text('($note)',
                  style: AppFonts.label(
                      color: Colors.grey.shade500, size: 10)),
            ]),
          ],
        )),
      ]),
    );
  }
}

// ── DoseBadge ─────────────────────────────────────────────────────────────────

class DoseBadge extends StatelessWidget {
  final double dose;
  final Color color;

  const DoseBadge({
    super.key,
    required this.dose,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
              color: color.withOpacity(0.13), shape: BoxShape.circle),
          child: Icon(Icons.medication_liquid_rounded,
              color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Dose d'insuline".tr,
                style: AppFonts.label(
                    color: color.withOpacity(0.75), size: 11)
                    .copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            RichText(text: TextSpan(children: [
              TextSpan(text: dose.toString(),
                  style: AppFonts.bold(color: color, size: 18)),
              TextSpan(text: '  UI',
                  style: AppFonts.unit(
                      color: color.withOpacity(0.7))),
            ])),
          ],
        )),
      ]),
    );
  }
}