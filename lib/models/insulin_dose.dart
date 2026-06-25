import 'package:uuid/uuid.dart';

/// Représente une injection d'insuline
class InsulinDose {
  final String id;
  final double units;
  final String insulinType;
  final DateTime timestamp;
  final String? note;
  final String? mealContext;

  InsulinDose({
    String? id,
    required this.units,
    this.insulinType = 'rapid',
    required this.timestamp,
    this.note,
    this.mealContext,
  }) : id = id ?? const Uuid().v4();

  String get insulinTypeLabel {
    switch (insulinType) {
      case 'rapid': return 'Rapide (bolus)';
      case 'slow':  return 'Lente (basal)';
      case 'mixed': return 'Mixte';
      default:      return insulinType;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'units': units, 'insulinType': insulinType,
    'timestamp': timestamp.toIso8601String(),
    'note': note, 'mealContext': mealContext,
  };

  factory InsulinDose.fromJson(Map<String, dynamic> j) => InsulinDose(
    id: j['id'] as String,
    units: (j['units'] as num).toDouble(),
    insulinType: j['insulinType'] as String? ?? 'rapid',
    timestamp: DateTime.parse(j['timestamp'] as String),
    note: j['note'] as String?,
    mealContext: j['mealContext'] as String?,
  );
}