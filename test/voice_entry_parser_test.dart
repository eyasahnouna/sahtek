import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahtek/models/meal_entry.dart';
import 'package:sahtek/services/voice_entry_parser.dart';

void main() {
  const evening = TimeOfDay(hour: 20, minute: 15);
  List<VoiceItem> parse(String s, {TimeOfDay now = evening}) =>
      VoiceEntryParser.parse(s, now: now);

  void expectItem(VoiceItem it, String slot, VoiceField field, double? value,
      {TimeOfDay? time, GlycemieMode mode = GlycemieMode.directe}) {
    expect(it.slotId, slot, reason: '$it');
    expect(it.field, field, reason: '$it');
    expect(it.value, value, reason: '$it');
    expect(it.mode, mode, reason: '$it');
    if (time != null) expect(it.time, time, reason: '$it');
  }

  test('récit complet de la matinée en français', () {
    final r = parse(
        "j'ai fait une mesure à 7h30 de 1,10 et après j'ai mangé un petit "
        "déjeuner. Après le petit déjeuner j'ai fait la dose 12. Ensuite, "
        "après le jeûne de 2 heures, j'ai fait une hypoglycémie, deux mesures "
        "qui est 0,6, et après j'ai fait une mesure spontanée qui vaut 3,6");
    expect(r, hasLength(4));
    expectItem(r[0], VoiceSlots.bkfMesure, VoiceField.glycemie, 1.10,
        time: const TimeOfDay(hour: 7, minute: 30));
    expectItem(r[1], VoiceSlots.bkfDose, VoiceField.dose, 12);
    expectItem(r[2], VoiceSlots.bkfAfter, VoiceField.glycemie, 0.6);
    expectItem(r[3], VoiceSlots.spontaneous, VoiceField.glycemie, 3.6,
        time: evening);
  });

  test("l'heure seule est rangée sur la mesure quand aucune valeur n'est dite", () {
    final r = parse("j'ai fait une mesure à 7h30 puis la dose 12 unités");
    expect(r, hasLength(2));
    expectItem(r[0], VoiceSlots.bkfMesure, VoiceField.glycemie, null,
        time: const TimeOfDay(hour: 7, minute: 30));
    expectItem(r[1], VoiceSlots.bkfDose, VoiceField.dose, 12);
  });

  test("l'heure dite après la valeur choisit le créneau", () {
    final r = parse("j'ai mesuré 1,25 à 12h45");
    expect(r, hasLength(1));
    expectItem(r[0], VoiceSlots.lunchMesure, VoiceField.glycemie, 1.25,
        time: const TimeOfDay(hour: 12, minute: 45));
  });

  test('nombres en toutes lettres et unités', () {
    final r = parse('à jeun un gramme vingt, petit déjeuner dix-sept unités, '
        'deux heures après zéro virgule neuf');
    expect(r, hasLength(3));
    expectItem(r[0], VoiceSlots.bkfMesure, VoiceField.glycemie, 1.20);
    expectItem(r[1], VoiceSlots.bkfDose, VoiceField.dose, 17);
    expectItem(r[2], VoiceSlots.bkfAfter, VoiceField.glycemie, 0.9);
  });

  test('plusieurs repas, avant / après, coucher', () {
    final r = parse('avant le déjeuner glycémie 1,3 dose 8 unités '
        'après le déjeuner 1,8 au dîner 1,1 et 10 unités '
        'avant de dormir 1,4');
    expect(r, hasLength(6));
    expectItem(r[0], VoiceSlots.lunchMesure, VoiceField.glycemie, 1.3);
    expectItem(r[1], VoiceSlots.lunchDose, VoiceField.dose, 8);
    expectItem(r[2], VoiceSlots.lunchAfter, VoiceField.glycemie, 1.8);
    expectItem(r[3], VoiceSlots.dinerMesure, VoiceField.glycemie, 1.1);
    expectItem(r[4], VoiceSlots.dinerDose, VoiceField.dose, 10);
    expectItem(r[5], VoiceSlots.bedtime, VoiceField.glycemie, 1.4);
  });

  test('sans repas ni heure, le créneau suit l\'heure courante', () {
    final r = parse('ma glycémie est 1,5',
        now: const TimeOfDay(hour: 8, minute: 0));
    expectItem(r.single, VoiceSlots.bkfMesure, VoiceField.glycemie, 1.5);
  });

  test('mg/dL et mmol/L', () {
    final r = parse('à jeun 110, déjeuner 6,5 mmol');
    expectItem(r[0], VoiceSlots.bkfMesure, VoiceField.glycemie, 1.10);
    expectItem(r[1], VoiceSlots.lunchMesure, VoiceField.glycemie, 6.5,
        mode: GlycemieMode.convertie);
  });

  test('anglais', () {
    final r = parse('I measured my sugar at 7:30 am it was 1.1 then after '
        'breakfast I took 12 units, two hours later it was 0.6 '
        'and a random reading of 3.6');
    expect(r, hasLength(4));
    expectItem(r[0], VoiceSlots.bkfMesure, VoiceField.glycemie, 1.1,
        time: const TimeOfDay(hour: 7, minute: 30));
    expectItem(r[1], VoiceSlots.bkfDose, VoiceField.dose, 12);
    expectItem(r[2], VoiceSlots.bkfAfter, VoiceField.glycemie, 0.6);
    expectItem(r[3], VoiceSlots.spontaneous, VoiceField.glycemie, 3.6);
  });

  test('arabe', () {
    final r = parse('قست السكر على الريق الساعة 7 و 30 وكان 1.1 '
        'وبعد فطور الصباح أخذت جرعة 12 وحدة '
        'وبعد ساعتين قياس 0.6 ثم قياس عشوائي 3.6');
    expect(r, hasLength(4));
    expectItem(r[0], VoiceSlots.bkfMesure, VoiceField.glycemie, 1.1,
        time: const TimeOfDay(hour: 7, minute: 30));
    expectItem(r[1], VoiceSlots.bkfDose, VoiceField.dose, 12);
    expectItem(r[2], VoiceSlots.bkfAfter, VoiceField.glycemie, 0.6);
    expectItem(r[3], VoiceSlots.spontaneous, VoiceField.glycemie, 3.6);
  });

  test('arabe : chiffres indiens, heure en lettres, repas du soir', () {
    final r = parse('قبل العشاء الساعة السابعة والنصف مساء السكر ١٫٤ '
        'والجرعة خمسة وعشرين وحدة');
    expect(r, hasLength(2));
    expectItem(r[0], VoiceSlots.dinerMesure, VoiceField.glycemie, 1.4,
        time: const TimeOfDay(hour: 19, minute: 30));
    expectItem(r[1], VoiceSlots.dinerDose, VoiceField.dose, 25);
  });

  test('texte sans valeur', () {
    expect(parse('bonjour, je me sens bien'), isEmpty);
    expect(parse(''), isEmpty);
  });
}
