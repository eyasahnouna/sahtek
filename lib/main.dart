import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'firebase_options.dart';
import 'providers/app_provider.dart';
import 'providers/reminder_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/charts_screen.dart';
import 'screens/reminders_screen.dart';
import 'screens/collaborators_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'utils/app_theme.dart';
import 'widgets/sahtek_logo.dart';
import 'l10n/l10n.dart';

// ignore_for_file: unused_import

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
  } catch (_) {}
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
  await initializeDateFormatting('ar', null);
  final localeProvider = LocaleProvider();
  await localeProvider.load();
  await NotificationService.instance.init();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: localeProvider),
        ChangeNotifierProvider(create: (_) => AppProvider()),
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
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;
    return MaterialApp(
      // Changer de langue recrée toute l'arborescence : les widgets `const`
      // ne se reconstruiraient pas autrement et garderaient l'ancien texte.
      key: ValueKey(locale.languageCode),
      title: 'Sahtek',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      locale: locale,
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const _AuthGate(),
      routes: {
        '/auth': (context) => const AuthScreen(),
      },
    );
  }
}

// ── Splash animé ─────────────────────────────────────────────────────────────
class _SplashScreen extends StatefulWidget {
  const _SplashScreen();
  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _logoScale;
  late Animation<double>   _logoOpacity;
  late Animation<double>   _textOpacity;
  late Animation<Offset>   _textSlide;
  late Animation<double>   _loaderOpacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl,
          curve: const Interval(0.0, 0.6, curve: Curves.elasticOut)),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl,
          curve: const Interval(0.0, 0.4, curve: Curves.easeIn)),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl,
          curve: const Interval(0.4, 0.75, curve: Curves.easeIn)),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end:   Offset.zero,
    ).animate(
      CurvedAnimation(parent: _ctrl,
          curve: const Interval(0.4, 0.8, curve: Curves.easeOut)),
    );
    _loaderOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl,
          curve: const Interval(0.75, 1.0, curve: Curves.easeIn)),
    );

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A7A93), Color(0xFF0B8FAC), Color(0xFF00C9B1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: const SahtekLogo(size: 96, animate: false),
                  ),
                ),
                const SizedBox(height: 24),
                // Texte
                FadeTransition(
                  opacity: _textOpacity,
                  child: SlideTransition(
                    position: _textSlide,
                    child: Column(
                      children: [
                        Text(
                          'Sahtek',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Votre santé, sécurisée'.tr,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.80),
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                // Loader
                Opacity(
                  opacity: _loaderOpacity.value,
                  child: SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white.withValues(alpha: 0.7),
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Auth Gate ─────────────────────────────────────────────────────────────────
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseService.instance.authStateChanges,
      builder: (context, snapshot) {

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        if (snapshot.hasData && snapshot.data != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<AppProvider>().syncFromCloud();
            context.read<ReminderProvider>().rescheduleAll();
            _syncUserBackend(snapshot.data!);
          });
          return const _RootNav();
        }

        return const AuthScreen();
      },
    );
  }
}

// ── Navigation principale ─────────────────────────────────────────────────────
class _RootNav extends StatelessWidget {
  const _RootNav();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: FirebaseService.instance.streamProfileComplete(),
      builder: (context, profileSnap) {
        if (profileSnap.data == false) return const ProfileSetupScreen();

        return StreamBuilder<String?>(
          stream: FirebaseService.instance.streamUserType(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                  backgroundColor: AppTheme.bgColor,
                  body: Center(child: CircularProgressIndicator()));
            }
            final userType = snap.data;
            if (userType == 'doctor') return const _DoctorNav();
            return const _PatientNav();
          },
        );
      },
    );
  }
}

// ── Vue médecin/proche ────────────────────────────────────────────────────────
class _DoctorNav extends StatelessWidget {
  const _DoctorNav();
  @override
  Widget build(BuildContext context) =>
      const CollaboratorsScreen(isDoctor: true);
}

// ── Données des onglets ───────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String   label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}

const _navItems = [
  _NavItem(Icons.home_outlined,          Icons.home_rounded,       'Journée'),
  _NavItem(Icons.show_chart_outlined,    Icons.show_chart_rounded, 'Graphiques'),
  _NavItem(Icons.bar_chart_outlined,     Icons.bar_chart_rounded,  'Stats'),
  _NavItem(Icons.alarm_outlined,         Icons.alarm_rounded,      'Rappels'),
  _NavItem(Icons.medical_services_outlined, Icons.medical_services_rounded, 'Médecin'),
];

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
    CollaboratorsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: _AnimatedNavBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

// ── Bottom Nav animée ─────────────────────────────────────────────────────────
class _AnimatedNavBar extends StatelessWidget {
  final int      currentIndex;
  final ValueChanged<int> onTap;

  const _AnimatedNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_navItems.length, (i) {
              return Expanded(child: _NavBarItem(
                item:     _navItems[i],
                selected: currentIndex == i,
                onTap:    () => onTap(i),
              ));
            }),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatefulWidget {
  final _NavItem  item;
  final bool      selected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavBarItem> createState() => _NavBarItemState();
}

class _NavBarItemState extends State<_NavBarItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scaleAnim;
  late Animation<double>   _pillAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _pillAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );

    if (widget.selected) _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(_NavBarItem old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected) {
      _ctrl.forward(from: 0.0);
    } else if (!widget.selected && old.selected) {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Indicateur pill derrière l'icône
            Stack(
              alignment: Alignment.center,
              children: [
                // Pill animée
                Container(
                  width:  44 * _pillAnim.value,
                  height: 28 * _pillAnim.value,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(
                        alpha: 0.13 * _pillAnim.value),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                // Icône avec scale
                Transform.scale(
                  scale: _scaleAnim.value,
                  child: Icon(
                    widget.selected
                        ? widget.item.activeIcon
                        : widget.item.icon,
                    size:  22,
                    color: widget.selected
                        ? AppTheme.primary
                        : const Color(0xFFB0C4CE),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            // Label
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize:   widget.selected ? 10.5 : 10,
                fontWeight: widget.selected
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: widget.selected
                    ? AppTheme.primary
                    : const Color(0xFFB0C4CE),
              ),
              child: Text(widget.item.label.tr),
            ),
          ],
        ),
      ),
    );
  }
}
