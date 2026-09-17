import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import 'hub_avatar.dart';

class ShareRecipient {
  const ShareRecipient({
    required this.id,
    required this.name,
    required this.username,
    required this.avatarAsset,
  });

  final String id;
  final String name;
  final String username;
  final String avatarAsset;
}

class AppShareSheet extends StatefulWidget {
  const AppShareSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.shareText,
    required this.recipients,
    required this.onSelected,
    this.onSendToRecipient,
    this.onShareToStory,
  });

  final String title;
  final String subtitle;
  final String shareText;
  final List<ShareRecipient> recipients;
  final ValueChanged<String> onSelected;
  final Future<String> Function(ShareRecipient recipient)? onSendToRecipient;
  final Future<void> Function()? onShareToStory;

  @override
  State<AppShareSheet> createState() => _AppShareSheetState();
}

class _AppShareSheetState extends State<AppShareSheet> {
  String _query = '';

  Future<void> _shareOnWhatsApp() async {
    final url = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(widget.shareText)}',
    );
    var opened = false;
    try {
      opened = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    widget.onSelected(
      opened ? 'WhatsApp abierto' : 'No se pudo abrir WhatsApp',
    );
  }

  Future<void> _copyLink() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.shareText));
    } catch (_) {
      if (!mounted) return;
      _showManualLink();
      return;
    }
    if (!mounted) return;
    widget.onSelected('Enlace copiado');
  }

  Future<void> _sendToRecipient(ShareRecipient recipient) async {
    if (widget.onSendToRecipient == null) {
      widget.onSelected('Enviado a ${recipient.name}');
      return;
    }
    try {
      final message = await widget.onSendToRecipient!(recipient);
      if (!mounted) return;
      widget.onSelected(message);
    } catch (_) {
      if (!mounted) return;
      widget.onSelected('No pudimos enviar a ${recipient.name}.');
    }
  }

  void _showManualLink() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.nightSoft,
        title: const Text(
          'Enlace listo para compartir',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: SelectableText(
          widget.shareText,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final filtered = widget.recipients.where((recipient) {
      if (query.isEmpty) return true;
      final initials = recipient.name
          .split(' ')
          .where((part) => part.isNotEmpty)
          .map((part) => part[0])
          .join()
          .toLowerCase();
      return recipient.name.toLowerCase().contains(query) ||
          recipient.username.toLowerCase().contains(query) ||
          initials.contains(query);
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      decoration: const BoxDecoration(
        color: AppTheme.nightSoft,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
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
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close),
                  color: Colors.white,
                  tooltip: 'Cerrar',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _ShareShortcut(
                  icon: Icons.chat_rounded,
                  label: 'WhatsApp',
                  color: const Color(0xFF25D366),
                  onTap: _shareOnWhatsApp,
                ),
                const SizedBox(width: 10),
                _ShareShortcut(
                  icon: Icons.link_rounded,
                  label: 'Copiar enlace',
                  color: AppTheme.cyan,
                  onTap: _copyLink,
                ),
                if (widget.onShareToStory != null) ...[
                  const SizedBox(width: 10),
                  _ShareShortcut(
                    icon: Icons.add_to_photos_outlined,
                    label: 'En mi historia',
                    color: AppTheme.violet,
                    onTap: () async {
                      await widget.onShareToStory!();
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Enviar a seguidores',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 9),
            TextField(
              key: const ValueKey('share-recipient-search'),
              onChanged: (value) => setState(() => _query = value),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o iniciales',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.42),
                ),
                prefixIcon: const Icon(Icons.search, color: AppTheme.cyan),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.07),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No encontramos seguidores con esa búsqueda.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.58),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => Divider(
                        color: Colors.white.withValues(alpha: 0.08),
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final recipient = filtered[index];
                        return Material(
                          color: Colors.transparent,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: HubAvatar(
                              asset: recipient.avatarAsset,
                              size: 42,
                            ),
                            title: Text(
                              recipient.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Text(
                              recipient.username,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.54),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            trailing: IconButton.filledTonal(
                              key: ValueKey(
                                'share-recipient-${recipient.username}',
                              ),
                              onPressed: () => _sendToRecipient(recipient),
                              icon: const Icon(Icons.send_rounded),
                              tooltip: 'Enviar a ${recipient.name}',
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareShortcut extends StatelessWidget {
  const _ShareShortcut({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
