import 'package:flutter/material.dart' show Color, TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/reminder.dart';
import '../models/meal_entry.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _reminderChannelId   = 'sahtek_reminders';
  static const _glucoseChannelId    = 'sahtek_glucose';

  // Logo Sahtek : silhouette blanche (barre d'état) + logo couleur (alerte)
  static const _smallIcon = 'ic_stat_sahtek';
  static const _largeIcon = DrawableResourceAndroidBitmap('ic_notif_large');

  // IDs fixes pour éviter les doublons
  static const _idPostInsulin    = 3001;
  static const _idHypoRecheck   = 3002;
  static const _idHyperWater1   = 3003;
  static const _idHyperWater2   = 3004;
  static const _idHyperWater3   = 3005;

  Future<void> init() async {
    const android = AndroidInitializationSettings('@drawable/ic_stat_sahtek');
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
    await ap?.requestExactAlarmsPermission();
  }

  // ── Rappel depuis un objet Reminder (quotidien) ────────────────────────────
  Future<void> scheduleReminder(dynamic reminder) async {
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
      'Sahtek — ${reminder.displayLabel}',
      _reminderBody(reminder),
      tz.TZDateTime.from(scheduled, tz.local),
      NotificationDetails(
        android: const AndroidNotificationDetails(
          _reminderChannelId, 'Rappels Sahtek',
          icon: _smallIcon,
          largeIcon: _largeIcon,
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

  // ── Rappel depuis un MealEntry ─────────────────────────────────────────────
  Future<void> scheduleMealEntryReminder(MealEntry entry) async {
    if (entry.doseTime == null) return;
    await _scheduleAtTime(
      id:    entry.id.hashCode & 0x7FFFFFFF,
      title: 'Sahtek — ${entry.name}',
      body:  'Rappel : dose prévue pour ${entry.name}',
      time:  entry.doseTime!,
    );
  }

  Future<void> scheduleDoseReminder(MealEntry entry) =>
      scheduleMealEntryReminder(entry);

  // ── Mesure glycémie 2h après repas ────────────────────────────────────────
  Future<void> schedulePostMealMeasure({
    required String    slotId,
    required TimeOfDay mealTime,
    required String    mealName,
  }) async {
    final now   = DateTime.now();
    final total = mealTime.hour * 60 + mealTime.minute + 120;
    final h     = (total ~/ 60) % 24;
    final m     = total % 60;
    final scheduled = DateTime(now.year, now.month, now.day, h, m);
    if (scheduled.isBefore(now)) return;

    final id = _postMealId(slotId);
    await _plugin.cancel(id);
    await _plugin.zonedSchedule(
      id,
      'Sahtek — Mesure glycémie',
      'Mesurez votre glycémie 2h après $mealName',
      tz.TZDateTime.from(scheduled, tz.local),
      NotificationDetails(
        android: const AndroidNotificationDetails(
          _reminderChannelId, 'Rappels Sahtek',
          icon: _smallIcon,
          largeIcon: _largeIcon,
importance: Importance.high, priority: Priority.high,
          color: Color(0xFF0B8FAC),
        ),
        iOS: const DarwinNotificationDetails(
            presentAlert: true, presentBadge: true, presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelPostMealMeasure(String slotId) =>
      _plugin.cancel(_postMealId(slotId));

  int _postMealId(String slotId) =>
      ('post2h_$slotId').hashCode & 0x7FFFFFFF;

  // ── Post-insuline : mesurer la glycémie 2h après la dose ─────────────────
  Future<void> schedulePostInsulinMeasure(DateTime insulinTime) async {
    final checkAt = insulinTime.add(const Duration(hours: 2));
    if (checkAt.isBefore(DateTime.now())) return;

    await _plugin.cancel(_idPostInsulin);
    await _plugin.zonedSchedule(
      _idPostInsulin,
      'Sahtek — Mesure glycémie',
      'Mesurez votre glycémie — 2h après votre dose d\'insuline',
      tz.TZDateTime.from(checkAt, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _glucoseChannelId, 'Suivi glycémique',
          icon: _smallIcon,
          largeIcon: _largeIcon,
importance: Importance.high,
          priority:   Priority.high,
          color:      Color(0xFF0B8FAC),
        ),
        iOS: DarwinNotificationDetails(
            presentAlert: true, presentBadge: true, presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ── Hypoglycémie : refaire la mesure dans 15 min ──────────────────────────
  Future<void> scheduleHypoglycemiaRecheck() async {
    final recheckAt = DateTime.now().add(const Duration(minutes: 15));
    await _plugin.cancel(_idHypoRecheck);
    await _plugin.zonedSchedule(
      _idHypoRecheck,
      'Sahtek ⚠️ Hypoglycémie',
      'Refaites votre mesure — 15 min après votre hypoglycémie',
      tz.TZDateTime.from(recheckAt, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _glucoseChannelId, 'Suivi glycémique',
          icon: _smallIcon,
          largeIcon: _largeIcon,
importance: Importance.max,
          priority:   Priority.max,
          color:      Color(0xFFE53935),
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
            presentAlert: true, presentBadge: true, presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ── Hyperglycémie : rappels d'hydratation toutes les 30 min (×3) ──────────
  Future<void> scheduleHyperglycemiaWaterReminders() async {
    // Annuler les éventuels rappels précédents
    await cancelHyperglycemiaReminders();

    final now = DateTime.now();
    final ids     = [_idHyperWater1, _idHyperWater2, _idHyperWater3];
    final delays  = [30, 60, 90];      // minutes après la mesure
    final bodies  = [
      'Buvez un verre d\'eau — votre glycémie est élevée',
      'Rappel hydratation — buvez encore un verre d\'eau',
      'Dernier rappel — pensez à bien vous hydrater',
    ];

    for (var i = 0; i < 3; i++) {
      final fireAt = now.add(Duration(minutes: delays[i]));
      await _plugin.zonedSchedule(
        ids[i],
        'Sahtek 💧 Hydratation',
        bodies[i],
        tz.TZDateTime.from(fireAt, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _glucoseChannelId, 'Suivi glycémique',
            icon: _smallIcon,
            largeIcon: _largeIcon,
importance: Importance.high,
            priority:   Priority.high,
            color:      Color(0xFFFF9A3C),
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(
              presentAlert: true, presentBadge: true, presentSound: true),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelHyperglycemiaReminders() async {
    await _plugin.cancel(_idHyperWater1);
    await _plugin.cancel(_idHyperWater2);
    await _plugin.cancel(_idHyperWater3);
  }

  Future<void> cancelHypoglycemiaRecheck() =>
      _plugin.cancel(_idHypoRecheck);

  // ── Helpers internes ───────────────────────────────────────────────────────
  Future<void> _scheduleAtTime({
    required int       id,
    required String    title,
    required String    body,
    required TimeOfDay time,
  }) async {
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, time.hour, time.minute)
        .subtract(const Duration(minutes: 5));
    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      id, title, body,
      tz.TZDateTime.from(scheduled, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _reminderChannelId, 'Rappels Sahtek',
          icon: _smallIcon,
          largeIcon: _largeIcon,
importance: Importance.high, priority: Priority.high,
          color: Color(0xFF0B8FAC),
        ),
        iOS: DarwinNotificationDetails(
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

  Future<void> cancelAll() => _plugin.cancelAll();
}
