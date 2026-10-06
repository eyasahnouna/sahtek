import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../l10n/l10n.dart';

/// Résultat de la reconnaissance OCR
class OcrResult {
   final double? value;

   final String rawText;

   final String? errorMessage;

  const OcrResult({this.value, required this.rawText, this.errorMessage});

  bool get hasValue => value != null;
}

/// Service OCR — lecture de glucomètre par photo
class OcrService {
  OcrService._();
  static final OcrService instance = OcrService._();

  final _picker = ImagePicker();

  /// Ouvre la caméra, analyse l'image et retourne la valeur glycémique
  /// [fromGallery] — si true, ouvre la galerie au lieu de la caméra
  Future<OcrResult?> pickAndRecognize({bool fromGallery = false}) async {
    try {
      final picked = await _picker.pickImage(
        source: fromGallery ? ImageSource.gallery : ImageSource.camera,
        imageQuality: 90,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (picked == null) return null; // Annulé par l'utilisateur

      return await _recognizeFromFile(File(picked.path));
    } catch (e) {
      return OcrResult(
        rawText: '',
        errorMessage: 'Impossible d\'accéder à la caméra : {e}'.trp({'e': e}),
      );
    }
  }

  /// Analyse un fichier image et extrait la valeur glycémique
  Future<OcrResult> _recognizeFromFile(File imageFile) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognized = await textRecognizer.processImage(inputImage);

      final rawText = recognized.text;

      if (rawText.trim().isEmpty) {
        return OcrResult(
          rawText: rawText,
          errorMessage: 'Aucun texte détecté. Réessayez en vous rapprochant de l\'écran.'.tr,
        );
      }

      final value = _extractGlucoseValue(rawText);

      if (value == null) {
        return OcrResult(
          rawText: rawText,
          errorMessage: 'Valeur glycémique non trouvée. Texte lu : "{text}"'
              .trp({'text': rawText}),
        );
      }

      return OcrResult(rawText: rawText, value: value);
    } finally {
      textRecognizer.close();
    }
  }

  /// Extrait la valeur glycémique la plus probable depuis le texte OCR
  ///
  /// Stratégie :
  /// 1. Cherche d'abord des patterns avec unités explicites (mg/dL, mmol/L)
  /// 2. Sinon, cherche des nombres dans les plages typiques (40–600 mg/dL ou 1.0–33.3 mmol/L)
  /// 3. Préfère les grands nombres (mg/dL) aux petits (mmol/L) si ambiguïté
  double? _extractGlucoseValue(String text) {
    // Normaliser le texte : supprimer les espaces doubles, convertir virgules
    final normalized = text
        .replaceAll(',', '.')
        .replaceAll('O', '0') // OCR confond souvent O et 0
        .replaceAll('l', '1') // OCR confond parfois l et 1
        .toLowerCase();

    // ── Pattern 1 : valeur avec unité "mg/dl" ou "mg dL" ──────────────────
    final mgDlPattern = RegExp(r'(\d{2,3})\s*mg');
    final mgMatch = mgDlPattern.firstMatch(normalized);
    if (mgMatch != null) {
      final val = double.tryParse(mgMatch.group(1)!);
      if (val != null && _isValidMgDl(val)) return val;
    }

    // ── Pattern 2 : valeur avec unité "mmol/l" ou "mmol" ──────────────────
    final mmolPattern = RegExp(r'(\d{1,2}\.?\d?)\s*mmol');
    final mmolMatch = mmolPattern.firstMatch(normalized);
    if (mmolMatch != null) {
      final val = double.tryParse(mmolMatch.group(1)!);
      if (val != null && _isValidMmol(val)) return val;
    }

    // ── Pattern 3 : chercher tous les nombres dans le texte ───────────────
    // Prioriser les nombres de 2-3 chiffres (typique mg/dL : 40-600)
    final allNumbers = RegExp(r'\b(\d{1,3}(?:\.\d{1,2})?)\b')
        .allMatches(normalized)
        .map((m) => double.tryParse(m.group(1)!))
        .whereType<double>()
        .toList();

    // Chercher d'abord dans la plage mg/dL (40-600)
    final mgCandidates = allNumbers.where(_isValidMgDl).toList();
    if (mgCandidates.isNotEmpty) {
      // Retourner le premier nombre plausible (souvent le plus grand affiché)
      // Les glucomètres affichent en grand la valeur principale
      mgCandidates.sort((a, b) => b.compareTo(a)); // tri décroissant
      return mgCandidates.first;
    }

    // Ensuite dans la plage mmol/L (1.0–33.3)
    final mmolCandidates = allNumbers.where(_isValidMmol).toList();
    if (mmolCandidates.isNotEmpty) {
      return mmolCandidates.first;
    }

    return null;
  }

  bool _isValidMgDl(double v) => v >= 20 && v <= 600;
  bool _isValidMmol(double v) => v >= 1.0 && v <= 33.3 && v != v.roundToDouble();
}
