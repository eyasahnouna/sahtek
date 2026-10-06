import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/day_record.dart';
import '../models/meal_entry.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../services/voice_entry_parser.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AppProvider
//  • Auto-save Firestore avec debounce (500 ms)
//  • SetOptions(merge: true)  → create ou update automatique
//  • Stream temps réel  → UI toujours à jour
//  • Cache local SharedPreferences  → offline support
//  • syncing bool  → loader dans AppBar
// ─────────────────────────────────────────────────────────────────────────────
class AppProvider extends ChangeNotifier {

  // ── État interne ────────────────────────────────────────────────────────────
  final Map<String, DayRecord> _records = {};
  DateTime  _selectedDate          = DateTime.now();
  bool      _notificationsEnabled  = true;
  bool      _loaded                = false;
  bool      _syncing               = false;

  // ── Abonnements ─────────────────────────────────────────────────────────────
  StreamSubscription<List<DayRecord>>? _firestoreSub;

  // ── Debounce : un timer par dateKey ─────────────────────────────────────────
  final Map<String, Timer> _debounceTimers = {};

  // ── Durée du debounce (évite les écritures en rafale) ───────────────────────
  static const _kDebounce = Duration(milliseconds: 500);

  // ── Getters publics ─────────────────────────────────────────────────────────
  bool     get notificationsEnabled => _notificationsEnabled;
  bool     get loaded               => _loaded;
  bool     get syncing              => _syncing;
  DateTime get selectedDate         => _selectedDate;

  DayRecord get currentRecord {
    _records.putIfAbsent(_currentKey, () => DayRecord(dateKey: _currentKey));
    return _records[_currentKey]!;
  }

  List<DayRecord> get allRecords {
    final list = _records.values.toList();
    list.sort((a, b) => a.dateKey.compareTo(b.dateKey));
    return list;
  }

  // ── Clé de la date sélectionnée ─────────────────────────────────────────────
  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  String get _currentKey => _key(_selectedDate);

  // ─────────────────────────────────────────────────────────────────────────────
  //  Constructeur → init
  // ─────────────────────────────────────────────────────────────────────────────
  AppProvider() { _init(); }

  Future<void> _init() async {
    // 1. Charger le cache local d'abord (offline-first)
    await _loadLocal();

    // 2. Activer le support offline Firestore
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,          // cache Firestore sur disque
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // 3. Écouter les changements d'auth
    FirebaseService.instance.authStateChanges.listen((user) {
      if (user != null) {
        _startRealtimeSync();
      } else {
        _stopRealtimeSync();
        // Vider les données en mémoire à la déconnexion
        _records.clear();
        notifyListeners();
      }
    });

    // 4. Si déjà connecté au démarrage → stream immédiat
    if (FirebaseService.instance.isLoggedIn) {
      _startRealtimeSync();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  Stream Firestore temps réel (auto-create, auto-update via snapshots)
  // ─────────────────────────────────────────────────────────────────────────────
  void _startRealtimeSync() {
    _stopRealtimeSync();
    _syncing = true;
    notifyListeners();

    _firestoreSub = FirebaseService.instance.streamMyRecords().listen(
          (cloudRecords) {
        // Fusionner : Firestore gagne toujours sur le cache local
        for (final r in cloudRecords) {
          _records[r.dateKey] = r;
        }
        _persistLocal();          // mettre à jour le cache local
        _syncing = false;
        notifyListeners();
      },
      onError: (_) {
        // En cas d'erreur réseau, Firestore utilise son cache interne
        _syncing = false;
        notifyListeners();
      },
    );
  }

  void _stopRealtimeSync() {
    _firestoreSub?.cancel();
    _firestoreSub = null;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  _saveToFirestore  ← cœur de l'auto-save
  //  Utilise SetOptions(merge: true) :
  //    • Document existe   → update (fusionne les champs)
  //    • Document absent   → création automatique
  //    • Collection absente → Firestore la crée automatiquement
  // ─────────────────────────────────────────────────────────────────────────────
  void _saveToFirestore(DayRecord record) {
    if (!FirebaseService.instance.isLoggedIn) return;

    final key = record.dateKey;

    // Annuler le timer précédent pour ce record → debounce
    _debounceTimers[key]?.cancel();

    _debounceTimers[key] = Timer(_kDebounce, () async {
      try {
        final uid = FirebaseService.instance.currentUid!;
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('records')
            .doc(key)
            .set(
          record.toJson(),
          SetOptions(merge: true),  // ← create OU update automatique
        );
        _debounceTimers.remove(key);
      } catch (_) {
        // Firestore mettra en attente si hors ligne (persistenceEnabled: true)
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  Cache local (SharedPreferences) → données disponibles hors ligne
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    _notificationsEnabled = prefs.getBool('notifEnabled') ?? true;

    final raw = prefs.getString('records');
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        for (final e in map.entries) {
          _records[e.key] =
              DayRecord.fromJson(e.value as Map<String, dynamic>);
        }
      } catch (_) {}
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persistLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'records',
      jsonEncode(_records.map((k, v) => MapEntry(k, v.toJson()))),
    );
    await prefs.setBool('notifEnabled', _notificationsEnabled);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  API publique — chaque méthode :
  //    1. Modifie l'état en mémoire
  //    2. Notifie les widgets
  //    3. Persiste en local
  //    4. Lance _saveToFirestore (debounced)
  // ─────────────────────────────────────────────────────────────────────────────

  void selectDate(DateTime date) {
    _selectedDate = DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

  /// Sauvegarder le record courant dans Firebase (appelé après _ensureSlots)
  void saveCurrentRecord() {
    final record = _records[_currentKey];
    if (record == null) return;
    _persistLocal();
    _saveToFirestore(record);
  }

  /// Mise à jour d'une entrée (glycémie, dose, heure, mode…)
  /// Appelé depuis le FocusNode quand l'utilisateur quitte un champ
  void updateEntry(MealEntry updated) {
    _ensureRecord();
    final entries = _records[_currentKey]!.entries;
    final idx     = entries.indexWhere((e) => e.id == updated.id);
    if (idx == -1) return;

    entries[idx] = updated;

    if (_notificationsEnabled) {
      // Rappel de dose insuline (pas pour une mesure spontanée ponctuelle)
      if (updated.doseTime != null && updated.slotId != spontaneousSlot) {
        NotificationService.instance.scheduleReminder(updated);
      }
      // Notification "Mesure glycémie 2h après repas" pour les repas principaux
      const _mainSlots = {'bkf_mesure', 'lunch_mesure', 'diner_mesure'};
      if (_mainSlots.contains(updated.slotId) && updated.mealTime != null) {
        NotificationService.instance.schedulePostMealMeasure(
          slotId:   updated.slotId!,
          mealTime: updated.mealTime!,
          mealName: updated.name,
        );
      }
    }

    notifyListeners();
    _persistLocal();
    _saveToFirestore(_records[_currentKey]!);   // ← auto-save debounced
  }

  /// Effacer les données d'une entrée (glycémie + dose)
  void clearEntryData(String id) {
    final record = _records[_currentKey];
    if (record == null) return;
    final idx = record.entries.indexWhere((e) => e.id == id);
    if (idx == -1) return;

    record.entries[idx] = record.entries[idx].copyWith(
      clearGlycemie:    true,
      clearDose:        true,
      clearCarbsG:      true,
      clearObservation: true,
    );

    notifyListeners();
    _persistLocal();
    _saveToFirestore(record);
  }

  /// Met à jour uniquement l'imageUrl d'une entrée (photo de repas sans analyse IA)
  void updateImageUrl(String id, String? imageUrl) {
    _ensureRecord();
    final entries = _records[_currentKey]!.entries;
    final idx     = entries.indexWhere((e) => e.id == id);
    if (idx == -1) return;

    entries[idx] = entries[idx].copyWith(
        imageUrl: imageUrl, clearImageUrl: imageUrl == null);

    notifyListeners();
    _persistLocal();
    _saveToFirestore(_records[_currentKey]!);
  }

  /// Ajouter un snack dynamique dans une section
  void addSnack({required int afterIndex, String? sectionKey}) {
    _ensureRecord();
    final slotId = sectionKey != null ? 'snack_$sectionKey' : null;
    _records[_currentKey]!.entries.insert(
      afterIndex + 1,
      MealEntry(name: 'Snack', type: MealType.snack, slotId: slotId),
    );

    notifyListeners();
    _persistLocal();
    _saveToFirestore(_records[_currentKey]!);
  }

  /// slotId des mesures spontanées (hors créneaux fixes)
  static const spontaneousSlot = 'spontane';

  /// Ajouter une mesure spontanée (hors slots fixes)
  void addSensorMeasure({
    required String name,
    required TimeOfDay time,
    double? glycemie,
    GlycemieMode glycemieMode = GlycemieMode.directe,
  }) {
    _ensureRecord();
    final entry = MealEntry(
      name:     name.trim().isEmpty ? 'Mesure spontanée' : name.trim(),
      type:     MealType.mesure,
      slotId:   spontaneousSlot,
      glycemie: glycemie,
      glycemieMode: glycemieMode,
      mealTime: time,
      doseTime: time,
    );

    final entries = _records[_currentKey]!.entries;

    // Insertion triée par heure
    final insertIdx = entries.indexWhere((e) {
      final t = e.mealTime ?? e.doseTime;
      if (t == null) return false;
      return (t.hour * 60 + t.minute) > (time.hour * 60 + time.minute);
    });

    if (insertIdx == -1) {
      entries.add(entry);
    } else {
      entries.insert(insertIdx, entry);
    }

    notifyListeners();
    _persistLocal();
    _saveToFirestore(_records[_currentKey]!);
  }

  /// Ranger dans le record courant les valeurs dictées (saisie vocale)
  void applyVoiceItems(List<VoiceItem> items) {
    _ensureRecord();
    for (final it in items) {
      if (it.slotId == spontaneousSlot) {
        addSensorMeasure(
          name: '',
          time: it.time ?? TimeOfDay.now(),
          glycemie: it.value,
          glycemieMode: it.mode,
        );
        continue;
      }
      final e = _records[_currentKey]!.entries
          .where((e) => e.slotId == it.slotId)
          .firstOrNull;
      if (e == null) continue;
      updateEntry(it.field == VoiceField.dose
          ? e.copyWith(dose: it.value, doseTime: it.time)
          : e.copyWith(
              glycemie: it.value,
              glycemieMode: it.value != null ? it.mode : null,
              mealTime: it.time,
              doseTime: it.time,
            ));
    }
  }

  /// Supprimer une entrée (snack ou mesure libre)
  void removeEntry(String id) {
    final record = _records[_currentKey];
    if (record == null) return;

    record.entries.removeWhere((e) => e.id == id);
    NotificationService.instance.cancelReminder(id);

    notifyListeners();
    _persistLocal();
    _saveToFirestore(record);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  Notifications
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> toggleNotifications() async {
    _notificationsEnabled = !_notificationsEnabled;
    if (!_notificationsEnabled) {
      await NotificationService.instance.cancelAll();
    } else {
      for (final e in currentRecord.entries) {
        if (e.doseTime != null) {
          NotificationService.instance.scheduleReminder(e);
        }
      }
    }
    await _persistLocal();
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  Sync forcée (appelée après connexion)
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> syncFromCloud() async {
    if (!FirebaseService.instance.isLoggedIn) return;
    _syncing = true;
    notifyListeners();
    try {
      final cloud = await FirebaseService.instance.fetchMyRecords();
      for (final r in cloud) {
        _records[r.dateKey] = r;
      }
      await _persistLocal();
    } catch (_) {} finally {
      _syncing = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  Helpers
  // ─────────────────────────────────────────────────────────────────────────────
  void _ensureRecord() {
    _records.putIfAbsent(_currentKey, () => DayRecord(dateKey: _currentKey));
  }


  @override
  void dispose() {
    _stopRealtimeSync();
    for (final t in _debounceTimers.values) {
      t.cancel();
    }
    _debounceTimers.clear();
    super.dispose();
  }
}