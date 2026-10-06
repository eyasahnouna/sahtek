import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/l10n.dart';
import '../providers/reminder_provider.dart';
import '../utils/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // Chaque langue est affichée dans sa propre écriture, quelle que soit la
  // langue courante, pour rester lisible par quelqu'un qui s'est trompé.
  static const _languages = [
    (code: 'fr', native: 'Français', name: 'Français'),
    (code: 'ar', native: 'العربية', name: 'Arabe'),
  ];

  Future<void> _select(BuildContext context, String code) async {
    final locale    = context.read<LocaleProvider>();
    final reminders = context.read<ReminderProvider>();
    if (locale.code == code) return;
    await locale.setLanguage(code);
    // Les notifications déjà programmées gardent leur texte : on les recrée.
    await reminders.rescheduleAll();
  }

  @override
  Widget build(BuildContext context) {
    final current = context.watch<LocaleProvider>().code;

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(title: Text('Paramètres'.tr)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            const Icon(Icons.language_rounded, size: 18, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text('Langue de l\'application'.tr, style: AppFonts.title(size: 15)),
          ]),
          const SizedBox(height: 4),
          Text('Choisissez la langue d\'affichage de Sahtek.'.tr,
              style: AppFonts.body(color: Colors.grey, size: 13)),
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (final l in _languages) ...[
                if (l != _languages.first) const Divider(height: 1),
                ListTile(
                  title: Text(l.native, style: AppFonts.bold(size: 15)),
                  subtitle: Text(l.name.tr, style: AppFonts.label(size: 12)),
                  trailing: current == l.code
                      ? const Icon(Icons.check_circle_rounded,
                          color: AppTheme.primary)
                      : Icon(Icons.circle_outlined,
                          color: Colors.grey.shade400),
                  onTap: () => _select(context, l.code),
                ),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

/// Bouton d'accès aux paramètres — à placer à côté du bouton de déconnexion.
class SettingsIconButton extends StatelessWidget {
  const SettingsIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.settings_rounded, color: Colors.white),
      tooltip: 'Paramètres'.tr,
      onPressed: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const SettingsScreen())),
    );
  }
}
