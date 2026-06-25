import 'package:uuid/uuid.dart';

enum AlertCondition { above, below, between }
enum AlertAction    { hydration, insulin, notify, call }

/// Règle d'alerte glycémique définie par l'utilisateur
class AlertRule {
  final String id;
  final String name;
  final AlertCondition condition;
  final double threshold1;
  final double? threshold2;     // utilisé si condition == between
  final AlertAction action;
  final String? customMessage;
  final int repeatMinutes;      // répéter toutes les N min (0 = une seule fois)
  final bool isEnabled;

  AlertRule({
    String? id,
    required this.name,
    required this.condition,
    required this.threshold1,
    this.threshold2,
    required this.action,
    this.customMessage,
    this.repeatMinutes = 0,
    this.isEnabled = true,
  }) : id = id ?? const Uuid().v4();

  String get conditionText {
    switch (condition) {
      case AlertCondition.above:   return '> ${threshold1.toStringAsFixed(1)} Mg/dl';
      case AlertCondition.below:   return '< ${threshold1.toStringAsFixed(1)} Mg/dl';
      case AlertCondition.between: return '${threshold1.toStringAsFixed(1)} – ${(threshold2 ?? 0).toStringAsFixed(1)} Mg/dl';
    }
  }

  String get actionText {
    switch (action) {
      case AlertAction.hydration: return 'Rappel hydratation';
      case AlertAction.insulin:   return 'Alerte insuline';
      case AlertAction.notify:    return 'Notification';
      case AlertAction.call:      return 'Appel d\'urgence';
    }
  }

  /// Vérifie si la valeur déclenche cette règle
  bool matches(double value) {
    switch (condition) {
      case AlertCondition.above:   return value > threshold1;
      case AlertCondition.below:   return value < threshold1;
      case AlertCondition.between:
        return value >= threshold1 && value <= (threshold2 ?? threshold1);
    }
  }

  AlertRule copyWith({
    String? name, AlertCondition? condition,
    double? threshold1, double? threshold2,
    AlertAction? action, String? customMessage,
    int? repeatMinutes, bool? isEnabled,
  }) => AlertRule(
    id: id,
    name:          name          ?? this.name,
    condition:     condition     ?? this.condition,
    threshold1:    threshold1    ?? this.threshold1,
    threshold2:    threshold2    ?? this.threshold2,
    action:        action        ?? this.action,
    customMessage: customMessage ?? this.customMessage,
    repeatMinutes: repeatMinutes ?? this.repeatMinutes,
    isEnabled:     isEnabled     ?? this.isEnabled,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'condition': condition.name,
    'threshold1': threshold1, 'threshold2': threshold2,
    'action': action.name, 'customMessage': customMessage,
    'repeatMinutes': repeatMinutes, 'isEnabled': isEnabled,
  };

  factory AlertRule.fromJson(Map<String, dynamic> j) => AlertRule(
    id:         j['id'] as String,
    name:       j['name'] as String,
    condition:  AlertCondition.values.firstWhere((e) => e.name == j['condition']),
    threshold1: (j['threshold1'] as num).toDouble(),
    threshold2: (j['threshold2'] as num?)?.toDouble(),
    action:     AlertAction.values.firstWhere((e) => e.name == j['action']),
    customMessage: j['customMessage'] as String?,
    repeatMinutes: j['repeatMinutes'] as int? ?? 0,
    isEnabled:  j['isEnabled'] as bool? ?? true,
  );
}