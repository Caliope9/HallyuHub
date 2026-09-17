import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/legal_documents.dart';
import '../models.dart';
import '../services/beta_signup_service.dart';
import '../services/feedback_report_service.dart';
import '../services/content_moderation_service.dart';
import '../services/local_artist_tag_service.dart';
import '../services/news_service.dart';
import '../services/store_profile_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_mark.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({
    super.key,
    required this.user,
    required this.betaSignupService,
    required this.feedbackReportService,
    required this.artistTagService,
    required this.storeProfileService,
    this.contentModerationService = const UnavailableContentModerationService(),
  });

  final AuthUser user;
  final BetaSignupService betaSignupService;
  final FeedbackReportService feedbackReportService;
  final LocalArtistTagService artistTagService;
  final StoreProfileService storeProfileService;
  final ContentModerationService contentModerationService;

  @override
  Widget build(BuildContext context) {
    if (!user.canAccessAdminPanel) {
      return Scaffold(
        backgroundColor: AppTheme.night,
        appBar: AppBar(
          backgroundColor: AppTheme.night,
          foregroundColor: Colors.white,
          title: const Text('Panel Admin'),
        ),
        body: const _AdminAccessDenied(),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.night,
      appBar: AppBar(
        backgroundColor: AppTheme.night,
        foregroundColor: Colors.white,
        title: const Text('Panel Admin'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          children: [
            const _AdminHero(),
            const SizedBox(height: 18),
            _AdminSectionCard(
              icon: Icons.verified_user_outlined,
              title: 'Acceso anticipado',
              detail:
                  'Cupos, usuarios aprobados y lista de espera. La gestión completa queda protegida por Supabase.',
              status: 'Preparado',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AdminBetaPanelScreen(
                    user: user,
                    betaSignupService: betaSignupService,
                  ),
                ),
              ),
            ),
            _AdminSectionCard(
              icon: Icons.newspaper_rounded,
              title: 'Noticias',
              detail:
                  'Control del importador automático, fuentes, rumores y errores. Las noticias completas se publican sin aprobación manual.',
              status: 'Automático',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AdminNewsPanelScreen(user: user),
                ),
              ),
            ),
            _AdminSectionCard(
              icon: Icons.flag_outlined,
              title: 'Denuncias',
              detail:
                  'Revisión de reportes de perfiles y contenido. Solo roles autorizados deben poder leer estos datos.',
              status: 'Privado',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AdminContentReportsPanelScreen(
                    user: user,
                    moderationService: contentModerationService,
                  ),
                ),
              ),
            ),
            _AdminSectionCard(
              icon: Icons.person_remove_outlined,
              title: 'Eliminaciones de cuenta',
              detail:
                  'Seguimiento administrativo. El procesamiento requiere un backend seguro separado.',
              status: 'Preparado',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AdminDeletionInfoScreen(),
                ),
              ),
            ),
            _AdminSectionCard(
              icon: Icons.bug_report_outlined,
              title: 'Problemas / Feedback',
              detail:
                  'Espacio para ordenar errores reportados por usuarios durante el acceso anticipado.',
              status: 'Real',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AdminFeedbackPanelScreen(
                    user: user,
                    feedbackReportService: feedbackReportService,
                  ),
                ),
              ),
            ),
            _AdminSectionCard(
              icon: Icons.auto_awesome_outlined,
              title: 'Sugerencias',
              detail:
                  'Grupos, idols y artistas propuestos por fans. Nada se publica hasta que lo revises.',
              status: 'Real',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AdminArtistSuggestionsPanelScreen(
                    user: user,
                    artistTagService: artistTagService,
                  ),
                ),
              ),
            ),
            _AdminSectionCard(
              icon: Icons.storefront_outlined,
              title: 'Tiendas',
              detail:
                  'Perfiles tienda enviados por fans. Revisá, activá, pausá o verificá sin publicar productos.',
              status: 'Real',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AdminStoreProfilesPanelScreen(
                    user: user,
                    storeProfileService: storeProfileService,
                  ),
                ),
              ),
            ),
            _AdminSectionCard(
              icon: Icons.group_outlined,
              title: 'Usuarios',
              detail:
                  'Vista preparada para revisar cuentas, roles y estado de acceso sin exponer claves sensibles.',
              status: 'RLS',
            ),
            const SizedBox(height: 12),
            Text(
              'Tu acceso viene de profiles.role = ${user.role}. No se usa contraseña admin ni service_role en la app.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminContentReportsPanelScreen extends StatefulWidget {
  const AdminContentReportsPanelScreen({
    super.key,
    required this.user,
    required this.moderationService,
  });

  final AuthUser user;
  final ContentModerationService moderationService;

  @override
  State<AdminContentReportsPanelScreen> createState() =>
      _AdminContentReportsPanelScreenState();
}

class _AdminContentReportsPanelScreenState
    extends State<AdminContentReportsPanelScreen> {
  // Load every report first so an older/invalid status cannot make the inbox
  // look empty. The status chips still allow focused review afterwards.
  String _status = 'all';
  List<ContentReport> _reports = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    debugPrint(
      'ADMIN_REPORTS_PANEL_INIT service=${widget.moderationService.runtimeType} '
      'role=${widget.user.role} username=${widget.user.username}',
    );
    _load();
  }

  Future<void> _load() async {
    if (!widget.user.canAccessAdminPanel) {
      debugPrint(
        'ADMIN_REPORTS_LOAD_SKIPPED reason=role_not_allowed '
        'service=${widget.moderationService.runtimeType} role=${widget.user.role}',
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No tenés permisos para ver las denuncias.';
      });
      return;
    }
    debugPrint(
      'ADMIN_REPORTS_LOAD_START service=${widget.moderationService.runtimeType} '
      'status=$_status',
    );
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reports = await widget.moderationService.listReports(
        status: _status,
      );
      if (!mounted) return;
      debugPrint(
        'ADMIN_REPORTS_LOAD_OK count=${reports.length} status=$_status',
      );
      setState(() {
        _reports = reports;
        _loading = false;
      });
    } catch (error) {
      debugPrint('ADMIN_REPORTS_LOAD_ERROR error=$error');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ContentModerationException
            ? error.message
            : 'No pudimos cargar las denuncias.';
      });
    }
  }

  Future<void> _update(ContentReport report, String status) async {
    final noteController = TextEditingController(text: report.resolutionNote);
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_reportStatusLabel(status)),
        content: TextField(
          controller: noteController,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Nota interna opcional'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(noteController.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    noteController.dispose();
    if (note == null || !mounted) return;
    try {
      await widget.moderationService.updateReport(
        id: report.id,
        status: status,
        resolutionNote: note,
      );
      await _load();
    } catch (error) {
      debugPrint('ADMIN_REPORT_UPDATE_UI_ERROR error=$error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is ContentModerationException
                  ? error.message
                  : 'No pudimos actualizar la denuncia.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _hide(ContentReport report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ocultar contenido'),
        content: Text(
          'Se ocultará ${report.contentType} y la denuncia quedará resuelta. Esta acción no borra el contenido físicamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ocultar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.moderationService.hideContent(
        report: report,
        reason: 'Ocultado por moderación desde Panel Admin.',
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contenido ocultado y denuncia resuelta.'),
        ),
      );
    } catch (error) {
      debugPrint('ADMIN_REPORT_HIDE_UI_ERROR error=$error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ContentModerationException
                ? error.message
                : 'No pudimos ocultar el contenido.',
          ),
        ),
      );
    }
  }

  Future<void> _enforce(ContentReport report, String status) async {
    if (report.reportedUserId.isEmpty) return;
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Aplicar ${_enforcementLabel(status)}'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motivo obligatorio',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.of(context).pop(value);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;
    try {
      await widget.moderationService.enforceUser(
        userId: report.reportedUserId,
        status: status,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_enforcementLabel(status)} aplicada.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ContentModerationException
                ? error.message
                : 'No pudimos aplicar la medida.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.user.canAccessAdminPanel) {
      return const Scaffold(body: _AdminAccessDenied());
    }
    return Scaffold(
      backgroundColor: AppTheme.night,
      appBar: AppBar(
        backgroundColor: AppTheme.night,
        foregroundColor: Colors.white,
        title: const Text('Denuncias'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: Row(
                children: [
                  for (final value in const [
                    'all',
                    'pending',
                    'reviewing',
                    'resolved',
                    'dismissed',
                  ]) ...[
                    ChoiceChip(
                      label: Text(_reportStatusLabel(value)),
                      selected: _status == value,
                      onSelected: (_) {
                        setState(() => _status = value);
                        _load();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    )
                  : _reports.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay denuncias con este estado.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                        itemCount: _reports.length,
                        itemBuilder: (context, index) {
                          final report = _reports[index];
                          return _ReportCard(
                            report: report,
                            onStatus: (status) => _update(report, status),
                            onHide: () => _hide(report),
                            onEnforce: (status) => _enforce(report, status),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.onStatus,
    required this.onHide,
    required this.onEnforce,
  });

  final ContentReport report;
  final ValueChanged<String> onStatus;
  final VoidCallback onHide;
  final ValueChanged<String> onEnforce;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withValues(alpha: 0.08),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${report.contentType} · ${report.contentId}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _StatusPill(_reportStatusLabel(report.status)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Motivo: ${report.reason}',
              style: const TextStyle(color: Colors.white70),
            ),
            if (report.details.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                report.details,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Reportó: ${report.reporterId}\nUsuario reportado: ${report.reportedUserId.isEmpty ? 'No informado' : report.reportedUserId}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                if (report.status == 'pending')
                  OutlinedButton(
                    onPressed: () => onStatus('reviewing'),
                    child: const Text('Marcar en revisión'),
                  ),
                if (report.status == 'pending' ||
                    report.status == 'reviewing') ...[
                  if (_moderatableContentTypes.contains(
                    report.contentType.trim().toLowerCase(),
                  ))
                    OutlinedButton(
                      onPressed: onHide,
                      child: const Text('Ocultar contenido'),
                    ),
                  OutlinedButton(
                    onPressed: () => onStatus('resolved'),
                    child: const Text('Resolver'),
                  ),
                  OutlinedButton(
                    onPressed: () => onStatus('dismissed'),
                    child: const Text('Descartar'),
                  ),
                ],
              ],
            ),
            if (report.reportedUserId.isNotEmpty &&
                (report.status == 'pending' || report.status == 'reviewing'))
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => onEnforce('restricted'),
                    child: const Text('Restringir usuario'),
                  ),
                  TextButton(
                    onPressed: () => onEnforce('suspended'),
                    child: const Text('Suspender usuario'),
                  ),
                  TextButton(
                    onPressed: () => onEnforce('banned'),
                    child: const Text('Banear usuario'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class AdminDeletionInfoScreen extends StatelessWidget {
  const AdminDeletionInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.night,
      appBar: AppBar(
        backgroundColor: AppTheme.night,
        foregroundColor: Colors.white,
        title: const Text('Eliminaciones de cuenta'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'El seguimiento administrativo requiere una RPC protegida para listar solicitudes. La app no consulta directamente account_deletion_requests ni procesa eliminaciones desde Flutter.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
      ),
    );
  }
}

String _reportStatusLabel(String status) {
  return switch (status) {
    'all' => 'Todas',
    'pending' => 'Pendientes',
    'reviewing' => 'En revisión',
    'resolved' => 'Resueltas',
    'dismissed' => 'Descartadas',
    _ => status,
  };
}

String _enforcementLabel(String status) => switch (status) {
  'restricted' => 'restricción',
  'suspended' => 'suspensión',
  'banned' => 'ban',
  _ => status,
};

const _moderatableContentTypes = <String>{
  'post',
  'drop',
  'fancam',
  'comment',
  'drop_comment',
  'fancam_comment',
  'story',
  'direct_message',
  'community',
  'community_message',
};

class _AdminAccessDenied extends StatelessWidget {
  const _AdminAccessDenied();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            color: AppTheme.nightSoft,
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, color: AppTheme.rose, size: 42),
              SizedBox(height: 14),
              Text(
                'No tenés permisos para ver esta sección',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'El Panel Admin solo está disponible para cuentas con rol admin o moderator en Supabase.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminHero extends StatelessWidget {
  const _AdminHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.rose.withValues(alpha: 0.42),
            AppTheme.violet.withValues(alpha: 0.32),
            AppTheme.cyan.withValues(alpha: 0.24),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.rose.withValues(alpha: 0.2),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: const Row(
        children: [
          HallyuBrandIcon(size: 52, radiusFactor: 0.28),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Panel Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Base privada para moderar el acceso anticipado de HallyuHub.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSectionCard extends StatelessWidget {
  const _AdminSectionCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.status,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Colors.white.withValues(alpha: 0.07),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.cyan.withValues(alpha: 0.32),
                      AppTheme.rose.withValues(alpha: 0.26),
                    ],
                  ),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _StatusPill(status),
                        if (onTap != null) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white70,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      detail,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.66),
                        fontWeight: FontWeight.w700,
                        height: 1.32,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminNewsPanelScreen extends StatefulWidget {
  const AdminNewsPanelScreen({super.key, required this.user});

  final AuthUser user;

  @override
  State<AdminNewsPanelScreen> createState() => _AdminNewsPanelScreenState();
}

class _AdminNewsPanelScreenState extends State<AdminNewsPanelScreen> {
  final SupabaseNewsService _newsService = SupabaseNewsService();
  NewsAdminSnapshot _snapshot = const NewsAdminSnapshot(items: [], runs: []);
  String _filter = 'all';
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    if (!widget.user.canAccessAdminPanel) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await _newsService.restoreAdminSnapshot();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } on NewsServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  List<NewsAdminItem> get _filteredItems {
    return _snapshot.items
        .where((item) {
          return switch (_filter) {
            'published' => item.isPublished && item.autoPublished,
            'rumor' => item.isPublished && item.editorialStatus == 'rumor',
            'developing' =>
              item.isPublished && item.editorialStatus == 'developing',
            'unpublished' => !item.isPublished,
            _ => true,
          };
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.user.canAccessAdminPanel) {
      return const Scaffold(
        backgroundColor: AppTheme.night,
        body: _AdminAccessDenied(),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.night,
      appBar: AppBar(
        backgroundColor: AppTheme.night,
        foregroundColor: Colors.white,
        title: const Text('Admin · Noticias'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _restore,
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            const _AdminPanelIntro(
              icon: Icons.newspaper_rounded,
              title: 'Noticias automáticas',
              detail:
                  'El importador publica contenido completo cada 60 minutos. Este panel sirve para control y diagnóstico, no para aprobar una por una.',
            ),
            const SizedBox(height: 16),
            if (_loading)
              const _AdminLoadingCard(text: 'Cargando estado del importador...')
            else if (_error != null)
              _NewsAdminErrorCard(message: _error!, onRetry: _restore)
            else ...[
              _NewsImportRunCard(run: _snapshot.latestRun),
              const SizedBox(height: 14),
              _NewsAdminStats(snapshot: _snapshot),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChipButton(
                      label: 'Todas',
                      value: 'all',
                      selected: _filter == 'all',
                      onSelected: (value) => setState(() => _filter = value),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipButton(
                      label: 'Publicadas',
                      value: 'published',
                      selected: _filter == 'published',
                      onSelected: (value) => setState(() => _filter = value),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipButton(
                      label: 'Rumores',
                      value: 'rumor',
                      selected: _filter == 'rumor',
                      onSelected: (value) => setState(() => _filter = value),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipButton(
                      label: 'En desarrollo',
                      value: 'developing',
                      selected: _filter == 'developing',
                      onSelected: (value) => setState(() => _filter = value),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipButton(
                      label: 'No publicadas',
                      value: 'unpublished',
                      selected: _filter == 'unpublished',
                      onSelected: (value) => setState(() => _filter = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_filteredItems.isEmpty)
                const _AdminEmptyCard(
                  text: 'Todavía no hay noticias en este estado.',
                )
              else
                for (final item in _filteredItems) _NewsAdminTile(item: item),
            ],
          ],
        ),
      ),
    );
  }
}

class _NewsAdminStats extends StatelessWidget {
  const _NewsAdminStats({required this.snapshot});

  final NewsAdminSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final stats = [
      ('Publicadas', snapshot.autoPublishedCount, AppTheme.cyan),
      ('Rumores', snapshot.rumorCount, AppTheme.rose),
      ('En desarrollo', snapshot.developingCount, AppTheme.violet),
      ('Incompletas', snapshot.unpublishedCount, Colors.orangeAccent),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final stat in stats)
              SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: stat.$3.withValues(alpha: 0.1),
                    border: Border.all(color: stat.$3.withValues(alpha: 0.28)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${stat.$2}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stat.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.68),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _NewsImportRunCard extends StatelessWidget {
  const _NewsImportRunCard({required this.run});

  final NewsImportRunRecord? run;

  @override
  Widget build(BuildContext context) {
    final current = run;
    final hasError = current?.errorMessage.isNotEmpty ?? false;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.07),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: current == null
          ? const Text(
              'Aún no hay ejecuciones registradas.',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w800,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Última importación',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _StatusPill(_newsStatusLabel(current.status)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${_newsDateLabel(current.startedAt)} · '
                  '${current.importedCount} importadas · '
                  '${current.publishedCount} publicadas · '
                  '${current.skippedCount} omitidas',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                if (hasError) ...[
                  const SizedBox(height: 8),
                  Text(
                    current.errorMessage,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _NewsAdminTile extends StatelessWidget {
  const _NewsAdminTile({required this.item});

  final NewsAdminItem item;

  Future<void> _openSource() async {
    final uri = Uri.tryParse(item.articleUrl);
    if (uri == null) return;
    await launchUrl(uri, webOnlyWindowName: '_blank');
  }

  @override
  Widget build(BuildContext context) {
    final detail = [
      item.sourceName.isEmpty ? 'Fuente pendiente' : item.sourceName,
      _newsDateLabel(item.publishedAt),
      if (item.qualityScore != null) 'calidad ${item.qualityScore}/100',
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StatusPill(_newsStatusLabel(item.editorialStatus)),
                    const SizedBox(width: 7),
                    if (!item.isPublished) const _StatusPill('No publicada'),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  detail,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!item.isPublished && item.rejectionReason.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    item.rejectionReason,
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (item.articleUrl.isNotEmpty)
            IconButton(
              onPressed: _openSource,
              tooltip: 'Abrir fuente original',
              icon: const Icon(Icons.open_in_new_rounded),
              color: AppTheme.cyan,
            ),
        ],
      ),
    );
  }
}

class _NewsAdminErrorCard extends StatelessWidget {
  const _NewsAdminErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: AppTheme.rose.withValues(alpha: 0.1),
        border: Border.all(color: AppTheme.rose.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

String _newsStatusLabel(String status) {
  return switch (status.toLowerCase()) {
    'official' => 'Oficial',
    'confirmed' => 'Confirmado',
    'developing' => 'En desarrollo',
    'rumor' => 'Rumor',
    'trending' => 'Tendencia',
    'success' => 'Correcta',
    'partial' => 'Con avisos',
    'failed' => 'Falló',
    'running' => 'En curso',
    'skipped' => 'Omitida',
    _ => status.isEmpty ? 'Pendiente' : status,
  };
}

String _newsDateLabel(DateTime? date) {
  if (date == null) return 'Fecha pendiente';
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/${local.year} · $hour:$minute';
}

class AdminBetaPanelScreen extends StatefulWidget {
  const AdminBetaPanelScreen({
    super.key,
    required this.user,
    required this.betaSignupService,
  });

  final AuthUser user;
  final BetaSignupService betaSignupService;

  @override
  State<AdminBetaPanelScreen> createState() => _AdminBetaPanelScreenState();
}

class _AdminBetaPanelScreenState extends State<AdminBetaPanelScreen> {
  final _queryController = TextEditingController();
  final _countryController = TextEditingController();
  String _status = 'all';
  String _platform = 'all';
  bool _loading = true;
  bool _updating = false;
  String? _error;
  BetaSignupAdminData _data = const BetaSignupAdminData(entries: []);

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    if (!widget.user.canAccessAdminPanel) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.betaSignupService.restoreAdminData(
        status: _status,
        platform: _platform,
        country: _countryController.text,
        query: _queryController.text,
      );
      if (!mounted) return;
      setState(() => _data = data);
    } on BetaSignupException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = 'No pudimos cargar la lista de acceso anticipado.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _update(
    BetaSignupEntry entry, {
    String? status,
    String? adminNotes,
    int? priorityScore,
    bool markInvited = false,
    bool resetReferralScore = false,
  }) async {
    if (_updating) return;
    setState(() {
      _updating = true;
      _error = null;
    });
    try {
      await widget.betaSignupService.updateSignup(
        id: entry.id,
        status: status,
        adminNotes: adminNotes,
        priorityScore: priorityScore,
        markInvited: markInvited,
        resetReferralScore: resetReferralScore,
      );
      await _restore();
    } on BetaSignupException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _approve(BetaSignupEntry entry) async {
    await _update(entry, status: 'approved');
    if (!mounted) return;
    if (entry.status == BetaSignupStatus.waiting) {
      _snack('Cupo aprobado. Ya podés copiar el mensaje de invitación.');
    }
  }

  Future<void> _editNote(BetaSignupEntry entry) async {
    final controller = TextEditingController(text: entry.adminNotes);
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.nightSoft,
        title: const Text(
          'Nota admin',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Agregar nota interna'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note == null) return;
    await _update(entry, adminNotes: note);
  }

  Future<void> _copyApprovedEmails() async {
    final emails = _data.entries
        .where((entry) => entry.status == BetaSignupStatus.approved)
        .map((entry) => entry.email)
        .where((email) => email.isNotEmpty)
        .join('\n');
    await Clipboard.setData(ClipboardData(text: emails));
    if (!mounted) return;
    _snack('Emails aprobados copiados.');
  }

  Future<void> _copyEmail(BetaSignupEntry entry) async {
    await Clipboard.setData(ClipboardData(text: entry.email));
    if (!mounted) return;
    _snack('Email copiado.');
  }

  String _inviteMessageFor(BetaSignupEntry entry) {
    final name = entry.nickname.trim();
    final greeting = name.isEmpty ? '¡Hola!' : '¡Hola $name!';
    return '$greeting Ya se liberó tu cupo para el acceso anticipado de HallyuHub 💜\n'
        'Ya podés ingresar desde acá:\n'
        '$publicAppUrl\n\n'
        'Gracias por sumarte a esta primera etapa. Tu opinión nos ayuda a mejorar la comunidad K-pop latina.';
  }

  Future<void> _copyInviteMessage(BetaSignupEntry entry) async {
    await Clipboard.setData(ClipboardData(text: _inviteMessageFor(entry)));
    await _update(entry, markInvited: true);
    if (!mounted) return;
    _snack('Mensaje de invitación copiado y marcado como avisado.');
  }

  Future<void> _copyInviteWithEmail(BetaSignupEntry entry) async {
    final text = '${entry.email}\n\n${_inviteMessageFor(entry)}';
    await Clipboard.setData(ClipboardData(text: text));
    await _update(entry, markInvited: true);
    if (!mounted) return;
    _snack('Invitación + email copiados y marcados como avisados.');
  }

  Future<void> _copyReferralLink(BetaSignupEntry entry) async {
    final link = entry.shareUrl.trim();
    if (link.isEmpty) {
      _snack('Esta solicitud todavía no tiene link de referido.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    _snack('Link de referido copiado.');
  }

  Future<void> _editPriority(BetaSignupEntry entry) async {
    final controller = TextEditingController(
      text: entry.priorityScore.toString(),
    );
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.nightSoft,
        title: const Text(
          'Prioridad de acceso',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Puntaje de prioridad'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed == null) return;
              Navigator.of(context).pop(parsed);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    await _update(entry, priorityScore: value);
  }

  Future<void> _resetReferralScore(BetaSignupEntry entry) async {
    await _update(entry, priorityScore: 0, resetReferralScore: true);
  }

  Future<void> _copyCsv() async {
    final csv = [
      'fecha,nickname,email,pais,fandom,plataforma,status,posicion,referral_code,referral_count,referral_score,priority_score,share_url,invited_at,nota',
      for (final entry in _data.entries)
        [
          _csv(entry.createdAt.toIso8601String()),
          _csv(entry.nickname),
          _csv(entry.email),
          _csv(entry.country),
          _csv(entry.fandom),
          _csv(entry.platformLabel),
          _csv(entry.status.key),
          _csv(entry.position?.toString() ?? ''),
          _csv(entry.referralCode),
          _csv(entry.referralCount.toString()),
          _csv(entry.referralScore.toString()),
          _csv(entry.priorityScore.toString()),
          _csv(entry.shareUrl),
          _csv(entry.invitedAt?.toIso8601String() ?? ''),
          _csv(entry.adminNotes),
        ].join(','),
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    _snack('CSV copiado al portapapeles.');
  }

  String _csv(String value) {
    return '"${value.replaceAll('"', '""')}"';
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.nightSoft,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.user.canAccessAdminPanel) {
      return Scaffold(
        backgroundColor: AppTheme.night,
        appBar: AppBar(
          backgroundColor: AppTheme.night,
          foregroundColor: Colors.white,
          title: const Text('Acceso anticipado'),
        ),
        body: const _AdminAccessDenied(),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.night,
      appBar: AppBar(
        backgroundColor: AppTheme.night,
        foregroundColor: Colors.white,
        title: const Text('Acceso anticipado'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _restore,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _BetaStatsGrid(data: _data),
            const SizedBox(height: 14),
            _BetaFilters(
              queryController: _queryController,
              countryController: _countryController,
              status: _status,
              platform: _platform,
              onStatus: (value) {
                setState(() => _status = value);
                _restore();
              },
              onPlatform: (value) {
                setState(() => _platform = value);
                _restore();
              },
              onSearch: _restore,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _data.entries.isEmpty
                        ? null
                        : _copyApprovedEmails,
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copiar aprobados'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _data.entries.isEmpty ? null : _copyCsv,
                    icon: const Icon(Icons.table_view_rounded),
                    label: const Text('Exportar CSV'),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppTheme.rose,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (_loading)
              const _AdminLoadingCard(
                text: 'Cargando solicitudes de acceso anticipado...',
              )
            else if (_data.entries.isEmpty)
              const _AdminEmptyCard(
                text:
                    'Todavía no hay solicitudes para estos filtros. Cuando compartas /acceso, van a aparecer acá.',
              )
            else
              for (final entry in _data.entries)
                _BetaSignupTile(
                  entry: entry,
                  busy: _updating,
                  onApprove: () => _approve(entry),
                  onWait: () => _update(entry, status: 'waiting'),
                  onBlock: () => _update(entry, status: 'blocked'),
                  onNote: () => _editNote(entry),
                  onInvite: () => _update(entry, markInvited: true),
                  onCopyEmail: () => _copyEmail(entry),
                  onCopyInviteMessage: () => _copyInviteMessage(entry),
                  onCopyInviteWithEmail: () => _copyInviteWithEmail(entry),
                  onCopyReferralLink: () => _copyReferralLink(entry),
                  onEditPriority: () => _editPriority(entry),
                  onResetReferralScore: () => _resetReferralScore(entry),
                ),
          ],
        ),
      ),
    );
  }
}

class AdminFeedbackPanelScreen extends StatefulWidget {
  const AdminFeedbackPanelScreen({
    super.key,
    required this.user,
    required this.feedbackReportService,
  });

  final AuthUser user;
  final FeedbackReportService feedbackReportService;

  @override
  State<AdminFeedbackPanelScreen> createState() =>
      _AdminFeedbackPanelScreenState();
}

class _AdminFeedbackPanelScreenState extends State<AdminFeedbackPanelScreen> {
  final _queryController = TextEditingController();
  String _status = 'all';
  String _type = 'all';
  String _screen = 'all';
  String _platform = 'all';
  String _priority = 'all';
  bool _loading = true;
  bool _updating = false;
  String? _error;
  FeedbackAdminData _data = const FeedbackAdminData(entries: []);

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    if (!widget.user.canAccessAdminPanel) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.feedbackReportService.restoreAdminReports(
        status: _status,
        type: _type,
        screen: _screen,
        platform: _platform,
        priority: _priority,
        query: _queryController.text,
      );
      if (!mounted) return;
      setState(() => _data = data);
    } on FeedbackReportException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'No pudimos cargar los reportes.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _update(
    FeedbackReportEntry entry, {
    String? status,
    String? priority,
    String? adminNotes,
  }) async {
    if (_updating) return;
    setState(() {
      _updating = true;
      _error = null;
    });
    try {
      await widget.feedbackReportService.updateReport(
        id: entry.id,
        status: status,
        priority: priority,
        adminNotes: adminNotes,
      );
      await _restore();
    } on FeedbackReportException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _editNote(FeedbackReportEntry entry) async {
    final controller = TextEditingController(text: entry.adminNotes);
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.nightSoft,
        title: const Text(
          'Nota admin',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Agregar nota interna del problema',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note == null) return;
    await _update(entry, adminNotes: note);
  }

  Future<void> _openAttachment(FeedbackReportEntry entry) async {
    final url = entry.attachmentUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.user.canAccessAdminPanel) {
      return Scaffold(
        backgroundColor: AppTheme.night,
        appBar: AppBar(
          backgroundColor: AppTheme.night,
          foregroundColor: Colors.white,
          title: const Text('Problemas'),
        ),
        body: const _AdminAccessDenied(),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.night,
      appBar: AppBar(
        backgroundColor: AppTheme.night,
        foregroundColor: Colors.white,
        title: const Text('Problemas / Feedback'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _restore,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _FeedbackStatsGrid(data: _data),
            const SizedBox(height: 14),
            _FeedbackFilters(
              queryController: _queryController,
              status: _status,
              type: _type,
              screen: _screen,
              platform: _platform,
              priority: _priority,
              onStatus: (value) {
                setState(() => _status = value);
                _restore();
              },
              onType: (value) {
                setState(() => _type = value);
                _restore();
              },
              onScreen: (value) {
                setState(() => _screen = value);
                _restore();
              },
              onPlatform: (value) {
                setState(() => _platform = value);
                _restore();
              },
              onPriority: (value) {
                setState(() => _priority = value);
                _restore();
              },
              onSearch: _restore,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppTheme.rose,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (_loading)
              const _AdminLoadingCard(
                text: 'Cargando reportes de acceso anticipado...',
              )
            else if (_data.entries.isEmpty)
              const _AdminEmptyCard(
                text:
                    'Todavía no hay reportes para estos filtros. Cuando los testers usen “Reportar problema”, van a aparecer acá.',
              )
            else
              for (final entry in _data.entries)
                _FeedbackReportTile(
                  entry: entry,
                  busy: _updating,
                  onStatus: (status) => _update(entry, status: status),
                  onPriority: (priority) => _update(entry, priority: priority),
                  onNote: () => _editNote(entry),
                  onAttachment: entry.attachmentUrl == null
                      ? null
                      : () => _openAttachment(entry),
                ),
          ],
        ),
      ),
    );
  }
}

class AdminArtistSuggestionsPanelScreen extends StatefulWidget {
  const AdminArtistSuggestionsPanelScreen({
    super.key,
    required this.user,
    required this.artistTagService,
  });

  final AuthUser user;
  final LocalArtistTagService artistTagService;

  @override
  State<AdminArtistSuggestionsPanelScreen> createState() =>
      _AdminArtistSuggestionsPanelScreenState();
}

class _AdminArtistSuggestionsPanelScreenState
    extends State<AdminArtistSuggestionsPanelScreen> {
  final _queryController = TextEditingController();
  String _status = 'pending';
  String _type = 'all';
  bool _loading = true;
  bool _updating = false;
  String? _error;
  ArtistSuggestionAdminData _data = const ArtistSuggestionAdminData(
    entries: [],
  );

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    if (!widget.user.canAccessAdminPanel) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.artistTagService.restoreAdminEntitySuggestions(
        status: _status,
        type: _type,
        query: _queryController.text,
      );
      if (!mounted) return;
      setState(() => _data = data);
    } catch (error) {
      debugPrint('ADMIN_ARTIST_SUGGESTIONS_FETCH_ERROR $error');
      if (!mounted) return;
      setState(
        () => _error =
            'No pudimos cargar las sugerencias. Revisá permisos o SQL.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _review(
    ArtistSuggestionEntry entry,
    ArtistSuggestionStatus status, {
    String? name,
    KpopEntitySuggestionType? type,
    String? adminNotes,
  }) async {
    if (_updating) return;
    setState(() {
      _updating = true;
      _error = null;
    });
    try {
      await widget.artistTagService.updateEntitySuggestion(
        id: entry.id,
        status: status,
        name: name,
        type: type,
        adminNotes: adminNotes,
      );
      await _restore();
      if (!mounted) return;
      _snack(
        status == ArtistSuggestionStatus.approved
            ? 'Sugerencia aprobada y sumada al catálogo.'
            : 'Sugerencia marcada como ${status.label.toLowerCase()}.',
      );
    } catch (error) {
      debugPrint('ADMIN_ARTIST_SUGGESTIONS_REVIEW_ERROR $error');
      if (!mounted) return;
      setState(
        () => _error =
            'No pudimos actualizar la sugerencia. Revisá permisos o schema.',
      );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _approveWithReview(ArtistSuggestionEntry entry) async {
    final nameController = TextEditingController(text: entry.name);
    final noteController = TextEditingController(text: entry.adminNotes);
    var type = entry.type;
    final result = await showDialog<_ArtistReviewDraft>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.nightSoft,
          title: const Text(
            'Aprobar sugerencia',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Nombre final'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<KpopEntitySuggestionType>(
                  initialValue: type,
                  dropdownColor: AppTheme.nightSoft,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: [
                    for (final item in KpopEntitySuggestionType.values)
                      DropdownMenuItem(value: item, child: Text(item.label)),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => type = value);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteController,
                  minLines: 2,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Nota admin opcional',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.of(context).pop(
                  _ArtistReviewDraft(
                    name: name,
                    type: type,
                    adminNotes: noteController.text.trim(),
                  ),
                );
              },
              child: const Text('Aprobar'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    noteController.dispose();
    if (result == null) return;
    await _review(
      entry,
      ArtistSuggestionStatus.approved,
      name: result.name,
      type: result.type,
      adminNotes: result.adminNotes,
    );
  }

  Future<void> _editNote(
    ArtistSuggestionEntry entry,
    ArtistSuggestionStatus status,
  ) async {
    final controller = TextEditingController(text: entry.adminNotes);
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.nightSoft,
        title: Text(
          status == ArtistSuggestionStatus.duplicate
              ? 'Marcar duplicado'
              : 'Rechazar sugerencia',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Nota interna opcional'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note == null) return;
    await _review(entry, status, adminNotes: note);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.nightSoft,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.user.canAccessAdminPanel) {
      return Scaffold(
        backgroundColor: AppTheme.night,
        appBar: AppBar(
          backgroundColor: AppTheme.night,
          foregroundColor: Colors.white,
          title: const Text('Sugerencias'),
        ),
        body: const _AdminAccessDenied(),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.night,
      appBar: AppBar(
        backgroundColor: AppTheme.night,
        foregroundColor: Colors.white,
        title: const Text('Sugerencias'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _restore,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _ArtistSuggestionStats(data: _data),
            const SizedBox(height: 14),
            _ArtistSuggestionFilters(
              queryController: _queryController,
              status: _status,
              type: _type,
              onStatus: (value) {
                setState(() => _status = value);
                _restore();
              },
              onType: (value) {
                setState(() => _type = value);
                _restore();
              },
              onSearch: _restore,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppTheme.rose,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (_loading)
              const _AdminLoadingCard(text: 'Cargando sugerencias...')
            else if (_data.entries.isEmpty)
              const _AdminEmptyCard(
                text:
                    'Todavía no hay sugerencias para estos filtros. Cuando alguien use “Sugerir grupo o artista”, van a aparecer acá.',
              )
            else
              for (final entry in _data.entries)
                _ArtistSuggestionTile(
                  entry: entry,
                  busy: _updating,
                  onApprove: () => _approveWithReview(entry),
                  onReject: () =>
                      _editNote(entry, ArtistSuggestionStatus.rejected),
                  onDuplicate: () =>
                      _editNote(entry, ArtistSuggestionStatus.duplicate),
                ),
          ],
        ),
      ),
    );
  }
}

class _ArtistReviewDraft {
  const _ArtistReviewDraft({
    required this.name,
    required this.type,
    required this.adminNotes,
  });

  final String name;
  final KpopEntitySuggestionType type;
  final String adminNotes;
}

class _ArtistSuggestionStats extends StatelessWidget {
  const _ArtistSuggestionStats({required this.data});

  final ArtistSuggestionAdminData data;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Total', data.total.toString(), Icons.auto_awesome_outlined),
      ('Pendientes', data.pending.toString(), Icons.hourglass_top_rounded),
      ('Aprobadas', data.approved.toString(), Icons.check_circle_outline),
      ('Duplicadas', data.duplicate.toString(), Icons.copy_rounded),
    ];
    return GridView.count(
      crossAxisCount: MediaQuery.sizeOf(context).width > 520 ? 4 : 2,
      childAspectRatio: 1.75,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white.withValues(alpha: 0.07),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Icon(item.$3, color: AppTheme.cyan),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$2,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        item.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ArtistSuggestionFilters extends StatelessWidget {
  const _ArtistSuggestionFilters({
    required this.queryController,
    required this.status,
    required this.type,
    required this.onStatus,
    required this.onType,
    required this.onSearch,
  });

  final TextEditingController queryController;
  final String status;
  final String type;
  final ValueChanged<String> onStatus;
  final ValueChanged<String> onType;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          TextField(
            controller: queryController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Buscar por nombre, fandom, país o usuario',
            ),
            onSubmitted: (_) => onSearch(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: status,
                  dropdownColor: AppTheme.nightSoft,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Todas')),
                    DropdownMenuItem(
                      value: 'pending',
                      child: Text('Pendientes'),
                    ),
                    DropdownMenuItem(
                      value: 'approved',
                      child: Text('Aprobadas'),
                    ),
                    DropdownMenuItem(
                      value: 'rejected',
                      child: Text('Rechazadas'),
                    ),
                    DropdownMenuItem(
                      value: 'duplicate',
                      child: Text('Duplicadas'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) onStatus(value);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: type,
                  dropdownColor: AppTheme.nightSoft,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('Todos')),
                    for (final item in KpopEntitySuggestionType.values)
                      DropdownMenuItem(
                        value: item.key,
                        child: Text(item.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) onType(value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onSearch,
              icon: const Icon(Icons.filter_alt_outlined),
              label: const Text('Aplicar filtros'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminPanelIntro extends StatelessWidget {
  const _AdminPanelIntro({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            AppTheme.rose.withValues(alpha: 0.2),
            AppTheme.cyan.withValues(alpha: 0.1),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.cyan.withValues(alpha: 0.14),
            ),
            child: Icon(icon, color: AppTheme.cyan),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.66),
                    height: 1.32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminStoreProfilesPanelScreen extends StatefulWidget {
  const AdminStoreProfilesPanelScreen({
    super.key,
    required this.user,
    required this.storeProfileService,
  });

  final AuthUser user;
  final StoreProfileService storeProfileService;

  @override
  State<AdminStoreProfilesPanelScreen> createState() =>
      _AdminStoreProfilesPanelScreenState();
}

class _AdminStoreProfilesPanelScreenState
    extends State<AdminStoreProfilesPanelScreen> {
  final _queryController = TextEditingController();
  StoreProfileAdminData _data = const StoreProfileAdminData(entries: []);
  String _status = 'all';
  bool _loading = true;
  String? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final statusForQuery = _status == 'verified' ? 'all' : _status;
      final data = await widget.storeProfileService.restoreAdminStores(
        status: statusForQuery,
        query: _queryController.text,
      );
      if (!mounted) return;
      final entries = _status == 'verified'
          ? data.entries.where((store) => store.isVerified).toList()
          : data.entries;
      setState(() {
        _data = StoreProfileAdminData(entries: entries);
        _loading = false;
      });
    } on StoreProfileException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (error) {
      debugPrint('ADMIN_STORE_PROFILES_RESTORE_ERROR error=$error');
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar perfiles tienda.';
        _loading = false;
      });
    }
  }

  Future<void> _updateStore(
    StoreProfile store, {
    StoreProfileStatus? status,
    bool? isVerified,
  }) async {
    setState(() => _busyId = store.id);
    try {
      await widget.storeProfileService.updateAdminStore(
        id: store.id,
        status: status,
        isVerified: isVerified,
      );
      if (!mounted) return;
      _showSnack('Perfil tienda actualizado.');
      await _restore();
    } on StoreProfileException catch (error) {
      if (!mounted) return;
      _showSnack(error.message);
    } catch (error) {
      debugPrint('ADMIN_STORE_PROFILE_UPDATE_ERROR error=$error');
      if (!mounted) return;
      _showSnack('No pudimos actualizar esa tienda.');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.night,
      appBar: AppBar(
        backgroundColor: AppTheme.night,
        foregroundColor: Colors.white,
        title: const Text('Admin · Tiendas'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          children: [
            const _AdminPanelIntro(
              icon: Icons.storefront_outlined,
              title: 'Perfiles tienda',
              detail:
                  'Revisá solicitudes, activá vidrieras y marcá tiendas verificadas. No hay productos ni pagos dentro de HallyuHub.',
            ),
            const SizedBox(height: 14),
            _StoreStatsGrid(data: _data),
            const SizedBox(height: 14),
            _StoreFilters(
              queryController: _queryController,
              status: _status,
              onStatus: (value) {
                setState(() => _status = value);
                _restore();
              },
              onSearch: _restore,
            ),
            const SizedBox(height: 14),
            if (_error != null) _AdminEmptyCard(text: _error!),
            if (_loading)
              const _AdminLoadingCard(text: 'Cargando perfiles tienda...')
            else if (_data.entries.isEmpty)
              const _AdminEmptyCard(
                text: 'Todavía no hay perfiles tienda con estos filtros.',
              )
            else
              for (final store in _data.entries)
                _StoreProfileAdminTile(
                  store: store,
                  busy: _busyId == store.id,
                  onActivate: () =>
                      _updateStore(store, status: StoreProfileStatus.active),
                  onPending: () =>
                      _updateStore(store, status: StoreProfileStatus.pending),
                  onPause: () =>
                      _updateStore(store, status: StoreProfileStatus.paused),
                  onBlock: () =>
                      _updateStore(store, status: StoreProfileStatus.blocked),
                  onVerify: () =>
                      _updateStore(store, isVerified: !store.isVerified),
                ),
          ],
        ),
      ),
    );
  }
}

class _StoreStatsGrid extends StatelessWidget {
  const _StoreStatsGrid({required this.data});

  final StoreProfileAdminData data;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: MediaQuery.sizeOf(context).width > 520 ? 3 : 2,
      childAspectRatio: 1.55,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        _BetaMetricCard(
          label: 'Total',
          value: data.total.toString(),
          icon: Icons.storefront_rounded,
          color: AppTheme.cyan,
        ),
        _BetaMetricCard(
          label: 'Pendientes',
          value: data.pending.toString(),
          icon: Icons.pending_actions_rounded,
          color: AppTheme.amber,
        ),
        _BetaMetricCard(
          label: 'Activas',
          value: data.active.toString(),
          icon: Icons.check_circle_rounded,
          color: AppTheme.teal,
        ),
        _BetaMetricCard(
          label: 'Pausadas',
          value: data.paused.toString(),
          icon: Icons.pause_circle_outline_rounded,
          color: AppTheme.violet,
        ),
        _BetaMetricCard(
          label: 'Verificadas',
          value: data.verified.toString(),
          icon: Icons.verified_rounded,
          color: AppTheme.rose,
        ),
      ],
    );
  }
}

class _StoreFilters extends StatelessWidget {
  const _StoreFilters({
    required this.queryController,
    required this.status,
    required this.onStatus,
    required this.onSearch,
  });

  final TextEditingController queryController;
  final String status;
  final ValueChanged<String> onStatus;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          TextField(
            controller: queryController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Buscar tienda, ciudad o usuario',
            ),
            onSubmitted: (_) => onSearch(),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: status,
            dropdownColor: AppTheme.nightSoft,
            decoration: const InputDecoration(labelText: 'Estado'),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('Todas')),
              DropdownMenuItem(value: 'pending', child: Text('Pendientes')),
              DropdownMenuItem(value: 'active', child: Text('Activas')),
              DropdownMenuItem(value: 'paused', child: Text('Pausadas')),
              DropdownMenuItem(value: 'blocked', child: Text('Bloqueadas')),
              DropdownMenuItem(value: 'verified', child: Text('Verificadas')),
            ],
            onChanged: (value) {
              if (value != null) onStatus(value);
            },
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onSearch,
              icon: const Icon(Icons.filter_alt_outlined),
              label: const Text('Aplicar filtros'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreProfileAdminTile extends StatelessWidget {
  const _StoreProfileAdminTile({
    required this.store,
    required this.busy,
    required this.onActivate,
    required this.onPending,
    required this.onPause,
    required this.onBlock,
    required this.onVerify,
  });

  final StoreProfile store;
  final bool busy;
  final VoidCallback onActivate;
  final VoidCallback onPending;
  final VoidCallback onPause;
  final VoidCallback onBlock;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final owner = store.owner;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.07),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.cyan.withValues(alpha: 0.16),
                ),
                child: const Icon(Icons.storefront, color: AppTheme.cyan),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.storeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        owner?.username ?? 'sin usuario',
                        if (store.city.isNotEmpty) store.city,
                        if (store.country.isNotEmpty) store.country,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.64),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(
                store.isVerified
                    ? '${store.status.label} · verificada'
                    : store.status.label,
              ),
            ],
          ),
          if (store.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              store.description,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontWeight: FontWeight.w700,
                height: 1.32,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in store.categories)
                _TinyMeta(storeOptionLabel(category)),
              for (final delivery in store.deliveryMethods)
                _TinyMeta(storeOptionLabel(delivery)),
              if (store.contactUrl.isNotEmpty) const _TinyMeta('Contacto'),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallAdminAction(
                icon: Icons.check_circle_rounded,
                label: 'Activar',
                onTap: busy ? null : onActivate,
              ),
              _SmallAdminAction(
                icon: Icons.pending_actions_rounded,
                label: 'Pendiente',
                onTap: busy ? null : onPending,
              ),
              _SmallAdminAction(
                icon: Icons.pause_circle_outline_rounded,
                label: 'Pausar',
                onTap: busy ? null : onPause,
              ),
              _SmallAdminAction(
                icon: Icons.block_rounded,
                label: 'Bloquear',
                onTap: busy ? null : onBlock,
              ),
              _SmallAdminAction(
                icon: store.isVerified
                    ? Icons.verified_outlined
                    : Icons.verified_user_outlined,
                label: store.isVerified ? 'Quitar verificación' : 'Verificar',
                onTap: busy ? null : onVerify,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArtistSuggestionTile extends StatelessWidget {
  const _ArtistSuggestionTile({
    required this.entry,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onDuplicate,
  });

  final ArtistSuggestionEntry entry;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onDuplicate;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.07),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.rose.withValues(alpha: 0.65),
                      AppTheme.cyan.withValues(alpha: 0.46),
                    ],
                  ),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${entry.type.label} · ${entry.displayAuthor}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(entry.status.label),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (entry.fandom.isNotEmpty) _TinyMeta('Fandom: ${entry.fandom}'),
              if (entry.country.isNotEmpty) _TinyMeta('País: ${entry.country}'),
              if (entry.agency.isNotEmpty)
                _TinyMeta('Agencia: ${entry.agency}'),
              if (entry.officialUrl.isNotEmpty) _TinyMeta('Link oficial'),
            ],
          ),
          if (entry.note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              entry.note,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontWeight: FontWeight.w700,
                height: 1.32,
              ),
            ),
          ],
          if (entry.adminNotes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Nota admin: ${entry.adminNotes}',
              style: const TextStyle(
                color: AppTheme.cyan,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed:
                    busy || entry.status == ArtistSuggestionStatus.approved
                    ? null
                    : onApprove,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Aprobar'),
              ),
              OutlinedButton.icon(
                onPressed:
                    busy || entry.status == ArtistSuggestionStatus.rejected
                    ? null
                    : onReject,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Rechazar'),
              ),
              OutlinedButton.icon(
                onPressed:
                    busy || entry.status == ArtistSuggestionStatus.duplicate
                    ? null
                    : onDuplicate,
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Duplicado'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TinyMeta extends StatelessWidget {
  const _TinyMeta(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: AppTheme.night.withValues(alpha: 0.42),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: AppTheme.night.withValues(alpha: 0.46),
        border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.32)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.cyan,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _BetaStatsGrid extends StatelessWidget {
  const _BetaStatsGrid({required this.data});

  final BetaSignupAdminData data;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: MediaQuery.sizeOf(context).width > 520 ? 3 : 2,
      childAspectRatio: 1.55,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        _BetaMetricCard(
          label: 'Total',
          value: data.total.toString(),
          icon: Icons.groups_rounded,
          color: AppTheme.cyan,
        ),
        _BetaMetricCard(
          label: 'Approved',
          value: data.approved.toString(),
          icon: Icons.verified_rounded,
          color: AppTheme.teal,
        ),
        _BetaMetricCard(
          label: 'Waiting',
          value: data.waiting.toString(),
          icon: Icons.hourglass_top_rounded,
          color: AppTheme.amber,
        ),
        _BetaMetricCard(
          label: 'Blocked',
          value: data.blocked.toString(),
          icon: Icons.block_rounded,
          color: AppTheme.rose,
        ),
        _BetaMetricCard(
          label: 'Android',
          value: data.android.toString(),
          icon: Icons.android_rounded,
          color: AppTheme.violet,
        ),
        _BetaMetricCard(
          label: 'iOS',
          value: data.ios.toString(),
          icon: Icons.phone_iphone_rounded,
          color: AppTheme.cyan,
        ),
      ],
    );
  }
}

class _BetaMetricCard extends StatelessWidget {
  const _BetaMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.07),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.16),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackStatsGrid extends StatelessWidget {
  const _FeedbackStatsGrid({required this.data});

  final FeedbackAdminData data;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: MediaQuery.sizeOf(context).width > 520 ? 3 : 2,
      childAspectRatio: 1.55,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        _BetaMetricCard(
          label: 'Total',
          value: data.total.toString(),
          icon: Icons.bug_report_rounded,
          color: AppTheme.cyan,
        ),
        _BetaMetricCard(
          label: 'Pendientes',
          value: data.pending.toString(),
          icon: Icons.pending_actions_rounded,
          color: AppTheme.amber,
        ),
        _BetaMetricCard(
          label: 'En revisión',
          value: data.reviewing.toString(),
          icon: Icons.manage_search_rounded,
          color: AppTheme.violet,
        ),
        _BetaMetricCard(
          label: 'Resueltos',
          value: data.resolved.toString(),
          icon: Icons.check_circle_rounded,
          color: AppTheme.teal,
        ),
        _BetaMetricCard(
          label: 'Urgentes',
          value: data.urgent.toString(),
          icon: Icons.priority_high_rounded,
          color: AppTheme.rose,
        ),
      ],
    );
  }
}

class _FeedbackFilters extends StatelessWidget {
  const _FeedbackFilters({
    required this.queryController,
    required this.status,
    required this.type,
    required this.screen,
    required this.platform,
    required this.priority,
    required this.onStatus,
    required this.onType,
    required this.onScreen,
    required this.onPlatform,
    required this.onPriority,
    required this.onSearch,
  });

  final TextEditingController queryController;
  final String status;
  final String type;
  final String screen;
  final String platform;
  final String priority;
  final ValueChanged<String> onStatus;
  final ValueChanged<String> onType;
  final ValueChanged<String> onScreen;
  final ValueChanged<String> onPlatform;
  final ValueChanged<String> onPriority;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: queryController,
            style: const TextStyle(color: Colors.white),
            onSubmitted: (_) => onSearch(),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              labelText: 'Buscar email o descripción',
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FeedbackDropdown(
                value: status,
                label: 'Estado',
                choices: const [
                  FeedbackChoice('all', 'Todos'),
                  ...feedbackStatuses,
                ],
                onChanged: onStatus,
              ),
              _FeedbackDropdown(
                value: priority,
                label: 'Prioridad',
                choices: const [
                  FeedbackChoice('all', 'Todas'),
                  ...feedbackPriorities,
                ],
                onChanged: onPriority,
              ),
              _FeedbackDropdown(
                value: type,
                label: 'Tipo',
                choices: const [
                  FeedbackChoice('all', 'Todos'),
                  ...feedbackProblemTypes,
                ],
                onChanged: onType,
              ),
              _FeedbackDropdown(
                value: screen,
                label: 'Pantalla',
                choices: const [
                  FeedbackChoice('all', 'Todas'),
                  ...feedbackScreens,
                ],
                onChanged: onScreen,
              ),
              _FeedbackDropdown(
                value: platform,
                label: 'Plataforma',
                choices: const [
                  FeedbackChoice('all', 'Todas'),
                  FeedbackChoice('web', 'Web'),
                  FeedbackChoice('android', 'Android'),
                  FeedbackChoice('iOS', 'iOS'),
                  FeedbackChoice('macOS', 'macOS'),
                  FeedbackChoice('unknown', 'Desconocida'),
                ],
                onChanged: onPlatform,
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onSearch,
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Aplicar filtros'),
          ),
        ],
      ),
    );
  }
}

class _FeedbackDropdown extends StatelessWidget {
  const _FeedbackDropdown({
    required this.value,
    required this.label,
    required this.choices,
    required this.onChanged,
  });

  final String value;
  final String label;
  final List<FeedbackChoice> choices;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        dropdownColor: AppTheme.nightSoft,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
        decoration: InputDecoration(labelText: label),
        items: choices
            .map(
              (choice) => DropdownMenuItem<String>(
                value: choice.key,
                child: Text(choice.label),
              ),
            )
            .toList(),
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      ),
    );
  }
}

class _FeedbackReportTile extends StatelessWidget {
  const _FeedbackReportTile({
    required this.entry,
    required this.busy,
    required this.onStatus,
    required this.onPriority,
    required this.onNote,
    this.onAttachment,
  });

  final FeedbackReportEntry entry;
  final bool busy;
  final ValueChanged<String> onStatus;
  final ValueChanged<String> onPriority;
  final VoidCallback onNote;
  final VoidCallback? onAttachment;

  @override
  Widget build(BuildContext context) {
    final statusLabel = feedbackChoiceLabel(feedbackStatuses, entry.status);
    final priorityLabel = feedbackChoiceLabel(
      feedbackPriorities,
      entry.priority,
    );
    final typeLabel = feedbackChoiceLabel(feedbackProblemTypes, entry.type);
    final screenLabel = feedbackChoiceLabel(feedbackScreens, entry.screen);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.07),
        border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.email.isEmpty
                      ? 'Usuario de acceso anticipado'
                      : entry.email,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _StatusPill(statusLabel),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FeedbackBadge(label: typeLabel, color: AppTheme.cyan),
              _FeedbackBadge(label: screenLabel, color: AppTheme.violet),
              _FeedbackBadge(label: priorityLabel, color: AppTheme.rose),
              _FeedbackBadge(label: entry.platform, color: AppTheme.teal),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            entry.description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          if (entry.adminNotes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Nota admin: ${entry.adminNotes}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (entry.relatedContentType != null) ...[
            const SizedBox(height: 8),
            Text(
              'Relacionado: ${entry.relatedContentType} ${entry.relatedContentId ?? ''}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.52),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FeedbackActionMenu(
                label: 'Estado',
                enabled: !busy,
                choices: feedbackStatuses,
                onSelected: onStatus,
              ),
              _FeedbackActionMenu(
                label: 'Prioridad',
                enabled: !busy,
                choices: feedbackPriorities,
                onSelected: onPriority,
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : onNote,
                icon: const Icon(Icons.note_add_outlined),
                label: const Text('Nota'),
              ),
              if (onAttachment != null)
                OutlinedButton.icon(
                  onPressed: onAttachment,
                  icon: const Icon(Icons.attachment_rounded),
                  label: const Text('Adjunto'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeedbackBadge extends StatelessWidget {
  const _FeedbackBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _FeedbackActionMenu extends StatelessWidget {
  const _FeedbackActionMenu({
    required this.label,
    required this.enabled,
    required this.choices,
    required this.onSelected,
  });

  final String label;
  final bool enabled;
  final List<FeedbackChoice> choices;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      enabled: enabled,
      color: AppTheme.nightSoft,
      onSelected: onSelected,
      itemBuilder: (context) => choices
          .map(
            (choice) => PopupMenuItem<String>(
              value: choice.key,
              child: Text(
                choice.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
          color: Colors.white.withValues(alpha: enabled ? 0.06 : 0.03),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              color: enabled ? Colors.white : Colors.white38,
              size: 18,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: enabled ? Colors.white : Colors.white38,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BetaFilters extends StatelessWidget {
  const _BetaFilters({
    required this.queryController,
    required this.countryController,
    required this.status,
    required this.platform,
    required this.onStatus,
    required this.onPlatform,
    required this.onSearch,
  });

  final TextEditingController queryController;
  final TextEditingController countryController;
  final String status;
  final String platform;
  final ValueChanged<String> onStatus;
  final ValueChanged<String> onPlatform;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: queryController,
            style: const TextStyle(color: Colors.white),
            onSubmitted: (_) => onSearch(),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              labelText: 'Buscar email o nickname',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: countryController,
            style: const TextStyle(color: Colors.white),
            onSubmitted: (_) => onSearch(),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.public_rounded),
              labelText: 'Filtrar por país',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChipButton(
                label: 'Todos',
                value: 'all',
                selected: status == 'all',
                onSelected: onStatus,
              ),
              _FilterChipButton(
                label: 'Approved',
                value: 'approved',
                selected: status == 'approved',
                onSelected: onStatus,
              ),
              _FilterChipButton(
                label: 'Approved sin avisar',
                value: 'approved_uninvited',
                selected: status == 'approved_uninvited',
                onSelected: onStatus,
              ),
              _FilterChipButton(
                label: 'Approved avisados',
                value: 'approved_invited',
                selected: status == 'approved_invited',
                onSelected: onStatus,
              ),
              _FilterChipButton(
                label: 'Waiting',
                value: 'waiting',
                selected: status == 'waiting',
                onSelected: onStatus,
              ),
              _FilterChipButton(
                label: 'Blocked',
                value: 'blocked',
                selected: status == 'blocked',
                onSelected: onStatus,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChipButton(
                label: 'Todas',
                value: 'all',
                selected: platform == 'all',
                onSelected: onPlatform,
              ),
              _FilterChipButton(
                label: 'Android',
                value: 'android',
                selected: platform == 'android',
                onSelected: onPlatform,
              ),
              _FilterChipButton(
                label: 'iPhone',
                value: 'ios',
                selected: platform == 'ios',
                onSelected: onPlatform,
              ),
              _FilterChipButton(
                label: 'Otro',
                value: 'other',
                selected: platform == 'other',
                onSelected: onPlatform,
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onSearch,
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Aplicar filtros'),
          ),
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final String value;
  final bool selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => onSelected(value),
    );
  }
}

class _AdminLoadingCard extends StatelessWidget {
  const _AdminLoadingCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.07),
        border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminEmptyCard extends StatelessWidget {
  const _AdminEmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontWeight: FontWeight.w800,
          height: 1.35,
        ),
      ),
    );
  }
}

class _BetaSignupTile extends StatelessWidget {
  const _BetaSignupTile({
    required this.entry,
    required this.busy,
    required this.onApprove,
    required this.onWait,
    required this.onBlock,
    required this.onNote,
    required this.onInvite,
    required this.onCopyEmail,
    required this.onCopyInviteMessage,
    required this.onCopyInviteWithEmail,
    required this.onCopyReferralLink,
    required this.onEditPriority,
    required this.onResetReferralScore,
  });

  final BetaSignupEntry entry;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onWait;
  final VoidCallback onBlock;
  final VoidCallback onNote;
  final VoidCallback onInvite;
  final VoidCallback onCopyEmail;
  final VoidCallback onCopyInviteMessage;
  final VoidCallback onCopyInviteWithEmail;
  final VoidCallback onCopyReferralLink;
  final VoidCallback onEditPriority;
  final VoidCallback onResetReferralScore;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.07),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.cyan.withValues(alpha: 0.42),
                      AppTheme.rose.withValues(alpha: 0.34),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.nickname.isEmpty
                                ? 'Fan HallyuHub'
                                : entry.nickname,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _BetaStatusPill(entry.status),
                      ],
                    ),
                    const SizedBox(height: 3),
                    SelectableText(
                      entry.email,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.74),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      [
                        if (entry.country.isNotEmpty) entry.country,
                        if (entry.fandom.isNotEmpty) entry.fandom,
                        entry.platformLabel,
                        if (entry.position != null)
                          'Posición ${entry.position}',
                      ].join(' · '),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (entry.referralCode.isNotEmpty ||
                        entry.referralCount > 0 ||
                        entry.priorityScore > 0) ...[
                      const SizedBox(height: 7),
                      Text(
                        [
                          if (entry.referralCode.isNotEmpty)
                            'ref ${entry.referralCode}',
                          'referidos ${entry.referralCount}',
                          'score ${entry.referralScore}',
                          'prioridad ${entry.priorityScore}',
                        ].join(' · '),
                        style: const TextStyle(
                          color: AppTheme.cyan,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (entry.referredBy.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Invitado por ${entry.referredBy}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.52),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      entry.invitedAt == null
                          ? 'Invitado: No'
                          : 'Invitado: Sí · ${_compactDate(entry.invitedAt!)}',
                      style: TextStyle(
                        color: entry.invitedAt == null
                            ? AppTheme.amber
                            : AppTheme.teal,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    if (entry.adminNotes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        entry.adminNotes,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                          height: 1.32,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallAdminAction(
                icon: Icons.verified_rounded,
                label: 'Aprobar',
                onTap: busy ? null : onApprove,
              ),
              _SmallAdminAction(
                icon: Icons.hourglass_top_rounded,
                label: 'Espera',
                onTap: busy ? null : onWait,
              ),
              _SmallAdminAction(
                icon: Icons.block_rounded,
                label: 'Bloquear',
                onTap: busy ? null : onBlock,
              ),
              _SmallAdminAction(
                icon: Icons.edit_note_rounded,
                label: 'Nota',
                onTap: busy ? null : onNote,
              ),
              _SmallAdminAction(
                icon: Icons.copy_rounded,
                label: 'Copiar email',
                onTap: busy ? null : onCopyEmail,
              ),
              if (entry.status == BetaSignupStatus.approved) ...[
                _SmallAdminAction(
                  icon: Icons.campaign_rounded,
                  label: 'Copiar invitación',
                  onTap: busy ? null : onCopyInviteMessage,
                ),
                _SmallAdminAction(
                  icon: Icons.markunread_mailbox_outlined,
                  label: 'Invitación + email',
                  onTap: busy ? null : onCopyInviteWithEmail,
                ),
              ],
              _SmallAdminAction(
                icon: Icons.link_rounded,
                label: 'Copiar link',
                onTap: busy ? null : onCopyReferralLink,
              ),
              _SmallAdminAction(
                icon: Icons.trending_up_rounded,
                label: 'Prioridad',
                onTap: busy ? null : onEditPriority,
              ),
              _SmallAdminAction(
                icon: Icons.restart_alt_rounded,
                label: 'Reset ref.',
                onTap: busy ? null : onResetReferralScore,
              ),
              _SmallAdminAction(
                icon: Icons.mark_email_read_outlined,
                label: entry.invitedAt == null
                    ? 'Marcar invitado'
                    : 'Reinvitar',
                onTap: busy ? null : onInvite,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _compactDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }
}

class _BetaStatusPill extends StatelessWidget {
  const _BetaStatusPill(this.status);

  final BetaSignupStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      BetaSignupStatus.approved => AppTheme.teal,
      BetaSignupStatus.waiting => AppTheme.amber,
      BetaSignupStatus.blocked => AppTheme.rose,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.36)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SmallAdminAction extends StatelessWidget {
  const _SmallAdminAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      ),
    );
  }
}
