import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/reminder.dart';
import '../providers/reminder_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/logout_button.dart';
import '../l10n/l10n.dart';

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rappels'.tr),
        actions: const [LogoutIconButton()],
      ),
      body: Consumer<ReminderProvider>(builder: (_, provider, __) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Bannière info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppTheme.primary, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  'Les rappels vous notifient chaque jour à l\'heure choisie.'.tr,
                  style: AppFonts.body(color: AppTheme.primary, size: 13),
                )),
              ]),
            ),
            const SizedBox(height: 16),

            ...provider.reminders.map((r) => _ReminderCard(
              reminder: r,
              onToggle: () => provider.toggleEnabled(r.id),
              onEdit:   () => _showEditDialog(context, r, provider),
              onDelete: r.type == ReminderType.custom
                  ? () => provider.delete(r.id) : null,
            )),

            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _showAddDialog(context, provider),
              icon: const Icon(Icons.add_rounded, color: AppTheme.primary),
              label: Text('Ajouter un rappel personnalisé'.tr,
                  style: AppFonts.label(color: AppTheme.primary, size: 13)
                      .copyWith(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      }),
    );
  }

  void _showEditDialog(BuildContext ctx, Reminder r, ReminderProvider p) =>
      showDialog(context: ctx, builder: (_) =>
          _ReminderDialog(reminder: r, onSave: p.addOrUpdate));

  void _showAddDialog(BuildContext ctx, ReminderProvider p) =>
      showDialog(context: ctx, builder: (_) =>
          _ReminderDialog(onSave: p.addOrUpdate));
}

// ── Reminder card ─────────────────────────────────────────────────────────────
class _ReminderCard extends StatelessWidget {
  final Reminder reminder;
  final VoidCallback onToggle, onEdit;
  final VoidCallback? onDelete;
  const _ReminderCard({required this.reminder, required this.onToggle,
    required this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final active = reminder.isEnabled;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: (active ? AppTheme.primary : Colors.grey).withOpacity(0.12),
              shape: BoxShape.circle),
          child: Icon(reminder.type.icon,
              color: active ? AppTheme.primary : Colors.grey, size: 22),
        ),
        title: Text(reminder.displayLabel,
            style: AppFonts.title(color: active ? null : Colors.grey, size: 14)),
        subtitle: Text(reminder.timeString,
            style: AppFonts.bold(color: active ? AppTheme.primary : Colors.grey, size: 16)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 18),
            color: Colors.grey.shade400, onPressed: onEdit,
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_rounded, size: 18),
              color: AppTheme.danger.withOpacity(0.6), onPressed: onDelete,
            ),
          Switch(value: active, onChanged: (_) => onToggle()),
        ]),
      ),
    );
  }
}

// ── Dialog édition / ajout ────────────────────────────────────────────────────
class _ReminderDialog extends StatefulWidget {
  final Reminder? reminder;
  final ValueChanged<Reminder> onSave;
  const _ReminderDialog({this.reminder, required this.onSave});
  @override
  State<_ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<_ReminderDialog> {
  late TimeOfDay _time;
  late ReminderType _type;
  final _labelCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _time  = widget.reminder?.time ?? const TimeOfDay(hour: 8, minute: 0);
    _type  = widget.reminder?.type ?? ReminderType.custom;
    _labelCtrl.text = widget.reminder?.customLabel ?? '';
  }

  @override
  void dispose() { _labelCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.reminder == null ? 'Nouveau rappel'.tr : 'Modifier'.tr,
          style: AppFonts.title(size: 16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<ReminderType>(
          value: _type,
          decoration: InputDecoration(labelText: 'Type'.tr),
          items: ReminderType.values.map((t) => DropdownMenuItem(
            value: t,
            child: Row(children: [
              Icon(t.icon, size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(t.label, style: AppFonts.body(size: 13)),
            ]),
          )).toList(),
          onChanged: (v) { if (v != null) setState(() => _type = v); },
        ),
        if (_type == ReminderType.custom) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _labelCtrl,
            decoration: InputDecoration(labelText: 'Libellé personnalisé'.tr),
          ),
        ],
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            final t = await showTimePicker(
              context: context, initialTime: _time,
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                    colorScheme: const ColorScheme.light(
                        primary: AppTheme.primary)),
                child: child!,
              ),
            );
            if (t != null) setState(() => _time = t);
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primary.withOpacity(0.2))),
            child: Row(children: [
              const Icon(Icons.access_time_rounded,
                  color: AppTheme.primary, size: 18),
              const SizedBox(width: 10),
              Text('Heure : '.tr, style: AppFonts.label(size: 13)),
              Text('${_time.hour.toString().padLeft(2, '0')}:'
                  '${_time.minute.toString().padLeft(2, '0')}',
                  style: AppFonts.bold(color: AppTheme.primary, size: 18)),
              const Spacer(),
              Icon(Icons.edit_rounded, size: 14,
                  color: AppTheme.primary.withOpacity(0.5)),
            ]),
          ),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: Text('Annuler'.tr, style: AppFonts.body(color: Colors.grey))),
        ElevatedButton(
          onPressed: () {
            final r = (widget.reminder ??
                Reminder(type: _type, time: _time))
                .copyWith(
              type: _type, time: _time,
              customLabel: _labelCtrl.text.isEmpty ? null : _labelCtrl.text,
            );
            widget.onSave(r);
            Navigator.pop(context);
          },
          child: Text('Enregistrer'.tr),
        ),
      ],
    );
  }
}