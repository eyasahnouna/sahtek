import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/alert_rule.dart';
import '../providers/alert_provider.dart';
import '../widgets/logout_button.dart';
import '../utils/app_theme.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertes'),
        actions: const [LogoutIconButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Nouvelle règle',
            style: AppFonts.label(color: Colors.white, size: 13)
                .copyWith(fontWeight: FontWeight.w600)),
      ),
      body: Consumer<AlertProvider>(builder: (_, provider, __) {
        final rules = provider.rules;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.warning.withOpacity(0.25)),
              ),
              child: Row(children: [
                const Icon(Icons.notification_important_rounded,
                    color: AppTheme.warning, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  'Les alertes se déclenchent automatiquement quand vous '
                      'enregistrez une mesure qui correspond à une règle.',
                  style: AppFonts.body(color: AppTheme.warning, size: 12),
                )),
              ]),
            ),
            const SizedBox(height: 16),

            if (rules.isEmpty)
              Center(child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(children: [
                  Icon(Icons.notifications_off_rounded,
                      size: 60, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('Aucune règle d\'alerte',
                      style: AppFonts.title(color: Colors.grey, size: 15)),
                  const SizedBox(height: 6),
                  Text('Ajoutez une règle pour être alerté.',
                      style: AppFonts.body(color: Colors.grey, size: 13)),
                ]),
              ))
            else
              ...rules.map((r) => _AlertCard(
                rule: r,
                onToggle: () => provider.toggle(r.id),
                onEdit:   () => _showEditDialog(context, r),
                onDelete: () => provider.delete(r.id),
              )),
          ],
        );
      }),
    );
  }

  void _showAddDialog(BuildContext ctx) =>
      showDialog(context: ctx, builder: (_) =>
          _AlertRuleDialog(
              onSave: (r) => ctx.read<AlertProvider>().addOrUpdate(r)));

  void _showEditDialog(BuildContext ctx, AlertRule rule) =>
      showDialog(context: ctx, builder: (_) =>
          _AlertRuleDialog(rule: rule,
              onSave: (r) => ctx.read<AlertProvider>().addOrUpdate(r)));
}

// ── Alert card ────────────────────────────────────────────────────────────────
class _AlertCard extends StatelessWidget {
  final AlertRule rule;
  final VoidCallback onToggle, onEdit, onDelete;
  const _AlertCard({required this.rule, required this.onToggle,
    required this.onEdit, required this.onDelete});

  Color get _color => rule.isEnabled ? AppTheme.warning : Colors.grey;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: _color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(Icons.notifications_rounded, color: _color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(rule.name,
                style: AppFonts.title(color: rule.isEnabled ? null : Colors.grey, size: 14))),
            Switch(value: rule.isEnabled, onChanged: (_) => onToggle()),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            _Chip(label: rule.conditionText, color: _color),
            _Chip(label: rule.actionText, color: AppTheme.primary),
            if (rule.repeatMinutes > 0)
              _Chip(label: 'Répète /${rule.repeatMinutes}min',
                  color: AppTheme.secondary),
          ]),
          if (rule.customMessage != null) ...[
            const SizedBox(height: 8),
            Text(rule.customMessage!,
                style: AppFonts.body(color: Colors.grey.shade500, size: 12)),
          ],
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_rounded, size: 15),
              label: const Text('Modifier'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
            ),
            TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_rounded, size: 15),
              label: const Text('Supprimer'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.danger,
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
        color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25))),
    child: Text(label, style: AppFonts.label(color: color, size: 11)
        .copyWith(fontWeight: FontWeight.w600)),
  );
}

// ── Dialog création / édition ─────────────────────────────────────────────────
class _AlertRuleDialog extends StatefulWidget {
  final AlertRule? rule;
  final ValueChanged<AlertRule> onSave;
  const _AlertRuleDialog({this.rule, required this.onSave});
  @override
  State<_AlertRuleDialog> createState() => _AlertRuleDialogState();
}

class _AlertRuleDialogState extends State<_AlertRuleDialog> {
  final _nameCtrl      = TextEditingController();
  final _t1Ctrl        = TextEditingController();
  final _t2Ctrl        = TextEditingController();
  final _msgCtrl       = TextEditingController();
  final _repeatCtrl    = TextEditingController();
  late AlertCondition  _condition;
  late AlertAction     _action;

  @override
  void initState() {
    super.initState();
    final r = widget.rule;
    _nameCtrl.text   = r?.name ?? '';
    _t1Ctrl.text     = r?.threshold1.toString() ?? '1.9';
    _t2Ctrl.text     = r?.threshold2?.toString() ?? '';
    _msgCtrl.text    = r?.customMessage ?? '';
    _repeatCtrl.text = r?.repeatMinutes.toString() ?? '0';
    _condition = r?.condition ?? AlertCondition.above;
    _action    = r?.action    ?? AlertAction.notify;
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _t1Ctrl.dispose(); _t2Ctrl.dispose();
    _msgCtrl.dispose(); _repeatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.rule == null ? 'Nouvelle alerte' : 'Modifier',
          style: AppFonts.title(size: 16)),
      content: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Nom de la règle')),
        const SizedBox(height: 10),
        DropdownButtonFormField<AlertCondition>(
          value: _condition,
          decoration: const InputDecoration(labelText: 'Condition'),
          items: const [
            DropdownMenuItem(value: AlertCondition.above,   child: Text('Supérieur à (>)')),
            DropdownMenuItem(value: AlertCondition.below,   child: Text('Inférieur à (<)')),
            DropdownMenuItem(value: AlertCondition.between, child: Text('Entre deux valeurs')),
          ],
          onChanged: (v) { if (v != null) setState(() => _condition = v); },
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(
            controller: _t1Ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
            decoration: const InputDecoration(labelText: 'Valeur 1 (Mg/dl)'),
          )),
          if (_condition == AlertCondition.between) ...[
            const SizedBox(width: 10),
            Expanded(child: TextField(
              controller: _t2Ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
              decoration: const InputDecoration(labelText: 'Valeur 2'),
            )),
          ],
        ]),
        const SizedBox(height: 10),
        DropdownButtonFormField<AlertAction>(
          value: _action,
          decoration: const InputDecoration(labelText: 'Action'),
          items: const [
            DropdownMenuItem(value: AlertAction.notify,    child: Text('Notification simple')),
            DropdownMenuItem(value: AlertAction.hydration, child: Text('Rappel hydratation')),
            DropdownMenuItem(value: AlertAction.insulin,   child: Text('Alerte insuline')),
            DropdownMenuItem(value: AlertAction.call,      child: Text('Appel d\'urgence')),
          ],
          onChanged: (v) { if (v != null) setState(() => _action = v); },
        ),
        if (_action == AlertAction.hydration) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _repeatCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
                labelText: 'Répéter toutes les X minutes (0 = une seule fois)'),
          ),
        ],
        const SizedBox(height: 10),
        TextField(controller: _msgCtrl, maxLines: 2,
            decoration: const InputDecoration(
                labelText: 'Message personnalisé (optionnel)')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: AppFonts.body(color: Colors.grey))),
        ElevatedButton(
          onPressed: () {
            final t1 = double.tryParse(_t1Ctrl.text.replaceAll(',', '.')) ?? 1.9;
            final t2 = double.tryParse(_t2Ctrl.text.replaceAll(',', '.'));
            final r = (widget.rule ?? AlertRule(
              name: _nameCtrl.text, condition: _condition,
              threshold1: t1, action: _action,
            )).copyWith(
              name: _nameCtrl.text.isEmpty ? 'Alerte' : _nameCtrl.text,
              condition: _condition, threshold1: t1, threshold2: t2,
              action: _action,
              customMessage: _msgCtrl.text.isEmpty ? null : _msgCtrl.text,
              repeatMinutes: int.tryParse(_repeatCtrl.text) ?? 0,
            );
            widget.onSave(r);
            Navigator.pop(context);
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}