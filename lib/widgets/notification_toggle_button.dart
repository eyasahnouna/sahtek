import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../l10n/l10n.dart';

class NotificationToggleButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const NotificationToggleButton({super.key, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: enabled
                ? Colors.white.withOpacity(0.22)
                : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Icon(
                  enabled ? Icons.notifications_active_rounded
                      : Icons.notifications_off_rounded,
                  key: ValueKey(enabled), color: Colors.white, size: 16),
            ),
            const SizedBox(width: 5),
            Text(enabled ? 'Notif ON'.tr : 'Notif OFF'.tr,
                style: AppFonts.label(color: Colors.white, size: 11)
                    .copyWith(fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}