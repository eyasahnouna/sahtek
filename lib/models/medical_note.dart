import 'package:uuid/uuid.dart';
import '../l10n/l10n.dart';

/// Note médicale dans le dossier partagé
class MedicalNote {
  final String id;
  final String content;
  final DateTime createdAt;
  final String? category; // 'glucose', 'insulin', 'symptom', 'general'

  MedicalNote({
    String? id,
    required this.content,
    required this.createdAt,
    this.category,
  }) : id = id ?? const Uuid().v4();

  String get categoryLabel {
    switch (category) {
      case 'glucose':  return 'Glycémie'.tr;
      case 'insulin':  return 'Insuline'.tr;
      case 'symptom':  return 'Symptôme'.tr;
      case 'general':  return 'Général'.tr;
      default:         return 'Note'.tr;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'content': content,
    'createdAt': createdAt.toIso8601String(), 'category': category,
  };

  factory MedicalNote.fromJson(Map<String, dynamic> j) => MedicalNote(
    id:        j['id'] as String,
    content:   j['content'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    category:  j['category'] as String?,
  );
}