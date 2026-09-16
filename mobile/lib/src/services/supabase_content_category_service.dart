import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models.dart';
import 'local_content_category_service.dart';

class SupabaseContentCategoryService extends LocalContentCategoryService {
  SupabaseContentCategoryService({supabase.SupabaseClient? client})
    : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;

  @override
  bool get usesRealCategories => true;

  @override
  Future<void> saveContentCategories({
    required String userId,
    required ProfileContentType contentType,
    required String contentId,
    required Iterable<ProfileContentCategory> categories,
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) return;
    final ownerId = userId.trim().isEmpty ? authUser.id : userId.trim();
    final safeCategories = categories.toSet().take(
      LocalContentCategoryService.maxCategoriesPerContent,
    );
    await _client
        .from('content_categories')
        .delete()
        .eq('user_id', ownerId)
        .eq('content_type', contentType.key)
        .eq('content_id', contentId);
    if (safeCategories.isEmpty) {
      LocalContentCategoryService.revision.value++;
      return;
    }
    await _client
        .from('content_categories')
        .insert(
          safeCategories
              .map(
                (category) => {
                  'user_id': ownerId,
                  'content_type': contentType.key,
                  'content_id': contentId,
                  'category_key': category.key,
                },
              )
              .toList(growable: false),
        );
    LocalContentCategoryService.revision.value++;
  }

  @override
  Future<List<ContentCategoryAssignment>> restoreForUser(String userId) async {
    final authUser = _client.auth.currentUser;
    final ownerId = userId.trim().isEmpty ? authUser?.id ?? '' : userId.trim();
    if (ownerId.isEmpty) return const [];
    final rows = await _client
        .from('content_categories')
        .select('user_id,content_type,content_id,category_key,created_at')
        .eq('user_id', ownerId)
        .order('created_at', ascending: false);
    return rows
        .cast<Map<String, dynamic>>()
        .map(_assignmentFromRow)
        .whereType<ContentCategoryAssignment>()
        .toList(growable: false);
  }

  ContentCategoryAssignment? _assignmentFromRow(Map<String, dynamic> row) {
    final contentType = ProfileContentType.fromKey(
      row['content_type'] as String? ?? '',
    );
    final category = ProfileContentCategory.fromKey(
      row['category_key'] as String? ?? '',
    );
    if (contentType == null || category == null) return null;
    return ContentCategoryAssignment(
      userId: row['user_id'] as String? ?? '',
      contentType: contentType,
      contentId: row['content_id'] as String? ?? '',
      category: category,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
    );
  }
}
