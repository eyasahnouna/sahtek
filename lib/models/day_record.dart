import 'package:flutter/material.dart';
import 'meal_entry.dart';

class DayRecord {
  final String dateKey;
  List<MealEntry> entries;

  DayRecord({
    required this.dateKey,
    List<MealEntry>? entries,
  }) : entries = entries ?? [];

  Map<String, dynamic> toJson() => {
    'dateKey': dateKey,
    'entries': entries.map((e) => e.toJson()).toList(),
  };

  factory DayRecord.fromJson(Map<String, dynamic> j) => DayRecord(
    dateKey: j['dateKey'],
    entries: (j['entries'] as List<dynamic>?)
        ?.map((e) => MealEntry.fromJson(e))
        .toList() ??
        [],
  );

  double get totalDose =>
      entries.fold(0, (sum, e) => sum + (e.dose ?? 0));

  double get averageGlycemieAffichee {
    final values = entries
        .where((e) => e.hasGlycemie)
        .map((e) => e.glycemieAffichee ?? 0)
        .toList();

    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }
}