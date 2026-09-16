import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../data/discover_data.dart';

class NewsServiceException implements Exception {
  const NewsServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NewsAdminItem {
  const NewsAdminItem({
    required this.id,
    required this.title,
    required this.sourceName,
    required this.editorialStatus,
    required this.publishedAt,
    required this.articleUrl,
    required this.isPublished,
    required this.autoPublished,
    required this.qualityScore,
    required this.rejectionReason,
  });

  final String id;
  final String title;
  final String sourceName;
  final String editorialStatus;
  final DateTime? publishedAt;
  final String articleUrl;
  final bool isPublished;
  final bool autoPublished;
  final int? qualityScore;
  final String rejectionReason;
}

class NewsImportRunRecord {
  const NewsImportRunRecord({
    required this.id,
    required this.startedAt,
    required this.finishedAt,
    required this.status,
    required this.importedCount,
    required this.publishedCount,
    required this.rumorCount,
    required this.skippedCount,
    required this.errorMessage,
  });

  final String id;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String status;
  final int importedCount;
  final int publishedCount;
  final int rumorCount;
  final int skippedCount;
  final String errorMessage;
}

class NewsAdminSnapshot {
  const NewsAdminSnapshot({required this.items, required this.runs});

  final List<NewsAdminItem> items;
  final List<NewsImportRunRecord> runs;

  int get autoPublishedCount =>
      items.where((item) => item.isPublished && item.autoPublished).length;
  int get rumorCount => items
      .where((item) => item.isPublished && item.editorialStatus == 'rumor')
      .length;
  int get developingCount => items
      .where((item) => item.isPublished && item.editorialStatus == 'developing')
      .length;
  int get unpublishedCount => items.where((item) => !item.isPublished).length;
  NewsImportRunRecord? get latestRun => runs.isEmpty ? null : runs.first;
}

class SupabaseNewsService {
  SupabaseNewsService({supabase.SupabaseClient? client})
    : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;

  Future<List<DiscoverNews>> restoreNews({
    int limit = 60,
    int offset = 0,
  }) async {
    try {
      final response = await _client.rpc(
        'get_public_news',
        params: {'limit_count': limit, 'offset_count': offset},
      );
      if (response is! List) return const [];
      return response
          .whereType<Map>()
          .map((row) => _fromRow(row.cast<String, dynamic>()))
          .where((item) => item.displayTitle.isNotEmpty)
          .toList(growable: false);
    } on supabase.PostgrestException catch (error) {
      debugPrint(
        'NEWS_FETCH_ERROR code=${error.code} message=${error.message} '
        'details=${error.details}',
      );
      throw const NewsServiceException(
        'No pudimos cargar las noticias en este momento.',
      );
    } catch (error) {
      debugPrint('NEWS_FETCH_ERROR error=$error');
      throw const NewsServiceException(
        'No pudimos cargar las noticias en este momento.',
      );
    }
  }

  Future<NewsAdminSnapshot> restoreAdminSnapshot({int limit = 80}) async {
    try {
      final responses = await Future.wait([
        _client
            .from('news_items')
            .select(
              'id,title,source_name,editorial_status,published_at,'
              'article_url,canonical_url,is_published,auto_published,'
              'quality_score,rejection_reason',
            )
            .order('published_at', ascending: false)
            .limit(limit),
        _client
            .from('news_import_runs')
            .select(
              'id,started_at,finished_at,status,imported_count,'
              'published_count,rumor_count,skipped_count,error_message',
            )
            .order('started_at', ascending: false)
            .limit(20),
      ]);

      final itemRows = responses[0];
      final runRows = responses[1];
      return NewsAdminSnapshot(
        items: itemRows
            .whereType<Map>()
            .map((row) => _adminItemFromRow(row.cast<String, dynamic>()))
            .toList(growable: false),
        runs: runRows
            .whereType<Map>()
            .map((row) => _runFromRow(row.cast<String, dynamic>()))
            .toList(growable: false),
      );
    } on supabase.PostgrestException catch (error) {
      debugPrint(
        'NEWS_ADMIN_FETCH_ERROR code=${error.code} message=${error.message} '
        'details=${error.details}',
      );
      throw const NewsServiceException(
        'No pudimos cargar el control de Noticias. Revisá la automatización en Supabase.',
      );
    } catch (error) {
      debugPrint('NEWS_ADMIN_FETCH_ERROR error=$error');
      throw const NewsServiceException(
        'No pudimos cargar el control de Noticias en este momento.',
      );
    }
  }

  DiscoverNews _fromRow(Map<String, dynamic> row) {
    final entityNames = _strings(row['entity_names']);
    final entityIds = _strings(row['entity_ids']);
    final sourceName = _string(row['source_name']);
    return DiscoverNews(
      id: _string(row['id']),
      artist: entityNames.isEmpty ? '' : entityNames.first,
      title: _string(row['title']),
      source: sourceName,
      sourceName: sourceName,
      sourceDomain: _string(row['source_domain']),
      ingestionSource: _string(row['ingestion_source']),
      summary: _string(row['summary']),
      generatedSummary: _string(row['summary']),
      whyItMatters: _string(row['why_it_matters']),
      time: '',
      publishedAt: _string(row['published_at']),
      status: _string(row['editorial_status']),
      imageAsset: '',
      imageUrl: _string(row['image_url']),
      imageSource: _string(row['image_source']),
      imageLicense: _string(row['image_license']),
      attribution: _string(row['image_attribution']),
      articleUrl: _string(row['article_url']),
      canonicalUrl: _string(row['canonical_url']),
      googleNewsUrl: _string(row['google_news_url']),
      originalUrl: _string(row['article_url']),
      language: _string(row['language']).isEmpty
          ? 'es'
          : _string(row['language']),
      relatedGroups: entityNames,
      relatedEntityIds: entityIds,
      tags: _strings(row['tags']),
      trending: _string(row['editorial_status']).toLowerCase() == 'trending',
    );
  }

  NewsAdminItem _adminItemFromRow(Map<String, dynamic> row) {
    return NewsAdminItem(
      id: _string(row['id']),
      title: _string(row['title']),
      sourceName: _string(row['source_name']),
      editorialStatus: _string(row['editorial_status']),
      publishedAt: DateTime.tryParse(_string(row['published_at'])),
      articleUrl: _string(row['canonical_url']).isNotEmpty
          ? _string(row['canonical_url'])
          : _string(row['article_url']),
      isPublished: row['is_published'] == true,
      autoPublished: row['auto_published'] == true,
      qualityScore: row['quality_score'] is num
          ? (row['quality_score'] as num).toInt()
          : null,
      rejectionReason: _string(row['rejection_reason']),
    );
  }

  NewsImportRunRecord _runFromRow(Map<String, dynamic> row) {
    return NewsImportRunRecord(
      id: _string(row['id']),
      startedAt: DateTime.tryParse(_string(row['started_at'])),
      finishedAt: DateTime.tryParse(_string(row['finished_at'])),
      status: _string(row['status']),
      importedCount: _integer(row['imported_count']),
      publishedCount: _integer(row['published_count']),
      rumorCount: _integer(row['rumor_count']),
      skippedCount: _integer(row['skipped_count']),
      errorMessage: _string(row['error_message']),
    );
  }

  String _string(Object? value) => value?.toString().trim() ?? '';

  int _integer(Object? value) => value is num ? value.toInt() : 0;

  List<String> _strings(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}
