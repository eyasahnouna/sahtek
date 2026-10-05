# Sahtek — Spécification complète de l'application

## Vue d'ensemble

**Sahtek** est une application mobile Flutter de **suivi glycémique pour diabétiques**.  
Elle permet au patient de journaliser sa glycémie, ses doses d'insuline et ses repas,  
de prendre des photos de repas, et de partager ses données avec son médecin.

---

## Stack technique

| Couche | Technologie |
|--------|-------------|
| Mobile | Flutter (Material 3, Dart) |
| Auth | Firebase Authentication (email + mot de passe) |
| Base de données | Cloud Firestore |
| Stockage images | Cloudinary (gratuit, sans carte bancaire) |
| Backend | Spring Boot sur Render (`sahtekbackend.onrender.com`) |
| Emails | Brevo (SMTP HTTP API) |
| Notifications | flutter_local_notifications (local, dans le téléphone) |
| State management | Provider |
| Charts | fl_chart |
| PDF | pdf + printing (avec zoom sur mobile via PdfPreview) |
| Police | Poppins (Google Fonts) |
| Langue | Français |

---

## Palette de couleurs

| Nom | Hex | Usage |
|-----|-----|-------|
| `primary` | `#0B8FAC` | Couleur principale — teal |
| `secondary` | `#00C9B1` | Accent — menthe |
| `bgColor` | `#F5F7FA` | Fond de l'app |
| `cardBg` | `#FFFFFF` | Fond des cartes |
| `danger` | `#E53935` | Erreurs, hypoglycémie, hyperglycémie |
| `warning` | `#FF9A3C` | Petit-déjeuner, couleur alerte |
| `success` | `#16A34A` | Normal, snack |
| Déjeuner | `#0B8FAC` | Couleur slot déjeuner |
| Dîner | `#7C3AED` | Couleur slot dîner |

### Seuils glycémiques
- **< 0.7 g/L** → Hypoglycémie (rouge)
- **0.7 – 1.6 g/L** → Normale (vert)
- **1.6 – 1.9 g/L** → Légèrement élevée (orange)
- **> 1.9 g/L** → Hyperglycémie (rouge)

---

## Architecture des fichiers

```
lib/
├── main.dart                  # Entry point, routing, splash, nav bar (5 onglets)
├── firebase_options.dart
│
├── models/
│   ├── day_record.dart        # Un jour de suivi (liste de MealEntry)
│   ├── meal_entry.dart        # Une mesure / dose / repas
│   ├── reminder.dart          # Rappel quotidien
│   ├── medical_note.dart
│   ├── glucose_reading.dart
│   └── insulin_dose.dart
│
├── screens/
│   ├── auth_screen.dart           # Connexion / Inscription
│   ├── profile_setup_screen.dart  # Wizard profil (3 étapes)
│   ├── home_screen.dart           # Journal journalier (écran principal)
│   ├── charts_screen.dart         # Graphiques glycémie/insuline
│   ├── dashboard_screen.dart      # Statistiques et résumés
│   ├── reminders_screen.dart      # Rappels quotidiens
│   ├── collaborators_screen.dart  # Partage médecin/patient
│   ├── friend_view_screen.dart    # Vue médecin sur patient + PDF
│   ├── pdf_viewer_screen.dart     # Visionneuse PDF avec zoom (PdfPreview)
│   └── add_reading_sheet.dart     # Bottom sheet ajout glycémie/insuline
│
├── services/
│   ├── firebase_service.dart      # Auth + Firestore
│   ├── image_storage_service.dart # Upload Cloudinary
│   ├── report_service.dart        # Génération PDF (buildPdfBytes)
│   ├── notification_service.dart  # Notifications locales planifiées
│   ├── email_service.dart         # Emails via Brevo
│   └── ocr_service.dart           # OCR lecture glucomètre
│
├── providers/
│   ├── app_provider.dart      # Provider principal (données journalières)
│   ├── reminder_provider.dart # Rappels (persistence SharedPreferences)
│   ├── insulin_provider.dart
│   └── glucose_provider.dart  # Lectures glycémie (Firestore)
│
├── widgets/
│   ├── sahtek_logo.dart       # Logo animé + AnimatedTap
│   ├── logout_button.dart
│   ├── dose_badge.dart
│   ├── meal_zone_card.dart
│   ├── metric_input_field.dart
│   ├── notification_toggle_button.dart
│   └── time_picker_tile.dart
│
└── utils/
    └── app_theme.dart         # Couleurs, typographie Poppins, ThemeData
```

---

## Modèles de données

### MealEntry (une entrée dans le journal)
```dart
class MealEntry {
  final String   id;
  final String   name;           // ex: "Petit déjeuner — dose"
  final MealType type;           // breakfast | lunch | dinner | snack | mesure
  final String?  slotId;
  double?        glycemie;       // en g/L
  GlycemieMode   glycemieMode;   // directe (g/L) ou convertie (mmol/L)
  double?        dose;           // insuline UI
  TimeOfDay?     mealTime;
  TimeOfDay?     doseTime;
  String?        observation;
  String?        imageUrl;       // URL Cloudinary
}
```

### DayRecord (une journée)
```dart
class DayRecord {
  final String     dateKey;   // "2025-06-26"
  List<MealEntry>  entries;
  double get totalDose;
  double get averageGlycemieAffichee;
}
```

---

## Écrans (5 onglets de navigation)

### 1. SplashScreen (automatique au démarrage)
- Fond dégradé teal → menthe
- Logo Sahtek animé (scale-in + pulsation glow)
- Texte "Sahtek / Votre santé, sécurisée" (slide up)
- Spinner de chargement
- Durée ~1.2s puis bascule vers AuthGate

### 2. AuthScreen — Connexion / Inscription
- 2 onglets : **Connexion** | **Inscription**
- Sélecteur de rôle : **Patient** / **Médecin**
- Logo Sahtek animé en haut
- Animation d'entrée (fade + slide), bouton AnimatedTap
- ClipRect autour de l'AnimatedContainer pour éviter l'overflow pendant la transition

### 3. ProfileSetupScreen — Wizard 3 étapes (une seule fois)
- Étape 1 : Âge, poids, sexe
- Étape 2 : Type de diabète (Type 1, 2, Gestationnel, Autre)
- Étape 3 : Médicaments (insulines + comprimés, liste prédéfinie)

### 4. HomeScreen — Journal journalier ⭐ (onglet 1)
**Slots fixes dans l'ordre :**

| Slot | Nom | Type | Heure |
|------|-----|------|-------|
| `fasting` | À jeun | mesure | 07:00 |
| `bkf_mesure` | Petit déj. — mesure | breakfast | 07:30 |
| `bkf_dose` | Petit déj. — dose | breakfast | 07:30 |
| `bkf_after` | Après petit déj. 2h | mesure | 09:30 |
| `lunch_mesure` | Déjeuner — mesure | lunch | 12:00 |
| `lunch_dose` | Déjeuner — dose | lunch | 12:00 |
| `lunch_after` | Après déjeuner 2h | mesure | 14:00 |
| `diner_mesure` | Dîner — mesure | dinner | 19:00 |
| `diner_dose` | Dîner — dose | dinner | 19:00 |
| `diner_after` | Après dîner 2h | mesure | 21:00 |
| `bedtime` | Avant coucher | mesure | 22:30 |

**Types de cartes :**
- `_MealCard` — repas : glycémie + dose + heure + photo
- `_SimpleCard` — mesure simple : glycémie + heure + photo
- `_SnackCard` — snack supprimable : photo
- Bouton caméra → galerie ou appareil photo → upload Cloudinary
- Spinner pendant l'upload, SnackBar rouge si erreur

### 5. ChartsScreen — Graphiques (onglet 2)
- 2 onglets : Glycémie | Insuline
- Filtres : 24h / 7j / 30j
- Graphique linéaire (fl_chart)

### 6. DashboardScreen — Statistiques (onglet 3)
- 2 onglets : Résumé | Historique
- Glycémie moyenne, total insuline, nb mesures, nb photos

### 7. RemindersScreen — Rappels (onglet 4)
- Liste de rappels quotidiens avec toggle actif/inactif
- Types : Glycémie à jeun, 2h après petit déj., avant déjeuner, avant dîner, dose insuline, personnalisé
- Modification de l'heure via TimePicker
- Ajout de rappels personnalisés
- **Notifications locales planifiées** (flutter_local_notifications)

### 8. CollaboratorsScreen — Accès partagé (onglet 5)
**Vue patient :**
- Partager ses données avec un médecin

**Vue médecin :**
- Voir les données du patient en lecture seule
- Bouton "Voir le rapport" → `PdfViewerScreen`

### 9. PdfViewerScreen — Rapport PDF avec zoom
- `PdfPreview` widget (package printing)
- **Pinch-to-zoom** complet sur mobile
- Bouton partage (WhatsApp, email…)
- Bouton impression
- Photos des repas affichées en **grande taille (180px)** en grille 2 colonnes

---

## Système de notifications

### Permissions Android (AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
```

### Receivers (replanification après redémarrage)
```xml
<receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <!-- BOOT_COMPLETED + MY_PACKAGE_REPLACED + QUICKBOOT_POWERON -->
</receiver>
<receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
```

### Types de notifications
| Type | Déclenchement | Répétition |
|------|--------------|------------|
| Rappel glycémie/insuline | Heure choisie par l'utilisateur | Quotidienne |
| Mesure 2h après repas | Heure du repas + 2h | Unique (ce jour) |

### Initialisation
```dart
// NotificationService.init() au démarrage :
await plugin.initialize(...)
await ap?.requestNotificationsPermission()  // Android 13+
await ap?.requestExactAlarmsPermission()    // Android 12+
```

---

## Rapport PDF médecin

### Structure du PDF (A4, polices Nunito)
1. **En-tête répété** : titre + nom patient + date
2. **Résumé** : jours suivis, insuline moy., glycémie moy., nb photos
3. **Par journée** :
   - Bandeau date (fond teal)
   - Tableau : Heure | Repas | Glycémie g/L | Insuline UI
   - **Section photos** (si présentes) : grille 2 colonnes, images 180×180px, légende + données

### Visualisation mobile
- `PdfViewerScreen` avec `PdfPreview` → zoom tactile, partage, impression

---

## Services

### ImageStorageService (Cloudinary)
```dart
const _kCloudName    = 'dtrng1x4b';
const _kUploadPreset = 'sahtek_unsigned';  // preset non signé (safe)

Future<String?> pickAndUpload({uid, dateKey, entryId, source})
Future<String?> uploadFile(File file, String publicId)
```
- Public ID : `sahtek/meals/{uid}/{dateKey}/{entryId}`
- Re-upload sur le même public_id écrase l'ancienne image

### FirebaseService (Auth + Firestore)
```
Collection : users/{uid}/
  - profil (age, poids, sexe, typeDb, medicaments, userType)
  - records/{dateKey} → DayRecord
  - collaborators/
  - glucose_readings/
```

---

## Navigation

**Bottom nav 5 onglets (custom animée)** :

| Index | Icône | Label | Écran |
|-------|-------|-------|-------|
| 0 | home | Journée | HomeScreen |
| 1 | show_chart | Graphiques | ChartsScreen |
| 2 | bar_chart | Stats | DashboardScreen |
| 3 | alarm | Rappels | RemindersScreen |
| 4 | people | Accès | CollaboratorsScreen |

- Pill animée derrière l'icône active (elasticOut)
- Icône scale 1.25 + label bold à la sélection

---

## Animations

| Écran | Animation |
|-------|-----------|
| Splash | Logo scale-in elasticOut + text slide-up + loader fade |
| Auth | Fade + slide entrée formulaire + ClipRect transition onglets |
| Home (cartes) | FadeTransition + SlideTransition à l'apparition |
| Nav bar | Pill width/opacity + icon scale elasticOut |
| Logo | Pulsation glow (repeat reverse 1800ms) |
| Cartes expand | AnimatedSize easeInOut 250ms |

---

## Ce qui N'existe PAS dans l'app

- ❌ IA / Gemini / analyse automatique des repas (supprimé)
- ❌ Firebase Storage (remplacé par Cloudinary)
- ❌ Double authentification 2FA
- ❌ Alertes glycémiques personnalisées (supprimé)
- ❌ Notifications push via Spring Boot (notifications = locales Flutter uniquement)

---

## Contraintes importantes

- **Render free tier** : backend se met en veille après 15min → premier appel peut être lent
- **Cloudinary** : upload non signé avec preset `sahtek_unsigned` — cloud name public OK
- **Notifications** : replanifiées au démarrage de l'app via `ReminderProvider.rescheduleAll()`
- **Unités glycémie** : g/L (France) ou mmol/L (converti automatiquement × 0.18)
- **render.yaml** : `sync: false` — credentials uniquement dans le dashboard Render, pas dans git
