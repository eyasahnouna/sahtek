import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../l10n/l10n.dart';

const _kCloudName    = 'dtrng1x4b';    // ex: 'dxyz1234'
const _kUploadPreset = 'sahtek_unsigned';

class ImageStorageService {
  ImageStorageService._();
  static final instance = ImageStorageService._();

  final _picker = ImagePicker();

  Future<String?> pickAndUpload({
    required String uid,
    required String dateKey,
    required String entryId,
    ImageSource source = ImageSource.gallery,
  }) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 75,
    );
    if (picked == null) return null;
    return _upload(File(picked.path), 'sahtek/meals/$uid/$dateKey/$entryId');
  }

  Future<String?> uploadFile(File file, String publicId) =>
      _upload(file, 'sahtek/$publicId');

  Future<String?> _upload(File file, String publicId) async {
    try {
      final uri = Uri.parse(
          'https://api.cloudinary.com/v1_1/$_kCloudName/image/upload');
      final req = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _kUploadPreset
        ..fields['public_id']     = publicId
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final res  = await req.send().timeout(const Duration(seconds: 30));
      final body = await res.stream.bytesToString();

      if (res.statusCode == 200) {
        final data = jsonDecode(body) as Map<String, dynamic>;
        return data['secure_url'] as String?;
      }
      debugPrint('[Cloudinary] ${res.statusCode}: $body');
      throw ImageUploadException(_msg(res.statusCode));
    } on ImageUploadException {
      rethrow;
    } catch (e) {
      debugPrint('[Cloudinary] Erreur: $e');
      throw ImageUploadException('Erreur réseau. Vérifiez votre connexion.'.tr);
    }
  }

  String _msg(int code) {
    switch (code) {
      case 400: return 'Preset upload invalide. Vérifiez la configuration Cloudinary.'.tr;
      case 401: return 'Cloud name invalide. Vérifiez la configuration Cloudinary.'.tr;
      case 420: return 'Limite de requêtes atteinte. Réessayez plus tard.'.tr;
      default:  return 'Erreur lors de l\'envoi de l\'image (code {code}).'.trp({'code': code});
    }
  }

  Future<void> deleteImage(String url) async {
    // La suppression Cloudinary nécessite une signature serveur (API secret).
    // Avec le même public_id, la prochaine photo écrase automatiquement l'ancienne.
    debugPrint('[Cloudinary] deleteImage: image sera écrasée au prochain upload.');
  }
}

class ImageUploadException implements Exception {
  final String message;
  const ImageUploadException(this.message);
  @override
  String toString() => message;
}
