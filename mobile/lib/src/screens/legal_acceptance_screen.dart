import 'package:flutter/material.dart';

import '../data/legal_documents.dart';
import '../models.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_mark.dart';

class LegalAcceptanceScreen extends StatefulWidget {
  const LegalAcceptanceScreen({
    super.key,
    required this.user,
    required this.onAccepted,
    required this.onSignOut,
  });

  final AuthUser user;
  final Future<void> Function(AuthUser user) onAccepted;
  final Future<void> Function() onSignOut;

  @override
  State<LegalAcceptanceScreen> createState() => _LegalAcceptanceScreenState();
}

class _LegalAcceptanceScreenState extends State<LegalAcceptanceScreen> {
  final Set<String> _accepted = {};
  bool _isSaving = false;
  String? _error;

  bool get _canContinue {
    return legalAcceptanceDocuments.every(
      (document) => _accepted.contains(document.id),
    );
  }

  Future<void> _acceptAndContinue() async {
    if (!_canContinue || _isSaving) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    final acceptedAt = DateTime.now().toUtc();
    final nextUser = widget.user.copyWith(
      termsAcceptedAt: acceptedAt,
      privacyAcceptedAt: acceptedAt,
      communityGuidelinesAcceptedAt: acceptedAt,
      betaNoticeAcceptedAt: acceptedAt,
      legalVersion: hallyuHubLegalVersion,
    );
    try {
      await widget.onAccepted(nextUser);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = error is AuthException
            ? error.message
            : 'No pudimos guardar tu aceptación legal. Revisá conexión y probá de nuevo.';
      });
    }
  }

  void _toggle(String id, bool? value) {
    setState(() {
      if (value ?? false) {
        _accepted.add(id);
      } else {
        _accepted.remove(id);
      }
      _error = null;
    });
  }

  void _openDocument(LegalDocument document) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentScreen(document: document),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.night,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF090314), Color(0xFF190924), Color(0xFF05151E)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                children: [
                  const Center(
                    child: HallyuBrandLockup(
                      iconSize: 72,
                      wordmarkSize: 32,
                      compact: true,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    'Antes de continuar',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontSize: 30,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'HallyuHub en acceso anticipado usa cuentas, contenido y mensajes reales. '
                    'Necesitamos que leas y aceptes los documentos base para seguir.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.76),
                      height: 1.42,
                    ),
                  ),
                  const SizedBox(height: 22),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.violet.withValues(alpha: 0.16),
                          blurRadius: 32,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          for (final document in legalAcceptanceDocuments) ...[
                            _LegalAcceptanceTile(
                              key: ValueKey('legal-accept-${document.id}'),
                              document: document,
                              accepted: _accepted.contains(document.id),
                              onChanged: (value) => _toggle(document.id, value),
                              onRead: () => _openDocument(document),
                            ),
                            if (document != legalAcceptanceDocuments.last)
                              Divider(
                                color: Colors.white.withValues(alpha: 0.08),
                                height: 18,
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.rose,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _GradientButton(
                    key: const ValueKey('legal-accept-submit'),
                    label: _isSaving ? 'Guardando...' : 'Aceptar y continuar',
                    icon: Icons.check_circle_outline,
                    enabled: _canContinue && !_isSaving,
                    onPressed: _acceptAndContinue,
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _isSaving ? null : () => widget.onSignOut(),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Cerrar sesion'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.76),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Version legal: $hallyuHubLegalVersion',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.42),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Contacto y soporte: $supportEmail',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.54),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hallyuHubCopyrightNotice,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.42),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.night,
      appBar: AppBar(
        backgroundColor: AppTheme.night,
        foregroundColor: Colors.white,
        title: Text(document.title),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Text(
              document.subtitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 16),
            for (final paragraph in document.paragraphs)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  paragraph,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    height: 1.46,
                  ),
                ),
              ),
            if (!document.paragraphs.contains(hallyuHubCopyrightNotice)) ...[
              const SizedBox(height: 6),
              Text(
                hallyuHubCopyrightNotice,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.58),
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegalAcceptanceTile extends StatelessWidget {
  const _LegalAcceptanceTile({
    super.key,
    required this.document,
    required this.accepted,
    required this.onChanged,
    required this.onRead,
  });

  final LegalDocument document;
  final bool accepted;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          key: ValueKey('legal-checkbox-${document.id}'),
          value: accepted,
          onChanged: onChanged,
          activeColor: AppTheme.rose,
          checkColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                document.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                document.subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        TextButton(onPressed: onRead, child: const Text('Leer')),
      ],
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    super.key,
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.46,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [AppTheme.rose, AppTheme.violet, AppTheme.cyan],
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.rose.withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
