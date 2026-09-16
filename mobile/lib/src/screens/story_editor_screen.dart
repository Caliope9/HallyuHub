import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/demo_data.dart';
import '../models.dart';
import '../screens/camera_capture_screen.dart';
import '../services/local_artist_tag_service.dart';
import '../services/local_follow_service.dart';
import '../services/media_permission_service.dart';
import '../services/story_audio_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/contextual_permission_sheet.dart';
import '../widgets/editor_tagging_panel.dart';
import '../widgets/hally_feature_tip.dart';
import '../widgets/artist_tag_selector.dart';
import '../widgets/story_canvas.dart';
import '../widgets/user_tag_selector.dart';

class StoryEditorScreen extends StatefulWidget {
  const StoryEditorScreen({
    super.key,
    required this.initialDraft,
    this.currentUser,
    this.followService = const LocalFollowService(),
    this.artistTagService = const LocalArtistTagService(),
  });

  final StoryDraft initialDraft;
  final AuthUser? currentUser;
  final LocalFollowService followService;
  final LocalArtistTagService artistTagService;

  @override
  State<StoryEditorScreen> createState() => _StoryEditorScreenState();
}

class _StoryEditorScreenState extends State<StoryEditorScreen> {
  final _picker = ImagePicker();
  final _audio = StoryAudioController();
  final _permissionService = const MediaPermissionService();
  final _canvasKey = GlobalKey();
  late StoryDraft _draft;
  String? _selectedElementId;
  bool _mediaSelected = false;
  String? _draggingTargetId;
  bool _deleteArmed = false;
  double? _videoDurationSeconds;
  late List<CommunityProfile> _selectedTaggedUsers;
  late List<KpopEntity> _selectedTaggedEntities;

  static const _textColors = [
    Colors.white,
    Color(0xFFFFA7D0),
    AppTheme.cyan,
    Color(0xFFFFD166),
    Color(0xFFB9FBC0),
  ];

  @override
  void initState() {
    super.initState();
    _draft = widget.initialDraft;
    _selectedTaggedUsers = _draft.taggedUsers.toList(growable: true);
    _selectedTaggedEntities = _draft.taggedEntities.toList(growable: true);
  }

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  void _updateDraft(StoryDraft draft) {
    setState(() => _draft = draft);
  }

  void _updateElement(StoryElement next) {
    _updateDraft(
      _draft.copyWith(
        elements: _draft.elements
            .map((element) => element.id == next.id ? next : element)
            .toList(),
      ),
    );
  }

  void _deleteSelectedElement() {
    final id = _selectedElementId;
    if (_mediaSelected) {
      _deleteMedia();
      return;
    }
    if (id == null) return;
    setState(() {
      _draft = _draft.copyWith(
        elements: _draft.elements.where((element) => element.id != id).toList(),
      );
      _selectedElementId = null;
    });
  }

  void _deleteMedia() {
    setState(() {
      _draft = _draft.copyWith(
        type: StoryContentType.text,
        imageAsset: '',
        clearImageBytes: true,
        mediaPath: '',
        mediaScale: 1,
        mediaOffset: Offset.zero,
        mediaRotation: 0,
        videoTrimStartSeconds: 0,
        clearVideoTrimEndSeconds: true,
      );
      _mediaSelected = false;
      _videoDurationSeconds = null;
    });
  }

  void _selectMedia() {
    setState(() {
      _mediaSelected = true;
      _selectedElementId = null;
    });
  }

  void _selectElement(String id) {
    setState(() {
      _mediaSelected = false;
      _selectedElementId = id;
      final elements = [..._draft.elements];
      final index = elements.indexWhere((element) => element.id == id);
      if (index >= 0 && index != elements.length - 1) {
        final selected = elements.removeAt(index);
        elements.add(selected);
        _draft = _draft.copyWith(elements: elements);
      }
    });
  }

  void _startManipulation(String targetId, Offset globalFocalPoint) {
    _updateDeleteTarget(targetId, globalFocalPoint);
  }

  void _updateDeleteTarget(String targetId, Offset globalFocalPoint) {
    final renderBox =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final localPoint = renderBox.globalToLocal(globalFocalPoint);
    final size = renderBox.size;
    final armed =
        localPoint.dy >= size.height - 104 &&
        (localPoint.dx - size.width / 2).abs() <= 82;
    if (_draggingTargetId == targetId && _deleteArmed == armed) return;
    setState(() {
      _draggingTargetId = targetId;
      _deleteArmed = armed;
    });
  }

  void _finishManipulation(String targetId) {
    final shouldDelete = _deleteArmed && _draggingTargetId == targetId;
    setState(() {
      _draggingTargetId = null;
      _deleteArmed = false;
      if (!shouldDelete) return;
      if (targetId == StoryCanvas.mediaTargetId) {
        _draft = _draft.copyWith(
          type: StoryContentType.text,
          imageAsset: '',
          clearImageBytes: true,
          mediaPath: '',
          mediaScale: 1,
          mediaOffset: Offset.zero,
          mediaRotation: 0,
          videoTrimStartSeconds: 0,
          clearVideoTrimEndSeconds: true,
        );
        _mediaSelected = false;
        _videoDurationSeconds = null;
        return;
      }
      _draft = _draft.copyWith(
        elements: _draft.elements
            .where((element) => element.id != targetId)
            .toList(),
      );
      if (_selectedElementId == targetId) _selectedElementId = null;
    });
  }

  bool get _hasMedia =>
      _draft.imageBytes != null ||
      _draft.imageAsset.isNotEmpty ||
      _draft.mediaPath.isNotEmpty;

  bool get _hasValidContent =>
      _draft.elements.isNotEmpty || _hasMedia || _draft.text.trim().isNotEmpty;

  bool get _hasTextLayer =>
      _draft.elements.any((element) => element.type == StoryElementType.text);

  bool get _hasStickerLayer => _draft.elements.any(
    (element) => element.type == StoryElementType.sticker,
  );

  bool get _hasPhotoLayer =>
      _draft.elements.any((element) => element.type == StoryElementType.image);

  bool get _hasTags =>
      _selectedTaggedUsers.isNotEmpty || _selectedTaggedEntities.isNotEmpty;

  void _clearMusic() {
    _updateDraft(_draft.copyWith(music: '', musicAsset: ''));
    unawaited(_audio.stop());
  }

  StoryElement? get _selectedElement {
    final id = _selectedElementId;
    if (id == null) return null;
    return _draft.elements.where((element) => element.id == id).firstOrNull;
  }

  double? get _selectedScale {
    if (_mediaSelected) return _draft.mediaScale;
    return _selectedElement?.scale;
  }

  void _setSelectedScale(double scale) {
    if (_mediaSelected) {
      _updateDraft(_draft.copyWith(mediaScale: scale.clamp(0.55, 4)));
      return;
    }
    final element = _selectedElement;
    if (element == null) return;
    _updateElement(element.copyWith(scale: scale.clamp(0.45, 3.5)));
  }

  void _adjustSelectedScale(double delta) {
    final selectedScale = _selectedScale;
    if (selectedScale == null) return;
    _setSelectedScale(selectedScale + delta);
  }

  void _handleVideoDuration(Duration duration) {
    if (_draft.type != StoryContentType.video) return;
    final seconds = duration.inMilliseconds / 1000;
    if (seconds <= 0 || seconds == _videoDurationSeconds) return;
    final currentStart = _draft.videoTrimStartSeconds
        .clamp(0, seconds)
        .toDouble();
    final requestedEnd = _draft.videoTrimEndSeconds ?? seconds;
    final currentEnd = requestedEnd.clamp(
      (currentStart + 0.1).clamp(0.1, seconds),
      seconds,
    );
    final limitedEnd =
        (currentEnd - currentStart > 60 ? currentStart + 60 : currentEnd)
            .toDouble();
    setState(() {
      _videoDurationSeconds = seconds;
      _draft = _draft.copyWith(
        videoTrimStartSeconds: currentStart,
        videoTrimEndSeconds: limitedEnd,
      );
    });
  }

  void _updateVideoTrim(RangeValues values) {
    var start = values.start;
    var end = values.end;
    if (end - start > 60) {
      end = (start + 60).clamp(start, _videoDurationSeconds ?? end).toDouble();
    }
    _updateDraft(
      _draft.copyWith(videoTrimStartSeconds: start, videoTrimEndSeconds: end),
    );
  }

  void _addElement(StoryElement element) {
    setState(() {
      _draft = _draft.copyWith(elements: [..._draft.elements, element]);
      _selectedElementId = element.id;
      _mediaSelected = false;
    });
  }

  void _bringSelectedForward() {
    final id = _selectedElementId;
    if (id == null) return;
    final elements = [..._draft.elements];
    final index = elements.indexWhere((element) => element.id == id);
    if (index < 0 || index == elements.length - 1) return;
    final selected = elements.removeAt(index);
    elements.insert(index + 1, selected);
    _updateDraft(_draft.copyWith(elements: elements));
  }

  void _sendSelectedBackward() {
    final id = _selectedElementId;
    if (id == null) return;
    final elements = [..._draft.elements];
    final index = elements.indexWhere((element) => element.id == id);
    if (index <= 0) return;
    final selected = elements.removeAt(index);
    elements.insert(index - 1, selected);
    _updateDraft(_draft.copyWith(elements: elements));
  }

  Future<void> _addText() async {
    final controller = TextEditingController();
    var selectedColor = Colors.white;
    var useBackground = false;
    var textValue = '';
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.fromLTRB(
            18,
            12,
            18,
            MediaQuery.viewInsetsOf(context).bottom + 18,
          ),
          decoration: BoxDecoration(
            color: AppTheme.nightSoft,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: AppTheme.violet.withValues(alpha: 0.42)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _StorySheetHandle(),
                const SizedBox(height: 14),
                const _StorySheetHeader(
                  icon: Icons.text_fields_rounded,
                  title: 'Agregar texto',
                  subtitle: 'Escribí algo breve y acomodalo sobre tu historia.',
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('story-editor-text-input'),
                  controller: controller,
                  autofocus: true,
                  maxLength: 100,
                  onChanged: (value) => setSheetState(() => textValue = value),
                  style: TextStyle(color: selectedColor),
                  decoration: InputDecoration(
                    hintText: 'Escribí tu mensaje...',
                    counterStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: AppTheme.cyan),
                    ),
                  ),
                ),
                MentionSuggestionBar(
                  text: textValue,
                  enabled: !widget.followService.usesRealProfiles,
                  onSelected: (profile) {
                    final next = insertMention(textValue, profile.username);
                    controller.value = TextEditingValue(
                      text: next,
                      selection: TextSelection.collapsed(offset: next.length),
                    );
                    setSheetState(() => textValue = next);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final color in _textColors)
                      Padding(
                        padding: const EdgeInsets.only(right: 9),
                        child: InkWell(
                          onTap: () =>
                              setSheetState(() => selectedColor = color),
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color == selectedColor
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    const Spacer(),
                    FilterChip(
                      selected: useBackground,
                      onSelected: (value) =>
                          setSheetState(() => useBackground = value),
                      label: const Text('Fondo'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const ValueKey('story-editor-add-text'),
                  onPressed: textValue.trim().isEmpty
                      ? null
                      : () => Navigator.of(
                          sheetContext,
                        ).pop(controller.text.trim()),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Agregar a la historia'),
                ),
              ],
            ),
          ),
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
      id: 'text-${DateTime.now().microsecondsSinceEpoch}',
      type: StoryElementType.text,
      content: text,
      position: const Offset(0.5, 0.42),
      color: selectedColor,
      backgroundColor: useBackground
          ? Colors.black.withValues(alpha: 0.42)
          : null,
    );
    _addElement(element);
  }

  Future<void> _addSticker() async {
    final sticker = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => const _StoryStickerSheet(),
    );
    if (sticker == null || !mounted) return;
    _addElement(
      StoryElement(
        id: 'sticker-${DateTime.now().microsecondsSinceEpoch}',
        type: StoryElementType.sticker,
        content: sticker,
        position: const Offset(0.68, 0.58),
      ),
    );
  }

  Future<void> _addPhotoLayer() async {
    final file = await _pickGalleryImageFile();
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    _addElement(
      StoryElement(
        id: 'photo-${DateTime.now().microsecondsSinceEpoch}',
        type: StoryElementType.image,
        content: file.path,
        imageBytes: bytes,
        position: const Offset(0.56, 0.54),
        scale: 1,
        rotation: -0.04,
      ),
    );
  }

  Future<void> _chooseFilter() async {
    final selected = await showModalBottomSheet<StoryVisualFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var pending = _draft.visualFilter;
        return StatefulBuilder(
          builder: (context, setSheetState) => DraggableScrollableSheet(
            initialChildSize: 0.68,
            minChildSize: 0.48,
            maxChildSize: 0.86,
            builder: (context, controller) => Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              decoration: BoxDecoration(
                color: AppTheme.nightSoft,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border(
                  top: BorderSide(
                    color: AppTheme.violet.withValues(alpha: 0.42),
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _StorySheetHandle(),
                    const SizedBox(height: 14),
                    const _StorySheetHeader(
                      icon: Icons.auto_awesome_rounded,
                      title: 'Filtros HallyuHub',
                      subtitle:
                          'Elegí un estilo sin modificar tu archivo original.',
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: GridView.builder(
                        controller: controller,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 1.34,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                        itemCount: StoryVisualFilter.values.length,
                        itemBuilder: (context, index) {
                          final filter = StoryVisualFilter.values[index];
                          return _FilterChoice(
                            key: ValueKey('story-filter-${filter.name}'),
                            filter: filter,
                            selected: pending == filter,
                            onTap: () => setSheetState(() => pending = filter),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: const ValueKey('story-filter-apply'),
                      onPressed: () => Navigator.of(sheetContext).pop(pending),
                      icon: const Icon(Icons.check_rounded),
                      label: Text(
                        pending == StoryVisualFilter.original
                            ? 'Usar original'
                            : 'Aplicar ${pending.label}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    _updateDraft(_draft.copyWith(visualFilter: selected));
  }

  Future<void> _chooseMusic() async {
    final result = await showModalBottomSheet<_MusicPickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) =>
          _StoryMusicSheet(audio: _audio, selectedAsset: _draft.musicAsset),
    );
    unawaited(_audio.stop());
    if (!mounted) return;
    if (result == null) {
      _logStoryEditor('STORY_MUSIC_SELECTION_DISMISSED');
      return;
    }
    if (result.clearMusic) {
      _logStoryEditor('STORY_MUSIC_SELECTION_CLEARED');
      _clearMusic();
      return;
    }
    final track = result.track;
    if (track == null) return;
    _logStoryEditor('STORY_MUSIC_SELECTION_OK track=${track.id}');
    _updateDraft(
      _draft.copyWith(music: track.label, musicAsset: track.assetPath),
    );
  }

  Future<void> _openTaggingPanel() async {
    await _openStoryTagsPanel();
  }

  Future<void> _openStoryTagsPanel() async {
    var selectedUsers = _selectedTaggedUsers.toList(growable: true);
    var selectedEntities = _selectedTaggedEntities.toList(growable: true);
    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => DraggableScrollableSheet(
          initialChildSize: .72,
          minChildSize: .42,
          maxChildSize: .92,
          builder: (context, controller) => Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            decoration: BoxDecoration(
              color: AppTheme.night,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              border: Border(
                top: BorderSide(color: AppTheme.violet.withValues(alpha: 0.42)),
              ),
            ),
            child: ListView(
              controller: controller,
              children: [
                const _StorySheetHandle(),
                const SizedBox(height: 14),
                const _StorySheetHeader(
                  icon: Icons.sell_outlined,
                  title: 'Etiquetar en la historia',
                  subtitle: 'Conectá tu momento con fans, grupos e idols.',
                ),
                const SizedBox(height: 16),
                UserTagSelector(
                  followService: widget.followService,
                  currentUser: widget.currentUser,
                  selectedUsers: selectedUsers,
                  onChanged: (users) =>
                      setSheetState(() => selectedUsers = users),
                  searchFieldKey: const ValueKey('tag-panel-search'),
                  title: 'Etiquetar personas',
                  subtitle: 'Buscá fans reales por nombre o @usuario.',
                  showEmptyOnlyAfterSearch: true,
                ),
                const SizedBox(height: 14),
                ArtistTagSelector(
                  artistTagService: widget.artistTagService,
                  selectedEntities: selectedEntities,
                  onChanged: (entities) =>
                      setSheetState(() => selectedEntities = entities),
                  title: 'Etiquetar artista o grupo',
                  subtitle: 'La etiqueta abrirá la ficha real del artista.',
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed:
                      _sameProfileIds(selectedUsers, _selectedTaggedUsers) &&
                          _sameEntityIds(
                            selectedEntities,
                            _selectedTaggedEntities,
                          )
                      ? null
                      : () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Aplicar etiquetas'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || applied != true) return;
    _selectedTaggedUsers = selectedUsers.take(10).toList(growable: false);
    _selectedTaggedEntities = selectedEntities.take(10).toList(growable: false);
    final usernames = _selectedTaggedUsers
        .map((profile) => profile.username.trim())
        .where((username) => username.isNotEmpty)
        .map((username) => username.startsWith('@') ? username : '@$username')
        .toList(growable: false);
    final ids = _selectedTaggedUsers
        .map((profile) => profile.id)
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final entityLabels = _selectedTaggedEntities
        .map((entity) => entity.name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    final elements = _draft.elements
        .where((element) => element.id != 'story-user-tags')
        .where((element) => element.id != 'story-artist-tags')
        .toList(growable: true);
    if (usernames.isNotEmpty) {
      elements.add(
        StoryElement(
          id: 'story-user-tags',
          type: StoryElementType.text,
          content: 'Con ${usernames.join(', ')}',
          position: const Offset(0.5, 0.72),
          scale: 0.9,
          color: AppTheme.cyan,
          backgroundColor: Colors.black.withValues(alpha: 0.42),
        ),
      );
    }
    if (entityLabels.isNotEmpty) {
      elements.add(
        StoryElement(
          id: 'story-artist-tags',
          type: StoryElementType.text,
          content: 'Etiquetado: ${entityLabels.join(', ')}',
          position: const Offset(0.5, 0.8),
          scale: 0.82,
          color: AppTheme.amber,
          backgroundColor: Colors.black.withValues(alpha: 0.42),
        ),
      );
    }
    _updateDraft(
      _draft.copyWith(
        elements: elements,
        taggedPeople: usernames,
        taggedUserIds: ids,
        taggedUsers: _selectedTaggedUsers,
        taggedEntities: _selectedTaggedEntities,
      ),
    );
  }

  Future<void> _pickGallery() async {
    final file = await _pickGalleryFile();
    if (file == null || !mounted) return;
    await _useFile(file);
  }

  Future<bool> _ensureGalleryAccess() async {
    final allowed = await requestContextualPermission(
      context: context,
      permissionService: _permissionService,
      icon: Icons.photo_library_outlined,
      title: 'Elegir desde tu galería',
      detail:
          'HallyuHub necesita acceso únicamente para que selecciones la foto o video que querés usar.',
      allowLabel: 'Permitir galería',
      currentStatus: _permissionService.galleryStatus,
      request: _permissionService.requestGalleryAccess,
    );
    return allowed && mounted;
  }

  Future<XFile?> _pickGalleryFile() async {
    final allowed = await _ensureGalleryAccess();
    if (!allowed || !mounted) return null;
    return _picker.pickMedia(imageQuality: 86, maxWidth: 1440);
  }

  Future<XFile?> _pickGalleryImageFile() async {
    final allowed = await _ensureGalleryAccess();
    if (!allowed || !mounted) return null;
    return _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 86,
      maxWidth: 1440,
    );
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
    final video = forceVideo ?? _isVideo(file);
    final bytes = video ? null : await file.readAsBytes();
    if (!mounted) return;
    _updateDraft(
      _draft.copyWith(
        type: video ? StoryContentType.video : StoryContentType.image,
        imageAsset: '',
        imageBytes: bytes,
        clearImageBytes: video,
        mediaPath: file.path,
        mediaScale: 1,
        mediaOffset: Offset.zero,
        mediaRotation: 0,
        videoTrimStartSeconds: 0,
        videoTrimEndSeconds: video ? 60 : null,
        clearVideoTrimEndSeconds: !video,
        videoMuted: false,
      ),
    );
    setState(() => _videoDurationSeconds = null);
  }

  bool _isVideo(XFile file) {
    final mimeType = file.mimeType ?? '';
    return mimeType.startsWith('video/') ||
        RegExp(
          r'\.(mp4|mov|m4v|webm)$',
          caseSensitive: false,
        ).hasMatch(file.path);
  }

  void _publish() {
    if (!_hasValidContent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agregá una foto, texto o sticker primero.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop(_draft);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.night,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close),
                    color: Colors.white,
                    tooltip: 'Cerrar editor',
                  ),
                  const Expanded(
                    child: Text(
                      'Editar historia',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  FilledButton(
                    key: const ValueKey('story-editor-publish'),
                    onPressed: _hasValidContent ? _publish : null,
                    child: const Text('Publicar'),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: HallyFeatureTip(
                featureId: 'stories_intro',
                title: 'Historias de fans 💫',
                message: 'Compartí un momento con tus seguidores.',
                mascotAsset: 'assets/brand/hally_mascot_wave_transparent.png',
                compact: true,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.violet.withValues(alpha: 0.22),
                            blurRadius: 28,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            KeyedSubtree(
                              key: const ValueKey('story-editor-canvas'),
                              child: StoryCanvas(
                                key: _canvasKey,
                                contentType: _draft.type,
                                imageAsset: _draft.imageAsset,
                                imageBytes: _draft.imageBytes,
                                mediaPath: _draft.mediaPath,
                                backgroundColors: _draft.backgroundColors,
                                elements: _draft.elements,
                                mediaScale: _draft.mediaScale,
                                mediaOffset: _draft.mediaOffset,
                                mediaRotation: _draft.mediaRotation,
                                visualFilter: _draft.visualFilter,
                                videoTrimStartSeconds:
                                    _draft.videoTrimStartSeconds,
                                videoTrimEndSeconds: _draft.videoTrimEndSeconds,
                                videoMuted: _draft.videoMuted,
                                editable: true,
                                selectedMedia: _mediaSelected,
                                selectedElementId: _selectedElementId,
                                onMediaSelected: _selectMedia,
                                onElementSelected: _selectElement,
                                onElementChanged: _updateElement,
                                onMediaChanged: (scale, offset, rotation) =>
                                    _updateDraft(
                                      _draft.copyWith(
                                        mediaScale: scale,
                                        mediaOffset: offset,
                                        mediaRotation: rotation,
                                      ),
                                    ),
                                onManipulationStart: _startManipulation,
                                onManipulationUpdate: _updateDeleteTarget,
                                onManipulationEnd: _finishManipulation,
                                onVideoDurationChanged: _handleVideoDuration,
                              ),
                            ),
                            if (!_hasMedia)
                              Center(
                                child: OutlinedButton.icon(
                                  key: const ValueKey(
                                    'story-editor-empty-photo',
                                  ),
                                  onPressed: _pickGallery,
                                  icon: const Icon(
                                    Icons.add_photo_alternate_outlined,
                                  ),
                                  label: const Text('Elegir foto'),
                                ),
                              ),
                            if (_draggingTargetId != null)
                              _DeleteDropZone(highlighted: _deleteArmed),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_selectedScale != null)
              _SelectionControls(
                scale: _selectedScale!,
                min: _mediaSelected ? 0.55 : 0.45,
                max: _mediaSelected ? 4 : 3.5,
                onDecrease: () => _adjustSelectedScale(-0.15),
                onIncrease: () => _adjustSelectedScale(0.15),
                onChanged: _setSelectedScale,
                onDelete: _deleteSelectedElement,
                canReorder: _selectedElementId != null,
                onBringForward: _bringSelectedForward,
                onSendBackward: _sendSelectedBackward,
              ),
            if (_draft.type == StoryContentType.video)
              _VideoTrimControls(
                durationSeconds: _videoDurationSeconds,
                startSeconds: _draft.videoTrimStartSeconds,
                endSeconds: _draft.videoTrimEndSeconds,
                muted: _draft.videoMuted,
                onChanged: _updateVideoTrim,
                onToggleMute: () => _updateDraft(
                  _draft.copyWith(videoMuted: !_draft.videoMuted),
                ),
              ),
            if (_draft.music.isNotEmpty)
              Container(
                key: const ValueKey('story-editor-selected-music'),
                margin: const EdgeInsets.fromLTRB(18, 0, 18, 7),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.violet.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppTheme.cyan.withValues(alpha: 0.32),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.music_note_rounded,
                      color: AppTheme.cyan,
                      size: 17,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _draft.music,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('story-editor-remove-music'),
                      onPressed: _clearMusic,
                      icon: const Icon(Icons.close_rounded),
                      color: Colors.white70,
                      tooltip: 'Quitar música',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            _EditorToolbar(
              hasSelection: _selectedElementId != null || _mediaSelected,
              hasMusic: _draft.musicAsset.isNotEmpty,
              hasText: _hasTextLayer,
              hasSticker: _hasStickerLayer,
              hasPhotoLayer: _hasPhotoLayer,
              hasFilter: _draft.visualFilter != StoryVisualFilter.original,
              hasTags: _hasTags,
              onText: _addText,
              onSticker: _addSticker,
              onAddPhoto: _addPhotoLayer,
              onFilter: _chooseFilter,
              onMusic: _chooseMusic,
              onTagging: _openTaggingPanel,
              onGallery: _pickGallery,
              onCamera: _capture,
              onDelete: _deleteSelectedElement,
            ),
          ],
        ),
      ),
    );
  }
}

void _logStoryEditor(String message) {
  assert(() {
    debugPrint(message);
    return true;
  }());
}

class _StoryStickerSheet extends StatefulWidget {
  const _StoryStickerSheet();

  @override
  State<_StoryStickerSheet> createState() => _StoryStickerSheetState();
}

class _StoryStickerSheetState extends State<_StoryStickerSheet> {
  int _selectedCategory = 0;

  static const _categories = <_StickerCategory>[
    _StickerCategory('K-pop', Icons.auto_awesome_rounded, [
      '✨',
      '💜',
      '⭐',
      '🎧',
      '💿',
      '🎤',
      '💎',
      '🫶',
    ]),
    _StickerCategory('Cute', Icons.favorite_outline_rounded, [
      '🎀',
      '🌙',
      '🐰',
      '🐱',
      '🌸',
      '🍓',
      '☁️',
      '💕',
    ]),
    _StickerCategory('Celebración', Icons.celebration_outlined, [
      '🎉',
      '🥳',
      '🔥',
      '🎊',
      '🪩',
      '💥',
      '🎈',
      '🏆',
    ]),
    _StickerCategory('Música', Icons.music_note_rounded, [
      '🎵',
      '🎶',
      '🎼',
      '🎹',
      '🥁',
      '🎸',
      '🎧',
      '🎤',
    ]),
    _StickerCategory('Fandom', Icons.groups_2_outlined, [
      '🫰',
      '🫶',
      '💡',
      '📸',
      '💌',
      '👑',
      '🚀',
      '💜',
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    final category = _categories[_selectedCategory];
    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.42,
      maxChildSize: 0.82,
      builder: (context, controller) => Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        decoration: BoxDecoration(
          color: AppTheme.nightSoft,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: AppTheme.violet.withValues(alpha: 0.42)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _StorySheetHandle(),
              const SizedBox(height: 14),
              const _StorySheetHeader(
                icon: Icons.emoji_emotions_outlined,
                title: 'Stickers y emojis',
                subtitle: 'Elegí uno y después movelo o cambiale el tamaño.',
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_categories.length, (index) {
                    final item = _categories[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: index == _selectedCategory,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = index),
                        avatar: Icon(item.icon, size: 16),
                        label: Text(item.label),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: GridView.builder(
                  controller: controller,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: category.stickers.length,
                  itemBuilder: (context, index) {
                    final sticker = category.stickers[index];
                    return InkWell(
                      key: ValueKey('story-sticker-$sticker'),
                      onTap: () => Navigator.of(context).pop(sticker),
                      borderRadius: BorderRadius.circular(18),
                      child: Ink(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            sticker,
                            style: const TextStyle(fontSize: 30),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StickerCategory {
  const _StickerCategory(this.label, this.icon, this.stickers);

  final String label;
  final IconData icon;
  final List<String> stickers;
}

class _StoryMusicSheet extends StatefulWidget {
  const _StoryMusicSheet({required this.audio, required this.selectedAsset});

  final StoryAudioController audio;
  final String selectedAsset;

  @override
  State<_StoryMusicSheet> createState() => _StoryMusicSheetState();
}

class _StoryMusicSheetState extends State<_StoryMusicSheet> {
  String _previewAsset = '';
  String _loadingAsset = '';
  String? _errorMessage;

  @override
  void dispose() {
    unawaited(widget.audio.stop());
    super.dispose();
  }

  Future<void> _togglePreview(StoryMusic track) async {
    if (_loadingAsset.isNotEmpty) return;
    final isCurrent = _previewAsset == track.assetPath;
    if (isCurrent && widget.audio.isPlaying) {
      await widget.audio.pause();
      if (mounted) setState(() {});
      return;
    }
    setState(() {
      _loadingAsset = track.assetPath;
      _errorMessage = null;
    });
    await widget.audio.play(track.assetPath);
    if (!mounted) return;
    setState(() {
      _loadingAsset = '';
      if (widget.audio.activeAsset == track.assetPath) {
        _previewAsset = track.assetPath;
      } else {
        _previewAsset = '';
        _errorMessage =
            'No pudimos reproducir este audio. Probá con otra opción.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.52,
      maxChildSize: 0.94,
      builder: (context, controller) => Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        decoration: BoxDecoration(
          color: AppTheme.nightSoft,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: AppTheme.violet.withValues(alpha: 0.42)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _StorySheetHandle(),
              const SizedBox(height: 14),
              const _StorySheetHeader(
                icon: Icons.music_note_rounded,
                title: 'Música para tu historia',
                subtitle: 'Elegí un audio para acompañar tu historia.',
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                _StoryInlineNotice(
                  icon: Icons.info_outline_rounded,
                  message: _errorMessage!,
                ),
              ],
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  controller: controller,
                  itemCount: storyMusicLibrary.length + 1,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final selected = widget.selectedAsset.isEmpty;
                      return _MusicNoneTile(
                        selected: selected,
                        onTap: () => Navigator.of(
                          context,
                        ).pop(const _MusicPickerResult.clear()),
                      );
                    }
                    final track = storyMusicLibrary[index - 1];
                    final previewing =
                        _previewAsset == track.assetPath &&
                        widget.audio.isPlaying;
                    return _MusicTrackTile(
                      key: ValueKey('story-music-${track.id}'),
                      track: track,
                      selected: widget.selectedAsset == track.assetPath,
                      previewing: previewing,
                      loading: _loadingAsset == track.assetPath,
                      onPreview: () => _togglePreview(track),
                      onSelect: () {
                        _logStoryEditor(
                          'STORY_MUSIC_SELECT_TAP track=${track.id}',
                        );
                        Navigator.of(
                          context,
                        ).pop(_MusicPickerResult.track(track));
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MusicTrackTile extends StatelessWidget {
  const _MusicTrackTile({
    super.key,
    required this.track,
    required this.selected,
    required this.previewing,
    required this.loading,
    required this.onPreview,
    required this.onSelect,
  });

  final StoryMusic track;
  final bool selected;
  final bool previewing;
  final bool loading;
  final VoidCallback onPreview;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? track.color.withValues(alpha: 0.14)
          : Colors.white.withValues(alpha: 0.045),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? track.color.withValues(alpha: 0.66)
                  : Colors.white.withValues(alpha: 0.09),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      track.color.withValues(alpha: 0.95),
                      AppTheme.violet,
                    ],
                  ),
                ),
                child: IconButton(
                  onPressed: loading ? null : onPreview,
                  tooltip: previewing ? 'Pausar preview' : 'Escuchar preview',
                  icon: loading
                      ? const SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          previewing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                        ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${track.mood} · ${track.durationLabel}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (selected)
                const _SelectedMusicBadge()
              else
                TextButton(
                  key: ValueKey('story-music-select-${track.id}'),
                  onPressed: onSelect,
                  child: const Text('Elegir'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedMusicBadge extends StatelessWidget {
  const _SelectedMusicBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.cyan.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.42)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 14, color: AppTheme.cyan),
          SizedBox(width: 3),
          Text(
            'Seleccionado',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MusicNoneTile extends StatelessWidget {
  const _MusicNoneTile({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppTheme.cyan.withValues(alpha: 0.12)
          : Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(18),
      child: ListTile(
        key: const ValueKey('story-music-none'),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected
                ? AppTheme.cyan.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.09),
          ),
        ),
        leading: const CircleAvatar(
          backgroundColor: Color(0x25FFFFFF),
          child: Icon(Icons.music_off_outlined, color: Colors.white70),
        ),
        title: const Text(
          'Sin música',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          'Publicar solo con el audio original del video.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.56)),
        ),
        trailing: selected
            ? const Icon(Icons.check_circle_rounded, color: AppTheme.cyan)
            : null,
      ),
    );
  }
}

class _MusicPickerResult {
  const _MusicPickerResult.track(this.track) : clearMusic = false;
  const _MusicPickerResult.clear() : track = null, clearMusic = true;

  final StoryMusic? track;
  final bool clearMusic;
}

class _StorySheetHandle extends StatelessWidget {
  const _StorySheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.24),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

class _StorySheetHeader extends StatelessWidget {
  const _StorySheetHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.rose.withValues(alpha: 0.86),
                AppTheme.violet.withValues(alpha: 0.86),
                AppTheme.cyan.withValues(alpha: 0.76),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Colors.white, size: 21),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StoryInlineNotice extends StatelessWidget {
  const _StoryInlineNotice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppTheme.rose.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.rose.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.rose, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

bool _sameProfileIds(
  List<CommunityProfile> left,
  List<CommunityProfile> right,
) =>
    left
        .map((item) => item.id)
        .toSet()
        .containsAll(right.map((item) => item.id)) &&
    right
        .map((item) => item.id)
        .toSet()
        .containsAll(left.map((item) => item.id));

bool _sameEntityIds(List<KpopEntity> left, List<KpopEntity> right) =>
    left
        .map((item) => item.id)
        .toSet()
        .containsAll(right.map((item) => item.id)) &&
    right
        .map((item) => item.id)
        .toSet()
        .containsAll(left.map((item) => item.id));

class _FilterChoice extends StatelessWidget {
  const _FilterChoice({
    super.key,
    required this.filter,
    required this.selected,
    required this.onTap,
  });

  final StoryVisualFilter filter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 118,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: selected ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AppTheme.cyan
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 72,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFEF4F7A), Color(0xFF4DE7FF)],
                        ),
                      ),
                    ),
                    if (filter != StoryVisualFilter.original)
                      StoryFilterOverlay(filter: filter),
                    if (selected)
                      const Positioned(
                        top: 7,
                        right: 7,
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              filter.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionControls extends StatelessWidget {
  const _SelectionControls({
    required this.scale,
    required this.min,
    required this.max,
    required this.onDecrease,
    required this.onIncrease,
    required this.onChanged,
    required this.onDelete,
    required this.canReorder,
    required this.onBringForward,
    required this.onSendBackward,
  });

  final double scale;
  final double min;
  final double max;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final ValueChanged<double> onChanged;
  final VoidCallback onDelete;
  final bool canReorder;
  final VoidCallback onBringForward;
  final VoidCallback onSendBackward;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('story-editor-selection-controls'),
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 7),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('story-editor-scale-down'),
            onPressed: onDecrease,
            icon: const Icon(Icons.remove_rounded),
            color: Colors.white,
            tooltip: 'Achicar elemento',
          ),
          Expanded(
            child: Slider(
              key: const ValueKey('story-editor-scale-slider'),
              value: scale.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
          IconButton(
            key: const ValueKey('story-editor-scale-up'),
            onPressed: onIncrease,
            icon: const Icon(Icons.add_rounded),
            color: Colors.white,
            tooltip: 'Agrandar elemento',
          ),
          IconButton(
            key: const ValueKey('story-editor-selection-delete'),
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
            color: AppTheme.rose,
            tooltip: 'Eliminar elemento',
          ),
          if (canReorder) ...[
            IconButton(
              key: const ValueKey('story-editor-send-back'),
              onPressed: onSendBackward,
              icon: const Icon(Icons.flip_to_back_rounded),
              color: AppTheme.cyan,
              tooltip: 'Enviar atrás',
            ),
            IconButton(
              key: const ValueKey('story-editor-bring-forward'),
              onPressed: onBringForward,
              icon: const Icon(Icons.flip_to_front_rounded),
              color: AppTheme.cyan,
              tooltip: 'Traer al frente',
            ),
          ],
        ],
      ),
    );
  }
}

class _VideoTrimControls extends StatelessWidget {
  const _VideoTrimControls({
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
    final selectedDuration = (end - startSeconds).clamp(0.1, 60).toDouble();
    return Container(
      key: const ValueKey('story-editor-video-trim'),
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 7),
      padding: const EdgeInsets.fromLTRB(11, 7, 8, 7),
      decoration: BoxDecoration(
        color: AppTheme.violet.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.24)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.content_cut_rounded, color: AppTheme.cyan),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  duration == null
                      ? 'Preparando recorte de video...'
                      : 'Fragmento ${_formatSeconds(selectedDuration)} · máximo 60 s',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('story-editor-video-mute'),
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
              key: const ValueKey('story-editor-video-trim-slider'),
              values: RangeValues(
                startSeconds.clamp(0, duration),
                end.clamp(0.1, duration),
              ),
              min: 0,
              max: duration,
              labels: RangeLabels(
                _formatSeconds(startSeconds),
                _formatSeconds(end),
              ),
              onChanged: onChanged,
            ),
          if (duration != null && duration > 60)
            Text(
              'El video original dura ${_formatSeconds(duration)}. Publicaremos solo el tramo seleccionado.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

String _formatSeconds(double seconds) {
  final rounded = seconds.round();
  final minutes = rounded ~/ 60;
  final remainder = rounded % 60;
  return '$minutes:${remainder.toString().padLeft(2, '0')}';
}

class _DeleteDropZone extends StatelessWidget {
  const _DeleteDropZone({required this.highlighted});

  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: AnimatedContainer(
          key: const ValueKey('story-editor-delete-zone'),
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: highlighted
                ? AppTheme.rose.withValues(alpha: 0.96)
                : Colors.black.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: highlighted
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: highlighted
                    ? AppTheme.rose.withValues(alpha: 0.7)
                    : Colors.black26,
                blurRadius: highlighted ? 22 : 8,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.delete_outline_rounded,
                color: Colors.white,
                size: highlighted ? 24 : 21,
              ),
              const SizedBox(width: 6),
              Text(
                highlighted ? 'Soltá para eliminar' : 'Eliminar',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.hasSelection,
    required this.hasMusic,
    required this.hasText,
    required this.hasSticker,
    required this.hasPhotoLayer,
    required this.hasFilter,
    required this.hasTags,
    required this.onText,
    required this.onSticker,
    required this.onAddPhoto,
    required this.onFilter,
    required this.onMusic,
    required this.onTagging,
    required this.onGallery,
    required this.onCamera,
    required this.onDelete,
  });

  final bool hasSelection;
  final bool hasMusic;
  final bool hasText;
  final bool hasSticker;
  final bool hasPhotoLayer;
  final bool hasFilter;
  final bool hasTags;
  final VoidCallback onText;
  final VoidCallback onSticker;
  final VoidCallback onAddPhoto;
  final VoidCallback onFilter;
  final VoidCallback onMusic;
  final VoidCallback onTagging;
  final VoidCallback onGallery;
  final VoidCallback onCamera;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: AppTheme.nightSoft.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 18,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _EditorAction(
                key: const ValueKey('story-editor-tool-text'),
                icon: Icons.text_fields_rounded,
                label: 'Texto',
                active: hasText,
                onTap: onText,
              ),
              _EditorAction(
                key: const ValueKey('story-editor-tool-sticker'),
                icon: Icons.emoji_emotions_outlined,
                label: 'Sticker',
                active: hasSticker,
                onTap: onSticker,
              ),
              _EditorAction(
                key: const ValueKey('story-editor-tool-add-photo'),
                icon: Icons.add_photo_alternate_outlined,
                label: 'Foto',
                active: hasPhotoLayer,
                onTap: onAddPhoto,
              ),
              _EditorAction(
                key: const ValueKey('story-editor-tool-filter'),
                icon: Icons.auto_awesome_rounded,
                label: 'Filtro',
                active: hasFilter,
                onTap: onFilter,
              ),
              _EditorAction(
                key: const ValueKey('story-editor-tool-music'),
                icon: hasMusic
                    ? Icons.music_note_rounded
                    : Icons.music_note_outlined,
                label: 'Música',
                active: hasMusic,
                onTap: onMusic,
              ),
              _EditorAction(
                key: const ValueKey('story-editor-tool-tagging'),
                icon: Icons.sell_outlined,
                label: 'Etiquetar',
                active: hasTags,
                onTap: onTagging,
              ),
              _EditorAction(
                icon: Icons.photo_library_outlined,
                label: 'Galería',
                onTap: onGallery,
              ),
              _EditorAction(
                icon: Icons.photo_camera_outlined,
                label: 'Cámara',
                onTap: onCamera,
              ),
              if (hasSelection)
                _EditorAction(
                  key: const ValueKey('story-editor-tool-delete'),
                  icon: Icons.delete_outline_rounded,
                  label: 'Borrar',
                  color: AppTheme.rose,
                  onTap: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorAction extends StatelessWidget {
  const _EditorAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          width: 62,
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: active
                ? AppTheme.violet.withValues(alpha: 0.24)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? AppTheme.cyan.withValues(alpha: 0.42)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, color: active ? AppTheme.cyan : color, size: 22),
                  if (active)
                    const Positioned(
                      right: -7,
                      top: -5,
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 12,
                        color: AppTheme.rose,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : color.withValues(alpha: 0.88),
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
