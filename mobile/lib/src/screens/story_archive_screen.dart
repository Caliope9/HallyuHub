import 'package:flutter/material.dart';

import '../models.dart';
import '../services/local_story_service.dart';
import '../services/story_time.dart';
import '../theme/app_theme.dart';

class StoryArchiveScreen extends StatefulWidget {
  const StoryArchiveScreen({
    super.key,
    this.storyService = const LocalStoryService(),
  });

  final LocalStoryService storyService;

  @override
  State<StoryArchiveScreen> createState() => _StoryArchiveScreenState();
}

class _StoryArchiveScreenState extends State<StoryArchiveScreen> {
  List<Story> _stories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final stories = await widget.storyService.restoreStoryArchive();
    if (!mounted) return;
    setState(() {
      _stories = stories;
      _loading = false;
    });
  }

  Future<void> _repost(Story story) async {
    final memory = await widget.storyService.repostFromArchive(story);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${memory.memoryLabel} publicado'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.nightSoft,
        ),
      );
    await _restore();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.night,
      appBar: AppBar(
        backgroundColor: AppTheme.night,
        foregroundColor: Colors.white,
        title: const Text(
          'Archivo privado',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _stories.isEmpty
          ? const _EmptyArchive()
          : GridView.builder(
              key: const ValueKey('story-archive-grid'),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.62,
              ),
              itemCount: _stories.length,
              itemBuilder: (context, index) {
                final story = _stories[index];
                return _ArchiveStoryCard(
                  story: story,
                  onRepost: () => _repost(story),
                );
              },
            ),
    );
  }
}

class _ArchiveStoryCard extends StatelessWidget {
  const _ArchiveStoryCard({required this.story, required this.onRepost});

  final Story story;
  final VoidCallback onRepost;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('story-archive-${story.id}'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _ArchivePreview(story: story)),
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 8, 9, 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  story.memoryLabel.isEmpty
                      ? storyRelativeTime(story)
                      : story.memoryLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.cyan,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: ValueKey('story-archive-repost-${story.id}'),
                    onPressed: onRepost,
                    icon: const Icon(Icons.history_rounded, size: 16),
                    label: const Text('Recuerdo'),
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

class _ArchivePreview extends StatelessWidget {
  const _ArchivePreview({required this.story});

  final Story story;

  @override
  Widget build(BuildContext context) {
    if (story.imageBytes != null) {
      return Image.memory(story.imageBytes!, fit: BoxFit.cover);
    }
    if (story.imageAsset.isNotEmpty) {
      return Image.asset(story.imageAsset, fit: BoxFit.cover);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: story.backgroundColors),
      ),
      child: Center(
        child: Icon(
          story.contentType == StoryContentType.video
              ? Icons.videocam_outlined
              : Icons.text_fields_rounded,
          color: Colors.white,
          size: 36,
        ),
      ),
    );
  }
}

class _EmptyArchive extends StatelessWidget {
  const _EmptyArchive();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          'Tus historias publicadas se guardarán acá de forma privada.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.68),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
