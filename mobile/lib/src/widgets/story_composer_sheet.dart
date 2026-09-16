import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';

class StoryComposerSheet extends StatefulWidget {
  const StoryComposerSheet({
    super.key,
    required this.templates,
    required this.onPublish,
    required this.onCamera,
    required this.onGallery,
  });

  final List<StoryTemplate> templates;
  final ValueChanged<StoryDraft> onPublish;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  State<StoryComposerSheet> createState() => _StoryComposerSheetState();
}

class _StoryComposerSheetState extends State<StoryComposerSheet> {
  final _textController = TextEditingController();
  final _textFocusNode = FocusNode();
  int _selectedBackground = 0;

  static const _backgrounds = <List<Color>>[
    [Color(0xFFEF4F7A), Color(0xFFA855F7)],
    [Color(0xFF00A6A6), Color(0xFF4C6FFF)],
    [Color(0xFFFFB703), Color(0xFFEF4F7A)],
  ];

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  void _publishText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final element = StoryElement(
      id: 'text-${DateTime.now().microsecondsSinceEpoch}',
      type: StoryElementType.text,
      content: text,
      position: const Offset(0.5, 0.45),
    );
    widget.onPublish(
      StoryDraft(
        type: StoryContentType.text,
        text: text,
        title: 'Mi historia',
        elements: [element],
        backgroundColors: _backgrounds[_selectedBackground],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
        decoration: BoxDecoration(
          color: AppTheme.nightSoft,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border(
            top: BorderSide(color: AppTheme.violet.withValues(alpha: 0.42)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SheetHandle(),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppTheme.rose,
                            AppTheme.violet,
                            AppTheme.cyan,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.auto_stories_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Crear historia',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Compartí un momento rápido con tu fandom.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.64),
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Elegí cómo empezar',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _CreateStoryAction(
                        key: const ValueKey('story-create-camera'),
                        icon: Icons.photo_camera_outlined,
                        label: 'Cámara',
                        color: AppTheme.cyan,
                        onTap: widget.onCamera,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _CreateStoryAction(
                        key: const ValueKey('story-create-gallery'),
                        icon: Icons.photo_library_outlined,
                        label: 'Galería',
                        color: AppTheme.rose,
                        onTap: widget.onGallery,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _CreateStoryAction(
                        key: const ValueKey('story-create-text'),
                        icon: Icons.text_fields_rounded,
                        label: 'Texto',
                        color: AppTheme.violet,
                        onTap: _textFocusNode.requestFocus,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Divider(color: Colors.white.withValues(alpha: 0.1)),
                const SizedBox(height: 14),
                const Text(
                  'Historia de texto',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 9),
                TextField(
                  key: const ValueKey('story-text-input'),
                  controller: _textController,
                  focusNode: _textFocusNode,
                  onChanged: (_) => setState(() {}),
                  minLines: 2,
                  maxLines: 3,
                  maxLength: 140,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Escribí algo para tu comunidad...',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.46),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.07),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    ...List.generate(_backgrounds.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 9),
                        child: InkWell(
                          key: ValueKey('story-background-$index'),
                          onTap: () =>
                              setState(() => _selectedBackground = index),
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: _backgrounds[index],
                              ),
                              border: Border.all(
                                color: index == _selectedBackground
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    const Spacer(),
                    FilledButton.icon(
                      key: const ValueKey('story-publish-text'),
                      onPressed: _textController.text.trim().isEmpty
                          ? null
                          : _publishText,
                      icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                      label: const Text('Abrir editor'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateStoryAction extends StatelessWidget {
  const _CreateStoryAction({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}
