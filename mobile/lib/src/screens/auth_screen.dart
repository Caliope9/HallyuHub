import 'package:flutter/material.dart';

import '../data/legal_documents.dart';
import '../models.dart';
import '../services/auth_service.dart';
import '../services/age_policy.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_mark.dart';

enum _AuthMode { login, register }

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.authService,
    required this.onAuthenticated,
  });

  final AuthService authService;
  final ValueChanged<AuthUser> onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _AuthMode _mode = _AuthMode.login;
  bool _rememberDevice = true;
  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  bool _communityGuidelinesAccepted = false;
  DateTime? _birthDate;
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  bool _isLoading = false;

  bool get _isRegister => _mode == _AuthMode.register;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _setMode(_AuthMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      if (mode == _AuthMode.login) {
        _termsAccepted = false;
        _privacyAccepted = false;
        _communityGuidelinesAccepted = false;
      }
      _formKey.currentState?.reset();
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_isRegister &&
        (!_termsAccepted ||
            !_privacyAccepted ||
            !_communityGuidelinesAccepted)) {
      _showMessage(
        'Aceptá Terms, Privacy y las Normas de comunidad para crear tu cuenta.',
      );
      return;
    }
    if (_isRegister &&
        AgePolicy.validate(_birthDate) != AgeGateResult.allowed) {
      _showMessage(
        _birthDate == null
            ? 'Ingresá tu fecha de nacimiento para crear la cuenta.'
            : 'Debes tener al menos 16 años para crear una cuenta en HallyuHub.',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = _isRegister
          ? await widget.authService.register(
              name: _nameController.text,
              username: _usernameController.text,
              email: _emailController.text,
              password: _passwordController.text,
              termsAccepted: _termsAccepted,
              privacyAccepted: _privacyAccepted,
              communityGuidelinesAccepted: _communityGuidelinesAccepted,
              birthDate: _birthDate,
            )
          : await widget.authService.signIn(
              login: _emailController.text,
              password: _passwordController.text,
              rememberDevice: _rememberDevice,
            );

      if (!mounted) return;
      widget.onAuthenticated(user);
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        error is AuthException
            ? error.message
            : 'No pudimos completar el acceso.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.nightSoft,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
  }

  void _openRecovery() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _RecoverySheet(),
    );
  }

  void _openLegalDocument(String path) {
    final document = switch (path) {
      '/terms' => legalTermsDocument,
      '/privacy' => legalPrivacyDocument,
      '/community-guidelines' => legalCommunityGuidelinesDocument,
      _ => null,
    };
    if (document == null) return;
    showDialog<void>(
      context: context,
      builder: (_) => _LegalDocumentDialog(document: document),
    );
  }

  String? _requiredText(String? value, String message) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  String? _validateLogin(String? value) {
    final required = _requiredText(value, 'Ingresa tu email');
    if (required != null) return required;
    if (_isRegister) return _validateEmail(value);
    return null;
  }

  String? _validateEmail(String? value) {
    final required = _requiredText(value, 'Ingresa tu email');
    if (required != null) return required;
    final email = value!.trim();
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!valid) return 'Usa un email válido';
    final domain = email.split('@').last.toLowerCase();
    final reservedDomain =
        domain == 'localhost' ||
        domain.endsWith('.localhost') ||
        domain.endsWith('.test') ||
        domain.endsWith('.example') ||
        domain.endsWith('.invalid');
    return reservedDomain ? 'Usa un email real, no uno de prueba' : null;
  }

  String? _validateUsername(String? value) {
    final required = _requiredText(value, 'Elige un usuario');
    if (required != null) return required;
    final username = value!.trim();
    if (username.length < 3) return 'Mínimo 3 caracteres';
    if (username.contains(RegExp(r'\s'))) return 'Sin espacios';
    return null;
  }

  String? _validatePassword(String? value) {
    final required = _requiredText(value, 'Ingresa tu contraseña');
    if (required != null) return required;
    if (value!.length < 8) return 'Mínimo 8 caracteres';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final passwordError = _validatePassword(value);
    if (passwordError != null) return passwordError;
    if (value != _passwordController.text) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.night, Color(0xFF150A24), Color(0xFF07181C)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: _AuthBackdrop()),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _AuthBrand(),
                        const SizedBox(height: 24),
                        _AuthPanel(
                          mode: _mode,
                          isLoading: _isLoading,
                          rememberDevice: _rememberDevice,
                          termsAccepted: _termsAccepted,
                          privacyAccepted: _privacyAccepted,
                          communityGuidelinesAccepted:
                              _communityGuidelinesAccepted,
                          birthDate: _birthDate,
                          onBirthDateChanged: (value) =>
                              setState(() => _birthDate = value),
                          hidePassword: _hidePassword,
                          hideConfirmPassword: _hideConfirmPassword,
                          formKey: _formKey,
                          nameController: _nameController,
                          usernameController: _usernameController,
                          emailController: _emailController,
                          passwordController: _passwordController,
                          confirmPasswordController: _confirmPasswordController,
                          onModeChanged: _setMode,
                          onRememberChanged: (value) =>
                              setState(() => _rememberDevice = value),
                          onTermsChanged: (value) =>
                              setState(() => _termsAccepted = value),
                          onPrivacyChanged: (value) =>
                              setState(() => _privacyAccepted = value),
                          onCommunityGuidelinesChanged: (value) => setState(
                            () => _communityGuidelinesAccepted = value,
                          ),
                          onOpenLegalDocument: _openLegalDocument,
                          onPasswordVisibilityChanged: () =>
                              setState(() => _hidePassword = !_hidePassword),
                          onConfirmPasswordVisibilityChanged: () => setState(
                            () => _hideConfirmPassword = !_hideConfirmPassword,
                          ),
                          onSubmit: _submit,
                          onRecovery: _openRecovery,
                          validateName: (value) =>
                              _requiredText(value, 'Ingresa tu nombre'),
                          validateUsername: _validateUsername,
                          validateEmail: _validateLogin,
                          validatePassword: _validatePassword,
                          validateConfirmPassword: _validateConfirmPassword,
                        ),
                        const SizedBox(height: 18),
                        const _TrustStrip(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthBrand extends StatelessWidget {
  const _AuthBrand();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const HallyuBrandLockup(iconSize: 76, wordmarkSize: 35),
        const SizedBox(height: 10),
        Text(
          'Conectá con fans K-pop, seguí a tus idols favoritos y compartí tus mejores momentos.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
            fontSize: 14.5,
            height: 1.38,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _BirthDateField extends StatelessWidget {
  const _BirthDateField({required this.value, required this.onChanged});

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final dateLabel = value == null
        ? 'Seleccionar fecha (requerido, 16+)'
        : AgePolicy.format(value!);
    return InkWell(
      key: const ValueKey('auth-birth-date'),
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final today = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate:
              value ?? DateTime(today.year - 16, today.month, today.day),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
          helpText: 'Fecha de nacimiento',
          confirmText: 'Usar fecha',
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(
          color: AppTheme.night.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cake_outlined, color: AppTheme.cyan),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                dateLabel,
                key: const ValueKey('auth-birth-date-value'),
                style: TextStyle(
                  color: value == null ? Colors.white54 : Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalDocumentDialog extends StatelessWidget {
  const _LegalDocumentDialog({required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.night,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.42),
                blurRadius: 36,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          document.title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  document.subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView(
                    children: [
                      for (final paragraph in document.paragraphs)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Text(
                            paragraph,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.82),
                              height: 1.48,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cerrar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthPanel extends StatelessWidget {
  const _AuthPanel({
    required this.mode,
    required this.isLoading,
    required this.rememberDevice,
    required this.termsAccepted,
    required this.privacyAccepted,
    required this.communityGuidelinesAccepted,
    required this.birthDate,
    required this.onBirthDateChanged,
    required this.hidePassword,
    required this.hideConfirmPassword,
    required this.formKey,
    required this.nameController,
    required this.usernameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.onModeChanged,
    required this.onRememberChanged,
    required this.onTermsChanged,
    required this.onPrivacyChanged,
    required this.onCommunityGuidelinesChanged,
    required this.onOpenLegalDocument,
    required this.onPasswordVisibilityChanged,
    required this.onConfirmPasswordVisibilityChanged,
    required this.onSubmit,
    required this.onRecovery,
    required this.validateName,
    required this.validateUsername,
    required this.validateEmail,
    required this.validatePassword,
    required this.validateConfirmPassword,
  });

  final _AuthMode mode;
  final bool isLoading;
  final bool rememberDevice;
  final bool termsAccepted;
  final bool privacyAccepted;
  final bool communityGuidelinesAccepted;
  final DateTime? birthDate;
  final ValueChanged<DateTime?> onBirthDateChanged;
  final bool hidePassword;
  final bool hideConfirmPassword;
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController usernameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final ValueChanged<_AuthMode> onModeChanged;
  final ValueChanged<bool> onRememberChanged;
  final ValueChanged<bool> onTermsChanged;
  final ValueChanged<bool> onPrivacyChanged;
  final ValueChanged<bool> onCommunityGuidelinesChanged;
  final ValueChanged<String> onOpenLegalDocument;
  final VoidCallback onPasswordVisibilityChanged;
  final VoidCallback onConfirmPasswordVisibilityChanged;
  final VoidCallback onSubmit;
  final VoidCallback onRecovery;
  final FormFieldValidator<String> validateName;
  final FormFieldValidator<String> validateUsername;
  final FormFieldValidator<String> validateEmail;
  final FormFieldValidator<String> validatePassword;
  final FormFieldValidator<String> validateConfirmPassword;

  bool get isRegister => mode == _AuthMode.register;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.13),
            AppTheme.violet.withValues(alpha: 0.09),
            AppTheme.nightSoft.withValues(alpha: 0.74),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.rose.withValues(alpha: 0.13),
            blurRadius: 38,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 44,
            offset: const Offset(0, 28),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AuthModeSwitch(mode: mode, onChanged: onModeChanged),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: Column(
                key: ValueKey(mode),
                children: [
                  if (isRegister) ...[
                    _AuthTextField(
                      fieldKey: const ValueKey('auth-name'),
                      controller: nameController,
                      label: 'Nombre',
                      hint: 'Tu nombre',
                      icon: Icons.badge_outlined,
                      textInputAction: TextInputAction.next,
                      validator: validateName,
                      autofillHints: const [AutofillHints.name],
                    ),
                    const SizedBox(height: 12),
                    _AuthTextField(
                      fieldKey: const ValueKey('auth-username'),
                      controller: usernameController,
                      label: 'Usuario',
                      hint: 'tu_usuario',
                      icon: Icons.alternate_email,
                      textInputAction: TextInputAction.next,
                      validator: validateUsername,
                      autofillHints: const [AutofillHints.username],
                    ),
                    const SizedBox(height: 12),
                  ],
                  _AuthTextField(
                    fieldKey: const ValueKey('auth-email'),
                    controller: emailController,
                    label: 'Email',
                    hint: 'tu@email.com',
                    icon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: validateEmail,
                    autofillHints: isRegister
                        ? const [AutofillHints.email]
                        : const [],
                  ),
                  const SizedBox(height: 12),
                  _AuthTextField(
                    fieldKey: const ValueKey('auth-password'),
                    controller: passwordController,
                    label: 'Contraseña',
                    hint: 'Mínimo 8 caracteres',
                    icon: Icons.lock_outline,
                    obscureText: hidePassword,
                    textInputAction: isRegister
                        ? TextInputAction.next
                        : TextInputAction.done,
                    validator: validatePassword,
                    onSubmitted: isRegister ? null : (_) => onSubmit(),
                    autofillHints: isRegister
                        ? const [AutofillHints.newPassword]
                        : const [],
                    suffix: IconButton(
                      onPressed: onPasswordVisibilityChanged,
                      tooltip: hidePassword ? 'Mostrar' : 'Ocultar',
                      icon: Icon(
                        hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  if (isRegister) ...[
                    const SizedBox(height: 12),
                    _AuthTextField(
                      fieldKey: const ValueKey('auth-confirm-password'),
                      controller: confirmPasswordController,
                      label: 'Confirmar contraseña',
                      hint: 'Repite tu contraseña',
                      icon: Icons.lock_reset,
                      obscureText: hideConfirmPassword,
                      textInputAction: TextInputAction.done,
                      validator: validateConfirmPassword,
                      onSubmitted: (_) => onSubmit(),
                      autofillHints: const [AutofillHints.newPassword],
                      suffix: IconButton(
                        onPressed: onConfirmPasswordVisibilityChanged,
                        tooltip: hideConfirmPassword ? 'Mostrar' : 'Ocultar',
                        icon: Icon(
                          hideConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (isRegister)
              Column(
                children: [
                  _BirthDateField(
                    value: birthDate,
                    onChanged: onBirthDateChanged,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'HallyuHub está disponible para personas de 16 años o más.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _TermsCheck(
                    checkboxKey: const ValueKey('auth-terms-checkbox'),
                    value: termsAccepted,
                    onChanged: onTermsChanged,
                    prefixText: 'Acepto los ',
                    linkText: 'Términos de uso',
                    suffixText: ' de HallyuHub.',
                    onOpenLink: () => onOpenLegalDocument('/terms'),
                    errorText: 'Aceptá los Términos de uso para continuar.',
                  ),
                  _TermsCheck(
                    checkboxKey: const ValueKey('auth-privacy-checkbox'),
                    value: privacyAccepted,
                    onChanged: onPrivacyChanged,
                    prefixText: 'Acepto la ',
                    linkText: 'Política de privacidad',
                    suffixText: ' de HallyuHub.',
                    onOpenLink: () => onOpenLegalDocument('/privacy'),
                    errorText:
                        'Aceptá la Política de privacidad para continuar.',
                  ),
                  _TermsCheck(
                    checkboxKey: const ValueKey('auth-community-checkbox'),
                    value: communityGuidelinesAccepted,
                    onChanged: onCommunityGuidelinesChanged,
                    prefixText: 'Acepto las ',
                    linkText: 'Normas de comunidad',
                    suffixText: ' de HallyuHub.',
                    onOpenLink: () =>
                        onOpenLegalDocument('/community-guidelines'),
                    errorText: 'Aceptá las Normas de comunidad para continuar.',
                  ),
                ],
              )
            else
              _RememberRow(
                value: rememberDevice,
                onChanged: onRememberChanged,
                onRecovery: onRecovery,
              ),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isLoading
                      ? [
                          Colors.white.withValues(alpha: 0.22),
                          Colors.white.withValues(alpha: 0.12),
                        ]
                      : const [AppTheme.rose, AppTheme.violet, AppTheme.cyan],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  if (!isLoading)
                    BoxShadow(
                      color: AppTheme.rose.withValues(alpha: 0.28),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                ],
              ),
              child: FilledButton(
                key: const ValueKey('auth-submit'),
                onPressed: isLoading ? null : onSubmit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: isLoading
                      ? const SizedBox(
                          key: ValueKey('auth-loading'),
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text(
                          isRegister ? 'Crear cuenta' : 'Entrar',
                          key: const ValueKey('auth-submit-label'),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.82),
              ),
              onPressed: isLoading
                  ? null
                  : () => onModeChanged(
                      isRegister ? _AuthMode.login : _AuthMode.register,
                    ),
              child: Text(
                isRegister ? 'Ya tengo cuenta' : 'Crear una cuenta nueva',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthModeSwitch extends StatelessWidget {
  const _AuthModeSwitch({required this.mode, required this.onChanged});

  final _AuthMode mode;
  final ValueChanged<_AuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.night.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AuthModeOption(
              label: 'Iniciar sesión',
              selected: mode == _AuthMode.login,
              onTap: () => onChanged(_AuthMode.login),
            ),
          ),
          Expanded(
            child: _AuthModeOption(
              label: 'Crear cuenta',
              selected: mode == _AuthMode.register,
              onTap: () => onChanged(_AuthMode.register),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthModeOption extends StatelessWidget {
  const _AuthModeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: selected
                ? const LinearGradient(colors: [AppTheme.rose, AppTheme.violet])
                : null,
            color: selected ? null : Colors.transparent,
            border: Border.all(
              color: selected
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.transparent,
            ),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: AppTheme.rose.withValues(alpha: 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.68),
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthTextField extends StatelessWidget {
  const _AuthTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.validator,
    this.fieldKey,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffix,
    this.onSubmitted,
    this.autofillHints,
  });

  final Key? fieldKey;
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String> validator;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
    );

    return TextFormField(
      key: fieldKey,
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      autocorrect: false,
      enableSuggestions: !obscureText,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      autofillHints: autofillHints,
      cursorColor: AppTheme.cyan,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppTheme.night.withValues(alpha: 0.34),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.78)),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.42)),
        prefixIconColor: AppTheme.cyan.withValues(alpha: 0.85),
        suffixIconColor: Colors.white70,
        errorStyle: const TextStyle(
          color: Color(0xFFFFB7C8),
          fontWeight: FontWeight.w800,
        ),
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppTheme.cyan, width: 1.5),
        ),
        errorBorder: border.copyWith(
          borderSide: const BorderSide(color: AppTheme.rose),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: const BorderSide(color: AppTheme.rose, width: 1.4),
        ),
      ),
    );
  }
}

class _RememberRow extends StatelessWidget {
  const _RememberRow({
    required this.value,
    required this.onChanged,
    required this.onRecovery,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback onRecovery;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => onChanged(!value),
            borderRadius: BorderRadius.circular(14),
            child: Row(
              children: [
                Checkbox(
                  value: value,
                  onChanged: (checked) => onChanged(checked ?? false),
                  activeColor: AppTheme.rose,
                  checkColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.36)),
                ),
                const Flexible(
                  child: Text(
                    'Recordarme',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.cyan.withValues(alpha: 0.92),
          ),
          onPressed: onRecovery,
          child: const Text(
            'Recuperar acceso',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _TermsCheck extends StatelessWidget {
  const _TermsCheck({
    required this.value,
    required this.onChanged,
    required this.prefixText,
    required this.linkText,
    required this.suffixText,
    required this.onOpenLink,
    this.checkboxKey,
    this.errorText = 'Acepta los términos para continuar',
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String prefixText;
  final String linkText;
  final String suffixText;
  final VoidCallback onOpenLink;
  final Key? checkboxKey;
  final String errorText;

  @override
  Widget build(BuildContext context) {
    return FormField<bool>(
      validator: (_) => value ? null : errorText,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  key: checkboxKey,
                  value: value,
                  onChanged: (checked) {
                    final nextValue = checked ?? false;
                    onChanged(nextValue);
                    field.didChange(nextValue);
                  },
                  activeColor: AppTheme.rose,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.36)),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          prefixText,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Semantics(
                          link: true,
                          button: true,
                          label: linkText,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: onOpenLink,
                              child: Text(
                                linkText,
                                style: const TextStyle(
                                  color: AppTheme.cyan,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppTheme.cyan,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Text(
                          suffixText,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 2),
                child: Text(
                  field.errorText!,
                  style: const TextStyle(
                    color: Color(0xFFFFB7C8),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TrustStrip extends StatelessWidget {
  const _TrustStrip();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.verified_user_outlined, 'Fans reales'),
      (Icons.groups_2_outlined, 'Fandoms activos'),
      (Icons.auto_awesome, 'K-pop latino'),
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.$1, color: AppTheme.cyan, size: 16),
              const SizedBox(width: 6),
              Text(
                item.$2,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _RecoverySheet extends StatelessWidget {
  const _RecoverySheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
        decoration: const BoxDecoration(
          color: AppTheme.nightSoft,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Recuperar acceso',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
                Text(
                  'La recuperación automática aún no está disponible. Para recuperar tu cuenta, escribí a soporte@hallyuhub.net desde el email asociado.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.68),
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: AppTheme.cyan,
                  foregroundColor: AppTheme.night,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  'Cerrar',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthBackdrop extends CustomPainter {
  const _AuthBackdrop();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = AppTheme.rose.withValues(alpha: 0.075);
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height * 0.08)
        ..lineTo(size.width, size.height * 0.2)
        ..lineTo(size.width, size.height * 0.36)
        ..lineTo(0, size.height * 0.22)
        ..close(),
      paint,
    );

    paint.color = AppTheme.cyan.withValues(alpha: 0.07);
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height * 0.72)
        ..lineTo(size.width, size.height * 0.52)
        ..lineTo(size.width, size.height * 0.68)
        ..lineTo(0, size.height * 0.88)
        ..close(),
      paint,
    );

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.045);
    for (var x = -size.height; x < size.width; x += 34) {
      canvas.drawLine(
        Offset(x.toDouble(), size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AuthBackdrop oldDelegate) => false;
}
