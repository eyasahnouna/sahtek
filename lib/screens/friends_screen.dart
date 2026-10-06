import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../utils/app_theme.dart';
import 'auth_screen.dart';
import 'friend_view_screen.dart';
import '../l10n/l10n.dart';

/// Écran de gestion des collaborateurs (visiteurs lecture seule)
class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Non connecté → proposer la connexion
    if (!FirebaseService.instance.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: Text('Partage de données'.tr)),
        body: Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.lock_rounded,
                  size: 48, color: AppTheme.primary)),
          const SizedBox(height: 20),
          Text('Connexion requise'.tr, style: AppFonts.title(size: 18)),
          const SizedBox(height: 8),
          Text('Connectez-vous pour inviter\ndes visiteurs à voir vos données.'.tr,
              style: AppFonts.body(color: Colors.grey, size: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AuthScreen())),
            icon: const Icon(Icons.login_rounded),
            label: Text('Se connecter / S\'inscrire'.tr),
          ),
        ])),
      );
    }

    return DefaultTabController(length: 2, child: Scaffold(
      appBar: AppBar(
        title: Text('Partage de données'.tr),
        actions: [
          // Bouton déconnexion
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20),
            tooltip: 'Se déconnecter'.tr,
            onPressed: () async => FirebaseService.instance.signOut(),
          ),
        ],
        bottom: TabBar(
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: [
            Tab(icon: Icon(Icons.people_rounded, size: 16),
                text: 'Mes visiteurs'.tr),
            Tab(icon: Icon(Icons.mail_rounded, size: 16),
                text: 'Invitations reçues'.tr),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
              heroTag: 'fab_invite_visitor',
        onPressed: () => _showInviteDialog(context),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: Text('Inviter un visiteur'.tr,
            style: AppFonts.label(color: Colors.white, size: 13)
                .copyWith(fontWeight: FontWeight.w600)),
      ),
      body: const TabBarView(children: [
        _MyVisitorsTab(),
        _InvitationsReceivedTab(),
      ]),
    ));
  }

  Future<void> _showInviteDialog(BuildContext context) async {
    final emailCtrl = TextEditingController();
    String? error;

    await showDialog(context: context, builder: (_) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        title: Row(children: [
          Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.person_add_rounded,
                  color: AppTheme.primary, size: 20)),
          const SizedBox(width: 10),
          Expanded(child: Text('Inviter un visiteur'.tr,
              style: AppFonts.title(size: 15))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          // Info accès
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.primary.withOpacity(0.2))),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.visibility_rounded,
                    color: AppTheme.primary, size: 16),
                const SizedBox(width: 8),
                Text('Accès visiteur (lecture seule)'.tr,
                    style: AppFonts.label(
                        color: AppTheme.primary, size: 12)
                        .copyWith(fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 6),
              Text(
                'Le visiteur peut consulter vos mesures et doses. Il ne peut pas modifier vos données.'.tr,
                style: AppFonts.label(
                    color: AppTheme.primary.withOpacity(0.8), size: 11),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
                labelText: 'Email du visiteur'.tr,
                hintText: 'medecin@exemple.com',
                prefixIcon: const Icon(Icons.email_rounded, size: 18),
                errorText: error),
          ),
          const SizedBox(height: 10),
          // Note
          Row(children: [
            const Icon(Icons.info_outline_rounded,
                size: 14, color: Colors.grey),
            const SizedBox(width: 6),
            Expanded(child: Text(
              'La personne doit avoir un compte Sahtek avec cet email.'.tr,
              style: AppFonts.label(color: Colors.grey, size: 11),
            )),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler'.tr,
                  style: AppFonts.body(color: Colors.grey))),
          ElevatedButton.icon(
            icon: const Icon(Icons.send_rounded, size: 15),
            label: Text('Inviter'.tr),
            onPressed: () async {
              set(() => error = null);
              try {
                await FirebaseService.instance.inviteCollaborator(
                  email: emailCtrl.text,
                  role: 'viewer',  // ← toujours visiteur, pas éditeur
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        'Invitation envoyée à {email}'.trp({'email': emailCtrl.text.trim()})),
                    backgroundColor: AppTheme.success,
                  ));
                }
              } catch (e) {
                set(() => error = e.toString()
                    .replaceAll('Exception: ', '').tr);
              }
            },
          ),
        ],
      ),
    ));
  }
}

// ── Onglet : Mes visiteurs ────────────────────────────────────────────────────
class _MyVisitorsTab extends StatelessWidget {
  const _MyVisitorsTab();

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
          return _EmptyState(
            icon: Icons.people_outline_rounded,
            title: 'Aucun visiteur'.tr,
            sub: 'Appuyez sur "Inviter" pour partager\nvos données en lecture seule.'.tr,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _VisitorCard(c: list[i]),
        );
      },
    );
  }
}

class _VisitorCard extends StatelessWidget {
  final FirebaseCollaborator c;
  const _VisitorCard({required this.c});

  Color get _statusColor => c.status == 'accepted' ? AppTheme.success
      : c.status == 'rejected' ? AppTheme.danger : AppTheme.warning;
  IconData get _statusIcon => c.status == 'accepted'
      ? Icons.check_circle_rounded
      : c.status == 'rejected'
      ? Icons.cancel_rounded : Icons.schedule_rounded;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 10, offset: const Offset(0, 3))]),
      child: Row(children: [
        // Avatar
        Container(width: 46, height: 46,
            decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle),
            child: Center(child: Text(
                c.email.isNotEmpty
                    ? c.email.substring(0, 1).toUpperCase() : '?',
                style: AppFonts.bold(
                    color: AppTheme.primary, size: 18)))),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.email, style: AppFonts.title(size: 13),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Row(children: [
            // Badge visiteur
            Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.visibility_rounded,
                      size: 10, color: AppTheme.primary),
                  const SizedBox(width: 3),
                  Text('Visiteur'.tr,
                      style: AppFonts.label(
                          color: AppTheme.primary, size: 10)
                          .copyWith(fontWeight: FontWeight.w700)),
                ])),
            const SizedBox(width: 6),
            // Statut
            Icon(_statusIcon, color: _statusColor, size: 14),
            const SizedBox(width: 3),
            Text(c.statusLabel,
                style: AppFonts.label(
                    color: _statusColor, size: 11)),
          ]),
        ])),
        // Bouton supprimer
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, size: 20),
          color: Colors.red.shade300,
          tooltip: 'Retirer l\'accès'.tr,
          onPressed: () async {
            final ok = await showDialog<bool>(context: context,
              builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: Text('Retirer l\'accès ?'.tr,
                    style: AppFonts.title(size: 15)),
                content: Text(
                    '{email} ne pourra plus voir vos données.'.trp({'email': c.email}),
                    style: AppFonts.body(size: 13)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('Annuler'.tr)),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.danger),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('Retirer'.tr),
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

// ── Onglet : Invitations reçues ───────────────────────────────────────────────
class _InvitationsReceivedTab extends StatelessWidget {
  const _InvitationsReceivedTab();

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
          return _EmptyState(
            icon: Icons.mail_outline_rounded,
            title: 'Aucune invitation'.tr,
            sub: 'Quand quelqu\'un vous invite,\nvous le verrez ici.'.tr,
          );
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.warning.withOpacity(0.4)),
          boxShadow: [BoxShadow(
              color: AppTheme.warning.withOpacity(0.08),
              blurRadius: 10)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.mail_rounded,
                  color: AppTheme.warning, size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Invitation reçue'.tr,
                style: AppFonts.label(color: AppTheme.warning, size: 11)
                    .copyWith(fontWeight: FontWeight.w700)),
            Text(inv.ownerEmail,
                style: AppFonts.title(size: 13),
                overflow: TextOverflow.ellipsis),
          ])),
        ]),
        const SizedBox(height: 8),
        Text('vous invite à consulter ses données médicales en lecture seule.'.tr,
            style: AppFonts.body(size: 13)),
        const SizedBox(height: 6),
        // Badge visiteur
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.visibility_rounded,
                size: 12, color: AppTheme.primary),
            const SizedBox(width: 5),
            Text('Accès visiteur — lecture seule uniquement'.tr,
                style: AppFonts.label(
                    color: AppTheme.primary, size: 11)
                    .copyWith(fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: () async {
              await FirebaseService.instance.rejectInvitation(inv.id);
            },
            icon: const Icon(Icons.close_rounded, size: 15),
            label: Text('Refuser'.tr),
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.danger),
                foregroundColor: AppTheme.danger),
          )),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton.icon(
            onPressed: () async {
              await FirebaseService.instance.acceptInvitation(inv.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Invitation acceptée !'.tr),
                    backgroundColor: AppTheme.success,
                  ),
                );
              }
            },
            icon: const Icon(Icons.check_rounded, size: 15),
            label: Text('Accepter'.tr),
          )),
        ]),
      ]),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  const _EmptyState({required this.icon, required this.title,
    required this.sub});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 70, color: Colors.grey.shade300),
      const SizedBox(height: 16),
      Text(title, style: AppFonts.title(
          color: Colors.grey.shade400, size: 16)),
      const SizedBox(height: 8),
      Text(sub, style: AppFonts.body(
          color: Colors.grey.shade400, size: 13),
          textAlign: TextAlign.center),
    ]),
  ));
}