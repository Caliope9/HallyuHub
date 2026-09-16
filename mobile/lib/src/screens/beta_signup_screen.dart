import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/legal_documents.dart';
import '../services/beta_signup_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_mark.dart';

const _betaInk = Color(0xFF35113F);
const _betaMuted = Color(0xFF765E7E);
const _betaSoft = Color(0xFFFFF5FA);
const _betaCard = Color(0xFFFFFFFF);
const _betaLine = Color(0xFFFFC2DA);

class BetaSignupScreen extends StatefulWidget {
  const BetaSignupScreen({super.key, required this.betaSignupService});

  final BetaSignupService betaSignupService;

  @override
  State<BetaSignupScreen> createState() => _BetaSignupScreenState();
}

class _BetaSignupScreenState extends State<BetaSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _lookupEmailController = TextEditingController();
  final _countryController = TextEditingController();
  final _fandomController = TextEditingController();
  String _platform = 'android';
  bool _accepted = false;
  bool _ageConfirmed = false;
  bool _submitting = false;
  bool _lookingUp = false;
  BetaSignupResult? _result;
  BetaSignupResult? _lookupResult;
  String? _error;
  String? _lookupError;
  late final String _incomingReferralCode;

  @override
  void initState() {
    super.initState();
    _incomingReferralCode = (Uri.base.queryParameters['ref'] ?? '').trim();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _lookupEmailController.dispose();
    _countryController.dispose();
    _fandomController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_accepted) {
      setState(() {
        _error =
            'Necesitás aceptar participar en el acceso anticipado y recibir novedades para sumarte.';
      });
      return;
    }
    if (!_ageConfirmed) {
      setState(() => _error = hallyuHubBetaAgeValidationMessage);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
      _lookupError = null;
    });
    try {
      final result = await widget.betaSignupService.submit(
        nickname: _nicknameController.text,
        email: _emailController.text,
        country: _countryController.text,
        fandom: _fandomController.text,
        platform: _platform,
        accepted: _accepted,
        referralCode: _incomingReferralCode,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _lookupEmailController.text = _emailController.text.trim();
      });
    } on BetaSignupException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error =
            'No pudimos enviar tu solicitud. Revisá conexión y probá de nuevo.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _lookupStatus([String? rawEmail]) async {
    final email = (rawEmail ?? _lookupEmailController.text).trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() {
        _lookupResult = null;
        _lookupError = 'Usá el email con el que te anotaste.';
      });
      return;
    }
    setState(() {
      _lookingUp = true;
      _lookupError = null;
    });
    try {
      final result = await widget.betaSignupService.lookupStatus(email: email);
      if (!mounted) return;
      setState(() {
        _lookupEmailController.text = email;
        _lookupResult = result;
        _lookupError = result == null
            ? 'No encontramos una solicitud con ese email. Podés anotarte arriba.'
            : null;
      });
    } on BetaSignupException catch (error) {
      if (!mounted) return;
      setState(() {
        _lookupResult = null;
        _lookupError = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _lookupResult = null;
        _lookupError =
            'No pudimos consultar tu estado. Revisá conexión y probá de nuevo.';
      });
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  Future<void> _openApp() async {
    await launchUrl(
      Uri.parse(publicAppUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  String _shareText(BetaSignupResult result) {
    final link = result.shareUrl.trim();
    return 'Estoy probando HallyuHub en acceso anticipado 💗 Sumate acá: $link';
  }

  Future<void> _copyReferralLink(BetaSignupResult result) async {
    final text = result.hasShareUrl ? result.shareUrl : _shareText(result);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _snack('Link de acceso anticipado copiado.');
  }

  Future<void> _shareReferralText(BetaSignupResult result) async {
    await Clipboard.setData(ClipboardData(text: _shareText(result)));
    if (!mounted) return;
    _snack('Texto para compartir copiado.');
  }

  Future<void> _shareReferralOnWhatsApp(BetaSignupResult result) async {
    final uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(_shareText(result))}',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      await _shareReferralText(result);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _betaInk,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _betaSoft,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFEEF7), Color(0xFFFFFFFF), Color(0xFFFFE5F0)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 34),
                children: [
                  const _BetaHero(),
                  const SizedBox(height: 18),
                  if (_incomingReferralCode.isNotEmpty) ...[
                    _ReferralInviteNotice(code: _incomingReferralCode),
                    const SizedBox(height: 14),
                  ],
                  const _ExternalBrowserNotice(),
                  const SizedBox(height: 14),
                  if (_result == null)
                    _BetaForm(
                      formKey: _formKey,
                      nicknameController: _nicknameController,
                      emailController: _emailController,
                      countryController: _countryController,
                      fandomController: _fandomController,
                      platform: _platform,
                      accepted: _accepted,
                      ageConfirmed: _ageConfirmed,
                      submitting: _submitting,
                      error: _error,
                      onPlatformChanged: (value) =>
                          setState(() => _platform = value),
                      onAcceptedChanged: (value) =>
                          setState(() => _accepted = value),
                      onAgeConfirmedChanged: (value) =>
                          setState(() => _ageConfirmed = value),
                      onSubmit: _submit,
                    )
                  else
                    _BetaResultCard(
                      result: _result!,
                      onEnterApp: _openApp,
                      onCheckStatus: () =>
                          _lookupStatus(_emailController.text.trim()),
                      onCopyLink: () => _copyReferralLink(_result!),
                      onShare: () => _shareReferralText(_result!),
                      onShareWhatsApp: () => _shareReferralOnWhatsApp(_result!),
                    ),
                  const SizedBox(height: 18),
                  _BetaStatusLookup(
                    controller: _lookupEmailController,
                    result: _lookupResult,
                    error: _lookupError,
                    lookingUp: _lookingUp,
                    onLookup: () => _lookupStatus(),
                    onEnterApp: _openApp,
                    onCopyLink: _copyReferralLink,
                    onShare: _shareReferralText,
                    onShareWhatsApp: _shareReferralOnWhatsApp,
                  ),
                  const SizedBox(height: 18),
                  const _BetaGuideCards(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BetaHero extends StatelessWidget {
  const _BetaHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            const Color(0xFFFFE1EF),
            const Color(0xFFF4D8FF),
          ],
        ),
        border: Border.all(color: _betaLine),
        boxShadow: [
          BoxShadow(
            color: AppTheme.rose.withValues(alpha: 0.18),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              HallyuBrandIcon(size: 58, radiusFactor: 0.28),
              SizedBox(width: 14),
              Expanded(child: HallyuBrandWordmark(fontSize: 26)),
            ],
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: AppTheme.rose.withValues(alpha: 0.1),
                      border: Border.all(color: _betaLine),
                    ),
                    child: const Text(
                      'Primeros 100 cupos',
                      style: TextStyle(
                        color: AppTheme.rose,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Acceso anticipado',
                    style: TextStyle(
                      color: _betaInk,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      height: 1.04,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sumate a nuestra comunidad K-pop latina y ayudanos a mejorar HallyuHub desde sus primeros cupos.',
                    style: TextStyle(
                      color: _betaMuted,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.38,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _BetaMiniPill(
                        icon: Icons.favorite_rounded,
                        label: 'Posts',
                      ),
                      _BetaMiniPill(
                        icon: Icons.play_circle_outline_rounded,
                        label: 'Drops',
                      ),
                      _BetaMiniPill(
                        icon: Icons.video_collection_outlined,
                        label: 'Fancams',
                      ),
                      _BetaMiniPill(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Mensajes',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Si los cupos se completan, tu solicitud queda ordenada en lista de espera.',
                    style: TextStyle(
                      color: _betaMuted,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ],
              );
              const mascot = _BetaMascotCard();
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [mascot, const SizedBox(height: 16), copy],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: copy),
                  const SizedBox(width: 18),
                  const SizedBox(width: 174, child: mascot),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ExternalBrowserNotice extends StatelessWidget {
  const _ExternalBrowserNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _betaLine),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.open_in_browser_rounded, color: AppTheme.rose, size: 22),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'Si el link se ve raro desde Instagram o WhatsApp, abrilo en Chrome o Safari.',
              style: TextStyle(
                color: _betaInk,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferralInviteNotice extends StatelessWidget {
  const _ReferralInviteNotice({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white,
        border: Border.all(color: _betaLine),
        boxShadow: [
          BoxShadow(
            color: AppTheme.violet.withValues(alpha: 0.1),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [AppTheme.rose, AppTheme.cyan]),
            ),
            child: const Icon(Icons.favorite_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Llegaste con una invitación al acceso anticipado. Si te anotás, ese fan suma prioridad en la lista.',
              style: TextStyle(
                color: _betaInk.withValues(alpha: 0.82),
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BetaMascotCard extends StatelessWidget {
  const _BetaMascotCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.96),
            AppTheme.cyan.withValues(alpha: 0.2),
            AppTheme.rose.withValues(alpha: 0.14),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.cyan.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/brand/hally_mascot_wave.png',
              height: 186,
              fit: BoxFit.contain,
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(
                  colors: [AppTheme.rose, AppTheme.cyan],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.rose.withValues(alpha: 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Text(
                'Hally te acompaña',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BetaMiniPill extends StatelessWidget {
  const _BetaMiniPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.84),
        border: Border.all(color: _betaLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.rose, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: _betaInk,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _BetaGuideCards extends StatelessWidget {
  const _BetaGuideCards();

  @override
  Widget build(BuildContext context) {
    const cards = [
      _BetaGuideInfo(
        title: 'Qué podés hacer',
        icon: Icons.auto_awesome_rounded,
        lines: [
          'Explorar perfiles, posts, stories, drops y fancams.',
          'Seguir grupos, idols y comunidades.',
          'Probar notificaciones, mensajes y publicaciones.',
          'Reportar errores o detalles a mejorar.',
        ],
      ),
      _BetaGuideInfo(
        title: 'Qué necesitamos de vos',
        icon: Icons.volunteer_activism_outlined,
        lines: [
          'Usar la app con normalidad.',
          'Avisar errores visuales o de funcionamiento.',
          'Contarnos qué te gustó y qué mejorarías.',
        ],
      ),
      _BetaGuideInfo(
        title: 'Cómo reportar',
        icon: Icons.bug_report_outlined,
        lines: [
          'Desde la app, tocá Reportar problema.',
          'Indicá pantalla, error y, si podés, una captura.',
          '¿Tenés problemas para anotarte? Escribinos a $supportEmail.',
        ],
      ),
    ];
    return Column(
      children: [
        for (final card in cards) ...[
          _BetaGuideCard(info: card),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _BetaGuideInfo {
  const _BetaGuideInfo({
    required this.title,
    required this.icon,
    required this.lines,
  });

  final String title;
  final IconData icon;
  final List<String> lines;
}

class _BetaGuideCard extends StatelessWidget {
  const _BetaGuideCard({required this.info});

  final _BetaGuideInfo info;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        border: Border.all(color: _betaLine),
        boxShadow: [
          BoxShadow(
            color: AppTheme.rose.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppTheme.rose, AppTheme.cyan],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.violet.withValues(alpha: 0.26),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(info.icon, color: Colors.white),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.title,
                  style: const TextStyle(
                    color: _betaInk,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 8),
                for (final line in info.lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(
                            color: AppTheme.cyan,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            line,
                            style: TextStyle(
                              color: _betaMuted,
                              fontWeight: FontWeight.w700,
                              height: 1.28,
                            ),
                          ),
                        ),
                      ],
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

class _BetaForm extends StatelessWidget {
  const _BetaForm({
    required this.formKey,
    required this.nicknameController,
    required this.emailController,
    required this.countryController,
    required this.fandomController,
    required this.platform,
    required this.accepted,
    required this.ageConfirmed,
    required this.submitting,
    required this.error,
    required this.onPlatformChanged,
    required this.onAcceptedChanged,
    required this.onAgeConfirmedChanged,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nicknameController;
  final TextEditingController emailController;
  final TextEditingController countryController;
  final TextEditingController fandomController;
  final String platform;
  final bool accepted;
  final bool ageConfirmed;
  final bool submitting;
  final String? error;
  final ValueChanged<String> onPlatformChanged;
  final ValueChanged<bool> onAcceptedChanged;
  final ValueChanged<bool> onAgeConfirmedChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: _betaCard,
        border: Border.all(color: _betaLine),
        boxShadow: [
          BoxShadow(
            color: AppTheme.violet.withValues(alpha: 0.1),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Sumate al acceso anticipado',
              style: TextStyle(
                color: _betaInk,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            _BetaTextField(
              controller: nicknameController,
              label: 'Nickname',
              icon: Icons.alternate_email_rounded,
              validator: _required,
            ),
            const SizedBox(height: 12),
            _BetaTextField(
              controller: emailController,
              label: 'Email',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: _email,
            ),
            const SizedBox(height: 12),
            _BetaTextField(
              controller: countryController,
              label: 'País',
              icon: Icons.public_rounded,
              validator: _required,
            ),
            const SizedBox(height: 12),
            _BetaTextField(
              controller: fandomController,
              label: 'Fandom principal',
              icon: Icons.favorite_border_rounded,
              validator: _required,
            ),
            const SizedBox(height: 16),
            const Text(
              'Plataforma',
              style: TextStyle(color: _betaInk, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PlatformChip(
                  label: 'Android',
                  value: 'android',
                  selected: platform == 'android',
                  onSelected: onPlatformChanged,
                ),
                _PlatformChip(
                  label: 'iPhone',
                  value: 'ios',
                  selected: platform == 'ios',
                  onSelected: onPlatformChanged,
                ),
                _PlatformChip(
                  label: 'Otro',
                  value: 'other',
                  selected: platform == 'other',
                  onSelected: onPlatformChanged,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                value: accepted,
                onChanged: (value) => onAcceptedChanged(value ?? false),
                activeColor: AppTheme.rose,
                checkColor: Colors.white,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Acepto participar en el acceso anticipado y recibir novedades de HallyuHub.',
                  style: TextStyle(
                    color: _betaInk,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
            Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                value: ageConfirmed,
                onChanged: (value) => onAgeConfirmedChanged(value ?? false),
                activeColor: AppTheme.cyan,
                checkColor: Colors.white,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  hallyuHubBetaAgeCheckboxLabel,
                  style: TextStyle(
                    color: _betaInk,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(
                error!,
                style: const TextStyle(
                  color: AppTheme.rose,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: submitting ? null : onSubmit,
              icon: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(
                submitting ? 'Enviando...' : 'Sumate al acceso anticipado',
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String? _required(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Completá este campo.';
    return null;
  }

  static String? _email(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Completá tu email.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Usá un email válido.';
    }
    return null;
  }
}

class _BetaTextField extends StatelessWidget {
  const _BetaTextField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.validator,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      style: const TextStyle(color: _betaInk, fontWeight: FontWeight.w800),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _betaMuted),
        prefixIcon: Icon(icon, color: AppTheme.rose),
        filled: true,
        fillColor: const Color(0xFFFFF7FB),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _betaLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppTheme.rose, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppTheme.rose),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppTheme.rose, width: 1.4),
        ),
      ),
    );
  }
}

class _PlatformChip extends StatelessWidget {
  const _PlatformChip({
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
      selectedColor: AppTheme.rose.withValues(alpha: 0.18),
      backgroundColor: const Color(0xFFFFF7FB),
      side: BorderSide(color: selected ? AppTheme.rose : _betaLine),
      labelStyle: TextStyle(
        color: selected ? AppTheme.rose : _betaInk,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _BetaStatusLookup extends StatelessWidget {
  const _BetaStatusLookup({
    required this.controller,
    required this.result,
    required this.error,
    required this.lookingUp,
    required this.onLookup,
    required this.onEnterApp,
    required this.onCopyLink,
    required this.onShare,
    required this.onShareWhatsApp,
  });

  final TextEditingController controller;
  final BetaSignupResult? result;
  final String? error;
  final bool lookingUp;
  final VoidCallback onLookup;
  final VoidCallback onEnterApp;
  final ValueChanged<BetaSignupResult> onCopyLink;
  final ValueChanged<BetaSignupResult> onShare;
  final ValueChanged<BetaSignupResult> onShareWhatsApp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: Colors.white,
        border: Border.all(color: _betaLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Ya me anoté',
            style: TextStyle(
              color: _betaInk,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Consultá tu estado con el email que usaste en el formulario.',
            style: TextStyle(
              color: _betaMuted,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          _BetaTextField(
            controller: controller,
            label: 'Email',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (_) => null,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: lookingUp ? null : onLookup,
            icon: lookingUp
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search_rounded),
            label: Text(lookingUp ? 'Consultando...' : 'Consultar estado'),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              style: const TextStyle(
                color: AppTheme.rose,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 14),
            _BetaResultCard(
              result: result!,
              compact: true,
              onEnterApp: onEnterApp,
              onCheckStatus: onLookup,
              onCopyLink: () => onCopyLink(result!),
              onShare: () => onShare(result!),
              onShareWhatsApp: () => onShareWhatsApp(result!),
            ),
          ],
        ],
      ),
    );
  }
}

class _BetaResultCard extends StatelessWidget {
  const _BetaResultCard({
    required this.result,
    required this.onEnterApp,
    required this.onCheckStatus,
    required this.onCopyLink,
    required this.onShare,
    required this.onShareWhatsApp,
    this.compact = false,
  });

  final BetaSignupResult result;
  final VoidCallback onEnterApp;
  final VoidCallback onCheckStatus;
  final VoidCallback onCopyLink;
  final VoidCallback onShare;
  final VoidCallback onShareWhatsApp;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final waitingPosition = result.position == null
        ? ''
        : ' Tu puesto es #${result.position}.';
    final title = switch (result.status) {
      BetaSignupStatus.approved => 'Ya tenés acceso anticipado a HallyuHub',
      BetaSignupStatus.waiting => 'Ya estás en lista de espera',
      BetaSignupStatus.blocked => 'Solicitud no disponible',
    };
    final detail = switch (result.status) {
      BetaSignupStatus.approved =>
        'Tu acceso está aprobado. Ya podés entrar a HallyuHub.',
      BetaSignupStatus.waiting =>
        result.duplicate
            ? 'Tu solicitud sigue en espera.$waitingPosition Te avisaremos cuando se habilite tu acceso.'
            : 'Los primeros cupos ya se completaron. Te sumamos a la lista de espera.$waitingPosition Te avisaremos cuando se habilite tu acceso.',
      BetaSignupStatus.blocked =>
        'Por ahora no podemos habilitar esta solicitud.',
    };
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white,
        border: Border.all(color: _betaLine),
        boxShadow: [
          BoxShadow(
            color: AppTheme.rose.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            result.status == BetaSignupStatus.approved
                ? Icons.verified_rounded
                : result.status == BetaSignupStatus.waiting
                ? Icons.hourglass_top_rounded
                : Icons.lock_outline_rounded,
            color: result.status == BetaSignupStatus.blocked
                ? AppTheme.rose
                : AppTheme.rose,
            size: 52,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _betaInk,
              fontSize: compact ? 21 : 27,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _betaMuted,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '${result.approvedCount}/${result.betaUserLimit} cupos aprobados',
            style: const TextStyle(
              color: AppTheme.rose,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (result.status == BetaSignupStatus.waiting &&
              result.hasShareUrl) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: const Color(0xFFFFF7FB),
                border: Border.all(color: _betaLine),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tu link para invitar',
                    style: TextStyle(
                      color: _betaMuted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  SelectableText(
                    result.shareUrl,
                    style: const TextStyle(
                      color: _betaInk,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Invitaciones válidas: ${result.referralCount}. Tu prioridad sube cuando se anota alguien real desde tu link.',
                    style: const TextStyle(
                      color: _betaMuted,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (result.status == BetaSignupStatus.approved)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onEnterApp,
                icon: const Icon(Icons.login_rounded),
                label: const Text('Entrar a HallyuHub'),
              ),
            )
          else if (result.status == BetaSignupStatus.waiting)
            Column(
              children: [
                if (result.hasShareUrl) ...[
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onCopyLink,
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('Copiar link'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onShareWhatsApp,
                          icon: const Icon(Icons.chat_rounded),
                          label: const Text('WhatsApp'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onShare,
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('Copiar texto para compartir'),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onCheckStatus,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Consultar mi estado'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
