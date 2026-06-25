import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../utils/app_theme.dart';

/// Bouton déconnexion réutilisable — à placer dans actions d'un AppBar.
class LogoutIconButton extends StatelessWidget {
  const LogoutIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.logout_rounded, color: Colors.white),
      tooltip: 'Déconnexion',
      onPressed: () => _confirmer(context),
    );
  }

  Future<void> _confirmer(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Déconnexion', style: AppFonts.title(size: 16)),
        content: Text('Voulez-vous vous déconnecter ?',
            style: AppFonts.body(size: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );
    if (ok == true) await FirebaseService.instance.signOut();
  }
}
