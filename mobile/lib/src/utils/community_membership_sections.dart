import '../data/discover_data.dart';

class CommunityMembershipSections {
  const CommunityMembershipSections({
    required this.joined,
    required this.available,
  });

  final List<DiscoverCommunity> joined;
  final List<DiscoverCommunity> available;
}

CommunityMembershipSections splitCommunityMembership({
  required List<DiscoverCommunity> communities,
  required Set<String> joinedIds,
  String query = '',
}) {
  final normalizedQuery = query.trim().toLowerCase();
  final joined = <DiscoverCommunity>[];
  final available = <DiscoverCommunity>[];
  final seenIds = <String>{};

  for (final community in communities) {
    if (community.id.isEmpty || !seenIds.add(community.id)) continue;
    final searchable = [
      community.name,
      community.region,
      community.country,
      community.province,
      community.city,
      community.fandom,
      community.description,
      community.privacy,
    ].join(' ').toLowerCase();
    if (normalizedQuery.isNotEmpty && !searchable.contains(normalizedQuery)) {
      continue;
    }
    if (joinedIds.contains(community.id)) {
      joined.add(community);
    } else {
      available.add(community);
    }
  }

  return CommunityMembershipSections(joined: joined, available: available);
}
