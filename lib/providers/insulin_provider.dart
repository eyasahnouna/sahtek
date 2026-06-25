import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/insulin_dose.dart';
import '../services/firebase_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  InsulinProvider
//  Auto-save Firestore → collection users/{uid}/insulin_doses
// ─────────────────────────────────────────────────────────────────────────────
class InsulinProvider extends ChangeNotifier {
  List<InsulinDose> _doses  = [];
  bool              _loaded = false;

  List<InsulinDose> get doses  => List.unmodifiable(_doses);
  bool              get loaded => _loaded;

  InsulinDose? get latest =>
      _doses.isEmpty ? null : _doses.last;

  double get totalToday {
    final today = DateTime.now();
    return _doses
        .where((d) =>
    d.timestamp.year  == today.year  &&
        d.timestamp.month == today.month &&
        d.timestamp.day   == today.day)
        .fold(0.0, (s, d) => s + d.units);
  }

  InsulinProvider() { _init(); }

  Future<void> _init() async {
    await _loadLocal();
    if (FirebaseService.instance.isLoggedIn) {
      await _fetchFromFirestore();
    }
    FirebaseService.instance.authStateChanges.listen((user) {
      if (user != null) _fetchFromFirestore();
    });
  }

  CollectionReference<Map<String, dynamic>>? get _col {
    final uid = FirebaseService.instance.currentUid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('insulin_doses');   // ← créée auto au premier write
  }

  // ── Ajouter une dose ───────────────────────────────────────────────────────
  Future<void> addDose(InsulinDose dose) async {
    _doses.add(dose);
    _doses.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    notifyListeners();
    await _persistLocal();

    // Auto-save Firestore
    if (_col != null) {
      try {
        await _col!.doc(dose.id).set(
          dose.toJson(),
          SetOptions(merge: true),
        );
      } catch (_) {}
    }
  }

  // ── Supprimer ──────────────────────────────────────────────────────────────
  Future<void> removeDose(String id) async {
    _doses.removeWhere((d) => d.id == id);
    notifyListeners();
    await _persistLocal();
    try { await _col?.doc(id).delete(); } catch (_) {}
  }

  Future<void> _fetchFromFirestore() async {
    if (_col == null) return;
    try {
      final snap = await _col!.orderBy('timestamp').get();
      _doses = snap.docs
          .map((d) => InsulinDose.fromJson(d.data()))
          .toList();
      await _persistLocal();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('insulin_doses');
    if (raw != null) {
      try {
        _doses = (jsonDecode(raw) as List)
            .map((j) => InsulinDose.fromJson(j as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persistLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'insulin_doses',
        jsonEncode(_doses.map((d) => d.toJson()).toList()));
  }
}