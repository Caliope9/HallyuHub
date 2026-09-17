import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';
import 'hub_avatar.dart';

String communityChatAuthorName(CommunityProfile? profile) {
  final name = profile?.name.trim() ?? '';
  if (name.isNotEmpty && name.toLowerCase() != 'hallyu fan') return name;
  final username =
      profile?.username.trim().replaceFirst(RegExp(r'^@+'), '') ?? '';
  if (username.isNotEmpty && username.toLowerCase() != 'fan') return username;
  return 'Usuario';
}

class CommunityChatMessageTile extends StatelessWidget {
  const CommunityChatMessageTile({
    super.key,
    required this.profile,
    required this.body,
    required this.timeLabel,
    required this.isCurrentUser,
    this.onOpenProfile,
    this.onReport,
  });

  final CommunityProfile? profile;
  final String body;
  final String timeLabel;
  final bool isCurrentUser;
  final ValueChanged<CommunityProfile>? onOpenProfile;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final authorName = communityChatAuthorName(profile);
    final canOpenProfile = profile != null && onOpenProfile != null;
    final profileTap = canOpenProfile ? () => onOpenProfile!(profile!) : null;
    final username = profile?.username.trim() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: ValueKey(
              'community-message-avatar-${profile?.id ?? 'unknown'}',
            ),
            onTap: profileTap,
            customBorder: const CircleBorder(),
            child: HubAvatar(
              asset: profile?.avatarAsset ?? '',
              size: 42,
              fallbackLabel: authorName,
              fallbackColors: profile?.colors,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: InkWell(
                        key: ValueKey(
                          'community-message-author-${profile?.id ?? 'unknown'}',
                        ),
                        onTap: profileTap,
                        child: Text(
                          isCurrentUser ? 'Vos · $authorName' : authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isCurrentUser
                                ? AppTheme.cyan
                                : AppTheme.rose,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    if (!isCurrentUser && username.isNotEmpty) ...[
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          username.startsWith('@') ? username : '@$username',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .48),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Text(
                      timeLabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .45),
                        fontSize: 11,
                      ),
                    ),
                    if (onReport != null)
                      IconButton(
                        key: ValueKey(
                          'community-message-report-${profile?.id ?? 'unknown'}',
                        ),
                        onPressed: onReport,
                        icon: const Icon(Icons.flag_outlined, size: 17),
                        color: Colors.white54,
                        tooltip: 'Reportar',
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151D39),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: isCurrentUser
                            ? AppTheme.cyan.withValues(alpha: .24)
                            : Colors.white.withValues(alpha: .055),
                      ),
                    ),
                    child: Text(
                      body,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .9),
                        height: 1.35,
                      ),
                    ),
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
