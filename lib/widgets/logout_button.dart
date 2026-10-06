import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../utils/app_theme.dart';
import '../l10n/l10n.dart';

/// Bouton déconnexion réutilisable — à placer dans actions d'un AppBar.
class LogoutIconButton extends StatelessWidget {
  const LogoutIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.logout_rounded, color: Colors.white),
      tooltip: 'Déconnexion'.tr,
      onPressed: () => _confirmer(context),
    );
  }

  Future<void> _confirmer(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Déconnexion'.tr, style: AppFonts.title(size: 16)),
        content: Text('Voulez-vous vous déconnecter ?'.tr,
            style: AppFonts.body(size: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler'.tr),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Déconnecter'.tr),
          ),
        ],
      ),
    );
    if (ok == true) await FirebaseService.instance.signOut();
  }
}
