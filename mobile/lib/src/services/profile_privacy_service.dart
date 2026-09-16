bool canViewerSeePrivateProfileContent({
  required String? viewerId,
  required String profileOwnerId,
  required bool privateProfile,
  required bool followsProfile,
  required String viewerRole,
}) {
  if (!privateProfile) return true;
  final viewer = viewerId?.trim();
  final owner = profileOwnerId.trim();
  if (viewer != null && viewer.isNotEmpty && owner.isNotEmpty) {
    if (viewer == owner) return true;
  }
  final normalizedRole = viewerRole.trim().toLowerCase();
  if (normalizedRole == 'admin' || normalizedRole == 'moderator') return true;
  return followsProfile;
}
