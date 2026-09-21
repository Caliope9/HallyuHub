import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models.dart';

class KpopEntityMemberService {
  KpopEntityMemberService([supabase.SupabaseClient? client])
    : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;

  /// Returns null when the normalized relation is not available yet. An
  /// empty list is a valid remote result for a group with no loaded members.
  Future<List<KpopEntityMember>?> restoreMembers(String groupId) async {
    final safeGroupId = groupId.trim();
    if (safeGroupId.isEmpty) return const [];
    try {
      final rows = await _client
          .from('kpop_entity_members')
          .select(
            'group_id,member_id,position,stage_name,role,'
            'member:kpop_entities!kpop_entity_members_member_id_fkey('
            'id,entity_type,name,normalized_name,aliases,bio,image_url,'
            'image_source,image_license,attribution,fandom_name,is_verified)',
          )
          .eq('group_id', safeGroupId)
          .eq('is_active', true)
          .order('position', ascending: true);
      return rows
          .whereType<Map>()
          .map(
            (row) => KpopEntityMember.fromRow(
              Map<String, dynamic>.from(row),
              groupId: safeGroupId,
            ),
          )
          .where(
            (member) =>
                member.memberId.isNotEmpty && member.entity.name.isNotEmpty,
          )
          .toList(growable: false);
    } catch (_) {
      return null;
    }
  }
}
