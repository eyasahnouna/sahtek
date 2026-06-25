import 'package:flutter/material.dart' show Color, TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/reminder.dart';
import '../models/alert_rule.dart';
import '../models/meal_entry.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _reminderChannelId  = 'diabcare_reminders';
  static const _alertChannelId     = 'diabcare_alerts';
  static const _hydrationChannelId = 'diabcare_hydration';

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
        const InitializationSettings(android: android, iOS: iOS));
    final ap = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await ap?.requestNotificationsPermission();
  }

  // ── Rappel depuis un objet Reminder (nouveau système) ──────────────────────
  Future<void> scheduleReminder(dynamic reminder) async {
    // Supporte Reminder (nouveau) et MealEntry (ancien app_provider)
    if (reminder is Reminder) {
      return _scheduleReminderObj(reminder);
    } else if (reminder is MealEntry) {
      return scheduleMealEntryReminder(reminder);
    }
  }

  Future<void> _scheduleReminderObj(Reminder reminder) async {
    if (!reminder.isEnabled) return;
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day,
        reminder.time.hour, reminder.time.minute);
    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      reminder.id.hashCode & 0x7FFFFFFF,
      'DiabCare — ${reminder.displayLabel}',
      _reminderBody(reminder),
      tz.TZDateTime.from(scheduled, tz.local),
      NotificationDetails(
        android: const AndroidNotificationDetails(
          _reminderChannelId, 'Rappels DiabCare',
          importance: Importance.high, priority: Priority.high,
          color: Color(0xFF0B8FAC),
        ),
        iOS: const DarwinNotificationDetails(
            presentAlert: true, presentBadge: true, presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ── Rappel depuis un MealEntry (app_provider existant) ─────────────────────
  Future<void> scheduleMealEntryReminder(MealEntry entry) async {
    if (entry.doseTime == null) return;
    await _scheduleAtTime(
      id:      entry.id.hashCode & 0x7FFFFFFF,
      title:   'Sahtek — ${entry.name}',
      body:    'Rappel : dose prévue pour ${entry.name}',
      time:    entry.doseTime!,
    );
  }

  /// Alias conservé pour compatibilité descendante
  Future<void> scheduleDoseReminder(MealEntry entry) =>
      scheduleMealEntryReminder(entry);

  Future<void> _scheduleAtTime({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
  }) async {
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, time.hour, time.minute)
        .subtract(const Duration(minutes: 5));
    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduled, tz.local),
      NotificationDetails(
        android: const AndroidNotificationDetails(
          _reminderChannelId, 'Rappels DiabCare',
          importance: Importance.high, priority: Priority.high,
          color: Color(0xFF0B8FAC),
        ),
        iOS: const DarwinNotificationDetails(
            presentAlert: true, presentBadge: true, presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  String _reminderBody(Reminder r) {
    switch (r.type) {
      case ReminderType.fastingGlucose: return 'Mesurez votre glycémie à jeun';
      case ReminderType.afterBreakfast: return 'Glycémie 2h après le petit déjeuner';
      case ReminderType.beforeLunch:    return 'Glycémie avant le déjeuner';
      case ReminderType.beforeDinner:   return 'Glycémie avant le dîner';
      case ReminderType.insulin:        return 'Heure de votre dose d\'insuline';
      case ReminderType.custom:         return r.customLabel ?? 'Rappel';
    }
  }

  Future<void> cancelReminder(String id) async =>
      _plugin.cancel(id.hashCode & 0x7FFFFFFF);

   Future<void> triggerGlucoseAlert({
    required AlertRule rule,
    required double glucoseValue,
  }) async {
    await _plugin.show(
      rule.id.hashCode & 0x7FFFFFFF,
      glucoseValue < 0.7 ? 'Hypoglycémie !' : 'Hyperglycémie !',
      rule.customMessage ?? 'Glycémie: ${glucoseValue.toStringAsFixed(2)} Mg/dl',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _alertChannelId, 'Alertes glycémie',
          importance: Importance.max, priority: Priority.max,
          color: Color(0xFFE53935), enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
            presentAlert: true, presentBadge: true, presentSound: true),
      ),
    );
    if (rule.action == AlertAction.hydration && rule.repeatMinutes > 0) {
      for (var i = 1; i <= 3; i++) {
        await _scheduleHydration(rule, i * rule.repeatMinutes);
      }
    }
  }

  Future<void> _scheduleHydration(AlertRule rule, int delayMin) async {
    final when = tz.TZDateTime.now(tz.local).add(Duration(minutes: delayMin));
    await _plugin.zonedSchedule(
      (rule.id + delayMin.toString()).hashCode & 0x7FFFFFFF,
      'Rappel hydratation',
      'Buvez un verre d\'eau pour abaisser votre glycémie',
      when,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _hydrationChannelId, 'Rappels hydratation',
          importance: Importance.high, priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}