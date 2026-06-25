import 'package:uuid/uuid.dart';
class GlucoseReading {
  final String id;
  final double value;
  final bool   isConverted;
  final DateTime timestamp;
  final String? note;
  final String? mealContext;
  GlucoseReading({
    String? id,
    required this.value,
    this.isConverted = false,
    required this.timestamp,
    this.note,
    this.mealContext,
  }) : id = id ?? const Uuid().v4();

  double get displayValue =>
      isConverted ? double.parse((value * 0.18).toStringAsFixed(2)) : value;
  Map<String, dynamic> toJson() => {
    'id': id, 'value': value, 'isConverted': isConverted,
    'timestamp': timestamp.toIso8601String(),
    'note': note, 'mealContext': mealContext,
  };
  factory GlucoseReading.fromJson(Map<String, dynamic> j) => GlucoseReading(
    id: j['id'] as String,
    value: (j['value'] as num).toDouble(),
    isConverted: j['isConverted'] as bool? ?? false,
    timestamp: DateTime.parse(j['timestamp'] as String),
    note: j['note'] as String?,
    mealContext: j['mealContext'] as String?,
  );
  GlucoseReading copyWith({
    double? value, bool? isConverted, DateTime? timestamp,
    String? note, String? mealContext,
  }) => GlucoseReading(
    id: id,
    value:       value       ?? this.value,
    isConverted: isConverted ?? this.isConverted,
    timestamp:   timestamp   ?? this.timestamp,
    note:        note        ?? this.note,
    mealContext: mealContext  ?? this.mealContext,
  );
}