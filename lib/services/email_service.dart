import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class EmailService {
  EmailService._();
  static final EmailService instance = EmailService._();

  static const _backendBase = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://sahtekbackend.onrender.com',
  );

  Future<void> sendInvitationEmail({
    required String inviterEmail,
    required String destinationEmail,
    required String role,
  }) async {
    debugPrint('[EMAIL] ▶ sendInvitationEmail() début');
    debugPrint('[EMAIL]   inviterEmail     = $inviterEmail');
    debugPrint('[EMAIL]   destinationEmail = $destinationEmail');
    debugPrint('[EMAIL]   role             = $role');
    debugPrint('[EMAIL]   backend URL      = $_backendBase');

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[EMAIL] ✗ currentUser est null → abandon');
      return;
    }
    debugPrint('[EMAIL] ✓ user connecté uid=${user.uid}');

    final token = await user.getIdToken();
    debugPrint('[EMAIL] ✓ token Firebase récupéré (${token?.length ?? 0} chars)');

    final url = Uri.parse('$_backendBase/api/email/invitation');
    final body = jsonEncode({
      'inviterEmail':     inviterEmail,
      'destinationEmail': destinationEmail,
      'role':             role,
    });
    debugPrint('[EMAIL] → POST $url');
    debugPrint('[EMAIL]   body = $body');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: body,
      ).timeout(const Duration(seconds: 40));

      debugPrint('[EMAIL] ← status  = ${response.statusCode}');
      debugPrint('[EMAIL] ← body    = ${response.body}');
      debugPrint('[EMAIL] ← headers = ${response.headers}');

      if (response.statusCode != 200) {
        throw Exception(
          'Échec envoi email (HTTP ${response.statusCode}) : ${response.body}',
        );
      }
      debugPrint('[EMAIL] ✓ email envoyé avec succès');
    } catch (e, st) {
      debugPrint('[EMAIL] ✗ EXCEPTION : $e');
      debugPrint('[EMAIL]   stacktrace : $st');
      rethrow;
    }
  }
}
