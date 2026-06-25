import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder.dart';
import '../services/notification_service.dart';

class ReminderProvider extends ChangeNotifier {
  final List<Reminder> _reminders = [];
  bool _loaded = false;

  List<Reminder> get reminders => List.unmodifiable(_reminders);
  bool get loaded => _loaded;

  ReminderProvider() { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString('reminders_v2');
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _reminders.addAll(
          list.map((j) => Reminder.fromJson(j as Map<String, dynamic>)),
        );
      } catch (_) {}
    }
    // Créer les rappels par défaut si aucun
    if (_reminders.isEmpty) _seedDefaults();
    _loaded = true;
    notifyListeners();
  }

  void _seedDefaults() {
    for (final type in [
      ReminderType.fastingGlucose,
      ReminderType.afterBreakfast,
      ReminderType.beforeLunch,
      ReminderType.beforeDinner,
    ]) {
      final parts = type.defaultTime.split(':');
      _reminders.add(Reminder(
        type: type,
        time: TimeOfDay(
          hour:   int.parse(parts[0]),
          minute: int.parse(parts[1]),
        ),
      ));
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reminders_v2',
        jsonEncode(_reminders.map((r) => r.toJson()).toList()));
  }

  Future<void> addOrUpdate(Reminder reminder) async {
    final idx = _reminders.indexWhere((r) => r.id == reminder.id);
    if (idx == -1) {
      _reminders.add(reminder);
    } else {
      _reminders[idx] = reminder;
    }
    await _persist();
    if (reminder.isEnabled) {
      await NotificationService.instance.scheduleReminder(reminder);
    } else {
      await NotificationService.instance.cancelReminder(reminder.id);
    }
    notifyListeners();
  }

  Future<void> toggleEnabled(String id) async {
    final idx = _reminders.indexWhere((r) => r.id == id);
    if (idx == -1) return;
    await addOrUpdate(
        _reminders[idx].copyWith(isEnabled: !_reminders[idx].isEnabled));
  }

  Future<void> delete(String id) async {
    _reminders.removeWhere((r) => r.id == id);
    await NotificationService.instance.cancelReminder(id);
    await _persist();
    notifyListeners();
  }

  /// Replanifier tous les rappels actifs (appelé au démarrage)
  Future<void> rescheduleAll() async {
    for (final r in _reminders.where((r) => r.isEnabled)) {
      await NotificationService.instance.scheduleReminder(r);
    }
  }
}