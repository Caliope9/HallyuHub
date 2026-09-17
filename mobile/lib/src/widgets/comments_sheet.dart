import 'package:flutter/material.dart';

import '../models.dart';
import '../services/local_safety_service.dart';
import '../theme/app_theme.dart';
import 'hub_avatar.dart';
import 'safety_report_sheet.dart';

typedef CommentSubmitCallback =
    Future<PostComment> Function(String body, String parentId);
typedef CommentDeleteCallback = Future<void> Function(PostComment comment);
typedef CommentAuthorCallback = void Function(PostComment comment);

class CommentsSheet extends StatefulWidget {
  const CommentsSheet({
    super.key,
    required this.threadId,
    required this.subtitle,
    required this.initialComments,
    required this.onChanged,
    required this.onCommentAdded,
    this.onSubmitComment,
    this.onDeleteComment,
    this.onOpenAuthor,
    this.onCommentsRemoved,
    this.safetyService = const LocalSafetyService(),
    this.reportContentType = 'comment',
    this.currentUserName = 'Tu perfil',
    this.currentUsername = '@mika.hallyu',
    this.currentUserAvatar = 'assets/demo-users/user-01.jpg',
  });

  final String threadId;
  final String subtitle;
  final List<PostComment> initialComments;
  final ValueChanged<List<PostComment>> onChanged;
  final VoidCallback onCommentAdded;
  final CommentSubmitCallback? onSubmitComment;
  final CommentDeleteCallback? onDeleteComment;
  final CommentAuthorCallback? onOpenAuthor;
  final ValueChanged<int>? onCommentsRemoved;
  final LocalSafetyService safetyService;
  final String reportContentType;
  final String currentUserName;
  final String currentUsername;
  final String currentUserAvatar;

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  late List<PostComment> _comments = [...widget.initialComments];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final Set<String> _likedCommentIds = {};
  final Set<String> _deletingCommentIds = {};
  _ReplyTarget? _replyTarget;
  bool _sending = false;
  String? _errorMessage;

  static const _maxCommentLength = 280;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _commentId(PostComment comment, String path) {
    return comment.id.isEmpty ? 'legacy-$path' : comment.id;
  }

  Future<void> _send() async {
    if (_sending) return;
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    if (body.length > _maxCommentLength) {
      setState(() => _errorMessage = 'El comentario es demasiado largo.');
      return;
    }
    final parentId = _replyTarget?.commentId ?? '';
    setState(() {
      _sending = true;
      _errorMessage = null;
    });
    try {
      final comment = widget.onSubmitComment == null
          ? PostComment(
              id: '${widget.threadId}-${DateTime.now().microsecondsSinceEpoch}',
              parentId: parentId,
              author: widget.currentUserName,
              username: widget.currentUsername,
              avatarAsset: widget.currentUserAvatar,
              body: body,
              time: 'Ahora',
              isOwn: true,
            )
          : await widget.onSubmitComment!(body, parentId);
      if (!mounted) return;
      setState(() {
        if (_replyTarget == null) {
          _comments.add(comment);
        } else {
          _comments = _updateComment(
            _comments,
            _replyTarget!.commentId,
            (parent) => parent.copyWith(replies: [...parent.replies, comment]),
          );
        }
        _controller.clear();
        _replyTarget = null;
      });
      widget.onChanged([..._comments]);
      widget.onCommentAdded();
      _focusNode.requestFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _friendlyError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _deleteComment(String commentId, PostComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.nightSoft,
        title: const Text('Eliminar comentario'),
        content: const Text('¿Querés borrar este comentario?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || _deletingCommentIds.contains(commentId)) return;
    final removedCount =
        _countCommentTree(_comments) -
        _countCommentTree(_removeComment(_comments, commentId));
    setState(() {
      _deletingCommentIds.add(commentId);
      _errorMessage = null;
    });
    try {
      await widget.onDeleteComment?.call(comment);
      if (!mounted) return;
      setState(() {
        _comments = _removeComment(_comments, commentId);
      });
      widget.onChanged([..._comments]);
      if (removedCount > 0) widget.onCommentsRemoved?.call(removedCount);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _friendlyError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _deletingCommentIds.remove(commentId));
      }
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.startsWith('PostServiceException: ')) {
      return message.replaceFirst('PostServiceException: ', '');
    }
    return 'No pudimos actualizar los comentarios. Probá de nuevo en unos segundos.';
  }

  List<PostComment> _removeComment(
    List<PostComment> comments,
    String targetId, [
    String prefix = 'root',
  ]) {
    return [
      for (var index = 0; index < comments.length; index++)
        if (_commentId(comments[index], '$prefix-$index') != targetId)
          comments[index].copyWith(
            replies: _removeComment(
              comments[index].replies,
              targetId,
              '$prefix-$index-reply',
            ),
          ),
    ];
  }

  int _countCommentTree(List<PostComment> comments) {
    var count = 0;
    for (final comment in comments) {
      count += 1 + _countCommentTree(comment.replies);
    }
    return count;
  }

  void _toggleLike(String commentId) {
    final wasLiked = _likedCommentIds.contains(commentId);
    setState(() {
      if (wasLiked) {
        _likedCommentIds.remove(commentId);
      } else {
        _likedCommentIds.add(commentId);
      }
      _comments = _updateComment(
        _comments,
        commentId,
        (comment) => comment.copyWith(
          likes: (comment.likes + (wasLiked ? -1 : 1)).clamp(0, 999999),
        ),
      );
    });
    widget.onChanged([..._comments]);
  }

  Future<void> _reportComment(PostComment comment) async {
    final sent = await showSafetyReportSheet(
      context: context,
      safetyService: widget.safetyService,
      contentType: widget.reportContentType,
      contentId: comment.id,
      reportedUserId: comment.authorId,
      title: comment.parentId.isEmpty
          ? 'Reportar comentario'
          : 'Reportar respuesta',
      metadata: {'thread_id': widget.threadId},
    );
    if (!mounted || !sent) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gracias. Recibimos tu reporte.')),
    );
  }

  void _startReply(String commentId, PostComment comment) {
    setState(() {
      _replyTarget = _ReplyTarget(
        commentId: commentId,
        username: comment.username,
      );
    });
    _focusNode.requestFocus();
  }

  List<PostComment> _updateComment(
    List<PostComment> comments,
    String targetId,
    PostComment Function(PostComment comment) update, [
    String prefix = 'root',
  ]) {
    return [
      for (var index = 0; index < comments.length; index++)
        if (_commentId(comments[index], '$prefix-$index') == targetId)
          update(comments[index])
        else
          comments[index].copyWith(
            replies: _updateComment(
              comments[index].replies,
              targetId,
              update,
              '$prefix-$index-reply',
            ),
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 10,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF130B20),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.38),
              blurRadius: 34,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 10, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Comentarios',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.56),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close),
                      color: Colors.white.withValues(alpha: 0.72),
                      tooltip: 'Cerrar',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _comments.isEmpty
                    ? Center(
                        child: Text(
                          'Todavía no hay comentarios. Sé la primera persona en sumar una reacción.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.58),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                        itemCount: _comments.length,
                        separatorBuilder: (context, index) => Divider(
                          color: Colors.white.withValues(alpha: 0.08),
                          height: 18,
                        ),
                        itemBuilder: (context, index) => _CommentTile(
                          comment: _comments[index],
                          commentId: _commentId(
                            _comments[index],
                            'root-$index',
                          ),
                          idFor: _commentId,
                          likedCommentIds: _likedCommentIds,
                          deletingCommentIds: _deletingCommentIds,
                          onLike: _toggleLike,
                          onReply: _startReply,
                          onDelete: _deleteComment,
                          onReport: _reportComment,
                          onOpenAuthor: widget.onOpenAuthor,
                        ),
                      ),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: AppTheme.rose,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              if (_replyTarget != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Respondiendo a ${_replyTarget!.username}',
                          style: const TextStyle(
                            color: AppTheme.cyan,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _replyTarget = null),
                        child: const Text('Cancelar'),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Row(
                  children: [
                    HubAvatar(asset: widget.currentUserAvatar, size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        key: ValueKey('comment-input-${widget.threadId}'),
                        controller: _controller,
                        focusNode: _focusNode,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _send(),
                        textInputAction: TextInputAction.send,
                        minLines: 1,
                        maxLines: 3,
                        maxLength: _maxCommentLength,
                        buildCounter:
                            (
                              context, {
                              required currentLength,
                              required isFocused,
                              maxLength,
                            }) => null,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: _replyTarget == null
                              ? 'Escribe un comentario...'
                              : 'Escribe una respuesta...',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.42),
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.07),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _controller.text.trim().isEmpty || _sending
                          ? null
                          : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.arrow_upward_rounded),
                      tooltip: 'Enviar comentario',
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.rose,
                        disabledBackgroundColor: Colors.white.withValues(
                          alpha: 0.1,
                        ),
                        foregroundColor: Colors.white,
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

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.commentId,
    required this.idFor,
    required this.likedCommentIds,
    required this.deletingCommentIds,
    required this.onLike,
    required this.onReply,
    required this.onDelete,
    required this.onReport,
    this.onOpenAuthor,
    this.depth = 0,
  });

  final PostComment comment;
  final String commentId;
  final String Function(PostComment comment, String path) idFor;
  final Set<String> likedCommentIds;
  final Set<String> deletingCommentIds;
  final ValueChanged<String> onLike;
  final void Function(String commentId, PostComment comment) onReply;
  final void Function(String commentId, PostComment comment) onDelete;
  final ValueChanged<PostComment> onReport;
  final CommentAuthorCallback? onOpenAuthor;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final liked = likedCommentIds.contains(commentId);
    return Padding(
      padding: EdgeInsets.only(left: depth == 0 ? 0 : 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onOpenAuthor == null ? null : () => onOpenAuthor!(comment),
            child: HubAvatar(
              asset: comment.avatarAsset,
              size: depth == 0 ? 38 : 30,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: onOpenAuthor == null
                            ? null
                            : () => onOpenAuthor!(comment),
                        child: Text(
                          comment.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      comment.time,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.42),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (comment.isOwn)
                      IconButton(
                        key: ValueKey('comment-delete-$commentId'),
                        onPressed: deletingCommentIds.contains(commentId)
                            ? null
                            : () => onDelete(commentId, comment),
                        icon: deletingCommentIds.contains(commentId)
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white70,
                                ),
                              )
                            : const Icon(Icons.delete_outline_rounded),
                        color: Colors.white.withValues(alpha: 0.5),
                        tooltip: 'Eliminar comentario',
                      ),
                    if (!comment.isOwn)
                      IconButton(
                        key: ValueKey('comment-report-$commentId'),
                        onPressed: () => onReport(comment),
                        icon: const Icon(Icons.flag_outlined),
                        color: Colors.white.withValues(alpha: 0.5),
                        tooltip: 'Reportar',
                      ),
                  ],
                ),
                Text(
                  comment.username,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  comment.body,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    height: 1.32,
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      key: ValueKey('comment-reply-$commentId'),
                      onPressed: () => onReply(commentId, comment),
                      child: const Text('Responder'),
                    ),
                    const Spacer(),
                    Text(
                      '${comment.likes}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.54),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      key: ValueKey('comment-star-$commentId'),
                      onPressed: () => onLike(commentId),
                      icon: Icon(
                        liked ? Icons.star_rounded : Icons.star_border_rounded,
                      ),
                      color: liked ? AppTheme.rose : Colors.white54,
                      tooltip: liked ? 'Quitar estrella' : 'Dar estrella',
                    ),
                  ],
                ),
                for (var index = 0; index < comment.replies.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _CommentTile(
                      comment: comment.replies[index],
                      commentId: idFor(
                        comment.replies[index],
                        '$commentId-reply-$index',
                      ),
                      idFor: idFor,
                      likedCommentIds: likedCommentIds,
                      deletingCommentIds: deletingCommentIds,
                      onLike: onLike,
                      onReply: onReply,
                      onDelete: onDelete,
                      onReport: onReport,
                      onOpenAuthor: onOpenAuthor,
                      depth: depth + 1,
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

class _ReplyTarget {
  const _ReplyTarget({required this.commentId, required this.username});

  final String commentId;
  final String username;
}
