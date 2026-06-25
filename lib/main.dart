import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'firebase_options.dart';
import 'providers/app_provider.dart';
import 'providers/alert_provider.dart';
import 'providers/reminder_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/charts_screen.dart';
import 'screens/reminders_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/collaborators_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'utils/app_theme.dart';

// ignore_for_file: unused_import

// Crée l'utilisateur dans PostgreSQL (Spring Boot) s'il n'existe pas encore
Future<void> _syncUserBackend(User user) async {
  try {
    final token = await user.getIdToken();
    await http.get(
      Uri.parse('https://sahtekbackend.onrender.com/api/utilisateurs/moi'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
  } catch (_) {
    // Échec silencieux — l'appli fonctionne sans le backend
  }
}

tz.Location _resolveLocalTimezone() {
  final offset = DateTime.now().timeZoneOffset.inMinutes;
  try {
    for (final name in tz.timeZoneDatabase.locations.keys) {
      final loc = tz.timeZoneDatabase.locations[name]!;
      if (tz.TZDateTime.now(loc).timeZoneOffset.inMinutes == offset) return loc;
    }
  } catch (_) {}
  return tz.UTC;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  tz.initializeTimeZones();
  tz.setLocalLocation(_resolveLocalTimezone());
  await initializeDateFormatting('fr_FR', null);
  await NotificationService.instance.init();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => AlertProvider()),
        ChangeNotifierProvider(create: (_) => ReminderProvider()),
      ],
      child: const SahtekApp(),
    ),
  );
}

// ── App ───────────────────────────────────────────────────────────────────────
class SahtekApp extends StatelessWidget {
  const SahtekApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Sahtek',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.theme,
    home: const _AuthGate(),   // ← toujours le gate au démarrage
    routes: {
      '/auth': (context) => const AuthScreen(),
    },
  );
}

// ── Auth Gate ─────────────────────────────────────────────────────────────────
// • Non connecté  → AuthScreen (login / inscription)
// • Connecté      → _RootNav (app principale)
// StreamBuilder écoute Firebase Auth en temps réel :
//   connexion  → bascule automatiquement vers _RootNav
//   déconnexion → revient sur AuthScreen
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseService.instance.authStateChanges,
      builder: (context, snapshot) {

        // En attente de la réponse Auth Firebase (splash rapide)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppTheme.primary,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_rounded,
                      color: Colors.white, size: 56),
                  SizedBox(height: 16),
                  Text('Sahtek',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 32),
                  CircularProgressIndicator(
                      color: Colors.white70, strokeWidth: 2),
                ],
              ),
            ),
          );
        }

        // Connecté → app principale + sync cloud
        if (snapshot.hasData && snapshot.data != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<AppProvider>().syncFromCloud();
            context.read<ReminderProvider>().rescheduleAll();
            _syncUserBackend(snapshot.data!);
          });
          return const _RootNav();
        }

        // Non connecté → page login/inscription
        return const AuthScreen();
      },
    );
  }
}

// ── Navigation principale ─────────────────────────────────────────────────────
// 1. Profil incomplet → ProfileSetupScreen
// 2. Médecin/proche  → _DoctorNav
// 3. Patient         → _PatientNav
class _RootNav extends StatelessWidget {
  const _RootNav();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: FirebaseService.instance.streamProfileComplete(),
      builder: (context, profileSnap) {
        // Profil incomplet (ou pas encore chargé) → wizard
        if (profileSnap.data == false) return const ProfileSetupScreen();

        // Rôle : médecin ou patient
        return StreamBuilder<String?>(
          stream: FirebaseService.instance.streamUserType(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                  backgroundColor: AppTheme.bgColor,
                  body: Center(child: CircularProgressIndicator()));
            }
            final userType = snap.data;
            if (userType == 'doctor') {
              return const _DoctorNav();
            }
            return const _PatientNav();
          },
        );
      },
    );
  }
}

// ── Vue médecin/proche ────────────────────────────────────────────────────────
// Affiche uniquement la liste des patients et les invitations en attente.
class _DoctorNav extends StatelessWidget {
  const _DoctorNav();

  @override
  Widget build(BuildContext context) {
    return const CollaboratorsScreen(isDoctor: true);
  }
}

// ── Vue patient (app complète) ────────────────────────────────────────────────
class _PatientNav extends StatefulWidget {
  const _PatientNav();
  @override
  State<_PatientNav> createState() => _PatientNavState();
}

class _PatientNavState extends State<_PatientNav> {
  int _index = 0;

  static const _screens = [
    HomeScreen(),
    ChartsScreen(),
    DashboardScreen(),
    RemindersScreen(),
    AlertsScreen(),
    CollaboratorsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Journée',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart_outlined),
            activeIcon: Icon(Icons.show_chart_rounded),
            label: 'Graphiques',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart_rounded),
            label: 'Stats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.alarm_outlined),
            activeIcon: Icon(Icons.alarm_rounded),
            label: 'Rappels',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            activeIcon: Icon(Icons.notifications_rounded),
            label: 'Alertes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline_rounded),
            activeIcon: Icon(Icons.people_rounded),
            label: 'Accès',
          ),
        ],
      ),
    );
  }
}