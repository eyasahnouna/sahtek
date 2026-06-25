import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/glucose_reading.dart';
import '../models/alert_rule.dart';
import '../services/firebase_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  GlucoseProvider
//  Auto-save Firestore → collection users/{uid}/glucose_readings
//  Firestore crée la collection automatiquement au premier write
// ─────────────────────────────────────────────────────────────────────────────
class GlucoseProvider extends ChangeNotifier {
  List<GlucoseReading> _readings = [];
  bool _loaded = false;

  List<GlucoseReading> get readings  => List.unmodifiable(_readings);
  bool                 get loaded    => _loaded;

  // Dernière lecture
  GlucoseReading? get latest =>
      _readings.isEmpty ? null : _readings.last;

  // Moyenne sur les 7 derniers jours
  double get weekAverage {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final recent = _readings
        .where((r) => r.timestamp.isAfter(cutoff))
        .map((r) => r.displayValue)
        .toList();
    if (recent.isEmpty) return 0;
    return recent.reduce((a, b) => a + b) / recent.length;
  }

  GlucoseProvider() { _init(); }

  Future<void> _init() async {
    await _loadLocal();
    if (FirebaseService.instance.isLoggedIn) {
      await _fetchFromFirestore();
    }
    FirebaseService.instance.authStateChanges.listen((user) {
      if (user != null) _fetchFromFirestore();
    });
  }

  // ── Référence Firestore ─────────────────────────────────────────────────────
  CollectionReference<Map<String, dynamic>>? get _col {
    final uid = FirebaseService.instance.currentUid;
    if (uid == null) return null;
    // Firestore crée la collection automatiquement au premier document
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('glucose_readings');
  }

  // ── Ajouter une mesure ──────────────────────────────────────────────────────
  Future<void> addReading(
      GlucoseReading reading, {
        List<AlertRule> rules = const [],
      }) async {
    _readings.add(reading);
    _readings.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    notifyListeners();
    await _persistLocal();

    // Auto-save Firestore (crée doc + collection si absent)
    if (_col != null) {
      try {
        await _col!.doc(reading.id).set(
          reading.toJson(),
          SetOptions(merge: true),   // create OU update automatique
        );
      } catch (_) {
        // hors ligne → Firestore garde en attente et sync à la reconnexion
      }
    }

    // Vérifier les alertes
    _checkAlerts(reading, rules);
  }

  // ── Supprimer une mesure ───────────────────────────────────────────────────
  Future<void> removeReading(String id) async {
    _readings.removeWhere((r) => r.id == id);
    notifyListeners();
    await _persistLocal();
    try {
      await _col?.doc(id).delete();
    } catch (_) {}
  }

  // ── Lire depuis Firestore ──────────────────────────────────────────────────
  Future<void> _fetchFromFirestore() async {
    if (_col == null) return;
    try {
      final snap = await _col!.orderBy('timestamp').get();
      _readings = snap.docs
          .map((d) => GlucoseReading.fromJson(d.data()))
          .toList();
      await _persistLocal();
      notifyListeners();
    } catch (_) {}
  }

  // ── Alertes glycémie ───────────────────────────────────────────────────────
  void _checkAlerts(GlucoseReading reading, List<AlertRule> rules) {
    final v = reading.displayValue;
    for (final rule in rules.where((r) => r.isEnabled)) {
      // matches() gère above / below / between avec threshold1 et threshold2
      if (rule.matches(v)) {
        // Ici tu peux appeler NotificationService pour l'alerte
        // Ex: NotificationService.instance.showAlert(rule, v);
      }
    }
  }

  // ── Cache local ────────────────────────────────────────────────────────────
  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('glucose_readings');
    if (raw != null) {
      try {
        _readings = (jsonDecode(raw) as List)
            .map((j) => GlucoseReading.fromJson(j as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persistLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'glucose_readings',
        jsonEncode(_readings.map((r) => r.toJson()).toList()));
  }
}