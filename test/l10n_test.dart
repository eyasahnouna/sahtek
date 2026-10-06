import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:sahtek/l10n/l10n.dart';
import 'package:sahtek/l10n/strings_ar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocaleProvider().setLanguage('fr');
  });

  test('le français reste inchangé', () {
    expect('Rappels'.tr, 'Rappels');
    expect('Jour {day}'.trp({'day': 3}), 'Jour 3');
  });

  test('l\'arabe traduit les textes et remplace les paramètres', () async {
    await LocaleProvider().setLanguage('ar');
    expect('Rappels'.tr, 'التذكيرات');
    expect('Jour {day}'.trp({'day': 3}), 'اليوم 3');
    // Un texte sans traduction (ex : libellé saisi par l'utilisateur) est conservé.
    expect('avant sport'.tr, 'avant sport');
  });

  test('la langue choisie est mémorisée', () async {
    await LocaleProvider().setLanguage('ar');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_language'), 'ar');

    final reloaded = LocaleProvider();
    await reloaded.load();
    expect(reloaded.code, 'ar');
  });

  test('chaque traduction garde les mêmes {paramètres} que le français', () {
    final param = RegExp(r'\{\w+\}');
    List<String?> params(String s) =>
        param.allMatches(s).map((m) => m.group(0)).toList()..sort();
    kArabicStrings.forEach((fr, ar) {
      expect(params(ar), params(fr), reason: fr);
    });
  });

  test('les dates se formatent en arabe', () async {
    await initializeDateFormatting('ar', null);
    await LocaleProvider().setLanguage('ar');
    final s = DateFormat('d MMMM yyyy', L10n.dateLocale).format(DateTime(2026, 10, 5));
    expect(s, contains('أكتوبر'));
  });
}
