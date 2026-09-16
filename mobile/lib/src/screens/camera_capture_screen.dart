import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/media_permission_service.dart';
import '../theme/app_theme.dart';

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({
    super.key,
    required this.recordVideo,
    this.unifiedCapture = false,
    this.onGallery,
    this.permissionService = const MediaPermissionService(),
  });

  final bool recordVideo;
  final bool unifiedCapture;
  final Future<XFile?> Function()? onGallery;
  final MediaPermissionService permissionService;

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCamera = 0;
  bool _isBusy = false;
  bool _isRecording = false;
  String? _error;
  bool _showSettings = false;
  bool _permissionConfirmed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restorePermission();
  }

  Future<void> _restorePermission() async {
    final access = await widget.permissionService.cameraStatus(
      microphone: widget.recordVideo || widget.unifiedCapture,
    );
    if (!mounted || access != MediaAccessResult.ready) return;
    setState(() => _permissionConfirmed = true);
    await _prepareCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed && _permissionConfirmed) {
      _prepareCamera(selectedCamera: _selectedCamera);
    }
  }

  Future<void> _prepareCamera({int selectedCamera = 0}) async {
    setState(() {
      _error = null;
      _isBusy = true;
      _showSettings = false;
    });
    try {
      final access = await widget.permissionService.requestCameraAccess(
        microphone: widget.recordVideo || widget.unifiedCapture,
      );
      if (access != MediaAccessResult.ready) {
        if (!mounted) return;
        setState(() {
          _error = switch (access) {
            MediaAccessResult.restricted =>
              'La cámara tiene una restricción del dispositivo.',
            MediaAccessResult.denied || MediaAccessResult.settingsRequired =>
              'Necesitamos permiso para usar la cámara.',
            _ => 'No encontramos una cámara disponible.',
          };
          _showSettings =
              access == MediaAccessResult.denied ||
              access == MediaAccessResult.settingsRequired;
          _isBusy = false;
        });
        return;
      }
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw CameraException(
          'cameraUnavailable',
          'No encontramos una cámara disponible.',
        );
      }
      _selectedCamera = selectedCamera.clamp(0, _cameras.length - 1);
      final previousController = _controller;
      final nextController = CameraController(
        _cameras[_selectedCamera],
        ResolutionPreset.high,
        enableAudio: widget.recordVideo || widget.unifiedCapture,
      );
      _controller = nextController;
      await previousController?.dispose();
      await nextController.initialize();
      if (!mounted) return;
      setState(() => _isBusy = false);
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.code == 'CameraAccessDenied'
            ? 'Necesitamos permiso para usar la cámara.'
            : 'No pudimos abrir la cámara en este dispositivo.';
        _showSettings =
            error.code == 'CameraAccessDenied' ||
            error.code == 'CameraAccessDeniedWithoutPrompt';
        _isBusy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos abrir la cámara en este dispositivo.';
        _isBusy = false;
      });
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2 || _isBusy || _isRecording) return;
    final nextCamera = (_selectedCamera + 1) % _cameras.length;
    await _prepareCamera(selectedCamera: nextCamera);
  }

  Future<void> _capture() async {
    if (widget.unifiedCapture) {
      await _takePhoto();
      return;
    }
    if (widget.recordVideo) {
      if (_isRecording) {
        await _stopVideoRecording();
      } else {
        await _startVideoRecording();
      }
      return;
    }
    await _takePhoto();
  }

  Future<void> _takePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isBusy) {
      return;
    }
    setState(() => _isBusy = true);
    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(file);
    } on CameraException {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos guardar la captura. Intentá nuevamente.';
        _isBusy = false;
      });
    }
  }

  Future<void> _startVideoRecording() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isBusy ||
        _isRecording) {
      return;
    }
    setState(() => _isBusy = true);
    try {
      await controller.startVideoRecording();
      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _isBusy = false;
      });
    } on CameraException {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos iniciar el video. Intentá nuevamente.';
        _isBusy = false;
      });
    }
  }

  Future<void> _stopVideoRecording() async {
    final controller = _controller;
    if (controller == null || !_isRecording) return;
    setState(() => _isBusy = true);
    try {
      final file = await controller.stopVideoRecording();
      if (!mounted) return;
      Navigator.of(context).pop(file);
    } on CameraException {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos guardar el video. Intentá nuevamente.';
        _isBusy = false;
        _isRecording = false;
      });
    }
  }

  Future<void> _openGallery() async {
    final file = await widget.onGallery?.call();
    if (!mounted || file == null) return;
    Navigator.of(context).pop(file);
  }

  void _showEditorTool(String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$label se aplica después de capturar.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: !_permissionConfirmed
                  ? _CameraPermissionIntro(
                      onAllow: () {
                        setState(() => _permissionConfirmed = true);
                        _prepareCamera();
                      },
                    )
                  : ready
                  ? Center(child: CameraPreview(controller))
                  : _CameraStatus(
                      error: _error,
                      onRetry: _error == null ? null : _prepareCamera,
                      onOpenSettings: _showSettings
                          ? widget.permissionService.openSettings
                          : null,
                    ),
            ),
            Positioned(
              left: 12,
              right: 12,
              top: 10,
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close),
                    color: Colors.white,
                    tooltip: 'Cerrar cámara',
                  ),
                  const Spacer(),
                  Text(
                    widget.unifiedCapture
                        ? 'Cámara HallyuHub'
                        : widget.recordVideo
                        ? 'Grabar video'
                        : 'Tomar foto',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    onPressed: _cameras.length > 1 ? _flipCamera : null,
                    icon: const Icon(Icons.cameraswitch_outlined),
                    color: Colors.white,
                    tooltip: 'Cambiar cámara',
                  ),
                ],
              ),
            ),
            if (ready)
              Positioned(
                left: 0,
                right: 0,
                bottom: 28,
                child: Center(
                  child: Semantics(
                    button: true,
                    label: widget.recordVideo
                        ? (_isRecording ? 'Detener grabación' : 'Grabar video')
                        : 'Tomar foto',
                    child: GestureDetector(
                      key: const ValueKey('camera-capture'),
                      onTap: _isBusy ? null : _capture,
                      onLongPressStart: widget.unifiedCapture && !_isBusy
                          ? (_) => _startVideoRecording()
                          : null,
                      onLongPressEnd: widget.unifiedCapture
                          ? (_) => _stopVideoRecording()
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: _isRecording ? AppTheme.rose : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.7),
                            width: 5,
                          ),
                        ),
                        child: Icon(
                          _isRecording
                              ? Icons.stop_rounded
                              : widget.recordVideo || widget.unifiedCapture
                              ? Icons.videocam_rounded
                              : Icons.camera_alt_rounded,
                          color: _isRecording ? Colors.white : AppTheme.night,
                          size: 34,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (ready && widget.unifiedCapture)
              Positioned(
                left: 12,
                right: 12,
                bottom: 10,
                child: IgnorePointer(
                  child: Text(
                    _isRecording
                        ? 'Soltá para guardar el video'
                        : 'Tocá para foto · mantené para video',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            if (ready && widget.onGallery != null)
              Positioned(
                left: 18,
                bottom: 33,
                child: IconButton.filledTonal(
                  key: const ValueKey('camera-gallery'),
                  onPressed: _isRecording ? null : _openGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  color: Colors.white,
                  tooltip: 'Abrir galería',
                ),
              ),
            if (ready && widget.unifiedCapture)
              Positioned(
                right: 12,
                top: 86,
                child: _CameraToolsRail(onSelected: _showEditorTool),
              ),
          ],
        ),
      ),
    );
  }
}

class _CameraPermissionIntro extends StatelessWidget {
  const _CameraPermissionIntro({required this.onAllow});

  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.photo_camera_outlined,
              color: AppTheme.cyan,
              size: 48,
            ),
            const SizedBox(height: 14),
            const Text(
              'Preparar cámara',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'HallyuHub necesita cámara y micrófono para sacar fotos o grabar videos. El teléfono te pedirá confirmación.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const ValueKey('camera-permission-allow'),
              onPressed: onAllow,
              icon: const Icon(Icons.lock_open_outlined),
              label: const Text('Permitir cámara'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraToolsRail extends StatelessWidget {
  const _CameraToolsRail({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CameraTool(
          icon: Icons.text_fields_rounded,
          label: 'Texto',
          onTap: () => onSelected('Texto'),
        ),
        _CameraTool(
          icon: Icons.emoji_emotions_outlined,
          label: 'Stickers',
          onTap: () => onSelected('Stickers'),
        ),
        _CameraTool(
          icon: Icons.auto_awesome_outlined,
          label: 'Filtros',
          onTap: () => onSelected('Filtros'),
        ),
        _CameraTool(
          icon: Icons.music_note_outlined,
          label: 'Música',
          onTap: () => onSelected('Música'),
        ),
      ],
    );
  }
}

class _CameraTool extends StatelessWidget {
  const _CameraTool({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: IconButton.filledTonal(
        onPressed: onTap,
        icon: Icon(icon),
        color: Colors.white,
        tooltip: label,
      ),
    );
  }
}

class _CameraStatus extends StatelessWidget {
  const _CameraStatus({
    required this.error,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final String? error;
  final VoidCallback? onRetry;
  final Future<bool> Function()? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              error == null
                  ? Icons.photo_camera_outlined
                  : Icons.no_photography_outlined,
              color: Colors.white,
              size: 42,
            ),
            const SizedBox(height: 14),
            Text(
              error ?? 'Preparando cámara...',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Reintentar'),
              ),
            ],
            if (onOpenSettings != null) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const ValueKey('camera-open-settings'),
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Abrir Ajustes'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
