import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';


class FoodItemResult {
  final String name;
  final double? estimatedGrams;
  final double carbsG;
  final double? confidence;

  const FoodItemResult({
    required this.name,
    this.estimatedGrams,
    required this.carbsG,
    this.confidence,
  });

  factory FoodItemResult.fromJson(Map<String, dynamic> j) => FoodItemResult(
        name:           j['name']            as String? ?? '',
        estimatedGrams: (j['estimated_grams'] as num?)?.toDouble(),
        carbsG:         (j['carbs_g']         as num?)?.toDouble() ?? 0,
        confidence:     (j['confidence']       as num?)?.toDouble(),
      );

  String get portionLabel {
    if (estimatedGrams == null) return '';
    return estimatedGrams! >= 1000
        ? '~${(estimatedGrams! / 1000).toStringAsFixed(1)} kg'
        : '~${estimatedGrams!.toStringAsFixed(0)} g';
  }

  String get confidenceLabel {
    if (confidence == null) return '';
    if (confidence! >= 0.8) return 'fiable';
    if (confidence! >= 0.5) return 'estimé';
    return 'incertain';
  }
}

class MealAnalysisResult {
  final List<FoodItemResult> foods;
  final double totalCarbsG;
  final String? notes;
  final String? source;

  const MealAnalysisResult({
    required this.foods,
    required this.totalCarbsG,
    this.notes,
    this.source,
  });

  factory MealAnalysisResult.fromJson(Map<String, dynamic> j) =>
      MealAnalysisResult(
        foods: (j['foods'] as List<dynamic>? ?? [])
            .map((f) => FoodItemResult.fromJson(f as Map<String, dynamic>))
            .toList(),
        totalCarbsG: (j['total_carbs_g'] as num?)?.toDouble() ?? 0,
        notes:       j['notes']  as String?,
        source:      j['source'] as String?,
      );
}

// ── AiService ─────────────────────────────────────────────────────────────────

/// Envoie une photo de repas au backend Spring Boot → reçoit l'estimation
/// des glucides par Gemini Vision.
///
/// URL du backend :
///  • Production       → https://sahtekbackend.onrender.com/
class AiService {
  AiService._();
  static final AiService instance = AiService._();

  static const _backendBase = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://sahtekbackend.onrender.com',
  );

  final _picker = ImagePicker();

  // ── Sélection d'image ─────────────────────────────────────────────────────

  Future<XFile?> pickImage({bool fromGallery = false}) =>
      _picker.pickImage(
        source: fromGallery ? ImageSource.gallery : ImageSource.camera,
        imageQuality: 80,
        maxWidth:  1024,
        maxHeight: 1024,
        preferredCameraDevice: CameraDevice.rear,
      );

  // ── Analyse ───────────────────────────────────────────────────────────────

  /// Analyse un fichier image et retourne l'estimation des glucides.
  /// Lance une [AiException] en cas d'erreur réseau ou réponse invalide.
  Future<MealAnalysisResult> analyzeMealImage({
    required File imageFile,
    String? hint,
  }) async {
    final token = await _getFirebaseToken();
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final uri = Uri.parse('$_backendBase/api/meals/analyze');
    late http.Response response;

    try {
      response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type':  'application/json',
        },
        body: jsonEncode({
          'imageBase64': base64Image,
          'hint':        hint ?? '',
        }),
      ).timeout(const Duration(seconds: 90));
    } on SocketException {
      throw AiException(
        'Serveur injoignable. Vérifiez que le backend est démarré sur $_backendBase',
      );
    } on Exception catch (e) {
      throw AiException('Erreur réseau : $e');
    }

    if (response.statusCode == 200) {
      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return MealAnalysisResult.fromJson(json);
      } catch (_) {
        throw AiException('Réponse inattendue du serveur.');
      }
    }

    // Erreurs HTTP connues
    if (response.statusCode == 503) {
      throw AiException(
        'Service IA indisponible. Réessayez dans quelques instants.',
      );
    }
    if (response.statusCode == 401) {
      throw AiException('Session expirée. Reconnectez-vous.');
    }

    throw AiException(
      'Erreur serveur (${response.statusCode}). Réessayez.',
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<String> _getFirebaseToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw AiException('Utilisateur non connecté.');
    final token = await user.getIdToken();
    if (token == null) throw AiException('Impossible d\'obtenir le jeton Auth.');
    return token;
  }
}

/// Erreur métier spécifique au service IA.
class AiException implements Exception {
  final String message;
  const AiException(this.message);

  @override
  String toString() => message;
}
