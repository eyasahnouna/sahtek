import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'strings_ar.dart';

// ── Langue de l'application ───────────────────────────────────────────────────
//  Le français est la langue source : les textes restent écrits en français dans
//  le code et sont traduits à l'affichage via `'Texte'.tr`.
class L10n {
  static const supportedLocales = [Locale('fr'), Locale('ar')];

  static String _lang = 'fr';
  static String get lang => _lang;
  static bool get isArabic => _lang == 'ar';

  /// Locale à passer à `DateFormat`.
  static String get dateLocale => isArabic ? 'ar' : 'fr_FR';

  static String translate(String fr) =>
      isArabic ? (kArabicStrings[fr] ?? fr) : fr;
}

extension L10nString on String {
  /// Traduction du texte français dans la langue courante.
  String get tr => L10n.translate(this);

  /// Traduction avec paramètres : `'Jour {day}'.trp({'day': 3})`.
  String trp(Map<String, Object?> params) {
    var s = tr;
    params.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
    return s;
  }
}

class LocaleProvider extends ChangeNotifier {
  static const _prefKey = 'app_language';

  String get code => L10n.lang;
  Locale get locale => Locale(L10n.lang);

  /// À appeler avant `runApp` pour démarrer directement dans la bonne langue.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved == 'fr' || saved == 'ar') L10n._lang = saved!;
  }

  Future<void> setLanguage(String code) async {
    if (code == L10n._lang) return;
    L10n._lang = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, code);
  }
}
