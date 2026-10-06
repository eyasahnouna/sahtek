import 'package:flutter/material.dart' show TimeOfDay;

import '../models/meal_entry.dart';
import '../providers/app_provider.dart';

enum VoiceField { glycemie, dose }

/// Une information dictée, rattachée à un créneau du journal.
class VoiceItem {
  /// Créneau fixe (`bkf_mesure`, `lunch_dose`…) ou [AppProvider.spontaneousSlot].
  String slotId;
  final VoiceField field;

  /// `null` quand seule l'heure a été dictée (« j'ai fait une mesure à 7h30 »).
  final double? value;
  final GlycemieMode mode;
  TimeOfDay? time;

  VoiceItem({
    required this.slotId,
    required this.field,
    this.value,
    this.mode = GlycemieMode.directe,
    this.time,
  });

  @override
  String toString() => '$slotId ${field.name}=$value ${mode.name} '
      '${time == null ? '' : '${time!.hour}:${time!.minute}'}';
}

/// Créneaux du journal (mêmes identifiants que dans `home_screen.dart`).
class VoiceSlots {
  static const bkfMesure   = 'bkf_mesure';
  static const bkfDose     = 'bkf_dose';
  static const bkfAfter    = 'bkf_after';
  static const lunchMesure = 'lunch_mesure';
  static const lunchDose   = 'lunch_dose';
  static const lunchAfter  = 'lunch_after';
  static const dinerMesure = 'diner_mesure';
  static const dinerDose   = 'diner_dose';
  static const dinerAfter  = 'diner_after';
  static const bedtime     = 'bedtime';
  static const spontaneous = AppProvider.spontaneousSlot;

  static const glycemie = [
    bkfMesure, bkfAfter, lunchMesure, lunchAfter,
    dinerMesure, dinerAfter, bedtime, spontaneous,
  ];
  static const dose = [bkfDose, lunchDose, dinerDose, bedtime];
}

enum _Place { bkf, lunch, dinner, bed }

enum _K {
  num, time, after2h, place, fasting, spont, before, after, meal,
  doseKw, doseUnit, measureKw, glyUnit, mmol, other,
}

class _Tok {
  final _K k;
  final String raw;
  final TimeOfDay? time;
  final _Place? place;
  const _Tok(this.k, this.raw, {this.time, this.place});
}

// ─────────────────────────────────────────────────────────────────────────────
//  VoiceEntryParser
//  Transforme une phrase dictée (français, anglais ou arabe) en valeurs à
//  ranger dans le journal. Analyse locale par mots-clés : aucun appel réseau.
//
//  Le contexte se propage d'une valeur à la suivante : « petit déjeuner dose
//  12, deux heures après 1,60 » → la 2ᵉ valeur va dans « après petit déj. 2h ».
//  Sans repas cité, le créneau est déduit de l'heure dictée (ou de l'heure
//  courante).
// ─────────────────────────────────────────────────────────────────────────────
class VoiceEntryParser {
  static List<VoiceItem> parse(String transcript, {TimeOfDay? now}) {
    final clock = now ?? TimeOfDay.now();
    final words = _normalize(transcript)
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final toks = _scan(_wordsToDigits(words));

    final items = <VoiceItem>[];
    final usedGlycemie = <String>{};

    _Place? place;
    var placeExplicit = false;
    bool? after;                 // true = « 2 h après le repas »
    var afterFresh = false;      // `after` posé depuis la dernière valeur
    VoiceField? kind;
    TimeOfDay? time;
    var spont = false;
    int? relIdx;
    var relAfter = false;

    VoiceItem? last;
    var lastInferred = false;
    var lastAfter = false;
    var quiet = false;           // aucun mot-clé depuis la dernière valeur

    void emit(VoiceField f, double? value, {bool mmol = false}) {
      var v = value;
      var mode = GlycemieMode.directe;
      if (f == VoiceField.glycemie && v != null) {
        if (mmol || (v > 7 && v <= 35)) {
          mode = GlycemieMode.convertie;              // mmol/L
        } else if (v > 35) {
          v = double.parse((v / 100).toStringAsFixed(2)); // mg/dL → g/L
        }
      }

      String slot;
      var t = time;
      var inferred = false;
      if (f == VoiceField.glycemie && spont) {
        slot = VoiceSlots.spontaneous;
        t ??= clock;
      } else {
        if (place == null || (!placeExplicit && t != null)) {
          final p = _placeAt(t ?? clock);
          if (p != place && !afterFresh) after = null;
          place = p;
          inferred = true;
        }
        slot = _slot(place!, f, after == true);
        // Deux glycémies pour le même créneau : la 2ᵉ devient spontanée
        if (f == VoiceField.glycemie && v != null && !usedGlycemie.add(slot)) {
          slot = VoiceSlots.spontaneous;
          t ??= clock;
        }
      }
      last = VoiceItem(slotId: slot, field: f, value: v, mode: mode, time: t);
      lastInferred = inferred;
      lastAfter = after == true;
      items.add(last!);
    }

    for (var i = 0; i < toks.length; i++) {
      final tok = toks[i];
      final hasRel = relIdx != null && i - relIdx <= 3;
      switch (tok.k) {
        case _K.other:
        case _K.glyUnit:
        case _K.mmol:
          continue;
        case _K.before:
        case _K.after:
          relIdx = i;
          relAfter = tok.k == _K.after;
        case _K.place:
          if (hasRel) {
            after = relAfter;
            afterFresh = true;
          } else if (place != tok.place) {
            after = null;
          }
          place = tok.place;
          placeExplicit = true;
          spont = false;
        case _K.meal:
          if (hasRel) {
            after = relAfter;
            afterFresh = true;
          }
        case _K.fasting:
          place = _Place.bkf;
          placeExplicit = true;
          after = false;
          spont = false;
        case _K.after2h:
          after = true;
          afterFresh = true;
        case _K.spont:
          spont = true;
        case _K.measureKw:
          kind = VoiceField.glycemie;
        case _K.doseKw:
        case _K.doseUnit:
          // « une mesure à 7h30 … puis la dose » : l'heure revient à la mesure
          if (time != null && kind == VoiceField.glycemie) {
            emit(VoiceField.glycemie, null);
            time = null;
          }
          kind = VoiceField.dose;
        case _K.time:
          final l = last;
          if (l != null && quiet && l.time == null) {
            // « j'ai mesuré 1,10 à 7h30 » : l'heure suit la valeur
            l.time = tok.time;
            if (lastInferred && l.slotId != VoiceSlots.spontaneous) {
              place = _placeAt(tok.time!);
              l.slotId = _slot(place!, l.field, lastAfter);
              if (l.field == VoiceField.glycemie) usedGlycemie.add(l.slotId);
            }
          } else {
            time = tok.time;
          }
          continue;
        case _K.num:
          final v = double.tryParse(tok.raw) ?? 0;
          final next = i + 1 < toks.length ? toks[i + 1] : null;
          // « 2 mesures », « 3 fois » : un décompte, pas une valeur
          if (v <= 0 ||
              (!tok.raw.contains('.') &&
                  next != null &&
                  (next.k == _K.measureKw || _countWords.contains(next.raw)))) {
            continue;
          }
          final VoiceField f;
          if (next?.k == _K.doseUnit) {
            f = VoiceField.dose;
          } else if (next?.k == _K.glyUnit || next?.k == _K.mmol) {
            f = VoiceField.glycemie;
          } else {
            f = kind ??
                (tok.raw.contains('.') || v >= 40
                    ? VoiceField.glycemie
                    : VoiceField.dose);
          }
          emit(f, v, mmol: next?.k == _K.mmol);
          if (next?.k == _K.doseUnit) i++;
          kind = null;
          time = null;
          spont = false;
          afterFresh = false;
          quiet = true;
          continue;
      }
      quiet = false;
    }
    if (time != null && kind == VoiceField.glycemie) {
      emit(VoiceField.glycemie, null);
    }
    return items;
  }

  static _Place _placeAt(TimeOfDay t) {
    final m = t.hour * 60 + t.minute;
    if (m < 11 * 60) return _Place.bkf;
    if (m < 17 * 60) return _Place.lunch;
    if (m < 22 * 60) return _Place.dinner;
    return _Place.bed;
  }

  static String _slot(_Place p, VoiceField f, bool after) {
    if (p == _Place.bed) return VoiceSlots.bedtime;
    final prefix = switch (p) {
      _Place.bkf   => 'bkf',
      _Place.lunch => 'lunch',
      _                => 'diner',
    };
    if (f == VoiceField.dose) return '${prefix}_dose';
    return after ? '${prefix}_after' : '${prefix}_mesure';
  }

  // ── Normalisation du texte ─────────────────────────────────────────────────

  static const _latin = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'î': 'i', 'ï': 'i', 'ô': 'o', 'ö': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'œ': 'oe',
  };

  static String _normalize(String input) {
    var s = input.toLowerCase();
    // Chiffres arabes-indiens → chiffres latins
    s = s.replaceAllMapped(RegExp('[٠-٩]'),
        (m) => '${m[0]!.codeUnitAt(0) - 0x660}');
    s = s.replaceAllMapped(RegExp('[۰-۹]'),
        (m) => '${m[0]!.codeUnitAt(0) - 0x6F0}');
    s = s.replaceAll('٫', '.').replaceAll('،', ' ');
    // Arabe : voyelles brèves, tatweel, variantes de alif / ta marbuta / ya
    s = s.replaceAll(RegExp('[ً-ٰٟـ]'), '');
    s = s.replaceAll(RegExp('[أإآٱ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');
    s = s.replaceAllMapped(RegExp('[àâäéèêëîïôöùûüçœ]'), (m) => _latin[m[0]]!);
    s = s.replaceAllMapped(RegExp(r'\b([ap])\.? ?m\.(?!\w)'), (m) => '${m[1]}m');
    // « 7h30 », « 7:30 » → « 7 h 30 »
    s = s.replaceAllMapped(RegExp(r'(\d{1,2}) ?h ?(\d{2})?(?![a-z0-9])'),
        (m) => '${m[1]} h ${m[2] ?? ''} ');
    s = s.replaceAllMapped(RegExp(r'(\d{1,2}):(\d{2})'),
        (m) => '${m[1]} h ${m[2]} ');
    s = s.replaceAllMapped(RegExp(r'(\d),(\d)'), (m) => '${m[1]}.${m[2]}');
    s = s.replaceAll(RegExp(r'(?<!\d)\.|\.(?!\d)'), ' ');
    s = s.replaceAll(RegExp('[,;:!?()"«»\'’`\\-–—/؟؛]'), ' ');
    // « 12ui », « 1g20 » → séparer chiffres et lettres
    s = s.replaceAllMapped(RegExp(r'(\d)([a-zء-ي])'),
        (m) => '${m[1]} ${m[2]}');
    s = s.replaceAllMapped(RegExp(r'([a-zء-ي])(\d)'),
        (m) => '${m[1]} ${m[2]}');
    return s;
  }

  static bool _isArabic(String w) => RegExp('[ء-ي]').hasMatch(w);

  /// Formes d'un mot arabe sans ses préfixes (و، ب، ل، ال…), mot brut d'abord.
  static Iterable<String> _variants(String w) sync* {
    yield w;
    if (!_isArabic(w)) return;
    if (w.length > 3 && (w.startsWith('و') || w.startsWith('ف'))) {
      yield w.substring(1);
    }
    final m = RegExp('^[وف]?[بلك]?(?:ال|ل)?(.{3,})\$').firstMatch(w);
    if (m != null && m[1] != w) yield m[1]!;
  }

  // ── Nombres en toutes lettres ──────────────────────────────────────────────

  static const _units = <String, int>{
    // français
    'zero': 0, 'deux': 2, 'trois': 3, 'quatre': 4, 'cinq': 5, 'six': 6,
    'sept': 7, 'huit': 8, 'neuf': 9, 'onze': 11, 'douze': 12, 'treize': 13,
    'quatorze': 14, 'quinze': 15, 'seize': 16,
    // anglais
    'two': 2, 'three': 3, 'four': 4, 'five': 5, 'seven': 7, 'eight': 8,
    'nine': 9, 'eleven': 11, 'twelve': 12, 'thirteen': 13, 'fourteen': 14,
    'fifteen': 15, 'sixteen': 16, 'seventeen': 17, 'eighteen': 18,
    'nineteen': 19,
    // arabe (après normalisation)
    'صفر': 0, 'واحد': 1, 'واحده': 1, 'احد': 1, 'احدي': 1,
    'اثنين': 2, 'اثنان': 2, 'اثنتين': 2, 'اثنا': 2, 'اثني': 2, 'زوز': 2,
    'ثلاثه': 3, 'ثلاث': 3, 'تلاثه': 3, 'اربعه': 4, 'اربع': 4,
    'خمسه': 5, 'خمس': 5, 'سته': 6, 'ست': 6, 'سبعه': 7, 'سبع': 7,
    'ثمانيه': 8, 'ثماني': 8, 'ثمنيه': 8, 'تسعه': 9, 'تسع': 9,
    'عشره': 10, 'عشر': 10,
  };

  static const _tens = <String, int>{
    'dix': 10, 'vingt': 20, 'trente': 30, 'quarante': 40, 'cinquante': 50,
    'soixante': 60,
    'ten': 10, 'twenty': 20, 'thirty': 30, 'forty': 40, 'fifty': 50,
    'sixty': 60, 'seventy': 70, 'eighty': 80, 'ninety': 90,
    'عشرين': 20, 'عشرون': 20, 'ثلاثين': 30, 'ثلاثون': 30, 'اربعين': 40,
    'اربعون': 40, 'خمسين': 50, 'خمسون': 50, 'ستين': 60, 'ستون': 60,
  };

  static const _one = {'un', 'une', 'one'};

  /// « un / une / one » ne sont convertis que devant ces mots (sinon article).
  static const _afterOne = {
    'virgule', 'point', 'comma', 'g', 'gr', 'gramme', 'grammes', 'gram',
    'grams', 'unite', 'unit', 'ui',
  };

  static bool _combines(int tens, int u, bool french) {
    if (tens == 10) return french && u >= 7 && u <= 9;        // dix-sept
    if (french && (tens == 60 || tens == 80)) return u >= 1 && u <= 19;
    return u >= 1 && u <= 9;
  }

  static List<String> _wordsToDigits(List<String> t) {
    final out = <String>[];
    for (var i = 0; i < t.length; i++) {
      final w = t[i];
      final next = i + 1 < t.length ? t[i + 1] : null;

      if (_one.contains(w) && next != null && _afterOne.contains(next)) {
        out.add('1');
        continue;
      }

      var tens = _tens[w];
      var at = i;
      if (w == 'quatre' && next != null && next.startsWith('vingt')) {
        tens = 80;
        at = i + 1;
      }
      if (tens != null && !_isArabic(w)) {
        final french = w != 'ten' && !w.endsWith('ty');
        var j = at + 1;
        if (j < t.length && tens >= 20 && (t[j] == 'et' || t[j] == 'and')) j++;
        int? u;
        if (j < t.length) {
          u = _units[t[j]] ?? (t[j] == 'dix' ? 10 : null) ??
              (_one.contains(t[j]) ? 1 : null);
          if (u != null && _isArabic(t[j])) u = null;
        }
        if (u != null && _combines(tens, u, french)) {
          out.add('${tens + u}');
          i = j;
        } else {
          out.add('$tens');
          i = at;
        }
        continue;
      }
      if (tens != null) {
        out.add('$tens');
        continue;
      }

      final u = _units[w];
      if (u != null) {
        if (_isArabic(w) && u < 10 && next != null) {
          final afterHour =
              i > 0 && _variants(t[i - 1]).any(_arHour.contains);
          final nt = next.startsWith('و') ? _tens[next.substring(1)] : null;
          if (nt != null && !afterHour) {            // خمسه وعشرين
            out.add('${nt + u}');
            i++;
            continue;
          }
          if (next == 'عشر' || next == 'عشره') {     // خمسه عشر
            out.add('${10 + u}');
            i++;
            continue;
          }
        }
        out.add('$u');
        continue;
      }
      out.add(w);
    }
    return out;
  }

  // ── Mots-clés ──────────────────────────────────────────────────────────────

  static const _phrases = <String, (_K, _Place?)>{
    'petit dejeuner': (_K.place, _Place.bkf),
    'petit dej': (_K.place, _Place.bkf),
    'ptit dej': (_K.place, _Place.bkf),
    'a jeun': (_K.fasting, null),
    'empty stomach': (_K.fasting, null),
    'plus tard': (_K.after, null),
  };

  static const _words = <String, (_K, _Place?)>{
    // repas / moments de la journée
    'breakfast': (_K.place, _Place.bkf), 'matin': (_K.place, _Place.bkf),
    'morning': (_K.place, _Place.bkf),
    'فطور': (_K.place, _Place.bkf), 'افطار': (_K.place, _Place.bkf),
    'صباح': (_K.place, _Place.bkf), 'صبح': (_K.place, _Place.bkf),
    'dejeuner': (_K.place, _Place.lunch), 'dejeune': (_K.place, _Place.lunch),
    'midi': (_K.place, _Place.lunch), 'lunch': (_K.place, _Place.lunch),
    'غداء': (_K.place, _Place.lunch), 'غدا': (_K.place, _Place.lunch),
    'ظهر': (_K.place, _Place.lunch),
    'diner': (_K.place, _Place.dinner), 'dine': (_K.place, _Place.dinner),
    'souper': (_K.place, _Place.dinner), 'soir': (_K.place, _Place.dinner),
    'dinner': (_K.place, _Place.dinner), 'supper': (_K.place, _Place.dinner),
    'evening': (_K.place, _Place.dinner),
    'عشاء': (_K.place, _Place.dinner), 'عشا': (_K.place, _Place.dinner),
    'مساء': (_K.place, _Place.dinner),
    'coucher': (_K.place, _Place.bed), 'dormir': (_K.place, _Place.bed),
    'nuit': (_K.place, _Place.bed), 'bedtime': (_K.place, _Place.bed),
    'bed': (_K.place, _Place.bed), 'sleep': (_K.place, _Place.bed),
    'sleeping': (_K.place, _Place.bed), 'night': (_K.place, _Place.bed),
    'نوم': (_K.place, _Place.bed), 'ليل': (_K.place, _Place.bed),
    // à jeun
    'jeun': (_K.fasting, null), 'fasting': (_K.fasting, null),
    'صائم': (_K.fasting, null), 'صايم': (_K.fasting, null),
    'صيام': (_K.fasting, null), 'ريق': (_K.fasting, null),
    // mesure spontanée
    'spontane': (_K.spont, null), 'spontanee': (_K.spont, null),
    'aleatoire': (_K.spont, null), 'hasard': (_K.spont, null),
    'random': (_K.spont, null), 'spontaneous': (_K.spont, null),
    'عشوائي': (_K.spont, null), 'عشوائيه': (_K.spont, null),
    'تلقائي': (_K.spont, null), 'تلقائيه': (_K.spont, null),
    'عفوي': (_K.spont, null), 'عفويه': (_K.spont, null),
    // avant / après
    'avant': (_K.before, null), 'before': (_K.before, null),
    'قبل': (_K.before, null),
    'apres': (_K.after, null), 'after': (_K.after, null),
    'later': (_K.after, null), 'بعد': (_K.after, null),
    // repas (sans préciser lequel)
    'repas': (_K.meal, null), 'mange': (_K.meal, null),
    'manger': (_K.meal, null), 'meal': (_K.meal, null),
    'eating': (_K.meal, null), 'eaten': (_K.meal, null),
    'ate': (_K.meal, null), 'اكل': (_K.meal, null),
    'اكلت': (_K.meal, null), 'وجبه': (_K.meal, null),
    // insuline
    'dose': (_K.doseKw, null), 'doses': (_K.doseKw, null),
    'insuline': (_K.doseKw, null), 'insulin': (_K.doseKw, null),
    'injection': (_K.doseKw, null), 'injections': (_K.doseKw, null),
    'injecte': (_K.doseKw, null), 'injected': (_K.doseKw, null),
    'pique': (_K.doseKw, null), 'piqure': (_K.doseKw, null),
    'bolus': (_K.doseKw, null), 'basal': (_K.doseKw, null),
    'جرعه': (_K.doseKw, null), 'انسولين': (_K.doseKw, null),
    'حقنه': (_K.doseKw, null),
    'unite': (_K.doseUnit, null), 'unites': (_K.doseUnit, null),
    'unit': (_K.doseUnit, null), 'units': (_K.doseUnit, null),
    'ui': (_K.doseUnit, null), 'وحده': (_K.doseUnit, null),
    'وحدات': (_K.doseUnit, null),
    // glycémie
    'mesure': (_K.measureKw, null), 'mesures': (_K.measureKw, null),
    'glycemie': (_K.measureKw, null), 'sucre': (_K.measureKw, null),
    'taux': (_K.measureKw, null), 'hypoglycemie': (_K.measureKw, null),
    'hyperglycemie': (_K.measureKw, null), 'hypo': (_K.measureKw, null),
    'hyper': (_K.measureKw, null), 'glucose': (_K.measureKw, null),
    'measure': (_K.measureKw, null), 'measured': (_K.measureKw, null),
    'measurement': (_K.measureKw, null), 'measurements': (_K.measureKw, null),
    'reading': (_K.measureKw, null), 'readings': (_K.measureKw, null),
    'sugar': (_K.measureKw, null), 'glycemia': (_K.measureKw, null),
    'hypoglycemia': (_K.measureKw, null),
    'hyperglycemia': (_K.measureKw, null),
    'قياس': (_K.measureKw, null), 'قياسات': (_K.measureKw, null),
    'سكر': (_K.measureKw, null), 'سكري': (_K.measureKw, null),
    'تحليل': (_K.measureKw, null), 'قست': (_K.measureKw, null),
    'g': (_K.glyUnit, null), 'gr': (_K.glyUnit, null),
    'gramme': (_K.glyUnit, null), 'grammes': (_K.glyUnit, null),
    'gram': (_K.glyUnit, null), 'grams': (_K.glyUnit, null),
    'mg': (_K.glyUnit, null), 'غرام': (_K.glyUnit, null),
    'mmol': (_K.mmol, null), 'millimole': (_K.mmol, null),
    'millimoles': (_K.mmol, null),
  };

  static const _countWords = {
    'doses', 'injections', 'fois', 'times', 'مرات',
  };
  static const _decimalWords = {'virgule', 'point', 'comma', 'فاصله', 'فاصل'};
  static const _gramWords = {'g', 'gr', 'gramme', 'grammes', 'gram', 'grams', 'غرام'};
  static const _hourWords = {'h', 'heure', 'heures', 'hour', 'hours', 'hrs', 'ساعات'};
  static const _atWords = {'a', 'at', 'vers', 'around'};
  static const _arHour = {'ساعه'};
  static const _arTwoHours = {'ساعتين', 'ساعتان'};
  static const _arPm = {'مساء', 'مساءا', 'ليلا', 'عشيه'};
  static const _arOrdinals = <String, int>{
    'واحده': 1, 'ثانيه': 2, 'ثالثه': 3, 'رابعه': 4, 'خامسه': 5, 'سادسه': 6,
    'سابعه': 7, 'ثامنه': 8, 'تاسعه': 9, 'عاشره': 10, 'حاديه': 1,
  };
  static const _arFractions = <String, int>{'نصف': 30, 'ربع': 15, 'ثلث': 20};

  static final _numRe = RegExp(r'^\d+(\.\d+)?$');
  static final _intRe = RegExp(r'^\d+$');

  static bool _isInt(String w) => _intRe.hasMatch(w);

  static (_K, _Place?)? _lookup(String w) {
    for (final v in _variants(w)) {
      final hit = _words[v];
      if (hit != null) return hit;
    }
    return null;
  }

  /// Regroupe les mots en jetons typés : nombres, heures, mots-clés.
  static List<_Tok> _scan(List<String> w) {
    final out = <_Tok>[];
    final n = w.length;
    String? at(int i) => i >= 0 && i < n ? w[i] : null;
    bool isAfterWord(String? s) =>
        s != null && (_lookup(s)?.$1 == _K.after || s == 'tard');
    bool isUnitWord(String? s) {
      final k = s == null ? null : _lookup(s)?.$1;
      return k == _K.doseUnit || k == _K.glyUnit || k == _K.mmol ||
          (s != null && _decimalWords.contains(s));
    }

    var i = 0;
    while (i < n) {
      final cur = w[i];

      // ── « 2 heures après », « ساعتين » ────────────────────────────────────
      if (_variants(cur).any(_arTwoHours.contains)) {
        out.add(_Tok(_K.after2h, cur));
        i++;
        continue;
      }
      if (cur == '2' && _hourWords.contains(at(i + 1))) {
        var afterNear = isAfterWord(at(i + 2)) ||
            (at(i + 2) == 'plus' && at(i + 3) == 'tard');
        for (var j = i - 1; j >= 0 && j >= i - 4 && !afterNear; j--) {
          afterNear = isAfterWord(w[j]);
        }
        final nx = at(i + 2);
        final looksLikeTime = _atWords.contains(at(i - 1)) ||
            (nx != null && _isInt(nx) && nx.length == 2 && !isUnitWord(at(i + 3)));
        if (afterNear || !looksLikeTime) {
          out.add(_Tok(_K.after2h, cur));
          i += 2;
          continue;
        }
      }

      // ── Heure : « 7 h 30 », « 7 heures et demie », « 7 pm » ───────────────
      if (_isInt(cur) && int.parse(cur) <= 23) {
        var h = int.parse(cur);
        var m = 0;
        var j = -1;
        if (_hourWords.contains(at(i + 1))) {
          j = i + 2;
          final a = at(j), b = at(j + 1), c = at(j + 2);
          if (a != null && _isInt(a) && int.parse(a) < 60 && !isUnitWord(b)) {
            m = int.parse(a);
            j++;
            if (const {'minutes', 'minute', 'min', 'mn'}.contains(at(j))) j++;
          } else if (a == 'et' && (b == 'demie' || b == 'demi')) {
            m = 30;
            j += 2;
          } else if (a == 'et' && b == 'quart') {
            m = 15;
            j += 2;
          } else if (a == 'moins' && (b == 'le' || b == 'un') && c == 'quart') {
            h = (h + 23) % 24;
            m = 45;
            j += 3;
          }
        } else if (at(i + 1) == 'o' && at(i + 2) == 'clock') {
          j = i + 3;
        } else if (at(i + 1) == 'am' || at(i + 1) == 'pm') {
          j = i + 1;
        } else if (_isInt(at(i + 1) ?? '') && at(i + 1)!.length == 2 &&
            int.parse(at(i + 1)!) < 60 &&
            (at(i + 2) == 'am' || at(i + 2) == 'pm')) {
          m = int.parse(at(i + 1)!);
          j = i + 2;
        }
        if (j != -1) {
          if (at(j) == 'am' || at(j) == 'pm') {
            if (at(j) == 'pm' && h < 12) h += 12;
            if (at(j) == 'am' && h == 12) h = 0;
            j++;
          } else if (h < 12 &&
              ((at(j) == 'du' && at(j + 1) == 'soir') ||
                  (at(j) == 'de' && at(j + 2) == 'apres' && at(j + 3) == 'midi'))) {
            h += 12;
          }
          out.add(_Tok(_K.time, cur, time: TimeOfDay(hour: h, minute: m)));
          i = j;
          continue;
        }
      }
      if (cur == 'half' && at(i + 1) == 'past' && _isInt(at(i + 2) ?? '')) {
        var h = int.parse(w[i + 2]) % 24;
        var j = i + 3;
        if (at(j) == 'pm' && h < 12) h += 12;
        if (at(j) == 'am' || at(j) == 'pm') j++;
        out.add(_Tok(_K.time, cur, time: TimeOfDay(hour: h, minute: 30)));
        i = j;
        continue;
      }

      // ── Heure en arabe : « الساعه 7 و 30 », « الساعه السابعه والنصف » ──────
      if (_variants(cur).any(_arHour.contains) && at(i + 1) != null) {
        final hw = w[i + 1];
        int? h = _isInt(hw) ? int.parse(hw) : null;
        var j = i + 2;
        if (h == null) {
          for (final v in _variants(hw)) {
            h ??= _arOrdinals[v];
          }
          if (h != null && (at(j) == '10' || at(j) == 'عشره')) {
            h += 10;
            j++;
          }
        }
        if (h != null && h <= 23) {
          var m = 0;
          var a = at(j);
          if (a == 'و' && at(j + 1) != null) {
            j++;
            a = 'و${w[j]}';
          }
          if (a == 'الا' && at(j + 1) != null) {
            for (final v in _variants(w[j + 1])) {
              final f = _arFractions[v];
              if (f != null && m == 0) {
                h = (h! + 23) % 24;
                m = 60 - f;
                j += 2;
              }
            }
          } else if (a != null && a.startsWith('و') && a.length > 1) {
            final rest = a.substring(1);
            int? mm = _isInt(rest) ? int.parse(rest) : null;
            for (final v in _variants(rest)) {
              mm ??= _arFractions[v];
            }
            if (mm != null && mm < 60) {
              m = mm;
              j++;
              if (const {'دقيقه', 'دقائق', 'دقايق'}.contains(at(j))) j++;
            }
          }
          final pm = at(j);
          if (pm != null && h! < 12 && _variants(pm).any(_arPm.contains)) {
            h += 12;
          }
          out.add(_Tok(_K.time, cur, time: TimeOfDay(hour: h!, minute: m)));
          i = j;
          continue;
        }
      }

      // ── Nombres : « 1 virgule 2 », « 1 gramme 20 » ────────────────────────
      if (_numRe.hasMatch(cur)) {
        final a = at(i + 1), b = at(i + 2);
        if (_isInt(cur) && a != null && b != null && _isInt(b)) {
          if (_decimalWords.contains(a)) {
            out.add(_Tok(_K.num, '$cur.$b'));
            i += 3;
            continue;
          }
          if (_gramWords.contains(a) && b.length <= 2) {
            out.add(_Tok(_K.num, '$cur.$b'));
            out.add(_Tok(_K.glyUnit, a));
            i += 3;
            continue;
          }
        }
        out.add(_Tok(_K.num, cur));
        i++;
        continue;
      }

      // ── Mots-clés ─────────────────────────────────────────────────────────
      final phrase = at(i + 1) == null ? null : _phrases['$cur ${w[i + 1]}'];
      if (phrase != null) {
        out.add(_Tok(phrase.$1, '$cur ${w[i + 1]}', place: phrase.$2));
        i += 2;
        continue;
      }
      final hit = _lookup(cur);
      out.add(hit == null
          ? _Tok(_K.other, cur)
          : _Tok(hit.$1, cur, place: hit.$2));
      i++;
    }
    return out;
  }
}
