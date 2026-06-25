import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../utils/app_theme.dart';

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
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
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
  }

  @override
  void dispose() {
    _tabs.dispose();
    _emailCtrl.dispose(); _passCtrl.dispose();
    _nameCtrl.dispose();  _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Sign In ─────────────────────────────────────────────────────────────────
  Future<void> _signIn() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Remplissez tous les champs'); return;
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
      setState(() => _error = 'Remplissez tous les champs'); return;
    }
    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Les mots de passe ne correspondent pas'); return;
    }
    if (_passCtrl.text.length < 6) {
      setState(() => _error = 'Mot de passe trop court (6 car. min.)'); return;
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
      setState(() => _error = 'Entrez votre email d\'abord'); return;
    }
    try {
      await FirebaseService.instance.resetPassword(_emailCtrl.text);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Email de réinitialisation envoyé'),
        backgroundColor: AppTheme.success,
      ));
    } catch (e) {
      setState(() => _error = _msg(e.toString()));
    }
  }

  String _msg(String e) {
    if (e.contains('user-not-found') || e.contains('wrong-password') ||
        e.contains('invalid-credential')) return 'Email ou mot de passe incorrect';
    if (e.contains('email-already-in-use')) return 'Cet email est déjà utilisé';
    if (e.contains('weak-password'))   return 'Mot de passe trop faible';
    if (e.contains('invalid-email'))   return 'Email invalide';
    if (e.contains('network'))         return 'Vérifiez votre connexion internet';
    return 'Erreur : ${e.replaceAll(RegExp(r'\[.*?\]'), '').trim()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
        child: Column(children: [

          // ── Logo ─────────────────────────────────────────────────────────
          Container(
            width: 82, height: 82,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.secondary],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(
                  color: AppTheme.primary.withOpacity(0.3),
                  blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: const Icon(Icons.favorite_rounded,
                color: Colors.white, size: 42),
          ),
          const SizedBox(height: 18),
          Text('Sahtek',
              style: AppFonts.bold(size: 28, color: AppTheme.primary)),
          Text('Votre santé, sécurisée',
              style: AppFonts.body(color: Colors.grey, size: 14)),
          const SizedBox(height: 30),

          // ── Tabs ──────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10)]),
            child: TabBar(
              controller: _tabs,
              indicator: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(11)),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Connexion'),
                Tab(text: 'Inscription'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Erreur ────────────────────────────────────────────────────────
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppTheme.danger.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.danger.withOpacity(0.3))),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppTheme.danger, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!,
                    style: AppFonts.body(
                        color: AppTheme.danger, size: 13))),
              ]),
            ),
            const SizedBox(height: 12),
          ],

          // ── Formulaires ───────────────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: _tabs.index == 0 ? 220 : 385,
            child: TabBarView(controller: _tabs, children: [

              // ── Connexion ──────────────────────────────────────────────
              Column(children: [
                TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_rounded, size: 18))),
                const SizedBox(height: 12),
                TextField(
                    controller: _passCtrl,
                    obscureText: !_showPass,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _signIn(),
                    decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: const Icon(Icons.lock_rounded, size: 18),
                        suffixIcon: IconButton(
                            icon: Icon(_showPass
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded, size: 18),
                            onPressed: () =>
                                setState(() => _showPass = !_showPass)))),
                const SizedBox(height: 4),
                Align(alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _resetPassword,
                    child: Text('Mot de passe oublié ?',
                        style: AppFonts.label(
                            color: AppTheme.primary, size: 12)),
                  ),
                ),
              ]),

              // ── Inscription ───────────────────
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Sélecteur de rôle
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300)),
                  child: Row(children: ['patient', 'doctor'].map((r) {
                    final sel = _selectedRole == r;
                    return Expanded(child: GestureDetector(
                      onTap: () => setState(() => _selectedRole = r),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                            color: sel ? AppTheme.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(9)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                          Icon(r == 'doctor'
                              ? Icons.medical_services_rounded : Icons.person_rounded,
                              size: 14,
                              color: sel ? Colors.white : Colors.grey),
                          const SizedBox(width: 5),
                          Text(r == 'patient' ? 'Patient' : 'Médecin',
                              style: AppFonts.label(
                                  color: sel ? Colors.white : Colors.grey, size: 12)
                                  .copyWith(fontWeight: sel
                                      ? FontWeight.w700 : FontWeight.normal)),
                        ]),
                      ),
                    ));
                  }).toList()),
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: _nameCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                        labelText: 'Nom complet',
                        prefixIcon: Icon(Icons.person_rounded, size: 18))),
                const SizedBox(height: 10),
                TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_rounded, size: 18))),
                const SizedBox(height: 10),
                TextField(
                    controller: _passCtrl,
                    obscureText: !_showPass,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                        labelText: 'Mot de passe (6 car. min)',
                        prefixIcon: const Icon(Icons.lock_rounded, size: 18),
                        suffixIcon: IconButton(
                            icon: Icon(_showPass
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded, size: 18),
                            onPressed: () =>
                                setState(() => _showPass = !_showPass)))),
                const SizedBox(height: 10),
                TextField(
                    controller: _confirmCtrl,
                    obscureText: !_showPass,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _signUp(),
                    decoration: const InputDecoration(
                        labelText: 'Confirmer le mot de passe',
                        prefixIcon: Icon(
                            Icons.lock_outline_rounded, size: 18))),
              ]),
            ]),
          ),

          // ── Bouton principal ──────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null
                  : () { if (_tabs.index == 0) _signIn(); else _signUp(); },
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _loading
                  ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : Text(_tabs.index == 0
                  ? 'Se connecter' : 'Créer mon compte',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      )),
    );
  }
}