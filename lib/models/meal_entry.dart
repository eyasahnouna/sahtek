import 'package:flutter/material.dart';

enum GlycemieMode { directe, convertie }

enum MealType {
  breakfast,
  lunch,
  dinner,
  snack,
  mesure,
}

extension MealTypeExtension on MealType {
  String get label {
    switch (this) {
      case MealType.breakfast: return 'Petit déjeuner';
      case MealType.lunch:     return 'Déjeuner';
      case MealType.dinner:    return 'Dîner';
      case MealType.snack:     return 'Snack';
      case MealType.mesure:    return 'Mesure';
    }
  }

  IconData get icon {
    switch (this) {
      case MealType.breakfast: return Icons.free_breakfast_rounded;
      case MealType.lunch:     return Icons.lunch_dining_rounded;
      case MealType.dinner:    return Icons.dinner_dining_rounded;
      case MealType.snack:     return Icons.cookie_rounded;
      case MealType.mesure:    return Icons.sensors_rounded;
    }
  }

  bool get isDeletable => this == MealType.snack || this == MealType.mesure;
  bool get isSensorOnly => this == MealType.mesure;
}

class MealEntry {
  final String   id;
  final String   name;
  final MealType type;
  final String?  slotId;

  // Glycémie stockée en g/L (unité française standard)
  double? glycemie;
  GlycemieMode glycemieMode;

  double? dose;
  double? carbsG;       // glucides estimés en grammes (analyse photo)

  TimeOfDay? mealTime;
  TimeOfDay? doseTime;
  String?    observation;
  String?    imageUrl; // Added image URL

  MealEntry({
    String? id,
    required this.name,
    required this.type,
    this.slotId,
    this.glycemie,
    this.glycemieMode = GlycemieMode.directe,
    this.dose,
    this.carbsG,
    this.mealTime,
    this.doseTime,
    this.observation,
    this.imageUrl,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  // ── copyWith ──────────────────────────────────────────────────────────────
  // Les paramètres `clearX` permettent d'effacer une valeur nullable
  // (le pattern `??` standard ne peut pas distinguer null-voulu de non-fourni).
  MealEntry copyWith({
    String?      name,
    MealType?    type,
    double?      glycemie,
    bool         clearGlycemie = false,
    GlycemieMode? glycemieMode,
    double?      dose,
    bool         clearDose = false,
    double?      carbsG,
    bool         clearCarbsG = false,
    TimeOfDay?   mealTime,
    TimeOfDay?   doseTime,
    String?      observation,
    bool         clearObservation = false,
    String?      imageUrl,
    bool         clearImageUrl = false,
  }) {
    return MealEntry(
      id:           id,
      name:         name         ?? this.name,
      type:         type         ?? this.type,
      slotId:       slotId,
      glycemie:     clearGlycemie    ? null : (glycemie    ?? this.glycemie),
      glycemieMode: glycemieMode ?? this.glycemieMode,
      dose:         clearDose        ? null : (dose        ?? this.dose),
      carbsG:       clearCarbsG      ? null : (carbsG      ?? this.carbsG),
      mealTime:     mealTime     ?? this.mealTime,
      doseTime:     doseTime     ?? this.doseTime,
      observation:  clearObservation ? null : (observation ?? this.observation),
      imageUrl:     clearImageUrl    ? null : (imageUrl    ?? this.imageUrl),
    );
  }

  // ── Sérialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'id':           id,
    'name':         name,
    'type':         type.name,
    'slotId':       slotId,
    'glycemie':     glycemie,
    'glycemieMode': glycemieMode.name,
    'dose':         dose,
    'carbsG':       carbsG,
    'mealTime':     mealTime != null
        ? {'hour': mealTime!.hour, 'minute': mealTime!.minute}
        : null,
    'doseTime':     doseTime != null
        ? {'hour': doseTime!.hour, 'minute': doseTime!.minute}
        : null,
    'observation':  observation,
    'imageUrl':     imageUrl,
  };

  factory MealEntry.fromJson(Map<String, dynamic> json) {
    return MealEntry(
      id:   json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] ?? '',
      type: MealType.values.firstWhere(
            (e) => e.name == json['type'],
        orElse: () => MealType.mesure,
      ),
      slotId: json['slotId'],
      glycemie: (json['glycemie'] as num?)?.toDouble(),
      glycemieMode: GlycemieMode.values.firstWhere(
            (e) => e.name == json['glycemieMode'],
        orElse: () => GlycemieMode.directe,
      ),
      dose:   (json['dose']   as num?)?.toDouble(),
      carbsG: (json['carbsG'] as num?)?.toDouble(),
      mealTime: json['mealTime'] != null
          ? TimeOfDay(
        hour:   json['mealTime']['hour'],
        minute: json['mealTime']['minute'],
      )
          : null,
      doseTime: json['doseTime'] != null
          ? TimeOfDay(
        hour:   json['doseTime']['hour'],
        minute: json['doseTime']['minute'],
      )
          : null,
      observation: json['observation'],
      imageUrl: json['imageUrl'],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool get hasGlycemie => (glycemie ?? 0) > 0;
  bool get hasDose     => (dose     ?? 0) > 0;
  bool get hasCarbsG   => (carbsG   ?? 0) > 0;

  /// Valeur affichée :
  ///  • mode directe   → g/L  (valeur stockée telle quelle)
  ///  • mode convertie → mmol/L × 0.18 = g/L  (converti à la saisie)
  double? get glycemieAffichee =>
      glycemieMode == GlycemieMode.convertie && glycemie != null
          ? glycemie! * 0.18
          : glycemie;

  /// Unité d'affichage selon le mode de saisie
  String get glycemieUnit =>
      glycemieMode == GlycemieMode.convertie ? 'mmol/L' : 'g/L';
}
