import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alert_rule.dart';

class AlertProvider extends ChangeNotifier {
  final List<AlertRule> _rules = [];
  bool _loaded = false;

  List<AlertRule> get rules => List.unmodifiable(_rules);
  bool get loaded => _loaded;

  AlertProvider() { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString('alert_rules');
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _rules.addAll(
          list.map((j) => AlertRule.fromJson(j as Map<String, dynamic>)),
        );
      } catch (_) {}
    }
    if (_rules.isEmpty) _seedDefaults();
    _loaded = true;
    notifyListeners();
  }

  /// Règles par défaut pré-configurées
  void _seedDefaults() {
    _rules.addAll([
      AlertRule(
        name:          'Hypoglycémie sévère',
        condition:     AlertCondition.below,
        threshold1:    0.7,
        action:        AlertAction.notify,
        customMessage: 'Glycémie très basse ! Prenez du sucre immédiatement.',
      ),
      AlertRule(
        name:          'Hyperglycémie — boire de l\'eau',
        condition:     AlertCondition.above,
        threshold1:    1.9,
        action:        AlertAction.hydration,
        repeatMinutes: 30,
        customMessage: 'Glycémie élevée. Buvez de l\'eau toutes les 30 minutes.',
      ),
    ]);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('alert_rules',
        jsonEncode(_rules.map((r) => r.toJson()).toList()));
  }

  Future<void> addOrUpdate(AlertRule rule) async {
    final idx = _rules.indexWhere((r) => r.id == rule.id);
    if (idx == -1) {
      _rules.add(rule);
    } else {
      _rules[idx] = rule;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> toggle(String id) async {
    final idx = _rules.indexWhere((r) => r.id == id);
    if (idx == -1) return;
    _rules[idx] = _rules[idx].copyWith(isEnabled: !_rules[idx].isEnabled);
    await _persist();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _rules.removeWhere((r) => r.id == id);
    await _persist();
    notifyListeners();
  }
}