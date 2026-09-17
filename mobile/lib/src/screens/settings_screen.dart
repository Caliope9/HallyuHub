import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/legal_documents.dart';
import '../models.dart';
import '../services/auth_service.dart';
import '../services/account_deletion_service.dart';
import '../services/beta_signup_service.dart';
import '../services/content_moderation_service.dart';
import '../services/feedback_report_service.dart';
import '../services/hally_feature_tip_service.dart';
import '../services/local_artist_tag_service.dart';
import '../services/store_profile_service.dart';
import 'admin_panel_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/hub_avatar.dart';

enum _SettingsPanel {
  personalData,
  password,
  language,
  location,
  editProfile,
  storeProfile,
  profileBackground,
  privateAccount,
  messagePrivacy,
  storyPrivacy,
  blockedUsers,
  notifMessages,
  notifStars,
  notifComments,
  notifFollowers,
  notifDrops,
  accountVerification,
  activeSessions,
  reportProblem,
  sendSuggestion,
  plus,
  paymentMethods,
  privacyPolicy,
  terms,
  communityRules,
  adminPanel,
  betaNotice,
  legalContact,
  copyright,
  fanPolicy,
  legalModeration,
  deleteAccount,
  logout,
}

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({
    super.key,
    required this.user,
    required this.onUserChanged,
    required this.onPrivateProfileChanged,
    required this.onSignOut,
    this.initialPanel,
    this.feedbackReportService = const LocalFeedbackReportService(),
    this.storeProfileService = const LocalStoreProfileService(),
    this.accountDeletionService = const LocalAccountDeletionService(),
    this.betaSignupService = const LocalBetaSignupService(),
    this.artistTagService = const LocalArtistTagService(),
    this.contentModerationService = const UnavailableContentModerationService(),
  });

  final AuthUser user;
  final Future<void> Function(AuthUser user) onUserChanged;
  final Future<void> Function(bool privateProfile) onPrivateProfileChanged;
  final VoidCallback onSignOut;
  final String? initialPanel;
  final FeedbackReportService feedbackReportService;
  final StoreProfileService storeProfileService;
  final AccountDeletionService accountDeletionService;
  final BetaSignupService betaSignupService;
  final LocalArtistTagService artistTagService;
  final ContentModerationService contentModerationService;

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _countryController;
  late final TextEditingController _regionController;
  late final TextEditingController _cityController;
  late final TextEditingController _bioController;
  late final TextEditingController _fandomController;
  late final TextEditingController _biasController;
  late final TextEditingController _favoriteGroupController;
  late final TextEditingController _phraseController;
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;
  late final TextEditingController _blockedUserController;
  late final TextEditingController _reportController;
  late final TextEditingController _storeNameController;
  late final TextEditingController _storeDescriptionController;
  late final TextEditingController _storeContactController;
  late final TextEditingController _storeInstagramController;
  late final TextEditingController _storeWhatsappController;
  late final TextEditingController _storeHoursController;

  _SettingsPanel? _activePanel;
  late String _language;
  late String _contentRegion;
  late String _locationVisibility;
  late String _messagePrivacy;
  late String _storyPrivacy;
  late String _appTheme;
  late String _profileBackground;
  late String _reportCategory;
  late String _reportScreen;
  late bool _privateProfile;
  late bool _notifyMessages;
  late bool _notifyStars;
  late bool _notifyComments;
  late bool _notifyFollowers;
  late bool _notifyDrops;
  late bool _twoFactorEnabled;
  late bool _loginAlerts;
  late bool _verificationRequested;
  late List<String> _blockedUsers;
  StoreProfile? _storeProfile;
  bool _storeEnabled = false;
  bool _loadingStoreProfile = false;
  bool _savingStoreProfile = false;
  List<String> _storeCategories = const [];
  List<String> _storeDeliveryMethods = const [];
  List<String> _storePaymentMethods = const [];
  String? _savedMessage;
  FeedbackAttachment? _reportAttachment;
  bool _isSubmittingFeedback = false;
  AccountDeletionRequest? _deletionRequest;
  bool _loadingDeletion = false;
  bool _deletionActionInProgress = false;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _nameController = TextEditingController(text: user.name);
    _usernameController = TextEditingController(text: user.username);
    _emailController = TextEditingController(text: user.email);
    _phoneController = TextEditingController(text: user.phone);
    _countryController = TextEditingController(text: user.country);
    _regionController = TextEditingController(text: user.region);
    _cityController = TextEditingController(text: user.city);
    _bioController = TextEditingController(text: user.bio);
    _fandomController = TextEditingController(text: user.fandom);
    _biasController = TextEditingController(text: user.bias);
    _favoriteGroupController = TextEditingController(text: user.favoriteGroup);
    _phraseController = TextEditingController(text: user.phrase);
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _blockedUserController = TextEditingController();
    _reportController = TextEditingController();
    _storeNameController = TextEditingController();
    _storeDescriptionController = TextEditingController();
    _storeContactController = TextEditingController();
    _storeInstagramController = TextEditingController();
    _storeWhatsappController = TextEditingController();
    _storeHoursController = TextEditingController();
    _language = user.language;
    _contentRegion = user.contentRegion;
    _locationVisibility = user.locationVisibility;
    _messagePrivacy = user.messagePrivacy;
    _storyPrivacy = user.storyPrivacy;
    _appTheme = user.appTheme;
    _profileBackground = user.profileBackground;
    _privateProfile = user.privateProfile;
    _notifyMessages = user.notifyMessages;
    _notifyStars = user.notifyStars;
    _notifyComments = user.notifyComments;
    _notifyFollowers = user.notifyFollowers;
    _notifyDrops = user.notifyDrops;
    _twoFactorEnabled = user.twoFactorEnabled;
    _loginAlerts = user.loginAlerts;
    _verificationRequested = user.accountVerified;
    _blockedUsers = [...user.blockedUsers];
    _reportCategory = 'video_audio';
    _reportScreen = 'otro';
    _activePanel = _panelFromInitial(widget.initialPanel);
    LocalStoreProfileService.revision.addListener(_restoreStoreProfile);
    unawaited(_restoreStoreProfile());
    if (_activePanel == _SettingsPanel.deleteAccount) {
      unawaited(_loadDeletionStatus());
    }
  }

  _SettingsPanel? _panelFromInitial(String? panel) {
    switch (panel) {
      case 'editProfile':
        return _SettingsPanel.editProfile;
      case 'storeProfile':
        return _SettingsPanel.storeProfile;
      case 'profileBackground':
        return _SettingsPanel.profileBackground;
      case 'personalData':
        return _SettingsPanel.personalData;
      case 'reportProblem':
        return _SettingsPanel.reportProblem;
      case 'sendSuggestion':
        return _SettingsPanel.sendSuggestion;
      default:
        return null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _countryController.dispose();
    _regionController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    _fandomController.dispose();
    _biasController.dispose();
    _favoriteGroupController.dispose();
    _phraseController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _blockedUserController.dispose();
    _reportController.dispose();
    _storeNameController.dispose();
    _storeDescriptionController.dispose();
    _storeContactController.dispose();
    _storeInstagramController.dispose();
    _storeWhatsappController.dispose();
    _storeHoursController.dispose();
    LocalStoreProfileService.revision.removeListener(_restoreStoreProfile);
    super.dispose();
  }

  void _openPanel(_SettingsPanel panel) {
    if (panel == _SettingsPanel.adminPanel) {
      if (!widget.user.canAccessAdminPanel) return;
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => AdminPanelScreen(
            user: widget.user,
            betaSignupService: widget.betaSignupService,
            feedbackReportService: widget.feedbackReportService,
            artistTagService: widget.artistTagService,
            storeProfileService: widget.storeProfileService,
            contentModerationService: widget.contentModerationService,
          ),
        ),
      );
      return;
    }
    setState(() {
      _activePanel = panel;
      _savedMessage = null;
      _reportAttachment = null;
    });
    if (panel == _SettingsPanel.deleteAccount) {
      unawaited(_loadDeletionStatus());
    }
  }

  Future<void> _loadDeletionStatus() async {
    if (_loadingDeletion) return;
    setState(() => _loadingDeletion = true);
    try {
      final request = await widget.accountDeletionService.getStatus();
      if (!mounted) return;
      setState(() {
        _deletionRequest = request;
        _loadingDeletion = false;
        _savedMessage = null;
      });
    } catch (error) {
      debugPrint('ACCOUNT_DELETION_STATUS_UI_ERROR error=$error');
      if (!mounted) return;
      setState(() {
        _loadingDeletion = false;
        _savedMessage = _deletionErrorMessage(error);
      });
    }
  }

  String _deletionErrorMessage(Object error) {
    if (error is AccountDeletionException &&
        error.message.contains('requiere conexión')) {
      return error.message;
    }
    return 'No pudimos procesar la solicitud. Intentá nuevamente.';
  }

  void _returnToMain() {
    FocusScope.of(context).unfocus();
    setState(() {
      _activePanel = null;
      _savedMessage = null;
    });
  }

  Future<void> _saveUser(String message) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final nextUser = widget.user.copyWith(
      name: _nameController.text.trim(),
      username: _normalizeUsername(_usernameController.text),
      email: _emailController.text.trim().toLowerCase(),
      phone: _phoneController.text.trim(),
      country: _countryController.text.trim(),
      region: _regionController.text.trim(),
      city: _cityController.text.trim(),
      bio: _bioController.text.trim(),
      fandom: _fandomController.text.trim(),
      bias: _biasController.text.trim(),
      favoriteGroup: _favoriteGroupController.text.trim(),
      phrase: _phraseController.text.trim(),
      language: _language,
      contentRegion: _contentRegion,
      locationVisibility: _locationVisibility,
      locationUpdatedAt: DateTime.now(),
      messagePrivacy: _messagePrivacy,
      storyPrivacy: _storyPrivacy,
      appTheme: _appTheme,
      profileBackground: _profileBackground,
      privateProfile: _privateProfile,
      notificationsEnabled:
          _notifyMessages ||
          _notifyStars ||
          _notifyComments ||
          _notifyFollowers ||
          _notifyDrops,
      notifyMessages: _notifyMessages,
      notifyStars: _notifyStars,
      notifyComments: _notifyComments,
      notifyFollowers: _notifyFollowers,
      notifyDrops: _notifyDrops,
      twoFactorEnabled: _twoFactorEnabled,
      loginAlerts: _loginAlerts,
      accountVerified: _verificationRequested,
      blockedUsers: _blockedUsers,
    );
    debugPrint(
      'PROFILE_SETTINGS_SAVE_START private_profile=${nextUser.privateProfile}',
    );
    setState(() => _savedMessage = null);
    try {
      await widget.onUserChanged(nextUser);
      if (!mounted) return;
      debugPrint(
        'PROFILE_SETTINGS_SAVE_OK private_profile=${nextUser.privateProfile}',
      );
      setState(() => _savedMessage = message);
    } catch (error) {
      debugPrint(
        'PROFILE_SETTINGS_SAVE_ERROR private_profile=${nextUser.privateProfile} error=$error',
      );
      if (!mounted) return;
      setState(
        () => _savedMessage = error is AuthException
            ? error.message
            : 'No pudimos guardar los cambios. Revisá conexión o permisos.',
      );
    }
  }

  Future<void> _savePrivateProfile(String message) async {
    FocusScope.of(context).unfocus();
    debugPrint(
      'PROFILE_SETTINGS_PRIVACY_SAVE_START private_profile=$_privateProfile',
    );
    setState(() => _savedMessage = null);
    try {
      await widget.onPrivateProfileChanged(_privateProfile);
      if (!mounted) return;
      debugPrint(
        'PROFILE_SETTINGS_PRIVACY_SAVE_OK private_profile=$_privateProfile',
      );
      setState(() => _savedMessage = message);
    } catch (error) {
      debugPrint(
        'PROFILE_SETTINGS_PRIVACY_SAVE_ERROR private_profile=$_privateProfile error=$error',
      );
      if (!mounted) return;
      setState(
        () => _savedMessage = error is AuthException
            ? error.message
            : 'No pudimos guardar la privacidad. Revisá conexión o permisos.',
      );
    }
  }

  Future<void> _restoreStoreProfile() async {
    if (_loadingStoreProfile) return;
    _loadingStoreProfile = true;
    try {
      final store = await widget.storeProfileService.restoreOwnStore();
      if (!mounted) return;
      setState(() {
        _storeProfile = store;
        _storeEnabled =
            store != null &&
            store.status != StoreProfileStatus.paused &&
            store.status != StoreProfileStatus.blocked;
        if (store != null) {
          _storeNameController.text = store.storeName;
          _storeDescriptionController.text = store.description;
          _storeContactController.text = store.contactUrl;
          _storeInstagramController.text = store.instagramUrl;
          _storeWhatsappController.text = store.whatsappUrl;
          _storeHoursController.text = store.openingHours;
          if (store.country.isNotEmpty) _countryController.text = store.country;
          if (store.region.isNotEmpty) _regionController.text = store.region;
          if (store.city.isNotEmpty) _cityController.text = store.city;
          _storeCategories = store.categories;
          _storeDeliveryMethods = store.deliveryMethods;
          _storePaymentMethods = store.paymentMethods;
        } else {
          _storeNameController.text = widget.user.name;
          _storeDescriptionController.text = '';
          _storeContactController.text = '';
          _storeInstagramController.text = '';
          _storeWhatsappController.text = '';
          _storeHoursController.text = '';
          _storeCategories = const [];
          _storeDeliveryMethods = const [];
          _storePaymentMethods = const [];
        }
      });
    } catch (error) {
      debugPrint('STORE_PROFILE_SETTINGS_RESTORE_ERROR error=$error');
      if (!mounted) return;
      setState(
        () => _savedMessage =
            'No pudimos leer tu perfil tienda. Revisá conexión o Supabase.',
      );
    } finally {
      _loadingStoreProfile = false;
    }
  }

  Future<void> _saveStoreProfile() async {
    FocusScope.of(context).unfocus();
    if (_savingStoreProfile) return;
    setState(() {
      _savingStoreProfile = true;
      _savedMessage = null;
    });
    try {
      StoreProfile store;
      if (!_storeEnabled) {
        if (_storeProfile == null) {
          if (!mounted) return;
          setState(
            () => _savedMessage =
                'Tu cuenta sigue como fan. Podés activar tienda cuando quieras.',
          );
          return;
        }
        store = await widget.storeProfileService.pauseOwnStore();
        if (!mounted) return;
        setState(() {
          _storeProfile = store;
          _savedMessage = 'Perfil tienda pausado. Tu cuenta sigue como fan.';
        });
        return;
      }

      final draft = StoreProfileDraft(
        storeName: _storeNameController.text,
        description: _storeDescriptionController.text,
        country: _countryController.text,
        region: _regionController.text,
        city: _cityController.text,
        categories: _storeCategories,
        deliveryMethods: _storeDeliveryMethods,
        paymentMethods: _storePaymentMethods,
        contactUrl: _storeContactController.text,
        instagramUrl: _storeInstagramController.text,
        whatsappUrl: _storeWhatsappController.text,
        openingHours: _storeHoursController.text,
      );
      store = await widget.storeProfileService.saveOwnStore(draft);
      if (store.status == StoreProfileStatus.paused) {
        store = await widget.storeProfileService.resumeOwnStore();
      }
      if (!mounted) return;
      setState(() {
        _storeProfile = store;
        _storeEnabled = store.status != StoreProfileStatus.paused;
        _savedMessage = store.status == StoreProfileStatus.active
            ? 'Perfil tienda actualizado.'
            : 'Solicitud de perfil tienda guardada. La vamos a revisar.';
      });
    } on StoreProfileException catch (error) {
      if (!mounted) return;
      setState(() => _savedMessage = error.message);
    } catch (error) {
      debugPrint('STORE_PROFILE_SETTINGS_SAVE_ERROR error=$error');
      if (!mounted) return;
      setState(
        () => _savedMessage =
            'No pudimos guardar el perfil tienda. Revisá conexión o permisos.',
      );
    } finally {
      if (mounted) setState(() => _savingStoreProfile = false);
    }
  }

  void _toggleStoreValue({
    required String value,
    required List<String> values,
    required ValueChanged<List<String>> onChanged,
  }) {
    final next = [...values];
    if (next.contains(value)) {
      next.remove(value);
    } else {
      next.add(value);
    }
    onChanged(next);
  }

  void _savePassword() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    setState(() => _savedMessage = 'Contraseña actualizada');
  }

  void _addBlockedUser() {
    final raw = _blockedUserController.text.trim();
    if (raw.isEmpty) return;
    final handle = raw.startsWith('@') ? raw : '@$raw';
    setState(() {
      if (!_blockedUsers.contains(handle)) _blockedUsers.add(handle);
      _blockedUserController.clear();
    });
  }

  Future<void> _useApproximateLocation() async {
    FocusScope.of(context).unfocus();
    setState(
      () => _savedMessage =
          'HallyuHub no usa GPS. Completá país, región y ciudad manualmente.',
    );
  }

  void _confirmSignOut() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ConfirmActionSheet(
        title: 'Cerrar sesión',
        body: 'Vas a salir de HallyuHub en este dispositivo.',
        actionLabel: 'Cerrar sesión',
        onConfirm: () {
          Navigator.of(context).pop();
          Navigator.of(this.context).pop();
          widget.onSignOut();
        },
      ),
    );
  }

  void _confirmResetHallyTips() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.nightSoft,
        title: const Text('Volver a mostrar las ayudas'),
        content: const Text(
          'Se reactivarán únicamente las ayudas de Hally que desactivaste en este dispositivo. Tu sesión y tus preferencias no cambian.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('settings-hally-tips-reset-confirm'),
            onPressed: () async {
              await const HallyFeatureTipService().resetAll();
              if (!mounted || !dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Las ayudas de Hally vuelven a estar activas.',
                    ),
                  ),
                );
            },
            child: const Text('Volver a mostrar'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount() {
    if (_deletionActionInProgress) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ConfirmActionSheet(
        title: 'Solicitar eliminación',
        body:
            'Se generará una solicitud para revisar datos, publicaciones y seguridad antes de borrar la cuenta.',
        actionLabel: 'Solicitar eliminación',
        onConfirm: () {
          Navigator.of(context).pop();
          unawaited(_requestAccountDeletion());
        },
      ),
    );
  }

  Future<void> _requestAccountDeletion() async {
    if (_deletionActionInProgress) return;
    setState(() {
      _deletionActionInProgress = true;
      _savedMessage = null;
    });
    try {
      await widget.accountDeletionService.request();
      await _loadDeletionStatus();
    } catch (error) {
      debugPrint('ACCOUNT_DELETION_REQUEST_UI_ERROR error=$error');
      if (mounted) setState(() => _savedMessage = _deletionErrorMessage(error));
    } finally {
      if (mounted) setState(() => _deletionActionInProgress = false);
    }
  }

  void _confirmCancelDeletion() {
    final request = _deletionRequest;
    if (request == null || !request.canCancel || _deletionActionInProgress) {
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ConfirmActionSheet(
        title: 'Cancelar solicitud',
        body: 'La solicitud pendiente dejará de estar activa.',
        actionLabel: 'Cancelar solicitud',
        onConfirm: () {
          Navigator.of(context).pop();
          unawaited(_cancelAccountDeletion(request.id));
        },
      ),
    );
  }

  Future<void> _cancelAccountDeletion(String requestId) async {
    if (_deletionActionInProgress) return;
    setState(() {
      _deletionActionInProgress = true;
      _savedMessage = null;
    });
    try {
      await widget.accountDeletionService.cancel(requestId);
      await _loadDeletionStatus();
    } catch (error) {
      debugPrint('ACCOUNT_DELETION_CANCEL_UI_ERROR error=$error');
      if (mounted) setState(() => _savedMessage = _deletionErrorMessage(error));
    } finally {
      if (mounted) setState(() => _deletionActionInProgress = false);
    }
  }

  Future<void> _pickFeedbackAttachment({required bool video}) async {
    try {
      final file = video
          ? await _imagePicker.pickVideo(source: ImageSource.gallery)
          : await _imagePicker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 86,
            );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final mimeType = inferFeedbackMimeType(file.name, file.mimeType);
      setState(() {
        _reportAttachment = FeedbackAttachment(
          bytes: Uint8List.fromList(bytes),
          fileName: file.name,
          mimeType: mimeType,
        );
        _savedMessage = null;
      });
    } on FeedbackReportException catch (error) {
      if (!mounted) return;
      setState(() => _savedMessage = error.message);
    } catch (error) {
      debugPrint('FEEDBACK_ATTACHMENT_PICK_ERROR error=$error');
      if (!mounted) return;
      setState(
        () => _savedMessage =
            'No pudimos leer el archivo. Probá con otra captura o video.',
      );
    }
  }

  Future<void> _submitFeedback(_SettingsPanel panel) async {
    FocusScope.of(context).unfocus();
    if (_isSubmittingFeedback) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmittingFeedback = true;
      _savedMessage = null;
    });
    final isSuggestion = panel == _SettingsPanel.sendSuggestion;
    try {
      final description = _reportController.text.trim();
      await widget.feedbackReportService.submitReport(
        user: widget.user,
        draft: FeedbackReportDraft(
          type: isSuggestion ? 'otro' : _reportCategory,
          screen: isSuggestion ? 'otro' : _reportScreen,
          description: isSuggestion ? 'Sugerencia: $description' : description,
          attachment: _reportAttachment,
        ),
      );
      if (!mounted) return;
      setState(() {
        _reportController.clear();
        _reportAttachment = null;
        _savedMessage = isSuggestion
            ? 'Sugerencia enviada. Gracias por ayudar a mejorar HallyuHub.'
            : 'Reporte enviado. Lo vamos a revisar desde el Panel Admin.';
      });
    } on FeedbackReportException catch (error) {
      if (!mounted) return;
      setState(() => _savedMessage = error.message);
    } catch (error) {
      debugPrint('FEEDBACK_SUBMIT_UI_ERROR error=$error');
      if (!mounted) return;
      setState(
        () => _savedMessage =
            'No pudimos enviar el reporte. Probá de nuevo en unos segundos.',
      );
    } finally {
      if (mounted) setState(() => _isSubmittingFeedback = false);
    }
  }

  String _normalizeUsername(String value) {
    final cleaned = value
        .replaceAll('@', '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._]'), '');
    return '@${cleaned.isEmpty ? 'hallyufan' : cleaned}';
  }

  String? _required(String? value, String message) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  String? _validateEmail(String? value) {
    final required = _required(value, 'Ingresa un email');
    if (required != null) return required;
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value!.trim());
    return valid ? null : 'Usa un email válido';
  }

  String? _validateUsername(String? value) {
    final required = _required(value, 'Ingresa un usuario');
    if (required != null) return required;
    final cleaned = value!.replaceAll('@', '').trim();
    if (cleaned.length < 3) return 'Mínimo 3 caracteres';
    if (cleaned.contains(RegExp(r'\s'))) return 'Sin espacios';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.length < 8) return 'Mínimo 8 caracteres';
    return null;
  }

  String? _validateNewPasswordConfirmation(String? value) {
    final passwordError = _validatePassword(value);
    if (passwordError != null) return passwordError;
    if (value != _newPasswordController.text) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }

  String _storeStatusDetail(StoreProfile store) {
    if (store.status == StoreProfileStatus.active) {
      return store.isVerified
          ? 'Tu tienda está activa y marcada como verificada.'
          : 'Tu tienda está activa. La verificación queda para revisión admin.';
    }
    if (store.status == StoreProfileStatus.paused) {
      return 'Tu tienda está pausada y no aparece como perfil tienda público.';
    }
    if (store.status == StoreProfileStatus.blocked) {
      return 'La tienda está restringida. Contactá soporte para revisarla.';
    }
    return 'Tu solicitud está pendiente de revisión desde el Panel Admin.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.night, AppTheme.nightSoft, AppTheme.night],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _activePanel == null
                      ? _buildSettingsHome(context)
                      : _buildSettingsDetail(context, _activePanel!),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsHome(BuildContext context) {
    return ListView(
      key: const ValueKey('settings-home-scroll'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _SettingsTopBar(
          title: 'Centro de cuenta',
          subtitle: 'Cuenta, perfil, privacidad y legal',
          onBack: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 12),
        _AccountHero(user: widget.user),
        const SizedBox(height: 14),
        _ActionRow(
          key: const ValueKey('settings-hally-tips'),
          icon: Icons.lightbulb_outline_rounded,
          title: 'Ayudas de Hally',
          detail: 'Volver a mostrar todas las ayudas contextuales.',
          onTap: _confirmResetHallyTips,
        ),
        const SizedBox(height: 14),
        if (widget.user.canAccessAdminPanel)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _SettingsHomeSection(
              title: 'Administración',
              detail: 'Herramientas internas para cuentas autorizadas.',
              items: const [
                _SettingsItemData(
                  panel: _SettingsPanel.adminPanel,
                  title: 'Panel Admin',
                  detail: 'Denuncias, feedback, sugerencias y operaciones internas.',
                  icon: Icons.admin_panel_settings_outlined,
                ),
              ],
              valueForPanel: _panelValue,
              onOpen: _openPanel,
            ),
          ),
        for (final group in _settingsGroups)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _SettingsHomeSection(
              title: group.title,
              detail: group.detail,
              items: group.items,
              valueForPanel: _panelValue,
              onOpen: _openPanel,
            ),
          ),
      ],
    );
  }

  Widget _buildSettingsDetail(BuildContext context, _SettingsPanel panel) {
    return ListView(
      key: ValueKey('settings-detail-${panel.name}'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _SettingsTopBar(
          title: _panelTitle(panel),
          subtitle: _panelSubtitle(panel),
          onBack: _returnToMain,
        ),
        const SizedBox(height: 12),
        if (_savedMessage != null) ...[
          _SaveNotice(message: _savedMessage!),
          const SizedBox(height: 12),
        ],
        _SettingsDetailCard(children: _panelChildren(panel)),
        const SizedBox(height: 16),
        _panelPrimaryAction(panel),
      ],
    );
  }

  List<Widget> _panelChildren(_SettingsPanel panel) {
    switch (panel) {
      case _SettingsPanel.personalData:
        return [
          _SettingsTextField(
            key: const ValueKey('settings-email'),
            controller: _emailController,
            label: 'Email',
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            validator: _validateEmail,
          ),
          _SettingsTextField(
            controller: _phoneController,
            label: 'Teléfono',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const _InfoBox(
            text:
                'Estos datos no aparecen en tu perfil público. Se usan para seguridad y soporte de cuenta.',
          ),
        ];
      case _SettingsPanel.password:
        return [
          _SettingsTextField(
            controller: _currentPasswordController,
            label: 'Contraseña actual',
            icon: Icons.lock_outline,
            obscureText: true,
            validator: _validatePassword,
          ),
          _SettingsTextField(
            controller: _newPasswordController,
            label: 'Nueva contraseña',
            icon: Icons.lock_reset,
            obscureText: true,
            validator: _validatePassword,
          ),
          _SettingsTextField(
            controller: _confirmPasswordController,
            label: 'Confirmar contraseña',
            icon: Icons.verified_user_outlined,
            obscureText: true,
            validator: _validateNewPasswordConfirmation,
          ),
          const _InfoBox(
            text:
                'Usa mínimo 8 caracteres. Cuando conectemos backend, este cambio cerrará sesiones sospechosas automáticamente.',
          ),
        ];
      case _SettingsPanel.language:
        return [
          _SettingsDropdown(
            label: 'Idioma preferido',
            icon: Icons.translate,
            value: _language,
            options: const ['Español', 'Português', 'English'],
            onChanged: (value) => setState(() => _language = value),
          ),
          const _InfoBox(
            text:
                'Este dato indica qué idioma hablás o preferís. Por ahora no cambia el idioma completo de la app.',
          ),
          _SettingsDropdown(
            label: 'Región de contenido',
            icon: Icons.travel_explore,
            value: _contentRegion,
            options: const ['Latam', 'Chile', 'Argentina', 'Global'],
            onChanged: (value) => setState(() => _contentRegion = value),
          ),
          _SettingsDropdown(
            label: 'Tema de la app',
            icon: Icons.palette_outlined,
            value: _appTheme,
            options: const ['Sistema', 'Oscuro', 'Claro'],
            onChanged: (value) => setState(() => _appTheme = value),
          ),
        ];
      case _SettingsPanel.location:
        return [
          _ActionRow(
            icon: Icons.my_location_outlined,
            title: 'Usar mi ubicación',
            detail:
                'Pedimos permiso para detectar país o región aproximada. No guardamos coordenadas ni dirección exacta.',
            onTap: _useApproximateLocation,
          ),
          const _InfoBox(
            text:
                'Usamos tu ubicación para sugerirte fans, eventos y comunidades cercanas. Podés ocultarla en tu perfil.',
          ),
          _SettingsTextField(
            key: const ValueKey('settings-location-country'),
            controller: _countryController,
            label: 'País',
            icon: Icons.public,
          ),
          _SettingsTextField(
            key: const ValueKey('settings-location-region'),
            controller: _regionController,
            label: 'Provincia / región / estado',
            icon: Icons.map_outlined,
          ),
          _SettingsTextField(
            key: const ValueKey('settings-location-city'),
            controller: _cityController,
            label: 'Ciudad opcional',
            icon: Icons.location_city_outlined,
          ),
          _ChoiceRow(
            title: 'Visibilidad en mi perfil',
            value: _locationVisibility,
            options: const ['country', 'city', 'hidden'],
            labels: const {
              'country': 'Mostrar país',
              'city': 'Mostrar ciudad',
              'hidden': 'Ocultar ubicación',
            },
            onChanged: (value) => setState(() => _locationVisibility = value),
          ),
        ];
      case _SettingsPanel.editProfile:
        return [
          _SettingsTextField(
            key: const ValueKey('settings-name'),
            controller: _nameController,
            label: 'Nombre visible',
            icon: Icons.badge_outlined,
            validator: (value) => _required(value, 'Ingresa tu nombre'),
          ),
          _SettingsTextField(
            key: const ValueKey('settings-username'),
            controller: _usernameController,
            label: 'Usuario',
            icon: Icons.alternate_email,
            validator: _validateUsername,
          ),
          _SettingsTextField(
            controller: _bioController,
            label: 'Bio',
            icon: Icons.notes_outlined,
            minLines: 2,
            maxLines: 4,
            validator: (value) => _required(value, 'Agrega una bio breve'),
          ),
          _SettingsTextField(
            controller: _fandomController,
            label: 'Fandom principal (opcional)',
            icon: Icons.favorite_border,
          ),
          _SettingsTextField(
            controller: _favoriteGroupController,
            label: 'Grupo favorito (opcional)',
            icon: Icons.album_outlined,
          ),
          _SettingsTextField(
            controller: _biasController,
            label: 'Bias (opcional)',
            icon: Icons.star_border,
          ),
          _SettingsTextField(
            controller: _phraseController,
            label: 'Frase destacada',
            icon: Icons.format_quote,
          ),
          _AvatarPreview(user: widget.user),
        ];
      case _SettingsPanel.storeProfile:
        final store = _storeProfile;
        return [
          _SettingsSwitch(
            title: 'Activar perfil tienda',
            detail:
                'Mostrá una vidriera informativa para ventas, trades o merch. No activa pagos ni checkout.',
            icon: Icons.storefront_outlined,
            value: _storeEnabled,
            onChanged: (value) => setState(() => _storeEnabled = value),
          ),
          if (store != null)
            _StatusCard(
              icon: store.isVerified
                  ? Icons.verified_outlined
                  : Icons.pending_actions_outlined,
              title: store.isVerified
                  ? 'Tienda verificada'
                  : 'Estado: ${store.status.label}',
              detail: _storeStatusDetail(store),
            ),
          const _InfoBox(
            text:
                'El perfil tienda es una presentación. Los pagos, envíos y acuerdos se hacen fuera de HallyuHub por ahora.',
          ),
          _SettingsTextField(
            controller: _storeNameController,
            label: 'Nombre de tienda',
            icon: Icons.storefront_outlined,
            validator: _storeEnabled
                ? (value) => _required(value, 'Agregá el nombre de tu tienda')
                : null,
          ),
          _SettingsTextField(
            controller: _storeDescriptionController,
            label: 'Descripción',
            icon: Icons.notes_outlined,
            minLines: 2,
            maxLines: 4,
          ),
          _SettingsMultiChoiceRow(
            title: 'Categorías',
            values: _storeCategories,
            options: storeCategoryChoices,
            onToggle: (value) => _toggleStoreValue(
              value: value,
              values: _storeCategories,
              onChanged: (next) => setState(() => _storeCategories = next),
            ),
          ),
          _SettingsMultiChoiceRow(
            title: 'Entrega',
            values: _storeDeliveryMethods,
            options: storeDeliveryChoices,
            onToggle: (value) => _toggleStoreValue(
              value: value,
              values: _storeDeliveryMethods,
              onChanged: (next) => setState(() => _storeDeliveryMethods = next),
            ),
          ),
          _SettingsMultiChoiceRow(
            title: 'Métodos de pago informativos',
            values: _storePaymentMethods,
            options: storePaymentChoices,
            onToggle: (value) => _toggleStoreValue(
              value: value,
              values: _storePaymentMethods,
              onChanged: (next) => setState(() => _storePaymentMethods = next),
            ),
          ),
          _SettingsTextField(
            controller: _storeContactController,
            label: 'Link de contacto o tienda',
            icon: Icons.link,
            keyboardType: TextInputType.url,
          ),
          _SettingsTextField(
            controller: _storeInstagramController,
            label: 'Instagram',
            icon: Icons.alternate_email,
          ),
          _SettingsTextField(
            controller: _storeWhatsappController,
            label: 'WhatsApp o contacto',
            icon: Icons.chat_bubble_outline,
          ),
          _SettingsTextField(
            controller: _storeHoursController,
            label: 'Horarios o disponibilidad',
            icon: Icons.schedule_outlined,
            minLines: 2,
            maxLines: 3,
          ),
        ];
      case _SettingsPanel.profileBackground:
        return [
          for (final background in _profileBackgrounds)
            _BackgroundOptionTile(
              option: background,
              selected: _profileBackground == background.name,
              onTap: () => setState(() => _profileBackground = background.name),
            ),
        ];
      case _SettingsPanel.privateAccount:
        return [
          _SettingsSwitch(
            title: 'Cuenta privada',
            detail:
                'Solo seguidores aprobados pueden ver publicaciones, historias archivadas y actividad completa.',
            icon: Icons.lock_outline,
            value: _privateProfile,
            onChanged: (value) {
              if (widget.user.isTeen) return;
              setState(() => _privateProfile = value);
            },
          ),
          const _InfoBox(
            text:
                'Tu nombre, usuario y foto básica pueden seguir visibles para que otros fans puedan solicitar seguirte. Las cuentas de 16–17 son privadas por defecto.',
          ),
        ];
      case _SettingsPanel.messagePrivacy:
        return [
          _ChoiceRow(
            title: 'Quién puede escribirme',
            value: _messagePrivacy,
            options: widget.user.isTeen
                ? const ['Seguidores', 'Nadie']
                : const ['Todos', 'Seguidores', 'Nadie'],
            onChanged: (value) => setState(() => _messagePrivacy = value),
          ),
          const _InfoBox(
            text:
                'Las solicitudes filtradas quedan en bandeja separada y pueden reportarse antes de aceptar conversación.',
          ),
        ];
      case _SettingsPanel.storyPrivacy:
        return [
          _ChoiceRow(
            title: 'Quién puede ver mis historias',
            value: _storyPrivacy,
            options: widget.user.isTeen
                ? const ['Seguidores', 'Privado']
                : const ['Todos', 'Seguidores', 'Privado'],
            onChanged: (value) => setState(() => _storyPrivacy = value),
          ),
          const _InfoBox(
            text:
                'Las historias privadas no aparecen en exploración ni en recomendaciones públicas.',
          ),
        ];
      case _SettingsPanel.blockedUsers:
        return [
          if (_blockedUsers.isEmpty)
            const _InfoBox(text: 'No tenés usuarios bloqueados.')
          else
            for (final handle in _blockedUsers)
              _BlockedUserRow(
                handle: handle,
                onUnblock: () => setState(() => _blockedUsers.remove(handle)),
              ),
          Row(
            children: [
              Expanded(
                child: _SettingsTextField(
                  controller: _blockedUserController,
                  label: 'Usuario a bloquear',
                  icon: Icons.block,
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                onPressed: _addBlockedUser,
                icon: const Icon(Icons.add),
                tooltip: 'Bloquear usuario',
              ),
            ],
          ),
        ];
      case _SettingsPanel.notifMessages:
        return _notificationChildren(
          title: 'Mensajes y solicitudes',
          detail: 'DM, solicitudes nuevas y respuestas importantes.',
          value: _notifyMessages,
          onChanged: (value) => setState(() => _notifyMessages = value),
        );
      case _SettingsPanel.notifStars:
        return _notificationChildren(
          title: 'Estrellas y reacciones',
          detail: 'Likes, estrellas, guardados y actividad destacada.',
          value: _notifyStars,
          onChanged: (value) => setState(() => _notifyStars = value),
        );
      case _SettingsPanel.notifComments:
        return _notificationChildren(
          title: 'Comentarios',
          detail: 'Respuestas, menciones y comentarios fijados.',
          value: _notifyComments,
          onChanged: (value) => setState(() => _notifyComments = value),
        );
      case _SettingsPanel.notifFollowers:
        return _notificationChildren(
          title: 'Seguidores',
          detail: 'Nuevos fans, solicitudes y perfiles sugeridos.',
          value: _notifyFollowers,
          onChanged: (value) => setState(() => _notifyFollowers = value),
        );
      case _SettingsPanel.notifDrops:
        return _notificationChildren(
          title: 'Drops y eventos',
          detail: 'Challenges, eventos cerca y tendencias fandom.',
          value: _notifyDrops,
          onChanged: (value) => setState(() => _notifyDrops = value),
        );
      case _SettingsPanel.accountVerification:
        return [
          _StatusCard(
            icon: Icons.verified_user_outlined,
            title: _verificationRequested
                ? 'Solicitud enviada'
                : 'Cuenta sin verificar',
            detail: _verificationRequested
                ? 'Vamos a revisar identidad, actividad y señales de confianza.'
                : 'La verificación ayuda a destacar comunidades, creators y organizadores confiables.',
          ),
          _ActionRow(
            icon: Icons.workspace_premium_outlined,
            title: 'Solicitar revisión',
            detail: 'Enviar perfil a revisión de confianza.',
            onTap: () {
              setState(() {
                _verificationRequested = true;
                _savedMessage = 'Solicitud de verificación enviada';
              });
              _saveUser('Solicitud de verificación enviada');
            },
          ),
        ];
      case _SettingsPanel.activeSessions:
        return [
          const _DeviceRow(
            title: 'iPhone actual',
            detail: 'Sesión activa · este dispositivo',
            current: true,
          ),
          const _DeviceRow(
            title: 'Web local',
            detail: 'Último acceso reciente',
          ),
          _SettingsSwitch(
            title: 'Alertas de inicio de sesión',
            detail: 'Avisar cuando se detecte un nuevo dispositivo.',
            icon: Icons.notification_important_outlined,
            value: _loginAlerts,
            onChanged: (value) => setState(() => _loginAlerts = value),
          ),
          _SettingsSwitch(
            title: 'Verificación en dos pasos',
            detail: 'Pedir un segundo factor al iniciar sesión.',
            icon: Icons.security,
            value: _twoFactorEnabled,
            onChanged: (value) => setState(() => _twoFactorEnabled = value),
          ),
        ];
      case _SettingsPanel.reportProblem:
        return [
          const _InfoBox(
            text:
                'Estás participando en el acceso anticipado de HallyuHub. Si encontrás errores como videos sin sonido, problemas de carga o funciones que no responden, reportalos acá. También podés contactarnos en $supportEmail.',
          ),
          _ChoiceRow(
            title: 'Tipo de problema',
            value: _reportCategory,
            options: feedbackProblemTypes.map((choice) => choice.key).toList(),
            labels: {
              for (final choice in feedbackProblemTypes)
                choice.key: choice.label,
            },
            onChanged: (value) => setState(() => _reportCategory = value),
          ),
          _ChoiceRow(
            title: 'Pantalla donde pasó',
            value: _reportScreen,
            options: feedbackScreens.map((choice) => choice.key).toList(),
            labels: {
              for (final choice in feedbackScreens) choice.key: choice.label,
            },
            onChanged: (value) => setState(() => _reportScreen = value),
          ),
          _SettingsTextField(
            controller: _reportController,
            label: 'Describe el problema',
            icon: Icons.report_problem_outlined,
            minLines: 3,
            maxLines: 5,
            validator: (value) => _required(value, 'Contanos qué está pasando'),
          ),
          ..._feedbackAttachmentRows(),
        ];
      case _SettingsPanel.sendSuggestion:
        return [
          const _InfoBox(
            text:
                'Contanos una idea concreta para mejorar HallyuHub. También podés adjuntar una captura si ayuda a entenderla o escribirnos a $supportEmail.',
          ),
          _SettingsTextField(
            controller: _reportController,
            label: 'Tu sugerencia',
            icon: Icons.lightbulb_outline,
            minLines: 3,
            maxLines: 5,
            validator: (value) => _required(value, 'Escribí tu sugerencia'),
          ),
          ..._feedbackAttachmentRows(),
        ];
      case _SettingsPanel.plus:
        return [
          const _StatusCard(
            icon: Icons.auto_awesome,
            title: 'HallyuHub Plus',
            detail:
                'Badges, fondos premium, estadísticas avanzadas, más carpetas de photocards y filtros de fandom.',
          ),
          _ActionRow(
            icon: Icons.workspace_premium_outlined,
            title: 'Activar prueba Plus',
            detail:
                'Guardar interés y preparar checkout cuando conectemos pagos.',
            onTap: () => setState(
              () => _savedMessage = 'Prueba Plus marcada para activar',
            ),
          ),
        ];
      case _SettingsPanel.paymentMethods:
        return [
          const _StatusCard(
            icon: Icons.credit_card,
            title: 'Método principal',
            detail:
                'Todavía no hay método real conectado. Cuando agreguemos pagos, se verá tarjeta, historial y facturación.',
          ),
          _ActionRow(
            icon: Icons.add_card,
            title: 'Agregar método',
            detail: 'Preparar flujo para tarjeta o medio local.',
            onTap: () =>
                setState(() => _savedMessage = 'Método listo para conectar'),
          ),
        ];
      case _SettingsPanel.adminPanel:
        return const [];
      case _SettingsPanel.privacyPolicy:
      case _SettingsPanel.terms:
      case _SettingsPanel.communityRules:
      case _SettingsPanel.betaNotice:
      case _SettingsPanel.legalContact:
      case _SettingsPanel.copyright:
      case _SettingsPanel.fanPolicy:
      case _SettingsPanel.legalModeration:
        final document = _legalDocumentFor(panel);
        return [
          for (final paragraph in document.paragraphs)
            _LegalParagraph(text: paragraph),
        ];
      case _SettingsPanel.deleteAccount:
        return _deletionPanelContent();
      case _SettingsPanel.logout:
        return [
          const _StatusCard(
            icon: Icons.logout,
            title: 'Cerrar sesión',
            detail: 'Esto termina la sesión actual en este dispositivo.',
            danger: true,
          ),
          _ActionRow(
            key: const ValueKey('settings-sign-out'),
            icon: Icons.logout,
            title: 'Cerrar sesión ahora',
            detail: 'Volverás al inicio de sesión.',
            danger: true,
            onTap: _confirmSignOut,
          ),
        ];
    }
  }

  List<Widget> _deletionPanelContent() {
    if (_loadingDeletion) {
      return const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    final request = _deletionRequest;
    if (request == null || request.status == AccountDeletionStatus.canceled) {
      return [
        const _StatusCard(
          icon: Icons.delete_outline,
          title: 'Solicitar eliminación de cuenta',
          detail:
              'La solicitud será revisada y procesada. No elimina la cuenta de forma instantánea.',
          danger: true,
        ),
        _ActionRow(
          icon: Icons.delete_forever,
          title: 'Solicitar eliminación de cuenta',
          detail: 'Acción sensible con revisión de seguridad.',
          danger: true,
          onTap: _confirmDeleteAccount,
        ),
      ];
    }

    final title = switch (request.status) {
      AccountDeletionStatus.pending => 'Solicitud de eliminación pendiente',
      AccountDeletionStatus.inReview => 'Tu solicitud está siendo revisada',
      AccountDeletionStatus.completed =>
        'Tu solicitud de eliminación fue procesada',
      AccountDeletionStatus.canceled => 'Solicitud cancelada',
    };
    final detail = request.status == AccountDeletionStatus.pending
        ? 'Solicitada el ${_formatDeletionDate(request.requestedAt)}.'
        : 'Estado actualizado el ${_formatDeletionDate(request.requestedAt)}.';

    return [
      _StatusCard(
        icon: request.status == AccountDeletionStatus.completed
            ? Icons.check_circle_outline
            : Icons.hourglass_top_outlined,
        title: title,
        detail: detail,
        danger: request.status != AccountDeletionStatus.completed,
      ),
      if (request.canCancel)
        _ActionRow(
          icon: Icons.cancel_outlined,
          title: 'Cancelar solicitud',
          detail: 'La cancelación también se confirma con Supabase.',
          onTap: _confirmCancelDeletion,
        ),
    ];
  }

  String _formatDeletionDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  Widget _panelPrimaryAction(_SettingsPanel panel) {
    if (panel == _SettingsPanel.logout) {
      return const SizedBox.shrink();
    }
    if (panel == _SettingsPanel.password) {
      return _PrimaryActionButton(
        label: 'Actualizar contraseña',
        icon: Icons.lock_reset,
        onPressed: _savePassword,
      );
    }
    if (panel == _SettingsPanel.reportProblem ||
        panel == _SettingsPanel.sendSuggestion) {
      return _PrimaryActionButton(
        label: _isSubmittingFeedback
            ? 'Enviando...'
            : panel == _SettingsPanel.sendSuggestion
            ? 'Enviar sugerencia'
            : 'Enviar reporte',
        icon: Icons.send,
        onPressed: _isSubmittingFeedback ? () {} : () => _submitFeedback(panel),
      );
    }
    if (_isLegalPanel(panel)) {
      return _PrimaryActionButton(
        label: 'Entendido',
        icon: Icons.check,
        onPressed: _returnToMain,
      );
    }
    if (panel == _SettingsPanel.plus ||
        panel == _SettingsPanel.paymentMethods) {
      return _PrimaryActionButton(
        label: 'Guardar preferencia',
        icon: Icons.check,
        onPressed: () => _saveUser('Preferencia guardada'),
      );
    }
    if (panel == _SettingsPanel.deleteAccount) {
      return const SizedBox.shrink();
    }
    if (panel == _SettingsPanel.privateAccount) {
      return _PrimaryActionButton(
        buttonKey: const ValueKey('settings-save'),
        label: 'Guardar cambios',
        icon: Icons.check,
        onPressed: () => _savePrivateProfile('Privacidad guardada'),
      );
    }
    if (panel == _SettingsPanel.storeProfile) {
      return _PrimaryActionButton(
        buttonKey: const ValueKey('settings-store-save'),
        label: _savingStoreProfile ? 'Guardando...' : 'Guardar perfil tienda',
        icon: Icons.storefront_outlined,
        onPressed: _savingStoreProfile ? () {} : _saveStoreProfile,
      );
    }
    return _PrimaryActionButton(
      buttonKey: const ValueKey('settings-save'),
      label: 'Guardar cambios',
      icon: Icons.check,
      onPressed: () => _saveUser('Cambios guardados'),
    );
  }

  List<Widget> _feedbackAttachmentRows() {
    final attachment = _reportAttachment;
    final detail = attachment == null
        ? 'Podés adjuntar una captura o un video corto para que podamos reproducir el problema.'
        : '${attachment.fileName} · ${(attachment.bytes.lengthInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return [
      _ActionRow(
        icon: Icons.image_outlined,
        title: attachment == null ? 'Adjuntar captura' : 'Adjunto seleccionado',
        detail: detail,
        onTap: () => _pickFeedbackAttachment(video: false),
      ),
      _ActionRow(
        icon: Icons.video_file_outlined,
        title: 'Adjuntar video corto',
        detail:
            'Ideal para errores de audio, carga, uploads o pantallas trabadas.',
        onTap: () => _pickFeedbackAttachment(video: true),
      ),
      if (attachment != null)
        _ActionRow(
          icon: Icons.close_rounded,
          title: 'Quitar adjunto',
          detail: 'Enviar el reporte sin archivo.',
          onTap: () => setState(() => _reportAttachment = null),
          danger: true,
        ),
    ];
  }

  List<Widget> _notificationChildren({
    required String title,
    required String detail,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return [
      _SettingsSwitch(
        title: title,
        detail: detail,
        icon: Icons.notifications_active_outlined,
        value: value,
        onChanged: onChanged,
      ),
      const _InfoBox(
        text:
            'Más adelante podremos separar push, email y resumen semanal. Por ahora esta opción controla la preferencia principal.',
      ),
    ];
  }

  String _panelValue(_SettingsPanel panel) {
    switch (panel) {
      case _SettingsPanel.personalData:
        return widget.user.email;
      case _SettingsPanel.password:
        return 'Seguridad de acceso';
      case _SettingsPanel.language:
        return _contentRegion.trim().isEmpty
            ? 'Preferido: $_language'
            : 'Preferido: $_language · $_contentRegion';
      case _SettingsPanel.location:
        return widget.user.publicLocationLabel;
      case _SettingsPanel.editProfile:
        return widget.user.username;
      case _SettingsPanel.storeProfile:
        if (_storeProfile == null) return 'Cuenta fan';
        return _storeProfile!.isVerified
            ? '${_storeProfile!.status.label} · Verificada'
            : _storeProfile!.status.label;
      case _SettingsPanel.profileBackground:
        return _profileBackground;
      case _SettingsPanel.privateAccount:
        return _privateProfile ? 'Privada' : 'Pública';
      case _SettingsPanel.messagePrivacy:
        return _messagePrivacy;
      case _SettingsPanel.storyPrivacy:
        return _storyPrivacy;
      case _SettingsPanel.blockedUsers:
        return '${_blockedUsers.length} bloqueados';
      case _SettingsPanel.notifMessages:
        return _notifyMessages ? 'Activo' : 'Pausado';
      case _SettingsPanel.notifStars:
        return _notifyStars ? 'Activo' : 'Pausado';
      case _SettingsPanel.notifComments:
        return _notifyComments ? 'Activo' : 'Pausado';
      case _SettingsPanel.notifFollowers:
        return _notifyFollowers ? 'Activo' : 'Pausado';
      case _SettingsPanel.notifDrops:
        return _notifyDrops ? 'Activo' : 'Pausado';
      case _SettingsPanel.accountVerification:
        return _verificationRequested ? 'En revisión' : 'Sin verificar';
      case _SettingsPanel.activeSessions:
        return '2 sesiones';
      case _SettingsPanel.reportProblem:
        return 'Acceso anticipado';
      case _SettingsPanel.sendSuggestion:
        return 'Ideas';
      case _SettingsPanel.plus:
        return 'Plan gratuito';
      case _SettingsPanel.paymentMethods:
        return 'Sin método';
      case _SettingsPanel.adminPanel:
        return 'Acceso autorizado';
      case _SettingsPanel.privacyPolicy:
      case _SettingsPanel.terms:
      case _SettingsPanel.communityRules:
      case _SettingsPanel.betaNotice:
      case _SettingsPanel.legalContact:
      case _SettingsPanel.copyright:
      case _SettingsPanel.fanPolicy:
      case _SettingsPanel.legalModeration:
        return 'Documento';
      case _SettingsPanel.deleteAccount:
        return 'Acción sensible';
      case _SettingsPanel.logout:
        return 'Salir';
    }
  }
}

class _SettingsTopBar extends StatelessWidget {
  const _SettingsTopBar({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver',
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountHero extends StatelessWidget {
  const _AccountHero({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.rose.withValues(alpha: 0.22),
            AppTheme.cyan.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          HubAvatar(asset: user.avatarAsset, size: 68, isLive: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${user.username} · ${user.publicLocationLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniBadge(
                      label: user.fandom.trim().isEmpty
                          ? 'Agregar fandom'
                          : user.fandom,
                    ),
                    _MiniBadge(label: user.profileBackground),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.night.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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

class _SettingsHomeSection extends StatelessWidget {
  const _SettingsHomeSection({
    required this.title,
    required this.detail,
    required this.items,
    required this.valueForPanel,
    required this.onOpen,
  });

  final String title;
  final String detail;
  final List<_SettingsItemData> items;
  final String Function(_SettingsPanel panel) valueForPanel;
  final ValueChanged<_SettingsPanel> onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF10182A),
            AppTheme.violet.withValues(alpha: 0.11),
            const Color(0xFF090E1B),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.violet.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.violet.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              height: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          for (final item in items) ...[
            _SettingsMenuTile(
              item: item,
              value: valueForPanel(item.panel),
              onTap: () => onOpen(item.panel),
            ),
            if (item != items.last) const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }
}

class _SettingsMenuTile extends StatelessWidget {
  const _SettingsMenuTile({
    required this.item,
    required this.value,
    required this.onTap,
  });

  final _SettingsItemData item;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('settings-item-${item.panel.name}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.night.withValues(alpha: 0.26),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: item.danger
                    ? AppTheme.rose.withValues(alpha: 0.13)
                    : AppTheme.cyan.withValues(alpha: 0.13),
              ),
              child: Icon(
                item.icon,
                color: item.danger ? const Color(0xFFFFB7C8) : AppTheme.cyan,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      color: item.danger
                          ? const Color(0xFFFFB7C8)
                          : Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.56),
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 112),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.58),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsDetailCard extends StatelessWidget {
  const _SettingsDetailCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final child in children) ...[
            child,
            if (child != children.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _SaveNotice extends StatelessWidget {
  const _SaveNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cyan.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: AppTheme.cyan),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTextField extends StatelessWidget {
  const _SettingsTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.minLines = 1,
    this.maxLines = 1,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final int minLines;
  final int maxLines;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.09)),
    );

    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      minLines: obscureText ? 1 : minLines,
      maxLines: obscureText ? 1 : maxLines,
      obscureText: obscureText,
      cursorColor: AppTheme.cyan,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFF0C1323),
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        prefixIconColor: AppTheme.cyan.withValues(alpha: 0.82),
        errorStyle: const TextStyle(
          color: Color(0xFFFFB7C8),
          fontWeight: FontWeight.w800,
        ),
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppTheme.cyan, width: 1.3),
        ),
        errorBorder: border.copyWith(
          borderSide: const BorderSide(color: AppTheme.rose),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: const BorderSide(color: AppTheme.rose, width: 1.3),
        ),
      ),
    );
  }
}

class _SettingsDropdown extends StatelessWidget {
  const _SettingsDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.09)),
    );

    final selectedValue = options.contains(value) ? value : null;

    return DropdownButtonFormField<String>(
      initialValue: selectedValue,
      hint: Text(
        'Sin definir',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.56),
          fontWeight: FontWeight.w800,
        ),
      ),
      dropdownColor: AppTheme.nightSoft,
      iconEnabledColor: Colors.white70,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFF0C1323),
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        prefixIconColor: AppTheme.cyan.withValues(alpha: 0.82),
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppTheme.cyan, width: 1.3),
        ),
      ),
      items: options
          .map((option) => DropdownMenuItem(value: option, child: Text(option)))
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({
    required this.title,
    required this.detail,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String detail;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsRowFrame(
      icon: icon,
      title: title,
      detail: detail,
      trailing: Switch(
        value: value,
        activeThumbColor: AppTheme.rose,
        onChanged: onChanged,
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    this.labels = const {},
  });

  final String title;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final Map<String, String> labels;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.night.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final selected = option == value;
              return InkWell(
                onTap: () => onChanged(option),
                borderRadius: BorderRadius.circular(999),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? const LinearGradient(
                            colors: [AppTheme.rose, AppTheme.violet],
                          )
                        : null,
                    color: selected
                        ? null
                        : Colors.white.withValues(alpha: 0.075),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.34)
                          : Colors.white.withValues(alpha: 0.13),
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppTheme.rose.withValues(alpha: 0.22),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selected) ...[
                        const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        labels[option] ?? option,
                        style: TextStyle(
                          color: Colors.white.withValues(
                            alpha: selected ? 1 : 0.82,
                          ),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _SettingsMultiChoiceRow extends StatelessWidget {
  const _SettingsMultiChoiceRow({
    required this.title,
    required this.values,
    required this.options,
    required this.onToggle,
  });

  final String title;
  final List<String> values;
  final List<String> options;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.night.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                _MiniChoiceChip(
                  label: storeOptionLabel(option),
                  selected: values.contains(option),
                  onTap: () => onToggle(option),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniChoiceChip extends StatelessWidget {
  const _MiniChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [AppTheme.rose, AppTheme.violet])
              : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.075),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.34)
                : Colors.white.withValues(alpha: 0.13),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check_rounded, color: Colors.white, size: 15),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: selected ? 1 : 0.82),
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: _SettingsRowFrame(
        icon: icon,
        title: title,
        detail: detail,
        danger: danger,
        trailing: Icon(
          Icons.chevron_right,
          color: Colors.white.withValues(alpha: 0.48),
        ),
      ),
    );
  }
}

class _SettingsRowFrame extends StatelessWidget {
  const _SettingsRowFrame({
    required this.icon,
    required this.title,
    required this.detail,
    required this.trailing,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Widget trailing;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? AppTheme.rose : AppTheme.cyan;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.night.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: accent.withValues(alpha: 0.14),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: danger ? const Color(0xFFFFB7C8) : Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    this.buttonKey,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final Key? buttonKey;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: buttonKey,
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: AppTheme.rose,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.74),
          height: 1.35,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    return _SettingsRowFrame(
      icon: Icons.face_retouching_natural,
      title: 'Avatar actual',
      detail: 'La carga de foto real se conectará con el backend de media.',
      trailing: HubAvatar(asset: user.avatarAsset, size: 42, isLive: true),
    );
  }
}

class _BackgroundOptionTile extends StatelessWidget {
  const _BackgroundOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _ProfileBackgroundData option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AppTheme.cyan.withValues(alpha: 0.58)
                : Colors.white.withValues(alpha: 0.1),
          ),
          color: Colors.white.withValues(alpha: selected ? 0.1 : 0.06),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(colors: option.colors),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    option.detail,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.58),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle, color: AppTheme.cyan),
          ],
        ),
      ),
    );
  }
}

class _BlockedUserRow extends StatelessWidget {
  const _BlockedUserRow({required this.handle, required this.onUnblock});

  final String handle;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    return _SettingsRowFrame(
      icon: Icons.block,
      title: handle,
      detail: 'No puede escribirte, ver historias privadas ni interactuar.',
      trailing: TextButton(
        onPressed: onUnblock,
        child: const Text(
          'Desbloquear',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.title,
    required this.detail,
    this.current = false,
  });

  final String title;
  final String detail;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return _SettingsRowFrame(
      icon: current ? Icons.phone_iphone : Icons.language,
      title: title,
      detail: detail,
      trailing: current
          ? const _MiniBadge(label: 'Actual')
          : TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Sesión cerrada en el dispositivo'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
              },
              child: const Text(
                'Cerrar',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.title,
    required this.detail,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return _SettingsRowFrame(
      icon: icon,
      title: title,
      detail: detail,
      danger: danger,
      trailing: const SizedBox(width: 1),
    );
  }
}

class _LegalParagraph extends StatelessWidget {
  const _LegalParagraph({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.night.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.78),
          height: 1.35,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ConfirmActionSheet extends StatelessWidget {
  const _ConfirmActionSheet({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onConfirm,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
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
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onConfirm,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: AppTheme.rose,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancelar',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsGroupData {
  const _SettingsGroupData({
    required this.title,
    required this.detail,
    required this.items,
  });

  final String title;
  final String detail;
  final List<_SettingsItemData> items;
}

class _SettingsItemData {
  const _SettingsItemData({
    required this.panel,
    required this.title,
    required this.detail,
    required this.icon,
    this.danger = false,
  });

  final _SettingsPanel panel;
  final String title;
  final String detail;
  final IconData icon;
  final bool danger;
}

class _ProfileBackgroundData {
  const _ProfileBackgroundData({
    required this.name,
    required this.detail,
    required this.colors,
  });

  final String name;
  final String detail;
  final List<Color> colors;
}

const _profileBackgrounds = [
  _ProfileBackgroundData(
    name: 'Pastel neon',
    detail: 'Rosa suave, cyan y brillo social.',
    colors: [Color(0xFFEF4F7A), Color(0xFF65E4FF)],
  ),
  _ProfileBackgroundData(
    name: 'Stage violet',
    detail: 'Luces de escenario y fandom night.',
    colors: [Color(0xFF4C6FFF), Color(0xFFA855F7)],
  ),
  _ProfileBackgroundData(
    name: 'Lightstick cyan',
    detail: 'Oscuro elegante con acento eléctrico.',
    colors: [Color(0xFF07181C), Color(0xFF65E4FF)],
  ),
  _ProfileBackgroundData(
    name: 'Comeback rose',
    detail: 'Visual cálido para eras y moodboards.',
    colors: [Color(0xFFEF4F7A), Color(0xFFFFB703)],
  ),
  _ProfileBackgroundData(
    name: 'Midnight aurora',
    detail: 'Perfil premium oscuro con aura sutil.',
    colors: [Color(0xFF080311), Color(0xFF00A6A6)],
  ),
];

const _settingsGroups = [
  _SettingsGroupData(
    title: 'Cuenta',
    detail: 'Acceso, datos privados e idioma.',
    items: [
      _SettingsItemData(
        panel: _SettingsPanel.personalData,
        title: 'Datos personales',
        detail: 'Email, teléfono y país.',
        icon: Icons.badge_outlined,
      ),
      _SettingsItemData(
        panel: _SettingsPanel.password,
        title: 'Contraseña',
        detail: 'Seguridad de acceso.',
        icon: Icons.password,
      ),
      _SettingsItemData(
        panel: _SettingsPanel.language,
        title: 'Idioma preferido',
        detail: 'Dato de perfil, región de contenido y tema.',
        icon: Icons.translate,
      ),
      _SettingsItemData(
        panel: _SettingsPanel.location,
        title: 'Ubicación',
        detail: 'País, región, ciudad y visibilidad.',
        icon: Icons.location_on_outlined,
      ),
    ],
  ),
  _SettingsGroupData(
    title: 'Perfil',
    detail: 'Tu identidad pública dentro de HallyuHub.',
    items: [
      _SettingsItemData(
        panel: _SettingsPanel.editProfile,
        title: 'Editar perfil',
        detail: 'Nombre, usuario, avatar, bio y fandom.',
        icon: Icons.person_outline,
      ),
      _SettingsItemData(
        panel: _SettingsPanel.storeProfile,
        title: 'Tipo de cuenta / Perfil tienda',
        detail: 'Solicitar tienda, pausar o actualizar vidriera.',
        icon: Icons.storefront_outlined,
      ),
      _SettingsItemData(
        panel: _SettingsPanel.profileBackground,
        title: 'Fondo de perfil',
        detail: 'Estilo visual, comeback y lightstick.',
        icon: Icons.wallpaper_outlined,
      ),
    ],
  ),
  _SettingsGroupData(
    title: 'Privacidad',
    detail: 'Control de visibilidad, mensajes e historias.',
    items: [
      _SettingsItemData(
        panel: _SettingsPanel.privateAccount,
        title: 'Cuenta privada',
        detail: 'Controla quién puede ver tu perfil completo.',
        icon: Icons.lock_outline,
      ),
      _SettingsItemData(
        panel: _SettingsPanel.messagePrivacy,
        title: 'Quién puede escribirme',
        detail: 'DM, solicitudes y permisos.',
        icon: Icons.mark_chat_unread_outlined,
      ),
      _SettingsItemData(
        panel: _SettingsPanel.storyPrivacy,
        title: 'Quién puede ver mis historias',
        detail: 'Público, seguidores o privado.',
        icon: Icons.auto_stories_outlined,
      ),
      _SettingsItemData(
        panel: _SettingsPanel.blockedUsers,
        title: 'Usuarios bloqueados',
        detail: 'Ver y administrar bloqueos.',
        icon: Icons.block,
      ),
    ],
  ),
  _SettingsGroupData(
    title: 'Notificaciones',
    detail: 'Elige qué actividad merece avisarte.',
    items: [
      _SettingsItemData(
        panel: _SettingsPanel.notifMessages,
        title: 'Mensajes',
        detail: 'DM y solicitudes.',
        icon: Icons.mail_outline,
      ),
      _SettingsItemData(
        panel: _SettingsPanel.notifStars,
        title: 'Estrellas',
        detail: 'Likes, reacciones y guardados.',
        icon: Icons.star_border,
      ),
      _SettingsItemData(
        panel: _SettingsPanel.notifComments,
        title: 'Comentarios',
        detail: 'Respuestas y menciones.',
        icon: Icons.mode_comment_outlined,
      ),
      _SettingsItemData(
        panel: _SettingsPanel.notifFollowers,
        title: 'Seguidores',
        detail: 'Nuevos fans y solicitudes.',
        icon: Icons.group_add_outlined,
      ),
      _SettingsItemData(
        panel: _SettingsPanel.notifDrops,
        title: 'Drops',
        detail: 'Challenges y eventos cercanos.',
        icon: Icons.play_circle_outline,
      ),
    ],
  ),
  _SettingsGroupData(
    title: 'Seguridad',
    detail: 'Confianza, sesiones y protección de cuenta.',
    items: [
      _SettingsItemData(
        panel: _SettingsPanel.accountVerification,
        title: 'Verificación de cuenta',
        detail: 'Estado y señales de confianza.',
        icon: Icons.verified_user_outlined,
      ),
      _SettingsItemData(
        panel: _SettingsPanel.activeSessions,
        title: 'Sesiones activas',
        detail: 'Dispositivos conectados.',
        icon: Icons.devices_outlined,
      ),
    ],
  ),
  _SettingsGroupData(
    title: 'Soporte',
    detail: 'Ayuda, plan y pagos.',
    items: [
      _SettingsItemData(
        panel: _SettingsPanel.reportProblem,
        title: 'Reportar problema',
        detail: 'Videos, uploads, login, mensajes o errores.',
        icon: Icons.report_problem_outlined,
      ),
      _SettingsItemData(
        panel: _SettingsPanel.sendSuggestion,
        title: 'Enviar sugerencia',
        detail: 'Ideas para mejorar el acceso anticipado.',
        icon: Icons.lightbulb_outline,
      ),
      _SettingsItemData(
        panel: _SettingsPanel.plus,
        title: 'HallyuHub Plus',
        detail: 'Badges, fondos y estadísticas.',
        icon: Icons.auto_awesome,
      ),
      _SettingsItemData(
        panel: _SettingsPanel.paymentMethods,
        title: 'Métodos de pago',
        detail: 'Tarjetas y facturación.',
        icon: Icons.credit_card,
      ),
    ],
  ),
  _SettingsGroupData(
    title: 'Legal',
    detail: 'Documentos base para operar como producto real.',
    items: [
      _SettingsItemData(
        panel: _SettingsPanel.privacyPolicy,
        title: 'Política de privacidad',
        detail: 'Uso de datos y seguridad.',
        icon: Icons.privacy_tip_outlined,
      ),
      _SettingsItemData(
        panel: _SettingsPanel.terms,
        title: 'Términos y condiciones',
        detail: 'Reglas de uso.',
        icon: Icons.description_outlined,
      ),
      _SettingsItemData(
        panel: _SettingsPanel.communityRules,
        title: 'Normas de comunidad',
        detail: 'Convivencia fandom.',
        icon: Icons.groups_2_outlined,
      ),
      _SettingsItemData(
        panel: _SettingsPanel.betaNotice,
        title: 'Aviso de acceso anticipado',
        detail: 'Información sobre esta primera etapa.',
        icon: Icons.science_outlined,
      ),
      _SettingsItemData(
        panel: _SettingsPanel.legalContact,
        title: 'Contacto legal y soporte',
        detail: 'Reportes, privacidad y ayuda.',
        icon: Icons.support_agent_outlined,
      ),
      _SettingsItemData(
        panel: _SettingsPanel.copyright,
        title: 'Copyright',
        detail: 'Derechos de autor.',
        icon: Icons.copyright,
      ),
      _SettingsItemData(
        panel: _SettingsPanel.fanPolicy,
        title: 'Política de contenido fan',
        detail: 'UGC, edits y fancams.',
        icon: Icons.movie_filter_outlined,
      ),
      _SettingsItemData(
        panel: _SettingsPanel.legalModeration,
        title: 'Moderación legal',
        detail: 'Reportes y acciones de seguridad.',
        icon: Icons.gavel_outlined,
      ),
      _SettingsItemData(
        panel: _SettingsPanel.deleteAccount,
        title: 'Eliminar cuenta',
        detail: 'Baja de cuenta y datos.',
        icon: Icons.delete_outline,
        danger: true,
      ),
    ],
  ),
  _SettingsGroupData(
    title: 'Sesión',
    detail: 'Salida del dispositivo actual.',
    items: [
      _SettingsItemData(
        panel: _SettingsPanel.logout,
        title: 'Cerrar sesión',
        detail: 'Salir de HallyuHub.',
        icon: Icons.logout,
        danger: true,
      ),
    ],
  ),
];

String _panelTitle(_SettingsPanel panel) {
  return _settingsGroups
      .expand((group) => group.items)
      .firstWhere((item) => item.panel == panel)
      .title;
}

String _panelSubtitle(_SettingsPanel panel) {
  return _settingsGroups
      .expand((group) => group.items)
      .firstWhere((item) => item.panel == panel)
      .detail;
}

bool _isLegalPanel(_SettingsPanel panel) {
  return {
    _SettingsPanel.privacyPolicy,
    _SettingsPanel.terms,
    _SettingsPanel.communityRules,
    _SettingsPanel.betaNotice,
    _SettingsPanel.legalContact,
    _SettingsPanel.copyright,
    _SettingsPanel.fanPolicy,
    _SettingsPanel.legalModeration,
  }.contains(panel);
}

LegalDocument _legalDocumentFor(_SettingsPanel panel) {
  switch (panel) {
    case _SettingsPanel.privacyPolicy:
      return legalPrivacyDocument;
    case _SettingsPanel.terms:
      return legalTermsDocument;
    case _SettingsPanel.communityRules:
      return legalCommunityGuidelinesDocument;
    case _SettingsPanel.betaNotice:
      return legalBetaNoticeDocument;
    case _SettingsPanel.legalContact:
      return legalContactDocument;
    case _SettingsPanel.copyright:
      return legalCopyrightDocument;
    case _SettingsPanel.fanPolicy:
      return legalFanPolicyDocument;
    case _SettingsPanel.legalModeration:
      return legalModerationDocument;
    default:
      return const LegalDocument(
        id: 'pending',
        title: 'Documento',
        subtitle: 'Información legal',
        paragraphs: ['Documento pendiente.'],
      );
  }
}
