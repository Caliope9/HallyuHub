import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/legal_documents.dart';
import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_mark.dart';

class BetaAccessLoadingScreen extends StatelessWidget {
  const BetaAccessLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _BetaAccessScaffold(
      title: 'Validando tu cupo',
      message:
          'Estamos revisando tu acceso anticipado a HallyuHub. Esto toma solo unos segundos.',
      icon: Icons.hourglass_top_rounded,
      child: Padding(
        padding: EdgeInsets.only(top: 18),
        child: Center(
          child: SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppTheme.cyan,
            ),
          ),
        ),
      ),
    );
  }
}

class BetaAccessGateScreen extends StatelessWidget {
  const BetaAccessGateScreen({
    super.key,
    required this.access,
    required this.onSignOut,
    this.errorMessage,
  });

  final BetaAccessState? access;
  final String? errorMessage;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final hasError = errorMessage != null && errorMessage!.trim().isNotEmpty;
    final status = access?.status;
    final title = hasError
        ? 'No pudimos validar tu acceso'
        : status == BetaAccessStatus.blocked
        ? 'Acceso restringido'
        : 'Estás en lista de espera';
    final message = hasError
        ? errorMessage!
        : status == BetaAccessStatus.blocked
        ? 'Tu acceso anticipado está restringido. Contactá soporte para revisar tu cuenta.'
        : access?.position == null
        ? 'Para entrar a HallyuHub necesitás solicitar acceso anticipado primero.'
        : 'Estás en lista de espera en el puesto #${access!.position}. Te avisaremos cuando abramos una nueva tanda.';
    final detail = hasError
        ? 'No pudimos completar la validación del acceso anticipado. Probá nuevamente en unos segundos.'
        : status == BetaAccessStatus.blocked
        ? 'Esta pantalla protege la comunidad mientras resolvemos el caso.'
        : access?.position == null
        ? 'Completá el formulario público de acceso anticipado y vas a saber en el momento si entrás o quedás en espera.'
        : 'Gracias por querer probar HallyuHub. Queremos que esta primera etapa sea cuidada, estable y con una comunidad segura.';

    return _BetaAccessScaffold(
      title: title,
      message: message,
      detail: detail,
      icon: hasError
          ? Icons.error_outline_rounded
          : status == BetaAccessStatus.blocked
          ? Icons.block_rounded
          : Icons.favorite_border_rounded,
      child: Column(
        children: [
          if (access != null && !hasError) ...[
            const SizedBox(height: 18),
            _CapacityPill(access: access!),
          ],
          if (!hasError &&
              status == BetaAccessStatus.waitlist &&
              access?.position == null) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(publicAccessUrl),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.favorite_rounded),
                label: const Text('Solicitar acceso anticipado'),
              ),
            ),
          ],
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('beta-access-sign-out'),
              onPressed: onSignOut,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Cerrar sesión'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BetaAccessScaffold extends StatelessWidget {
  const _BetaAccessScaffold({
    required this.title,
    required this.message,
    required this.icon,
    required this.child,
    this.detail,
  });

  final String title;
  final String message;
  final String? detail;
  final IconData icon;
  final Widget child;

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
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
                children: [
                  const Center(
                    child: HallyuBrandLockup(
                      iconSize: 72,
                      wordmarkSize: 32,
                      compact: true,
                    ),
                  ),
                  const SizedBox(height: 28),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.violet.withValues(alpha: 0.18),
                          blurRadius: 34,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.rose.withValues(alpha: 0.9),
                                  AppTheme.cyan.withValues(alpha: 0.9),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.rose.withValues(alpha: 0.28),
                                  blurRadius: 22,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(15),
                              child: Icon(icon, color: Colors.white, size: 30),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(color: Colors.white, fontSize: 29),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.78),
                                  height: 1.45,
                                ),
                          ),
                          if (detail != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              detail!,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.56),
                                    height: 1.4,
                                  ),
                            ),
                          ],
                          child,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _BetaLegalNotice(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BetaLegalNotice extends StatelessWidget {
  const _BetaLegalNotice();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              hallyuHubBetaAgeNotice,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.72),
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              hallyuHubOperatorNotice,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hallyuHubCopyrightNotice,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.5),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapacityPill extends StatelessWidget {
  const _CapacityPill({required this.access});

  final BetaAccessState access;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.night.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(
          '${access.approvedCount}/${access.userLimit} lugares aprobados',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
