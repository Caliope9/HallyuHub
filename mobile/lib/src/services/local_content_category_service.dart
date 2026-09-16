import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

class LocalContentCategoryService {
  const LocalContentCategoryService();

  static const _categoriesKey = 'hallyuhub.local-content-categories.v1';
  static const maxCategoriesPerContent = 5;

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  bool get usesRealCategories => false;

  Future<void> saveContentCategories({
    required String userId,
    required ProfileContentType contentType,
    required String contentId,
    required Iterable<ProfileContentCategory> categories,
  }) async {
    final ownerId = userId.trim().isEmpty ? 'local-user' : userId.trim();
    final safeCategories = categories.toSet().take(maxCategoriesPerContent);
    final rows = await _restoreRows();
    rows.removeWhere(
      (row) =>
          row.userId == ownerId &&
          row.contentType == contentType &&
          row.contentId == contentId,
    );
    rows.addAll(
      safeCategories.map(
        (category) => ContentCategoryAssignment(
          userId: ownerId,
          contentType: contentType,
          contentId: contentId,
          category: category,
          createdAt: DateTime.now(),
        ),
      ),
    );
    await _saveRows(rows);
    revision.value++;
  }

  Future<List<ContentCategoryAssignment>> restoreForUser(String userId) async {
    final ownerId = userId.trim().isEmpty ? 'local-user' : userId.trim();
    final rows = await _restoreRows();
    return rows.where((row) => row.userId == ownerId).toList(growable: false);
  }

  Future<List<ContentCategoryAssignment>> _restoreRows() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_categoriesKey);
    if (stored == null) return [];
    try {
      return (jsonDecode(stored) as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_fromJson)
          .whereType<ContentCategoryAssignment>()
          .toList();
    } catch (_) {
      await preferences.remove(_categoriesKey);
      return [];
    }
  }

  Future<void> _saveRows(List<ContentCategoryAssignment> rows) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _categoriesKey,
      jsonEncode(rows.map(_toJson).toList()),
    );
  }

  ContentCategoryAssignment? _fromJson(Map<String, dynamic> json) {
    final contentType = ProfileContentType.fromKey(
      json['contentType'] as String? ?? '',
    );
    final category = ProfileContentCategory.fromKey(
      json['category'] as String? ?? '',
    );
    if (contentType == null || category == null) return null;
    return ContentCategoryAssignment(
      userId: json['userId'] as String? ?? 'local-user',
      contentType: contentType,
      contentId: json['contentId'] as String? ?? '',
      category: category,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }

  Map<String, dynamic> _toJson(ContentCategoryAssignment row) {
    return {
      'userId': row.userId,
      'contentType': row.contentType.key,
      'contentId': row.contentId,
      'category': row.category.key,
      'createdAt': row.createdAt?.toIso8601String(),
    };
  }
}
