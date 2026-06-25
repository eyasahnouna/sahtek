import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../screens/friend_view_screen.dart';
import '../services/firebase_service.dart';
import '../utils/app_theme.dart';

class CollaboratorsScreen extends StatelessWidget {
  final bool isDoctor;
  const CollaboratorsScreen({super.key, this.isDoctor = false});

  @override
  Widget build(BuildContext context) {
    if (!FirebaseService.instance.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Accès partagé')),
        body: Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.lock_rounded, size: 64, color: AppTheme.primary),
          const SizedBox(height: 16),
          Text('Connexion requise', style: AppFonts.title(size: 18)),
          const SizedBox(height: 8),
          Text('Connectez-vous pour partager\nvos données.',
              style: AppFonts.body(color: Colors.grey, size: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/auth'),
              icon: const Icon(Icons.login_rounded),
              label: const Text('Se connecter / S\'inscrire')),
        ])),
      );
    }

    // Mode médecin : 2 onglets seulement (Mes patients + Invitations), pas de FAB
    if (isDoctor) {
      return DefaultTabController(length: 2, child: Scaffold(
        appBar: AppBar(
          title: const Text('Mes patients'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.white),
              tooltip: 'Déconnexion',
              onPressed: () => _confirmLogout(context),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(icon: Icon(Icons.medical_services_rounded, size: 16), text: 'Mes patients'),
              Tab(icon: Icon(Icons.mail_rounded, size: 16), text: 'Invitations'),
            ],
          ),
        ),
        body: const TabBarView(children: [
          _MyPatientsTab(),
          _InvitationsTab(),
        ]),
      ));
    }

    // Mode patient : 3 onglets + FAB inviter
    return DefaultTabController(length: 3, child: Scaffold(
      appBar: AppBar(
        title: const Text('Accès partagé'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Déconnexion',
            onPressed: () => _confirmLogout(context),
          ),
        ],
        bottom: const TabBar(
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: [
            Tab(icon: Icon(Icons.medical_services_rounded, size: 16), text: 'Mes patients'),
            Tab(icon: Icon(Icons.people_rounded, size: 16), text: 'Mes accès'),
            Tab(icon: Icon(Icons.mail_rounded, size: 16), text: 'Invitations'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showInviteDialog(context),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: Text('Inviter', style: AppFonts.label(color: Colors.white, size: 13)
            .copyWith(fontWeight: FontWeight.w600)),
      ),
      body: const TabBarView(children: [
        _MyPatientsTab(),
        _MyCollaboratorsTab(),
        _InvitationsTab(),
      ]),
    ));
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Déconnexion', style: AppFonts.title(size: 16)),
        content: Text('Voulez-vous vous déconnecter ?',
            style: AppFonts.body(size: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );
    if (ok == true) await FirebaseService.instance.signOut();
  }

  Future<void> _showInviteDialog(BuildContext context) async {
    final emailCtrl = TextEditingController();
    String role = 'viewer';
    String? error;
    bool sending = false;

    await showDialog(context: context, builder: (_) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(children: [
          Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.person_add_rounded,
                  color: AppTheme.primary, size: 20)),
          const SizedBox(width: 10),
          Text('Inviter un collaborateur', style: AppFonts.title(size: 15)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2))),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded,
                  color: AppTheme.primary, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'La personne devra ouvrir Sahtek avec ce compte email pour accepter l\'invitation.',
                style: AppFonts.label(color: AppTheme.primary, size: 12),
              )),
            ]),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            onChanged: (_) {
              if (error != null) set(() => error = null);
            },
            decoration: InputDecoration(
                labelText: 'Email du collaborateur',
                hintText: 'exemple@mail.com',
                prefixIcon: const Icon(Icons.email_rounded, size: 18),
                errorText: error,
                suffixIcon: emailCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () { emailCtrl.clear(); set(() => error = null); })
                    : null),
          ),
          const SizedBox(height: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Rôle :', style: AppFonts.label(color: Colors.grey.shade600, size: 11)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: AppTheme.bgColor,
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: ['viewer', 'doctor'].map((r) {
                final sel = role == r;
                return Expanded(child: GestureDetector(
                  onTap: () => set(() => role = r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 9),
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
                      Column(children: [
                        Text(r == 'viewer' ? 'Proche' : 'Médecin',
                            style: AppFonts.label(
                                color: sel ? Colors.white : Colors.grey, size: 12)
                                .copyWith(fontWeight: sel
                                    ? FontWeight.w700 : FontWeight.normal)),
                        Text(r == 'viewer' ? 'Lecture seule' : 'Accès complet',
                            style: AppFonts.label(
                                color: sel ? Colors.white70 : Colors.grey.shade400,
                                size: 9)),
                      ]),
                    ]),
                  ),
                ));
              }).toList()),
            ),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler', style: AppFonts.body(color: Colors.grey))),
          ElevatedButton(
            onPressed: sending ? null : () async {
              final email = emailCtrl.text.trim().toLowerCase();
              final emailRegex = RegExp(r'^[\w\.\+\-]+@[\w\-]+\.[a-z]{2,}$');
              if (email.isEmpty) {
                set(() => error = 'Entrez un email'); return;
              }
              if (!emailRegex.hasMatch(email)) {
                set(() => error = 'Email invalide'); return;
              }
              set(() { sending = true; error = null; });
              try {
                await FirebaseService.instance.inviteCollaborator(
                    email: email, role: role);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Row(children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Invitation envoyée à $email')),
                    ]),
                    backgroundColor: AppTheme.success,
                    duration: const Duration(seconds: 4),
                  ));
                }
              } catch (e) {
                set(() {
                  sending = false;
                  error = e.toString().replaceAll('Exception: ', '');
                });
              }
            },
            child: sending
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Envoyer l\'invitation'),
          ),
        ],
      ),
    ));
  }
}

// ── Mes patients (personnes qui m'ont donné accès) ────────────────────────────
class _MyPatientsTab extends StatelessWidget {
  const _MyPatientsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FirebaseCollaborator>>(
      stream: FirebaseService.instance.streamAccessibleOwners(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.medical_services_outlined, size: 70,
                color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Aucun patient', style: AppFonts.title(
                color: Colors.grey.shade400, size: 16)),
            const SizedBox(height: 8),
            Text(
              'Quand un patient vous invite et que\nvous acceptez, il apparaîtra ici.',
              style: AppFonts.body(color: Colors.grey.shade400, size: 13),
              textAlign: TextAlign.center,
            ),
          ]));
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _PatientCard(collaborator: list[i]),
        );
      },
    );
  }
}

class _PatientCard extends StatelessWidget {
  final FirebaseCollaborator collaborator;
  const _PatientCard({required this.collaborator});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: FirebaseService.instance.getUserName(collaborator.ownerId),
      builder: (_, snap) {
        final name = snap.data ?? collaborator.ownerEmail;
        return InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => FriendViewScreen(
              friendId: collaborator.ownerId,
              friendName: name,
            ),
          )),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10, offset: const Offset(0, 3))]),
            child: Row(children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle),
                child: Center(child: Text(
                  name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                  style: AppFonts.bold(color: AppTheme.primary, size: 20),
                )),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: AppFonts.title(size: 14),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(collaborator.ownerEmail,
                    style: AppFonts.body(color: Colors.grey.shade500, size: 12),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(collaborator.roleLabel,
                      style: AppFonts.label(color: AppTheme.primary, size: 10)
                          .copyWith(fontWeight: FontWeight.w700)),
                ),
              ])),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.primary, size: 26),
            ]),
          ),
        );
      },
    );
  }
}

// ── Mes collaborateurs (ceux que j'ai invités) ────────────────────────────────
class _MyCollaboratorsTab extends StatelessWidget {
  const _MyCollaboratorsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FirebaseCollaborator>>(
      stream: FirebaseService.instance.streamMyCollaborators(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.people_outline_rounded, size: 70,
                color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Aucun collaborateur', style: AppFonts.title(
                color: Colors.grey.shade400, size: 16)),
            const SizedBox(height: 8),
            Text('Appuyez sur "Inviter" pour\npartager vos données.',
                style: AppFonts.body(color: Colors.grey.shade400, size: 13),
                textAlign: TextAlign.center),
          ]));
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _CollaboratorCard(c: list[i]),
        );
      },
    );
  }
}

class _CollaboratorCard extends StatelessWidget {
  final FirebaseCollaborator c;
  const _CollaboratorCard({required this.c});

  Color get _sColor => c.status == 'accepted' ? AppTheme.success
      : c.status == 'rejected' ? AppTheme.danger : AppTheme.warning;
  IconData get _sIcon => c.status == 'accepted'
      ? Icons.check_circle_rounded
      : c.status == 'rejected' ? Icons.cancel_rounded : Icons.schedule_rounded;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10, offset: const Offset(0, 3))]),
      child: Row(children: [
        Container(width: 46, height: 46,
            decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: Center(child: Text(
              c.email.isNotEmpty ? c.email.substring(0, 1).toUpperCase() : '?',
              style: AppFonts.bold(color: AppTheme.primary, size: 18)))),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.email, style: AppFonts.title(size: 13),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(c.roleLabel,
                  style: AppFonts.label(color: AppTheme.primary, size: 10)
                      .copyWith(fontWeight: FontWeight.w700))),
            const SizedBox(width: 6),
            Icon(_sIcon, color: _sColor, size: 14),
            const SizedBox(width: 3),
            Text(c.statusLabel,
                style: AppFonts.label(color: _sColor, size: 11)),
          ]),
        ])),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, size: 20),
          color: Colors.red.shade300,
          onPressed: () async {
            final ok = await showDialog<bool>(context: context,
              builder: (_) => AlertDialog(
                title: Text('Retirer l\'accès ?',
                    style: AppFonts.title(size: 15)),
                content: Text('${c.email} ne pourra plus voir vos données.',
                    style: AppFonts.body(size: 13)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false),
                      child: const Text('Annuler')),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.danger),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Retirer'),
                  ),
                ],
              ),
            );
            if (ok == true) {
              await FirebaseService.instance.removeCollaborator(c.id);
            }
          },
        ),
      ]),
    );
  }
}

// ── Invitations reçues ────────────────────────────────────────────────────────
class _InvitationsTab extends StatelessWidget {
  const _InvitationsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FirebaseCollaborator>>(
      stream: FirebaseService.instance.streamMyInvitations(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.mail_outline_rounded, size: 70,
                color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Aucune invitation', style: AppFonts.title(
                color: Colors.grey.shade400, size: 16)),
            const SizedBox(height: 8),
            Text('Vos invitations apparaîtront ici.',
                style: AppFonts.body(color: Colors.grey.shade400, size: 13)),
          ]));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _InvitationCard(inv: list[i]),
        );
      },
    );
  }
}

class _InvitationCard extends StatelessWidget {
  final FirebaseCollaborator inv;
  const _InvitationCard({required this.inv});

  Future<void> _acceptAndChangePassword(BuildContext context) async {
    await FirebaseService.instance.acceptInvitation(inv.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Accès accepté !'),
      backgroundColor: AppTheme.success,
    ));
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ChangePasswordDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
          boxShadow: [BoxShadow(color: AppTheme.warning.withValues(alpha: 0.08),
              blurRadius: 10)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.mail_rounded, color: AppTheme.warning, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text('Invitation Sahtek',
              style: AppFonts.label(color: AppTheme.warning, size: 12)
                  .copyWith(fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 8),
        Text(
          '${inv.ownerEmail} vous invite à consulter ses données médicales.',
          style: AppFonts.body(size: 13),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20)),
          child: Text('Rôle : ${inv.roleLabel}',
              style: AppFonts.label(color: AppTheme.primary, size: 11)
                  .copyWith(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: () async {
              await FirebaseService.instance.rejectInvitation(inv.id);
            },
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.danger),
                foregroundColor: AppTheme.danger),
            child: const Text('Refuser'),
          )),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton(
            onPressed: () => _acceptAndChangePassword(context),
            child: const Text('Accepter'),
          )),
        ]),
      ]),
    );
  }
}

// ── Dialog changement de mot de passe ─────────────────────────────────────────
class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();
  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _newCtrl  = TextEditingController();
  final _confCtrl = TextEditingController();
  bool _loading  = false;
  bool _showPass = false;
  String? _error;

  @override
  void dispose() {
    _newCtrl.dispose();
    _confCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final newPass = _newCtrl.text;
    if (newPass.length < 6) {
      setState(() => _error = 'Minimum 6 caractères'); return;
    }
    if (newPass != _confCtrl.text) {
      setState(() => _error = 'Les mots de passe ne correspondent pas'); return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await FirebaseService.instance.currentUser!.updatePassword(newPass);
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _loading = false;
        _error = e.code == 'requires-recent-login'
            ? 'Reconnectez-vous puis réessayez.'
            : e.message ?? 'Erreur inconnue';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle),
          child: const Icon(Icons.lock_outline_rounded,
              color: AppTheme.primary, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text('Modifier le mot de passe',
            style: AppFonts.title(size: 14))),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2))),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded,
                color: AppTheme.primary, size: 14),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Définissez un mot de passe personnel pour sécuriser votre compte.',
              style: AppFonts.label(color: AppTheme.primary, size: 11),
            )),
          ]),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _newCtrl,
          obscureText: !_showPass,
          decoration: InputDecoration(
            labelText: 'Nouveau mot de passe',
            prefixIcon: const Icon(Icons.lock_rounded, size: 18),
            suffixIcon: IconButton(
              icon: Icon(_showPass
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded, size: 18),
              onPressed: () => setState(() => _showPass = !_showPass),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _confCtrl,
          obscureText: !_showPass,
          decoration: InputDecoration(
            labelText: 'Confirmer le mot de passe',
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
            errorText: _error,
          ),
          onSubmitted: (_) => _loading ? null : _submit(),
        ),
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Passer', style: AppFonts.body(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Text('Modifier'),
        ),
      ],
    );
  }
}
