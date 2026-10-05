import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/day_record.dart';
import 'email_service.dart';
import 'image_storage_service.dart';

/// Service Firebase — Auth + Firestore
class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  final FirebaseAuth      _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db   = FirebaseFirestore.instance;

   User? get currentUser   => _auth.currentUser;
  String? get currentUid  => _auth.currentUser?.uid;
  String? get currentEmail => _auth.currentUser?.email;
  bool get isLoggedIn     => _auth.currentUser != null;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signUp({
    required String email,
    required String password,
    String? fullName,
    String userType = 'patient',
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    // Créer le profil — les médecins/proches n'ont pas de profil patient à remplir
    await _db.collection('users').doc(cred.user!.uid).set({
      'email':           email,
      'fullName':        fullName ?? '',
      'userType':        userType,
      'profileComplete': userType == 'doctor', // doctor → skip ProfileSetupScreen
      'createdAt':       FieldValue.serverTimestamp(),
    });
    if (fullName != null) {
      await cred.user!.updateDisplayName(fullName);
    }
    return cred;
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<void> signOut() => _auth.signOut();

  Future<void> resetPassword(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  // ── Day Records ────────────────────────────────────────────────────────────

  /// Collection de l'utilisateur courant
  CollectionReference<Map<String, dynamic>> get _myRecords =>
      _db.collection('users').doc(currentUid).collection('records');

  /// Sauvegarder / mettre à jour un record
  Future<void> upsertRecord(DayRecord record) async {
    if (currentUid == null) return;
    await _myRecords.doc(record.dateKey).set(record.toJson());
  }

  // ── Storage (Cloudinary) ───────────────────────────────────────────────────

  Future<String?> uploadMealImage(File imageFile) async {
    if (currentUid == null) return null;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    return ImageStorageService.instance.uploadFile(imageFile, 'meals/$currentUid/$id');
  }

  /// Charger tous les records de l'utilisateur
  Future<List<DayRecord>> fetchMyRecords() async {
    if (currentUid == null) return [];
    final snap = await _myRecords.orderBy('dateKey').get();
    return snap.docs
        .map((d) => DayRecord.fromJson(d.data()))
        .toList();
  }

  /// Stream temps réel des records de l'utilisateur courant
  Stream<List<DayRecord>> streamMyRecords() {
    if (currentUid == null) return const Stream.empty();
    return streamRecords(currentUid!);
  }

  /// Stream temps réel des records (pour les collaborateurs)
  Stream<List<DayRecord>> streamRecords(String uid) =>
      _db.collection('users').doc(uid).collection('records')
          .orderBy('dateKey')
          .snapshots()
          .map((s) => s.docs
          .map((d) => DayRecord.fromJson(d.data())).toList());

  // ── Collaborateurs ─────────────────────────────────────────────────────────

  /// Inviter quelqu'un par email
  Future<void> inviteCollaborator({
    required String email,
    String role = 'viewer',
  }) async {
    if (currentUid == null) throw Exception('Non connecté');
    if (email.trim().toLowerCase() == currentEmail?.toLowerCase()) {
      throw Exception('Vous ne pouvez pas vous inviter vous-même');
    }

    // Vérifier doublon
    final existing = await _db.collection('collaborators')
        .where('ownerId', isEqualTo: currentUid)
        .where('email',   isEqualTo: email.trim().toLowerCase())
        .get();
    if (existing.docs.isNotEmpty) throw Exception('Déjà invité');

    await _db.collection('collaborators').add({
      'ownerId':   currentUid,
      'ownerEmail': currentEmail,
      'email':     email.trim().toLowerCase(),
      'role':      role,
      'status':    'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Envoi de l'email via SMTP — on laisse l'exception remonter pour que l'UI l'affiche
    debugPrint('[INVITE] currentEmail = $currentEmail');
    await EmailService.instance.sendInvitationEmail(
      inviterEmail: currentEmail!,
      destinationEmail: email.trim().toLowerCase(),
      role: role,
    );
  }

  /// Mes collaborateurs (ceux que j'ai invités)
  Stream<List<FirebaseCollaborator>> streamMyCollaborators() =>
      _db.collection('collaborators')
          .where('ownerId', isEqualTo: currentUid)
          .snapshots()
          .map((s) => s.docs
          .map((d) => FirebaseCollaborator.fromDoc(d)).toList());

  /// Invitations reçues (quelqu'un m'a invité)
  Stream<List<FirebaseCollaborator>> streamMyInvitations() =>
      _db.collection('collaborators')
          .where('email',  isEqualTo: currentEmail?.toLowerCase())
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .map((s) => s.docs
          .map((d) => FirebaseCollaborator.fromDoc(d)).toList());

  /// Accepter une invitation
  Future<void> acceptInvitation(String docId) =>
      _db.collection('collaborators').doc(docId).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

  /// Refuser une invitation
  Future<void> rejectInvitation(String docId) =>
      _db.collection('collaborators').doc(docId).update({
        'status': 'rejected',
      });

  /// Supprimer un collaborateur
  Future<void> removeCollaborator(String docId) =>
      _db.collection('collaborators').doc(docId).delete();

  /// Récupérer le profil d'un utilisateur
  Future<Map<String, dynamic>?> getProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data();
  }

  // ── Profil patient ─────────────────────────────────────────────────────────

  Stream<bool> streamProfileComplete() {
    if (currentUid == null) return Stream.value(false);
    return _db.collection('users').doc(currentUid).snapshots()
        .map((doc) => doc.data()?['profileComplete'] == true);
  }

  Stream<String?> streamUserType() {
    if (currentUid == null) return Stream.value(null);
    return _db.collection('users').doc(currentUid).snapshots()
        .map((doc) => doc.data()?['userType'] as String?);
  }

  Future<void> savePatientProfile({
    required int age,
    required double weight,
    required String sex,
    required int diabetesType,
  }) async {
    if (currentUid == null) return;
    await _db.collection('users').doc(currentUid).update({
      'age':             age,
      'weight':          weight,
      'sex':             sex,
      'diabetesType':    diabetesType,
      'profileComplete': true,
    });
  }

  // ── Médicaments ────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _myMedications =>
      _db.collection('users').doc(currentUid).collection('medications');

  Stream<List<PatientMedication>> streamMedications() {
    if (currentUid == null) return Stream.value([]);
    return _myMedications
        .orderBy('createdAt')
        .snapshots()
        .map((s) => s.docs.map(PatientMedication.fromDoc).toList());
  }

  Future<void> addMedication({
    required String name,
    required String medicationType,
  }) async {
    if (currentUid == null) return;
    await _myMedications.add({
      'name':          name,
      'medicationType': medicationType,
      'createdAt':     FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeMedication(String id) =>
      _myMedications.doc(id).delete();

  // ── Nom d'affichage d'un utilisateur (fullName, partie email, ou email complet)
  Future<String> getUserName(String uid) async {
    if (uid.isEmpty) return '?';
    final data = await getProfile(uid);
    final fullName = data?['fullName'] as String?;
    if (fullName != null && fullName.isNotEmpty) return fullName;
    final email = data?['email'] as String?;
    if (email != null && email.isNotEmpty) {
      return email.contains('@') ? email.split('@').first : email;
    }
    return uid;
  }

  /// Collaborateurs qui m'ont accordé l'accès (pour voir leurs données)
  Stream<List<FirebaseCollaborator>> streamAccessibleOwners() =>
      _db.collection('collaborators')
          .where('email',  isEqualTo: currentEmail?.toLowerCase())
          .where('status', isEqualTo: 'accepted')
          .snapshots()
          .map((s) => s.docs
          .map((d) => FirebaseCollaborator.fromDoc(d)).toList());
}

/// Modèle collaborateur Firebase
class FirebaseCollaborator {
  final String id;
  final String ownerId;
  final String ownerEmail;
  final String email;
  final String role;
  final String status;
  final DateTime? createdAt;

  const FirebaseCollaborator({
    required this.id, required this.ownerId, required this.ownerEmail,
    required this.email, required this.role, required this.status,
    this.createdAt,
  });

  factory FirebaseCollaborator.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return FirebaseCollaborator(
      id:         doc.id,
      ownerId:    d['ownerId']    as String? ?? '',
      ownerEmail: d['ownerEmail'] as String? ?? '',
      email:      d['email']      as String? ?? '',
      role:       d['role']       as String? ?? 'viewer',
      status:     d['status']     as String? ?? 'pending',
      createdAt:  (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  bool get isAccepted => status == 'accepted';
  bool get isPending  => status == 'pending';

  String get roleLabel => role == 'doctor' ? 'Médecin' : 'Lecteur';

  String get statusLabel {
    switch (status) {
      case 'accepted': return 'Accepté';
      case 'rejected': return 'Refusé';
      default:         return 'En attente';
    }
  }
}

/// Médicament / insuline du patient
class PatientMedication {
  final String id;
  final String name;
  final String medicationType; // 'insulin' | 'pill'

  const PatientMedication({
    required this.id,
    required this.name,
    required this.medicationType,
  });

  factory PatientMedication.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return PatientMedication(
      id:             doc.id,
      name:           d['name']           as String? ?? '',
      medicationType: d['medicationType'] as String? ?? 'pill',
    );
  }
}