import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

enum ReminderType {
  fastingGlucose,   // Glycémie à jeun (défaut 07:30)
  afterBreakfast,   // 2h après petit déjeuner (défaut 09:30)
  beforeLunch,      // Avant déjeuner (défaut 12:00)
  beforeDinner,     // Avant dîner (défaut 19:00)
  insulin,          // Dose d'insuline (défaut 07:00)
  custom,           // Personnalisé
}

extension ReminderTypeX on ReminderType {
  String get label {
    switch (this) {
      case ReminderType.fastingGlucose: return 'Glycémie à jeun';
      case ReminderType.afterBreakfast: return '2h après petit déjeuner';
      case ReminderType.beforeLunch:    return 'Avant déjeuner';
      case ReminderType.beforeDinner:   return 'Avant dîner';
      case ReminderType.insulin:        return 'Dose d\'insuline';
      case ReminderType.custom:         return 'Personnalisé';
    }
  }

  String get defaultTime {
    switch (this) {
      case ReminderType.fastingGlucose: return '07:30';
      case ReminderType.afterBreakfast: return '09:30';
      case ReminderType.beforeLunch:    return '12:00';
      case ReminderType.beforeDinner:   return '19:00';
      case ReminderType.insulin:        return '07:00';
      case ReminderType.custom:         return '08:00';
    }
  }

  IconData get icon {
    switch (this) {
      case ReminderType.fastingGlucose: return Icons.water_drop_rounded;
      case ReminderType.afterBreakfast: return Icons.free_breakfast_rounded;
      case ReminderType.beforeLunch:    return Icons.lunch_dining_rounded;
      case ReminderType.beforeDinner:   return Icons.dinner_dining_rounded;
      case ReminderType.insulin:        return Icons.medication_liquid_rounded;
      case ReminderType.custom:         return Icons.alarm_rounded;
    }
  }
}

class Reminder {
  final String id;
  final ReminderType type;
  final TimeOfDay time;
  final String? customLabel;
  final bool isEnabled;

  Reminder({
    String? id,
    required this.type,
    required this.time,
    this.customLabel,
    this.isEnabled = true,
  }) : id = id ?? const Uuid().v4();

  String get displayLabel => customLabel ?? type.label;

  String get timeString =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Reminder copyWith({
    ReminderType? type, TimeOfDay? time,
    String? customLabel, bool? isEnabled,
  }) => Reminder(
    id: id,
    type:        type        ?? this.type,
    time:        time        ?? this.time,
    customLabel: customLabel ?? this.customLabel,
    isEnabled:   isEnabled   ?? this.isEnabled,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'type': type.name,
    'hour': time.hour, 'minute': time.minute,
    'customLabel': customLabel, 'isEnabled': isEnabled,
  };

  factory Reminder.fromJson(Map<String, dynamic> j) => Reminder(
    id: j['id'] as String,
    type: ReminderType.values.firstWhere((e) => e.name == j['type'],
        orElse: () => ReminderType.custom),
    time: TimeOfDay(hour: j['hour'] as int, minute: j['minute'] as int),
    customLabel: j['customLabel'] as String?,
    isEnabled: j['isEnabled'] as bool? ?? true,
  );
}