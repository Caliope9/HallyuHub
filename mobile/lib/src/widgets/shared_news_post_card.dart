import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../theme/app_theme.dart';

class SharedNewsPostCard extends StatefulWidget {
  const SharedNewsPostCard({super.key, required this.news, this.onOpen});

  final SharedNewsPostContent news;
  final ValueChanged<String>? onOpen;

  @override
  State<SharedNewsPostCard> createState() => _SharedNewsPostCardState();
}

class _SharedNewsPostCardState extends State<SharedNewsPostCard> {
  bool _imageFailed = false;

  SharedNewsPostContent get news => widget.news;

  Uri? get _articleUri {
    final uri = Uri.tryParse(news.articleUrl.trim());
    if (uri == null ||
        !{'https', 'http'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      return null;
    }
    return uri;
  }

  String get _imageUrl {
    final value = news.imageUrl.trim();
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !{'https', 'http'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      return '';
    }
    return value;
  }

  Future<void> _openArticle(BuildContext context) async {
    final uri = _articleUri;
    if (uri == null) return;
    if (widget.onOpen != null) {
      widget.onOpen!(uri.toString());
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pudimos abrir esta noticia.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pudimos abrir esta noticia.')),
        );
      }
    }
  }

  @override
  void didUpdateWidget(covariant SharedNewsPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.news.imageUrl != widget.news.imageUrl) {
      _imageFailed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _imageUrl;
    final showImage = imageUrl.isNotEmpty && !_imageFailed;
    return Semantics(
      container: true,
      label: 'Noticia compartida: ${news.title}. Fuente: ${news.source}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.nightSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.violet.withValues(alpha: 0.42)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showImage)
                InkWell(
                  key: const ValueKey('shared-news-cover-open'),
                  onTap: () => _openArticle(context),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _imageFailed = true);
                        });
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(15, showImage ? 13 : 15, 15, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.rose.withValues(alpha: .16),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text(
                            'Noticias',
                            style: TextStyle(
                              color: AppTheme.rose,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            [
                              news.source.trim().isEmpty
                                  ? 'Fuente por confirmar'
                                  : news.source.trim(),
                              if (news.publishedLabel.trim().isNotEmpty)
                                news.publishedLabel.trim(),
                            ].join(' · '),
                            key: const ValueKey('shared-news-source'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.cyan,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (!showImage)
                      Container(
                        key: const ValueKey('shared-news-fallback'),
                        margin: const EdgeInsets.only(bottom: 7),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF261746), Color(0xFF123447)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Wrap(
                          spacing: 5,
                          runSpacing: 2,
                          children: [
                            Text(
                              'HallyuHub Noticias',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '· sin imagen disponible',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    InkWell(
                      key: const ValueKey('shared-news-title-open'),
                      onTap: () => _openArticle(context),
                      child: Text(
                        news.title,
                        key: const ValueKey('shared-news-title'),
                        maxLines: showImage ? 3 : 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          height: 1.2,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (news.summary.trim().isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        news.summary.trim(),
                        key: const ValueKey('shared-news-summary'),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          height: 1.3,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        key: const ValueKey('shared-news-open'),
                        onPressed: _articleUri == null
                            ? null
                            : () => _openArticle(context),
                        icon: const Icon(Icons.open_in_new_rounded, size: 17),
                        label: const Text('Ver noticia'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.cyan,
                          minimumSize: const Size(0, 38),
                        ),
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
