import 'package:flutter/material.dart';

import '../services/media_permission_service.dart';
import '../theme/app_theme.dart';

Future<bool> requestContextualPermission({
  required BuildContext context,
  required MediaPermissionService permissionService,
  required IconData icon,
  required String title,
  required String detail,
  required String allowLabel,
  required Future<MediaAccessResult> Function() currentStatus,
  required Future<MediaAccessResult> Function() request,
}) async {
  if (await currentStatus() == MediaAccessResult.ready) return true;
  if (!context.mounted) return false;
  final shouldRequest = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _PermissionSheet(
      icon: icon,
      title: title,
      detail: detail,
      primaryLabel: allowLabel,
      onPrimary: () => Navigator.of(sheetContext).pop(true),
    ),
  );
  if (shouldRequest != true || !context.mounted) return false;

  final result = await request();
  if (result == MediaAccessResult.ready) return true;
  if (!context.mounted) return false;

  final needsSettings =
      result == MediaAccessResult.denied ||
      result == MediaAccessResult.settingsRequired;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _PermissionSheet(
      icon: needsSettings ? Icons.settings_outlined : Icons.info_outline,
      title: needsSettings
          ? 'Habilitalo desde Ajustes'
          : 'Acceso no disponible',
      detail: result == MediaAccessResult.restricted
          ? 'El dispositivo tiene una restricción activa para este permiso.'
          : 'Podés continuar sin esta función o habilitar el permiso desde los ajustes del teléfono.',
      primaryLabel: needsSettings ? 'Abrir Ajustes' : 'Entendido',
      onPrimary: () async {
        Navigator.of(sheetContext).pop();
        if (needsSettings) await permissionService.openSettings();
      },
    ),
  );
  return false;
}

class _PermissionSheet extends StatelessWidget {
  const _PermissionSheet({
    required this.icon,
    required this.title,
    required this.detail,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String primaryLabel;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: const BoxDecoration(
        color: AppTheme.nightSoft,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Icon(icon, color: AppTheme.cyan, size: 36),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              key: const ValueKey('contextual-permission-allow'),
              onPressed: onPrimary,
              child: Text(primaryLabel),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Ahora no'),
            ),
          ],
        ),
      ),
    );
  }
}
