import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../utils/app_theme.dart';
import '../widgets/sahtek_logo.dart';
import '../l10n/l10n.dart';
import 'settings_screen.dart';

// ── AuthScreen ────────────────────────────────────────────────────────────────
// Le StreamBuilder dans _AuthGate gère la navigation automatiquement :
// • Après signIn/signUp réussi → Auth émet un nouvel user → _RootNav s'affiche
// • Pas besoin de Navigator.push/pop ici
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with TickerProviderStateMixin {
  late TabController       _tabs;
  late AnimationController _entranceCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _nameCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading  = false;
  bool _showPass = false;
  String? _error;
  String _selectedRole = 'patient';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() => _error = null));

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end:   Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut),
    );
    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _entranceCtrl.dispose();
    _emailCtrl.dispose(); _passCtrl.dispose();
    _nameCtrl.dispose();  _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Sign In ─────────────────────────────────────────────────────────────────
  Future<void> _signIn() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Remplissez tous les champs'.tr); return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await FirebaseService.instance.signIn(
          email: _emailCtrl.text, password: _passCtrl.text);
      // ← pas de Navigator ici : _AuthGate bascule automatiquement
    } catch (e) {
      setState(() => _error = _msg(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Sign Up ─────────────────────────────────────────────────────────────────
  Future<void> _signUp() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _passCtrl.text.isEmpty) {
      setState(() => _error = 'Remplissez tous les champs'.tr); return;
    }
    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Les mots de passe ne correspondent pas'.tr); return;
    }
    if (_passCtrl.text.length < 6) {
      setState(() => _error = 'Mot de passe trop court (6 car. min.)'.tr); return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await FirebaseService.instance.signUp(
          email: _emailCtrl.text,
          password: _passCtrl.text,
          fullName: _nameCtrl.text.trim(),
          userType: _selectedRole);
      // ← _AuthGate bascule automatiquement après signUp
    } catch (e) {
      setState(() => _error = _msg(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Reset password ──────────────────────────────────────────────────────────
  Future<void> _resetPassword() async {
    if (_emailCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Entrez votre email d\'abord'.tr); return;
    }
    try {
      await FirebaseService.instance.resetPassword(_emailCtrl.text);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Email de réinitialisation envoyé'.tr),
        backgroundColor: AppTheme.success,
      ));
    } catch (e) {
      setState(() => _error = _msg(e.toString()));
    }
  }

  String _msg(String e) {
    if (e.contains('user-not-found') || e.contains('wrong-password') ||
        e.contains('invalid-credential')) return 'Email ou mot de passe incorrect'.tr;
    if (e.contains('email-already-in-use')) return 'Cet email est déjà utilisé'.tr;
    if (e.contains('weak-password'))   return 'Mot de passe trop faible'.tr;
    if (e.contains('invalid-email'))   return 'Email invalide'.tr;
    if (e.contains('network'))         return 'Vérifiez votre connexion internet'.tr;
    return 'Erreur : {e}'.trp({'e': e.replaceAll(RegExp(r'\[.*?\]'), '').trim()});
  }

  // ── Onglet Connexion ──────────────────────────────────────────────────────────
  Widget _buildLoginTab() {
    return Column(children: [
      TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
              labelText: 'Email'.tr,
              prefixIcon: Icon(Icons.email_rounded, size: 18))),
      const SizedBox(height: 12),
      TextField(
          controller: _passCtrl,
          obscureText: !_showPass,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _signIn(),
          decoration: InputDecoration(
              labelText: 'Mot de passe'.tr,
              prefixIcon: const Icon(Icons.lock_rounded, size: 18),
              suffixIcon: IconButton(
                  icon: Icon(_showPass
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded, size: 18),
                  onPressed: () => setState(() => _showPass = !_showPass)))),
      const SizedBox(height: 4),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: _resetPassword,
          child: Text('Mot de passe oublié ?'.tr,
              style: AppFonts.label(color: AppTheme.primary, size: 12)),
        ),
      ),
    ]);
  }

  // ── Onglet Inscription ────────────────────────────────────────────────────────
  Widget _buildSignUpTab() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Sélecteur de rôle
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300)),
        child: Row(
          children: ['patient', 'doctor'].map((r) {
            final sel = _selectedRole == r;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedRole = r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                      color: sel ? AppTheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(9)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                          r == 'doctor'
                              ? Icons.medical_services_rounded
                              : Icons.person_rounded,
                          size: 14,
                          color: sel ? Colors.white : Colors.grey),
                      const SizedBox(width: 5),
                      Text(
                          r == 'patient' ? 'Patient'.tr : 'Médecin'.tr,
                          style: AppFonts.label(
                              color: sel ? Colors.white : Colors.grey, size: 12)
                              .copyWith(
                              fontWeight: sel
                                  ? FontWeight.w700
                                  : FontWeight.normal)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 10),
      TextField(
          controller: _nameCtrl,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
              labelText: 'Nom complet'.tr,
              prefixIcon: Icon(Icons.person_rounded, size: 18))),
      const SizedBox(height: 10),
      TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
              labelText: 'Email'.tr,
              prefixIcon: Icon(Icons.email_rounded, size: 18))),
      const SizedBox(height: 10),
      TextField(
          controller: _passCtrl,
          obscureText: !_showPass,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
              labelText: 'Mot de passe (6 car. min)'.tr,
              prefixIcon: const Icon(Icons.lock_rounded, size: 18),
              suffixIcon: IconButton(
                  icon: Icon(_showPass
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded, size: 18),
                  onPressed: () => setState(() => _showPass = !_showPass)))),
      const SizedBox(height: 10),
      TextField(
          controller: _confirmCtrl,
          obscureText: !_showPass,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _signUp(),
          decoration: InputDecoration(
              labelText: 'Confirmer le mot de passe'.tr,
              prefixIcon: Icon(Icons.lock_outline_rounded, size: 18))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            children: [
              // ── Choix de la langue (accessible avant connexion) ─────────────
              SizedBox(
                height: 40,
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: IconButton(
                    icon: const Icon(Icons.language_rounded,
                        color: AppTheme.primary),
                    tooltip: 'Langue'.tr,
                    onPressed: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const SettingsScreen())),
                  ),
                ),
              ),
              // ── Logo animé ──────────────────────────────────────────────────
              const SahtekLogo(size: 88, animate: true, showText: true),
              const SizedBox(height: 32),

              // ── Formulaire avec animation d'entrée ──────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    children: [

                      // ── Tabs ───────────────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: TabBar(
                          controller: _tabs,
                          indicator: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(11)),
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.grey,
                          dividerColor: Colors.transparent,
                          tabs: [
                            Tab(text: 'Connexion'.tr),
                            Tab(text: 'Inscription'.tr),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Erreur ─────────────────────────────────────────────
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppTheme.danger.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: AppTheme.danger, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_error!,
                                    style: AppFonts.body(
                                        color: AppTheme.danger, size: 13)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // ── Formulaires ────────────────────────────────────────
                      // ClipRect évite le RenderFlex overflow pendant l'animation
                      // de transition entre les deux onglets (hauteur intermédiaire)
                      ClipRect(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: _tabs.index == 0 ? 230 : 400,
                          child: TabBarView(
                            controller: _tabs,
                            children: [
                              _buildLoginTab(),
                              _buildSignUpTab(),
                            ],
                          ),
                        ),
                      ),

                      // ── Bouton principal ────────────────────────────────────
                      AnimatedTap(
                        onTap: _loading
                            ? null
                            : () {
                                if (_tabs.index == 0) {
                                  _signIn();
                                } else {
                                  _signUp();
                                }
                              },
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading
                                ? null
                                : () {
                                    if (_tabs.index == 0) {
                                      _signIn();
                                    } else {
                                      _signUp();
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16)),
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : Text(
                                    _tabs.index == 0
                                        ? 'Se connecter'.tr
                                        : 'Créer mon compte'.tr,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}