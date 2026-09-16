import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/demo_data.dart';
import '../models.dart';
import '../screens/camera_capture_screen.dart';
import '../services/local_artist_tag_service.dart';
import '../services/local_follow_service.dart';
import '../services/media_upload_limits.dart';
import '../services/media_permission_service.dart';
import '../services/story_audio_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/contextual_permission_sheet.dart';
import '../widgets/editor_tagging_panel.dart';
import '../widgets/hallyu_surface.dart';
import '../widgets/hally_feature_tip.dart';
import '../widgets/artist_tag_selector.dart';
import '../widgets/profile_category_chips.dart';
import '../widgets/story_canvas.dart';
import '../widgets/user_tag_selector.dart';

class PostEditorScreen extends StatefulWidget {
  const PostEditorScreen({
    super.key,
    this.initialDraft = const PostDraft(),
    this.currentUser,
    this.followService = const LocalFollowService(),
    this.artistTagService = const LocalArtistTagService(),
    this.allowDemoMedia = true,
    this.allowEmptyCaptionForNews = false,
  });

  final PostDraft initialDraft;
  final AuthUser? currentUser;
  final LocalFollowService followService;
  final LocalArtistTagService artistTagService;
  final bool allowDemoMedia;
  final bool allowEmptyCaptionForNews;

  @override
  State<PostEditorScreen> createState() => _PostEditorScreenState();
}

class _PostEditorScreenState extends State<PostEditorScreen> {
  final _picker = ImagePicker();
  final _permissionService = const MediaPermissionService();
  final _mediaPageController = PageController();
  final _captionFocusNode = FocusNode();
  late final TextEditingController _captionController;
  late final TextEditingController _tagsController;
  late final TextEditingController _locationController;
  late final TextEditingController _peopleController;
  late final TextEditingController _artistController;
  late PostDraft _draft;
  double? _videoDurationSeconds;
  String? _selectedElementId;
  int _selectedMediaIndex = 0;
  String _captionText = '';
  bool _closingWithPublish = false;
  late Set<ProfileContentCategory> _selectedProfileCategories;
  late List<CommunityProfile> _selectedTaggedUsers;
  late List<KpopEntity> _selectedTaggedEntities;

  static const _stickers = ['✨', '💜', '⭐', '🎧', '📸', '🎀', '💎', '🔥'];
  static const _maxImageBytes = MediaUploadLimits.imageBytes;
  static const _maxVideoBytes = MediaUploadLimits.postVideoBytes;
  static const _maxMediaItems = MediaUploadLimits.maxPostMediaItems;
  static const _maxVideoSeconds = 60.0;
  static const _filterColors = <Color>[
    Colors.transparent,
    Color(0x26EF4F7A),
    Color(0x2439E6E6),
    Color(0x24A855F7),
  ];
  static const _filterNames = <String>[
    'Original',
    'Rose glow',
    'Cyan night',
    'Violet stage',
  ];

  @override
  void initState() {
    super.initState();
    _draft = widget.initialDraft;
    _captionController = TextEditingController(text: _draft.caption);
    _captionText = _draft.caption;
    _tagsController = TextEditingController(text: _draft.tags.join(' '));
    _locationController = TextEditingController(text: _draft.location);
    _peopleController = TextEditingController(
      text: _draft.taggedPeople.join(', '),
    );
    _artistController = TextEditingController(text: _draft.artist);
    _selectedProfileCategories = _draft.profileCategories.toSet();
    _selectedTaggedUsers = _draft.taggedUsers.toList(growable: true);
    _selectedTaggedEntities = _draft.taggedEntities.toList(growable: true);
  }

  @override
  void dispose() {
    _mediaPageController.dispose();
    _captionController.dispose();
    _captionFocusNode.dispose();
    _tagsController.dispose();
    _locationController.dispose();
    _peopleController.dispose();
    _artistController.dispose();
    super.dispose();
  }

  List<PostMediaItem> get _mediaItems => _draft.effectiveMediaItems;

  PostMediaItem? get _selectedMediaItem {
    final items = _mediaItems;
    if (items.isEmpty) return null;
    final index = _selectedMediaIndex.clamp(0, items.length - 1);
    return items[index];
  }

  Future<void> _pickGallery() async {
    final files = await _pickGalleryFiles(
      limit: _maxMediaItems - _mediaItems.length,
    );
    if (files.isEmpty || !mounted) return;
    await _useFiles(files, append: _draft.hasMedia);
  }

  Future<XFile?> _pickGalleryFile() async {
    final allowed = await requestContextualPermission(
      context: context,
      permissionService: _permissionService,
      icon: Icons.photo_library_outlined,
      title: 'Elegir desde tu galería',
      detail:
          'HallyuHub necesita acceso únicamente para que selecciones la foto o video de esta publicación.',
      allowLabel: 'Permitir galería',
      currentStatus: _permissionService.galleryStatus,
      request: _permissionService.requestGalleryAccess,
    );
    if (!allowed || !mounted) return null;
    return _picker.pickMedia(imageQuality: 86, maxWidth: 1440);
  }

  Future<List<XFile>> _pickGalleryFiles({required int limit}) async {
    if (limit <= 0) {
      _showSnack('Podés subir hasta 6 archivos por publicación.');
      return const [];
    }
    final allowed = await requestContextualPermission(
      context: context,
      permissionService: _permissionService,
      icon: Icons.photo_library_outlined,
      title: 'Elegir desde tu galería',
      detail:
          'HallyuHub necesita acceso únicamente para que selecciones las fotos o videos de esta publicación.',
      allowLabel: 'Permitir galería',
      currentStatus: _permissionService.galleryStatus,
      request: _permissionService.requestGalleryAccess,
    );
    if (!allowed || !mounted) return const [];
    try {
      final files = await _picker.pickMultipleMedia(
        imageQuality: 86,
        maxWidth: 1440,
        limit: limit.clamp(1, _maxMediaItems).toInt(),
      );
      return files;
    } catch (_) {
      final fallback = await _picker.pickMedia(
        imageQuality: 86,
        maxWidth: 1440,
      );
      return fallback == null ? const [] : [fallback];
    }
  }

  Future<void> _capture() async {
    final file = await Navigator.of(context).push<XFile>(
      MaterialPageRoute<XFile>(
        fullscreenDialog: true,
        builder: (context) => CameraCaptureScreen(
          recordVideo: false,
          unifiedCapture: true,
          onGallery: _pickGalleryFile,
        ),
      ),
    );
    if (file == null || !mounted) return;
    await _useFile(file);
  }

  Future<void> _useFile(XFile file, {bool? forceVideo}) async {
    final item = await _prepareMediaItem(file, forceVideo: forceVideo);
    if (item == null || !mounted) return;
    setState(() {
      _videoDurationSeconds = null;
      _replaceMediaItems([item], selectedIndex: 0);
    });
  }

  Future<void> _useFiles(List<XFile> files, {required bool append}) async {
    final currentItems = append ? _mediaItems : <PostMediaItem>[];
    final cleanFiles = files
        .where((file) => file.path.trim().isNotEmpty || file.name.isNotEmpty)
        .toList(growable: false);
    if (cleanFiles.isEmpty) return;
    if (currentItems.length + cleanFiles.length > _maxMediaItems) {
      _showSnack('Podés subir hasta 6 archivos por publicación.');
      return;
    }
    final prepared = <PostMediaItem>[];
    for (final file in cleanFiles) {
      final item = await _prepareMediaItem(file);
      if (!mounted || item == null) return;
      prepared.add(item);
    }
    if (prepared.isEmpty || !mounted) return;
    setState(() {
      final nextItems = [...currentItems, ...prepared];
      _videoDurationSeconds = null;
      _selectedElementId = null;
      _replaceMediaItems(
        nextItems,
        selectedIndex: currentItems.length.clamp(0, nextItems.length - 1),
      );
    });
    _animateToSelectedMedia();
  }

  Future<PostMediaItem?> _prepareMediaItem(
    XFile file, {
    bool? forceVideo,
  }) async {
    final video = forceVideo ?? _isVideo(file);
    final fileSizeBytes = await _safeFileSize(file);
    if (video && !_validateVideoFile(file, fileSizeBytes)) return null;
    if (!video && fileSizeBytes != null && fileSizeBytes > _maxImageBytes) {
      _showSnack('La imagen supera el límite de 10 MB.');
      return null;
    }
    Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      _showSnack('No pudimos leer el archivo. Probá con otra foto o video.');
      return null;
    }
    if (!mounted) return null;
    if (!_validatePickedBytes(bytes, video: video)) return null;
    return _mediaItemFromFile(
      file,
      bytes: bytes,
      video: video,
      fileSizeBytes: fileSizeBytes,
    );
  }

  PostMediaItem _mediaItemFromFile(
    XFile file, {
    required Uint8List? bytes,
    required bool video,
    required int? fileSizeBytes,
  }) {
    return PostMediaItem(
      id: 'post-media-${DateTime.now().microsecondsSinceEpoch}',
      type: video ? PostMediaType.video : PostMediaType.image,
      imageBytes: bytes,
      mediaPath: file.path,
      fileName: file.name,
      mimeType: file.mimeType ?? '',
      fileSizeBytes: fileSizeBytes ?? bytes?.lengthInBytes,
      mediaScale: 1,
      mediaOffset: Offset.zero,
      mediaRotation: 0,
      videoTrimEndSeconds: video ? 60 : null,
      videoMuted: true,
    );
  }

  void _replaceMediaItems(List<PostMediaItem> items, {int? selectedIndex}) {
    final nextItems = items.where((item) => item.hasMedia).toList();
    final nextIndex = nextItems.isEmpty
        ? 0
        : (selectedIndex ?? _selectedMediaIndex).clamp(0, nextItems.length - 1);
    final first = nextItems.isEmpty ? null : nextItems.first;
    _draft = _draft.copyWith(
      imageAsset: first?.imageAsset ?? '',
      imageBytes: first?.imageBytes,
      clearImageBytes: first?.imageBytes == null,
      mediaPath: first?.mediaPath ?? '',
      containsVideo: first?.isVideo ?? false,
      mediaScale: first?.mediaScale ?? 1,
      mediaOffset: first?.mediaOffset ?? Offset.zero,
      mediaRotation: first?.mediaRotation ?? 0,
      videoTrimStartSeconds: first?.videoTrimStartSeconds ?? 0,
      videoTrimEndSeconds: first?.videoTrimEndSeconds,
      clearVideoTrimEndSeconds: first?.videoTrimEndSeconds == null,
      videoMuted: first?.videoMuted ?? true,
      mediaItems: nextItems,
    );
    _selectedMediaIndex = nextIndex;
    if (_selectedElementId != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_mediaPageController.hasClients || nextItems.isEmpty) return;
      _mediaPageController.jumpToPage(nextIndex);
    });
  }

  void _updateSelectedMedia(PostMediaItem Function(PostMediaItem item) update) {
    final items = [..._mediaItems];
    if (items.isEmpty) return;
    final index = _selectedMediaIndex.clamp(0, items.length - 1);
    items[index] = update(items[index]);
    setState(() => _replaceMediaItems(items, selectedIndex: index));
  }

  bool _isVideo(XFile file) {
    final mimeType = file.mimeType ?? '';
    return mimeType.startsWith('video/') ||
        RegExp(
          r'\.(mp4|mov|m4v|webm)$',
          caseSensitive: false,
        ).hasMatch(file.path);
  }

  Future<int?> _safeFileSize(XFile file) async {
    try {
      return await file.length();
    } catch (_) {
      return null;
    }
  }

  bool _validateVideoFile(XFile file, int? fileSizeBytes) {
    final mimeType = (file.mimeType ?? '').toLowerCase();
    final filename = '${file.name} ${file.path}'.toLowerCase();
    final supported =
        mimeType == 'video/mp4' ||
        mimeType == 'video/quicktime' ||
        mimeType == 'video/webm' ||
        filename.contains('.mp4') ||
        filename.contains('.mov') ||
        filename.contains('.m4v') ||
        filename.contains('.webm');
    if (!supported) {
      _showSnack('Usá un video MP4 o MOV durante el acceso anticipado.');
      return false;
    }
    if (fileSizeBytes != null && fileSizeBytes > _maxVideoBytes) {
      _showSnack('El video supera el límite de 100 MB del acceso anticipado.');
      return false;
    }
    return true;
  }

  bool _validatePickedBytes(Uint8List bytes, {required bool video}) {
    if (bytes.isEmpty) {
      _showSnack('El archivo parece estar vacío o no se pudo leer.');
      return false;
    }
    if (video && bytes.lengthInBytes > _maxVideoBytes) {
      _showSnack('El video supera el límite de 100 MB del acceso anticipado.');
      return false;
    }
    if (!video && bytes.lengthInBytes > _maxImageBytes) {
      _showSnack('La imagen supera el límite de 10 MB.');
      return false;
    }
    if (!video && MediaUploadLimits.detectImageContentType(bytes) == null) {
      _showSnack('Este tipo de imagen no está permitido. Usá JPG, PNG o WEBP.');
      return false;
    }
    return true;
  }

  void _useDemoPhoto() {
    setState(() {
      _videoDurationSeconds = null;
      _replaceMediaItems(const [
        PostMediaItem(
          id: 'demo-post-media',
          imageAsset: 'assets/demo-posts/post-02.jpg',
        ),
      ], selectedIndex: 0);
    });
  }

  void _clearMedia() {
    setState(() {
      _videoDurationSeconds = null;
      _replaceMediaItems(const [], selectedIndex: 0);
    });
  }

  void _resetMedia() {
    _updateSelectedMedia(
      (item) => item.copyWith(
        mediaScale: 1,
        mediaOffset: Offset.zero,
        mediaRotation: 0,
      ),
    );
  }

  Future<void> _chooseFilter() async {
    var pending = _draft.filterIndex.clamp(0, _filterColors.length - 1);
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => _PostToolSheet(
          title: 'Elegí un estilo',
          subtitle: 'Aplicá un tono suave sin alterar el archivo original.',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(_filterNames.length, (index) {
              final active = pending == index;
              return ChoiceChip(
                selected: active,
                label: Text(_filterNames[index]),
                avatar: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == 0
                        ? Colors.white.withValues(alpha: 0.2)
                        : _filterColors[index].withValues(alpha: 0.9),
                    border: Border.all(
                      color: active ? AppTheme.cyan : Colors.white24,
                    ),
                  ),
                ),
                onSelected: (_) => setSheetState(() => pending = index),
              );
            }),
          ),
          onApply: () => Navigator.of(sheetContext).pop(pending),
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => _draft = _draft.copyWith(filterIndex: selected));
  }

  void _updateElement(StoryElement next) {
    setState(() {
      _draft = _draft.copyWith(
        elements: _draft.elements
            .map((element) => element.id == next.id ? next : element)
            .toList(),
      );
    });
  }

  StoryElement? get _selectedElement {
    final id = _selectedElementId;
    if (id == null) return null;
    return _draft.elements.where((element) => element.id == id).firstOrNull;
  }

  double get _selectedMediaScale => _selectedMediaItem?.mediaScale ?? 1;

  double get _selectedScale => _selectedElement?.scale ?? _selectedMediaScale;

  double get _selectedScaleMin => _selectedElement == null ? 0.55 : 0.45;

  double get _selectedScaleMax => _selectedElement == null ? 4 : 3.5;

  void _setSelectedScale(double scale) {
    final element = _selectedElement;
    if (element == null) {
      _updateSelectedMedia(
        (item) => item.copyWith(mediaScale: scale.clamp(0.55, 4)),
      );
      return;
    }
    _updateElement(element.copyWith(scale: scale.clamp(0.45, 3.5)));
  }

  void _moveSelected(Offset offset) {
    final element = _selectedElement;
    if (element == null) {
      _updateSelectedMedia(
        (item) => item.copyWith(mediaOffset: item.mediaOffset + offset),
      );
      return;
    }
    _updateElement(
      element.copyWith(
        position: Offset(
          (element.position.dx + offset.dx / 360).clamp(0.06, 0.94),
          (element.position.dy + offset.dy / 360).clamp(0.06, 0.94),
        ),
      ),
    );
  }

  void _resetSelected() {
    final element = _selectedElement;
    if (element == null) {
      _resetMedia();
      return;
    }
    _updateElement(
      element.copyWith(position: const Offset(0.5, 0.5), scale: 1, rotation: 0),
    );
  }

  void _deleteSelectedElement() {
    final id = _selectedElementId;
    if (id == null) {
      _deleteMediaAt(_selectedMediaIndex);
      return;
    }
    setState(() {
      _draft = _draft.copyWith(
        elements: _draft.elements.where((element) => element.id != id).toList(),
      );
      _selectedElementId = null;
    });
  }

  void _selectMediaAt(int index) {
    final items = _mediaItems;
    if (items.isEmpty) return;
    final nextIndex = index.clamp(0, items.length - 1);
    setState(() {
      _selectedMediaIndex = nextIndex;
      _selectedElementId = null;
    });
    _animateToSelectedMedia();
  }

  void _deleteMediaAt(int index) {
    final items = [..._mediaItems];
    if (items.isEmpty) return;
    if (items.length == 1) {
      _clearMedia();
      return;
    }
    final safeIndex = index.clamp(0, items.length - 1);
    items.removeAt(safeIndex);
    setState(() {
      _replaceMediaItems(
        items,
        selectedIndex: safeIndex.clamp(0, items.length - 1),
      );
      _selectedElementId = null;
    });
    _animateToSelectedMedia();
  }

  void _animateToSelectedMedia() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_mediaPageController.hasClients || _mediaItems.isEmpty) return;
      _mediaPageController.animateToPage(
        _selectedMediaIndex,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _addTextOverlay() async {
    final controller = TextEditingController();
    var textValue = '';
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => _PostToolSheet(
          title: 'Texto sobre la publicación',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 80,
                onChanged: (value) => setSheetState(() => textValue = value),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Escribí un texto breve...',
                ),
              ),
              MentionSuggestionBar(
                text: textValue,
                onSelected: (profile) {
                  final next = insertMention(textValue, profile.username);
                  controller.value = TextEditingValue(
                    text: next,
                    selection: TextSelection.collapsed(offset: next.length),
                  );
                  setSheetState(() => textValue = next);
                },
              ),
            ],
          ),
          onApply: () => Navigator.of(sheetContext).pop(controller.text.trim()),
        ),
      ),
    );
    unawaited(
      Future<void>.delayed(
        const Duration(milliseconds: 350),
        controller.dispose,
      ),
    );
    if (text == null || text.isEmpty || !mounted) return;
    final element = StoryElement(
      id: 'post-text-${DateTime.now().microsecondsSinceEpoch}',
      type: StoryElementType.text,
      content: text,
      position: const Offset(0.5, 0.42),
      backgroundColor: Colors.black.withValues(alpha: 0.38),
    );
    setState(() {
      _draft = _draft.copyWith(elements: [..._draft.elements, element]);
      _selectedElementId = element.id;
    });
  }

  Future<void> _addSticker() async {
    final sticker = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _PostToolSheet(
        title: 'Stickers y emojis',
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final sticker in _stickers)
              InkWell(
                onTap: () => Navigator.of(sheetContext).pop(sticker),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(sticker, style: const TextStyle(fontSize: 28)),
                ),
              ),
          ],
        ),
      ),
    );
    if (sticker == null || !mounted) return;
    final element = StoryElement(
      id: 'post-sticker-${DateTime.now().microsecondsSinceEpoch}',
      type: StoryElementType.sticker,
      content: sticker,
      position: const Offset(0.7, 0.58),
    );
    setState(() {
      _draft = _draft.copyWith(elements: [..._draft.elements, element]);
      _selectedElementId = element.id;
    });
  }

  Future<void> _addPhotoLayer() async {
    if (_mediaItems.length >= _maxMediaItems) {
      _showSnack('Podés subir hasta 6 archivos por publicación.');
      return;
    }
    final files = await _pickGalleryFiles(
      limit: _maxMediaItems - _mediaItems.length,
    );
    if (files.isEmpty || !mounted) return;
    await _useFiles(files, append: true);
  }

  Future<void> _chooseMusic() async {
    final choice = await showModalBottomSheet<_PostMusicSelection>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) =>
          _PostMusicSheet(selectedAsset: _draft.musicAsset),
    );
    if (!mounted || choice == null) return;
    final track = choice.track;
    setState(() {
      _draft = _draft.copyWith(
        music: track?.label ?? '',
        musicAsset: track?.assetPath ?? '',
      );
    });
  }

  void _clearLocation() {
    setState(() => _locationController.clear());
  }

  Future<void> _openPeopleSelector() async {
    var selected = _selectedTaggedUsers.toList(growable: true);
    final result = await showModalBottomSheet<List<CommunityProfile>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => _PostSelectorSheet(
          title: 'Etiquetar personas',
          subtitle: 'Buscá fans reales y elegí hasta 10 personas.',
          onApply: () => Navigator.of(sheetContext).pop(selected),
          child: UserTagSelector(
            followService: widget.followService,
            currentUser: widget.currentUser,
            selectedUsers: selected,
            onChanged: (users) {
              setSheetState(() => selected = users.take(10).toList());
            },
            title: 'Personas',
            subtitle: 'Solo se guardan perfiles reales seleccionados.',
          ),
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _selectedTaggedUsers = result);
  }

  Future<void> _openArtistSelector() async {
    var selected = _selectedTaggedEntities.toList(growable: true);
    final result = await showModalBottomSheet<List<KpopEntity>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => _PostSelectorSheet(
          title: 'Etiquetar grupos o artistas',
          subtitle: 'Conectá el post con el catálogo real de HallyuHub.',
          onApply: () => Navigator.of(sheetContext).pop(selected),
          child: ArtistTagSelector(
            artistTagService: widget.artistTagService,
            selectedEntities: selected,
            onChanged: (entities) {
              setSheetState(() => selected = entities.take(10).toList());
            },
            title: 'Artistas y grupos',
            subtitle: 'Ej. BTS, Jungkook, BLACKPINK o NewJeans.',
          ),
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _selectedTaggedEntities = result);
  }

  Future<void> _addLocation() async {
    FocusScope.of(context).unfocus();
    _showSnack(
      'Escribí la ciudad o el lugar manualmente. HallyuHub no usa GPS.',
    );
    if (!mounted) return;
    FocusScope.of(context).requestFocus();
  }

  Future<void> _openTaggingPanel({
    EditorTagKind initialKind = EditorTagKind.person,
  }) async {
    final choice = await showEditorTaggingPanel(
      context: context,
      initialKind: initialKind,
      suggestCurrentLocation: true,
      allowLocalSuggestions: !widget.followService.usesRealProfiles,
    );
    if (!mounted || choice == null) return;
    if (choice.id == 'place-current') {
      await _addLocation();
      return;
    }
    setState(() {
      switch (choice.kind) {
        case EditorTagKind.person:
        case EditorTagKind.business:
          final tags = _normalizedPeople();
          if (!tags.contains(choice.value)) tags.add(choice.value);
          _peopleController.text = tags.join(', ');
        case EditorTagKind.place:
          _locationController.text = choice.value;
        case EditorTagKind.artist:
          _artistController.text = choice.value;
      }
    });
  }

  void _insertCaptionMention(CommunityProfile profile) {
    final next = insertMention(_captionText, profile.username);
    _captionController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    setState(() => _captionText = next);
  }

  void _handleVideoDuration(Duration duration) {
    final seconds = duration.inMilliseconds / 1000;
    final media = _selectedMediaItem;
    if (media?.isVideo != true ||
        seconds <= 0 ||
        seconds == _videoDurationSeconds) {
      return;
    }
    _videoDurationSeconds = seconds;
    _updateSelectedMedia(
      (item) => item.copyWith(videoTrimEndSeconds: seconds > 60 ? 60 : seconds),
    );
  }

  void _updateVideoTrim(RangeValues values) {
    var end = values.end;
    if (end - values.start > 60) end = values.start + 60;
    _updateSelectedMedia(
      (item) => item.copyWith(
        videoTrimStartSeconds: values.start,
        videoTrimEndSeconds: end,
      ),
    );
  }

  List<String> _normalizedTags() {
    return _tagsController.text
        .split(RegExp(r'[\s,]+'))
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .map((tag) => tag.startsWith('#') ? tag : '#$tag')
        .toSet()
        .take(12)
        .toList();
  }

  List<String> _normalizedPeople() {
    final selected = _selectedTaggedUsers
        .map((profile) => profile.username.trim())
        .where((username) => username.isNotEmpty);
    final manual = _peopleController.text
        .split(',')
        .map((person) => person.trim())
        .where((person) => person.isNotEmpty);
    return {...selected, ...manual}.take(10).toList();
  }

  void _publish() {
    if (_closingWithPublish) return;
    final caption = _captionController.text.trim();
    final mediaItems = _draft.effectiveMediaItems;
    if (mediaItems.length > _maxMediaItems) {
      _showSnack(
        'Por ahora solo podés subir hasta 6 archivos por publicación.',
      );
      return;
    }
    for (final video in mediaItems.where((item) => item.isVideo)) {
      final end = video.videoTrimEndSeconds ?? _videoDurationSeconds;
      final selectedSeconds = end == null
          ? _maxVideoSeconds
          : end - video.videoTrimStartSeconds;
      if (selectedSeconds > _maxVideoSeconds + 0.1) {
        _showSnack('Elegí un fragmento de hasta 60 segundos.');
        return;
      }
    }
    if (caption.isEmpty && !widget.allowEmptyCaptionForNews) {
      _showSnack('Escribí algo para compartir con tu comunidad.');
      return;
    }
    _closingWithPublish = true;
    Navigator.of(context).pop(
      _draft.copyWith(
        caption: caption,
        tags: _normalizedTags(),
        location: _locationController.text.trim(),
        taggedPeople: _normalizedPeople(),
        taggedUserIds: _selectedTaggedUsers
            .map((profile) => profile.id)
            .where((id) => id.isNotEmpty)
            .toSet()
            .take(10)
            .toList(),
        taggedUsers: _selectedTaggedUsers.take(10).toList(growable: false),
        taggedEntities: _selectedTaggedEntities
            .take(10)
            .toList(growable: false),
        artist: _artistController.text.trim(),
        profileCategories: _selectedProfileCategories.toList(growable: false),
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final mediaItems = _mediaItems;
    final selectedMedia = _selectedMediaItem;
    return Scaffold(
      backgroundColor: AppTheme.night,
      appBar: AppBar(
        backgroundColor: const Color(0xFF060913),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Cerrar editor',
        ),
        title: const Text(
          'Nueva publicación',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilledButton(
              key: const ValueKey('post-editor-publish'),
              onPressed: _publish,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.rose,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Publicar'),
            ),
          ),
        ],
      ),
      body: HallyuBackdrop(
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SingleChildScrollView(
                key: const ValueKey('post-editor-scroll'),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const HallyFeatureTip(
                      featureId: 'create_post_intro',
                      title: 'Compartí con HallyuHub ✨',
                      message:
                          'Publicá fotos, videos o texto para la comunidad.',
                      mascotAsset:
                          'assets/brand/hally_mascot_wave_transparent.png',
                    ),
                    _PostSectionHeading(
                      eyebrow: 'CONTENIDO',
                      title: _draft.hasMedia
                          ? 'Prepará tu publicación'
                          : 'Empezá con una idea',
                      detail: _draft.hasMedia
                          ? 'Ajustá el encuadre, el orden y los detalles antes de publicar.'
                          : 'Podés compartir texto solo o sumar hasta 6 fotos y videos.',
                    ),
                    const SizedBox(height: 12),
                    AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: AppTheme.panel,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: AppTheme.violet.withValues(alpha: 0.38),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.violet.withValues(alpha: 0.14),
                              blurRadius: 24,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (_draft.hasMedia)
                              _PostCarouselEditorPreview(
                                pageController: _mediaPageController,
                                mediaItems: mediaItems,
                                selectedIndex: _selectedMediaIndex,
                                elements: _draft.elements,
                                selectedElementId: _selectedElementId,
                                filterColor: _draft.filterIndex > 0
                                    ? _filterColors[_draft.filterIndex]
                                    : Colors.transparent,
                                onPageChanged: (index) {
                                  setState(() {
                                    _selectedMediaIndex = index;
                                    _selectedElementId = null;
                                  });
                                },
                                onMediaSelected: () =>
                                    setState(() => _selectedElementId = null),
                                onElementSelected: (id) =>
                                    setState(() => _selectedElementId = id),
                                onElementChanged: _updateElement,
                                onMediaChanged: (scale, offset, rotation) {
                                  _updateSelectedMedia(
                                    (item) => item.copyWith(
                                      mediaScale: scale,
                                      mediaOffset: offset,
                                      mediaRotation: rotation,
                                    ),
                                  );
                                },
                                onVideoDurationChanged: _handleVideoDuration,
                                onDeleteCurrent: _deleteSelectedElement,
                              )
                            else
                              _EmptyPostPreview(
                                onUseDemo: _useDemoPhoto,
                                allowDemoMedia: widget.allowDemoMedia,
                              ),
                            Positioned(
                              left: 10,
                              right: 10,
                              bottom: 10,
                              child: _PostEditorToolsBar(
                                hasMedia: _draft.hasMedia,
                                onGallery: _pickGallery,
                                onCamera: _capture,
                                onAddPhoto: _addPhotoLayer,
                                onText: _addTextOverlay,
                                onSticker: _addSticker,
                                onFilter: _chooseFilter,
                                onMusic: _chooseMusic,
                                onTagging: _openTaggingPanel,
                                onReset: _resetMedia,
                                onDelete: _deleteSelectedElement,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_draft.hasMedia) ...[
                      const SizedBox(height: 12),
                      _PostSelectedMediaStrip(
                        mediaItems: mediaItems,
                        activeIndex: _selectedMediaIndex,
                        maxItems: _maxMediaItems,
                        onSelect: _selectMediaAt,
                        onDelete: _deleteMediaAt,
                        onAdd: _addPhotoLayer,
                      ),
                      const SizedBox(height: 10),
                      _PostMediaAdjustment(
                        label: _selectedElement == null
                            ? 'Encuadre del archivo ${_selectedMediaIndex + 1}'
                            : 'Ajustar elemento',
                        scale: _selectedScale,
                        min: _selectedScaleMin,
                        max: _selectedScaleMax,
                        onScaleChanged: _setSelectedScale,
                        onMove: _moveSelected,
                        onReset: _resetSelected,
                        onDelete: _deleteSelectedElement,
                      ),
                    ],
                    if (selectedMedia?.isVideo == true) ...[
                      const SizedBox(height: 12),
                      _PostVideoControls(
                        durationSeconds: _videoDurationSeconds,
                        startSeconds: selectedMedia?.videoTrimStartSeconds ?? 0,
                        endSeconds: selectedMedia?.videoTrimEndSeconds,
                        muted: selectedMedia?.videoMuted ?? true,
                        onChanged: _updateVideoTrim,
                        onToggleMute: () {
                          _updateSelectedMedia(
                            (item) =>
                                item.copyWith(videoMuted: !item.videoMuted),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 26),
                    const _PostSectionHeading(
                      eyebrow: 'MENSAJE',
                      title: 'Contá el momento',
                      detail:
                          'Una descripción clara ayuda a que otros fans encuentren tu publicación.',
                    ),
                    const SizedBox(height: 12),
                    _PostComposerPanel(
                      child: Column(
                        children: [
                          _PostField(
                            key: const ValueKey('post-editor-caption'),
                            controller: _captionController,
                            focusNode: _captionFocusNode,
                            label: 'Texto de la publicación',
                            hint: widget.allowEmptyCaptionForNews
                                ? 'Agregá un comentario (opcional)...'
                                : '¿Qué querés compartir con tu comunidad?',
                            maxLines: 5,
                            maxLength: 1200,
                            onChanged: (value) =>
                                setState(() => _captionText = value),
                          ),
                          MentionSuggestionBar(
                            text: _captionText,
                            onSelected: _insertCaptionMention,
                            enabled: !widget.followService.usesRealProfiles,
                          ),
                          const SizedBox(height: 10),
                          _PostField(
                            key: const ValueKey('post-editor-tags'),
                            controller: _tagsController,
                            label: 'Hashtags',
                            hint: '#BTS #Comeback #BuenosAires',
                            prefixIcon: Icons.tag_rounded,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    const _PostSectionHeading(
                      eyebrow: 'CONEXIONES',
                      title: 'Etiquetas y música',
                      detail:
                          'Sumá contexto real sin llenar la pantalla de campos.',
                    ),
                    const SizedBox(height: 12),
                    _PostDetailTile(
                      key: const ValueKey('post-editor-people'),
                      icon: Icons.alternate_email_rounded,
                      title: 'Etiquetar personas',
                      value: _selectedTaggedUsers.isEmpty
                          ? 'Nadie seleccionado'
                          : _selectedTaggedUsers
                                .map((profile) => profile.username)
                                .join(', '),
                      accent: AppTheme.cyan,
                      onTap: _openPeopleSelector,
                    ),
                    const SizedBox(height: 8),
                    _PostDetailTile(
                      key: const ValueKey('post-editor-artist-tags'),
                      icon: Icons.groups_2_outlined,
                      title: 'Etiquetar grupos o artistas',
                      value: _selectedTaggedEntities.isEmpty
                          ? 'Conectá el post con el catálogo K-pop'
                          : _selectedTaggedEntities
                                .map((entity) => entity.name)
                                .join(', '),
                      accent: AppTheme.rose,
                      onTap: _openArtistSelector,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                      child: Text(
                        'Etiquetá grupos o artistas para que más fans encuentren tu publicación.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .55),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _PostDetailTile(
                      key: const ValueKey('post-editor-open-tags'),
                      icon: Icons.sell_outlined,
                      title: 'Etiqueta rápida',
                      value: 'Persona, lugar, artista o emprendimiento',
                      accent: AppTheme.amber,
                      onTap: _openTaggingPanel,
                    ),
                    const SizedBox(height: 8),
                    _PostDetailTile(
                      key: const ValueKey('post-editor-music-detail'),
                      icon: Icons.music_note_rounded,
                      title: 'Música',
                      value: _draft.music.isEmpty
                          ? 'Elegí y escuchá pistas autorizadas'
                          : _draft.music,
                      accent: AppTheme.violet,
                      trailing: _draft.music.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () => setState(
                                () => _draft = _draft.copyWith(
                                  music: '',
                                  musicAsset: '',
                                ),
                              ),
                              icon: const Icon(Icons.close_rounded),
                              color: Colors.white70,
                              tooltip: 'Quitar música',
                            ),
                      onTap: _chooseMusic,
                    ),
                    if (_draft.music.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'La pista queda asociada al post. La reproducción dentro del feed todavía está en preparación.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.58),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 26),
                    const _PostSectionHeading(
                      eyebrow: 'DETALLES',
                      title: 'Ubicación y perfil',
                      detail:
                          'Todo es opcional y podés cambiarlo antes de publicar.',
                    ),
                    const SizedBox(height: 12),
                    _PostLocationPanel(
                      controller: _locationController,
                      onUseCurrent: _addLocation,
                      onChoosePlace: () =>
                          _openTaggingPanel(initialKind: EditorTagKind.place),
                      onClear: _clearLocation,
                    ),
                    const SizedBox(height: 14),
                    ProfileCategorySelector(
                      selected: _selectedProfileCategories,
                      onChanged: (categories) {
                        setState(() => _selectedProfileCategories = categories);
                      },
                    ),
                    const SizedBox(height: 26),
                    const _PostSectionHeading(
                      eyebrow: 'VISIBILIDAD',
                      title: 'Elegí quién puede verla',
                      detail:
                          'La privacidad se guarda junto con la publicación.',
                    ),
                    const SizedBox(height: 12),
                    _PostPrivacySelector(
                      key: const ValueKey('post-editor-privacy'),
                      value: _draft.privacy,
                      onChanged: (privacy) {
                        setState(
                          () => _draft = _draft.copyWith(privacy: privacy),
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                    _PostPublishButton(
                      key: const ValueKey('post-editor-publish-bottom'),
                      onPressed: _publish,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PostSectionHeading extends StatelessWidget {
  const _PostSectionHeading({
    required this.eyebrow,
    required this.title,
    required this.detail,
  });

  final String eyebrow;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: AppTheme.cyan,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          detail,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.62),
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _PostComposerPanel extends StatelessWidget {
  const _PostComposerPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.panelRaised.withValues(alpha: 0.9),
            AppTheme.panel.withValues(alpha: 0.96),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.stroke.withValues(alpha: 0.86)),
      ),
      child: child,
    );
  }
}

class _PostDetailTile extends StatelessWidget {
  const _PostDetailTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.accent,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color accent;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(13, 12, 8, 12),
          decoration: BoxDecoration(
            color: AppTheme.panel.withValues(alpha: 0.76),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.44),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostLocationPanel extends StatelessWidget {
  const _PostLocationPanel({
    required this.controller,
    required this.onUseCurrent,
    required this.onChoosePlace,
    required this.onClear,
  });

  final TextEditingController controller;
  final VoidCallback onUseCurrent;
  final VoidCallback onChoosePlace;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PostField(
            key: const ValueKey('post-editor-location'),
            controller: controller,
            label: 'Ubicación opcional',
            hint: 'Ej. Palermo, Buenos Aires',
            prefixIcon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 2),
          Wrap(
            spacing: 4,
            runSpacing: 2,
            children: [
              TextButton.icon(
                key: const ValueKey('post-editor-use-location'),
                onPressed: onUseCurrent,
                icon: const Icon(Icons.my_location_outlined),
                label: const Text('Usar mi ubicación'),
              ),
              TextButton.icon(
                key: const ValueKey('post-editor-choose-place'),
                onPressed: onChoosePlace,
                icon: const Icon(Icons.location_searching_outlined),
                label: const Text('Buscar lugar'),
              ),
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
                color: Colors.white60,
                tooltip: 'Quitar ubicación',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PostPrivacySelector extends StatelessWidget {
  const _PostPrivacySelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  static const _options = <(String, String, IconData)>[
    ('Todos', 'Todos', Icons.public_rounded),
    ('Seguidores', 'Seguidores', Icons.group_outlined),
    ('Privado', 'Solo yo', Icons.lock_outline_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
      ),
      child: Row(
        children: _options
            .map((option) {
              final active = value == option.$1;
              return Expanded(
                child: Semantics(
                  selected: active,
                  button: true,
                  label: option.$2,
                  child: InkWell(
                    onTap: () => onChanged(option.$1),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: active
                            ? const LinearGradient(
                                colors: [AppTheme.rose, AppTheme.violet],
                              )
                            : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(option.$3, color: Colors.white, size: 18),
                          const SizedBox(height: 3),
                          Text(
                            option.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(
                                alpha: active ? 1 : 0.68,
                              ),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _PostPublishButton extends StatelessWidget {
  const _PostPublishButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.rose, AppTheme.violet, AppTheme.cyan],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.rose.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.publish_rounded),
        label: const Text('Publicar ahora'),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _EmptyPostPreview extends StatelessWidget {
  const _EmptyPostPreview({
    required this.onUseDemo,
    required this.allowDemoMedia,
  });

  final VoidCallback onUseDemo;
  final bool allowDemoMedia;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 74),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.rose.withValues(alpha: 0.28),
                  AppTheme.cyan.withValues(alpha: 0.18),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: const Icon(
              Icons.add_photo_alternate_outlined,
              color: AppTheme.cyan,
              size: 29,
            ),
          ),
          const SizedBox(height: 11),
          const Text(
            'Tu contenido empieza acá',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Elegí fotos o videos desde la barra inferior. También podés publicar solo texto.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 12,
              height: 1.3,
            ),
          ),
          if (allowDemoMedia) ...[
            const SizedBox(height: 10),
            TextButton(
              key: const ValueKey('post-editor-demo-photo'),
              onPressed: onUseDemo,
              child: const Text('Probar con imagen de prueba'),
            ),
          ],
        ],
      ),
    );
  }
}

class _PostCarouselEditorPreview extends StatelessWidget {
  const _PostCarouselEditorPreview({
    required this.pageController,
    required this.mediaItems,
    required this.selectedIndex,
    required this.elements,
    required this.selectedElementId,
    required this.filterColor,
    required this.onPageChanged,
    required this.onMediaSelected,
    required this.onElementSelected,
    required this.onElementChanged,
    required this.onMediaChanged,
    required this.onVideoDurationChanged,
    required this.onDeleteCurrent,
  });

  final PageController pageController;
  final List<PostMediaItem> mediaItems;
  final int selectedIndex;
  final List<StoryElement> elements;
  final String? selectedElementId;
  final Color filterColor;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onMediaSelected;
  final ValueChanged<String> onElementSelected;
  final ValueChanged<StoryElement> onElementChanged;
  final void Function(double scale, Offset offset, double rotation)
  onMediaChanged;
  final ValueChanged<Duration> onVideoDurationChanged;
  final VoidCallback onDeleteCurrent;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          key: const ValueKey('post-editor-media-carousel'),
          controller: pageController,
          itemCount: mediaItems.length,
          onPageChanged: onPageChanged,
          itemBuilder: (context, index) {
            final item = mediaItems[index];
            return StoryCanvas(
              contentType: item.isVideo
                  ? StoryContentType.video
                  : StoryContentType.image,
              imageAsset: item.imageAsset,
              imageBytes: item.imageBytes,
              mediaPath: item.mediaPath,
              backgroundColors: const [AppTheme.nightSoft, AppTheme.violet],
              elements: elements,
              mediaScale: item.mediaScale,
              mediaOffset: item.mediaOffset,
              mediaRotation: item.mediaRotation,
              visualFilter: StoryVisualFilter.original,
              videoTrimStartSeconds: item.videoTrimStartSeconds,
              videoTrimEndSeconds: item.videoTrimEndSeconds,
              videoMuted: item.videoMuted,
              mediaFit: BoxFit.contain,
              editable: index == selectedIndex,
              selectedMedia:
                  selectedElementId == null && index == selectedIndex,
              selectedElementId: selectedElementId,
              onMediaSelected: onMediaSelected,
              onElementSelected: onElementSelected,
              onElementChanged: onElementChanged,
              onMediaChanged: onMediaChanged,
              onVideoDurationChanged: onVideoDurationChanged,
            );
          },
        ),
        if (filterColor != Colors.transparent)
          IgnorePointer(child: ColoredBox(color: filterColor)),
        Positioned(
          left: 12,
          top: 12,
          child: _PostCarouselCounter(
            current: selectedIndex + 1,
            total: mediaItems.length,
          ),
        ),
        if (mediaItems.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 82,
            child: _PostCarouselDots(
              count: mediaItems.length,
              activeIndex: selectedIndex,
            ),
          ),
        if (mediaItems.isNotEmpty)
          Positioned(
            right: 12,
            top: 12,
            child: IconButton.filledTonal(
              key: const ValueKey('post-editor-delete-current-media'),
              onPressed: onDeleteCurrent,
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Eliminar foto actual',
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.42),
                foregroundColor: AppTheme.rose,
              ),
            ),
          ),
      ],
    );
  }
}

class _PostCarouselCounter extends StatelessWidget {
  const _PostCarouselCounter({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('post-carousel-counter'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        '$current/$total',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PostCarouselDots extends StatelessWidget {
  const _PostCarouselDots({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final active = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: active ? 18 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            gradient: active
                ? const LinearGradient(colors: [AppTheme.rose, AppTheme.cyan])
                : null,
            color: active ? null : Colors.white.withValues(alpha: 0.38),
          ),
        );
      }),
    );
  }
}

class _PostSelectedMediaStrip extends StatelessWidget {
  const _PostSelectedMediaStrip({
    required this.mediaItems,
    required this.activeIndex,
    required this.maxItems,
    required this.onSelect,
    required this.onDelete,
    required this.onAdd,
  });

  final List<PostMediaItem> mediaItems;
  final int activeIndex;
  final int maxItems;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onDelete;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('post-editor-selected-media-strip'),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.view_carousel_outlined,
                color: AppTheme.cyan,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Carrusel de la publicación',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${mediaItems.length}/$maxItems',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.70),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount:
                  mediaItems.length + (mediaItems.length < maxItems ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == mediaItems.length) {
                  return _PostAddMediaTile(onAdd: onAdd);
                }
                return _PostSelectedMediaThumb(
                  item: mediaItems[index],
                  index: index,
                  selected: index == activeIndex,
                  onSelect: () => onSelect(index),
                  onDelete: () => onDelete(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PostSelectedMediaThumb extends StatelessWidget {
  const _PostSelectedMediaThumb({
    required this.item,
    required this.index,
    required this.selected,
    required this.onSelect,
    required this.onDelete,
  });

  final PostMediaItem item;
  final int index;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('post-editor-selected-media-$index'),
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 68,
        height: 76,
        padding: EdgeInsets.all(selected ? 2 : 1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: selected
              ? const LinearGradient(colors: [AppTheme.rose, AppTheme.cyan])
              : null,
          border: selected
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _PostSelectedMediaThumbImage(item: item),
              Positioned(
                left: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.58),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              if (item.isVideo)
                const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              Positioned(
                top: 4,
                right: 4,
                child: InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.64),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 15,
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

class _PostSelectedMediaThumbImage extends StatelessWidget {
  const _PostSelectedMediaThumbImage({required this.item});

  final PostMediaItem item;

  @override
  Widget build(BuildContext context) {
    if (!item.isVideo && item.imageBytes != null) {
      return Image.memory(item.imageBytes!, fit: BoxFit.cover);
    }
    if (!item.isVideo && item.mediaPath.startsWith('http')) {
      return Image.network(item.mediaPath, fit: BoxFit.cover);
    }
    if (!item.isVideo && item.imageAsset.isNotEmpty) {
      return Image.asset(item.imageAsset, fit: BoxFit.cover);
    }
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppTheme.nightSoft, AppTheme.violet]),
      ),
      child: Center(
        child: Icon(
          item.isVideo ? Icons.videocam_rounded : Icons.image_outlined,
          color: Colors.white70,
          size: 24,
        ),
      ),
    );
  }
}

class _PostAddMediaTile extends StatelessWidget {
  const _PostAddMediaTile({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const ValueKey('post-editor-add-media-tile'),
      onTap: onAdd,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 68,
        height: 76,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: const Icon(
          Icons.add_photo_alternate_outlined,
          color: AppTheme.cyan,
        ),
      ),
    );
  }
}

class _PostEditorToolsBar extends StatelessWidget {
  const _PostEditorToolsBar({
    required this.hasMedia,
    required this.onGallery,
    required this.onCamera,
    required this.onAddPhoto,
    required this.onText,
    required this.onSticker,
    required this.onFilter,
    required this.onMusic,
    required this.onTagging,
    required this.onReset,
    required this.onDelete,
  });

  final bool hasMedia;
  final VoidCallback onGallery;
  final VoidCallback onCamera;
  final VoidCallback onAddPhoto;
  final VoidCallback onText;
  final VoidCallback onSticker;
  final VoidCallback onFilter;
  final VoidCallback onMusic;
  final VoidCallback onTagging;
  final VoidCallback onReset;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tools = <Widget>[
      _PostToolIcon(
        key: const ValueKey('post-editor-gallery'),
        icon: Icons.photo_library_outlined,
        label: 'Galería',
        onTap: onGallery,
      ),
      _PostToolIcon(
        key: const ValueKey('post-editor-camera'),
        icon: Icons.photo_camera_outlined,
        label: 'Cámara',
        onTap: onCamera,
      ),
      if (hasMedia) ...[
        _PostToolIcon(
          key: const ValueKey('post-editor-add-photo'),
          icon: Icons.add_photo_alternate_outlined,
          label: 'Sumar',
          onTap: onAddPhoto,
        ),
        _PostToolIcon(
          key: const ValueKey('post-editor-overlay-text'),
          icon: Icons.text_fields_rounded,
          label: 'Texto',
          onTap: onText,
        ),
        _PostToolIcon(
          key: const ValueKey('post-editor-sticker'),
          icon: Icons.emoji_emotions_outlined,
          label: 'Sticker',
          onTap: onSticker,
        ),
        _PostToolIcon(
          key: const ValueKey('post-editor-tagging'),
          icon: Icons.sell_outlined,
          label: 'Etiquetar',
          onTap: onTagging,
        ),
        _PostToolIcon(
          key: const ValueKey('post-editor-filter'),
          icon: Icons.auto_awesome_outlined,
          label: 'Filtro',
          onTap: onFilter,
        ),
        _PostToolIcon(
          key: const ValueKey('post-editor-music'),
          icon: Icons.music_note_outlined,
          label: 'Música',
          onTap: onMusic,
        ),
        _PostToolIcon(
          key: const ValueKey('post-editor-reset-media'),
          icon: Icons.center_focus_strong_outlined,
          label: 'Centrar',
          onTap: onReset,
        ),
        _PostToolIcon(
          key: const ValueKey('post-editor-clear-media'),
          icon: Icons.delete_outline_rounded,
          label: 'Quitar',
          color: AppTheme.rose,
          onTap: onDelete,
        ),
      ],
    ];
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xE6171020),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tools.length,
        separatorBuilder: (_, _) => Container(
          width: 1,
          margin: const EdgeInsets.symmetric(vertical: 10),
          color: Colors.white.withValues(alpha: 0.08),
        ),
        itemBuilder: (context, index) => tools[index],
      ),
    );
  }
}

class _PostToolIcon extends StatelessWidget {
  const _PostToolIcon({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 58,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 21),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color.withValues(alpha: 0.9),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostMediaAdjustment extends StatelessWidget {
  const _PostMediaAdjustment({
    required this.label,
    required this.scale,
    required this.min,
    required this.max,
    required this.onScaleChanged,
    required this.onMove,
    required this.onReset,
    required this.onDelete,
  });

  final String label;
  final double scale;
  final double min;
  final double max;
  final ValueChanged<double> onScaleChanged;
  final ValueChanged<Offset> onMove;
  final VoidCallback onReset;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('post-editor-adjustment'),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Row(
            children: [
              IconButton(
                key: const ValueKey('post-editor-scale-down'),
                onPressed: () => onScaleChanged((scale - 0.15).clamp(min, max)),
                icon: const Icon(Icons.remove_rounded),
                color: Colors.white,
                tooltip: 'Achicar elemento',
              ),
              Expanded(
                child: Slider(
                  key: const ValueKey('post-editor-scale-slider'),
                  value: scale.clamp(min, max),
                  min: min,
                  max: max,
                  onChanged: onScaleChanged,
                ),
              ),
              IconButton(
                key: const ValueKey('post-editor-scale-up'),
                onPressed: () => onScaleChanged((scale + 0.15).clamp(min, max)),
                icon: const Icon(Icons.add_rounded),
                color: Colors.white,
                tooltip: 'Agrandar elemento',
              ),
              PopupMenuButton<Offset>(
                tooltip: 'Mover elemento',
                color: AppTheme.nightSoft,
                icon: const Icon(Icons.open_with_rounded, color: Colors.white),
                onSelected: onMove,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: Offset(0, -14),
                    child: Text('Mover arriba'),
                  ),
                  PopupMenuItem(
                    value: Offset(0, 14),
                    child: Text('Mover abajo'),
                  ),
                  PopupMenuItem(
                    value: Offset(-14, 0),
                    child: Text('Mover izquierda'),
                  ),
                  PopupMenuItem(
                    value: Offset(14, 0),
                    child: Text('Mover derecha'),
                  ),
                ],
              ),
              IconButton(
                onPressed: onReset,
                icon: const Icon(Icons.refresh_rounded),
                color: AppTheme.cyan,
                tooltip: 'Restablecer ajuste',
              ),
              IconButton(
                key: const ValueKey('post-editor-selection-delete'),
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                color: AppTheme.rose,
                tooltip: 'Eliminar elemento',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PostSelectorSheet extends StatelessWidget {
  const _PostSelectorSheet({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onApply,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.86,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        decoration: const BoxDecoration(
          color: AppTheme.nightSoft,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(child: SingleChildScrollView(child: child)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onApply,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Aplicar selección'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostMusicSelection {
  const _PostMusicSelection({this.track});

  final StoryMusic? track;
}

class _PostMusicSheet extends StatefulWidget {
  const _PostMusicSheet({required this.selectedAsset});

  final String selectedAsset;

  @override
  State<_PostMusicSheet> createState() => _PostMusicSheetState();
}

class _PostMusicSheetState extends State<_PostMusicSheet> {
  final StoryAudioController _audioController = StoryAudioController();
  StoryMusic? _selected;
  String _previewAsset = '';

  @override
  void initState() {
    super.initState();
    for (final track in storyMusicLibrary) {
      if (track.assetPath == widget.selectedAsset) {
        _selected = track;
        break;
      }
    }
  }

  @override
  void dispose() {
    _audioController.dispose();
    super.dispose();
  }

  Future<void> _togglePreview(StoryMusic track) async {
    if (_previewAsset == track.assetPath && _audioController.isPlaying) {
      await _audioController.pause();
      if (mounted) setState(() {});
      return;
    }
    await _audioController.play(track.assetPath);
    if (!mounted) return;
    if (_audioController.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pudimos reproducir esta pista. Probá otra.'),
        ),
      );
      return;
    }
    setState(() => _previewAsset = track.assetPath);
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        decoration: const BoxDecoration(
          color: AppTheme.nightSoft,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Agregar música',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Preescuchá pistas propias y autorizadas de HallyuHub Studio.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  itemCount: storyMusicLibrary.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final track = storyMusicLibrary[index];
                    final selected = _selected?.id == track.id;
                    final playing =
                        _previewAsset == track.assetPath &&
                        _audioController.isPlaying;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => setState(() => _selected = track),
                        borderRadius: BorderRadius.circular(15),
                        child: Ink(
                          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                          decoration: BoxDecoration(
                            color: selected
                                ? track.color.withValues(alpha: 0.14)
                                : Colors.white.withValues(alpha: 0.045),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: selected
                                  ? track.color.withValues(alpha: 0.56)
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            children: [
                              IconButton.filledTonal(
                                onPressed: () => _togglePreview(track),
                                icon: Icon(
                                  playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                ),
                                tooltip: playing
                                    ? 'Pausar vista previa'
                                    : 'Escuchar vista previa',
                                style: IconButton.styleFrom(
                                  foregroundColor: track.color,
                                  backgroundColor: track.color.withValues(
                                    alpha: 0.12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      track.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${track.artist} · ${track.mood}',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.58,
                                        ),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                selected
                                    ? Icons.check_circle_rounded
                                    : Icons.circle_outlined,
                                color: selected ? track.color : Colors.white30,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(const _PostMusicSelection()),
                    child: const Text('Sin música'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _selected == null
                          ? null
                          : () => Navigator.of(
                              context,
                            ).pop(_PostMusicSelection(track: _selected)),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Usar esta pista'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostToolSheet extends StatelessWidget {
  const _PostToolSheet({
    required this.title,
    required this.child,
    this.subtitle,
    this.onApply,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        18,
        16,
        18,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.nightSoft,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 12),
            child,
            if (onApply != null) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: onApply, child: const Text('Aplicar')),
            ],
          ],
        ),
      ),
    );
  }
}

class _PostField extends StatelessWidget {
  const _PostField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.maxLength,
    this.prefixIcon,
    this.focusNode,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final int? maxLength;
  final IconData? prefixIcon;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      maxLines: maxLines,
      maxLength: maxLength,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
      ),
    );
  }
}

class _PostVideoControls extends StatelessWidget {
  const _PostVideoControls({
    required this.durationSeconds,
    required this.startSeconds,
    required this.endSeconds,
    required this.muted,
    required this.onChanged,
    required this.onToggleMute,
  });

  final double? durationSeconds;
  final double startSeconds;
  final double? endSeconds;
  final bool muted;
  final ValueChanged<RangeValues> onChanged;
  final VoidCallback onToggleMute;

  @override
  Widget build(BuildContext context) {
    final duration = durationSeconds;
    final end = duration == null
        ? endSeconds ?? 60
        : (endSeconds ?? duration).clamp(0.1, duration);
    return Container(
      key: const ValueKey('post-editor-video-trim'),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppTheme.violet.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.content_cut_rounded, color: AppTheme.cyan),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  duration == null
                      ? 'Preparando recorte de video...'
                      : 'Elegí un fragmento de hasta 60 segundos',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('post-editor-video-mute'),
                onPressed: onToggleMute,
                icon: Icon(
                  muted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
                ),
                color: Colors.white,
                tooltip: muted ? 'Activar sonido del video' : 'Silenciar video',
              ),
            ],
          ),
          if (duration != null && duration > 0.1)
            RangeSlider(
              key: const ValueKey('post-editor-video-trim-slider'),
              values: RangeValues(
                startSeconds.clamp(0, duration),
                end.clamp(0.1, duration),
              ),
              min: 0,
              max: duration,
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}
