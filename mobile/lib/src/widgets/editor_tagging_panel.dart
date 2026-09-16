import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../models.dart';
import '../theme/app_theme.dart';

enum EditorTagKind { person, business, place, artist }

class EditorTagChoice {
  const EditorTagChoice({
    required this.id,
    required this.kind,
    required this.label,
    required this.value,
    required this.detail,
    this.avatarAsset = '',
    this.icon = Icons.alternate_email_rounded,
  });

  final String id;
  final EditorTagKind kind;
  final String label;
  final String value;
  final String detail;
  final String avatarAsset;
  final IconData icon;
}

Future<EditorTagChoice?> showEditorTaggingPanel({
  required BuildContext context,
  EditorTagKind initialKind = EditorTagKind.person,
  bool suggestCurrentLocation = false,
  bool allowLocalSuggestions = true,
}) {
  return showModalBottomSheet<EditorTagChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _EditorTaggingPanel(
      initialKind: initialKind,
      suggestCurrentLocation: suggestCurrentLocation,
      allowLocalSuggestions: allowLocalSuggestions,
    ),
  );
}

String? activeMentionQuery(String text) {
  final match = RegExp(r'(?:^|\s)@([\w.]*)$').firstMatch(text);
  return match?.group(1)?.toLowerCase();
}

String insertMention(String text, String username) {
  final mention = username.startsWith('@') ? username : '@$username';
  final match = RegExp(r'(?:^|\s)@[\w.]*$').firstMatch(text);
  if (match == null) return '$text $mention '.trimLeft();
  final prefix = text.substring(0, match.start);
  final leadingSpace = text[match.start].trim().isEmpty ? ' ' : '';
  return '$prefix$leadingSpace$mention ';
}

class MentionSuggestionBar extends StatelessWidget {
  const MentionSuggestionBar({
    super.key,
    required this.text,
    required this.onSelected,
    this.enabled = true,
  });

  final String text;
  final ValueChanged<CommunityProfile> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();
    final query = activeMentionQuery(text);
    if (query == null) return const SizedBox.shrink();
    final matches = demoProfiles
        .where(
          (profile) =>
              profile.name.toLowerCase().contains(query) ||
              profile.username.toLowerCase().contains(query),
        )
        .take(3)
        .toList();
    if (matches.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const ValueKey('mention-suggestions'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.22)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 174),
        child: SingleChildScrollView(
          child: Column(
            children: [
              for (final profile in matches)
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    key: ValueKey('mention-${profile.id}'),
                    dense: true,
                    leading: CircleAvatar(
                      radius: 17,
                      backgroundImage: AssetImage(profile.avatarAsset),
                    ),
                    title: Text(
                      profile.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      profile.username,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                      ),
                    ),
                    onTap: () => onSelected(profile),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorTaggingPanel extends StatefulWidget {
  const _EditorTaggingPanel({
    required this.initialKind,
    required this.suggestCurrentLocation,
    required this.allowLocalSuggestions,
  });

  final EditorTagKind initialKind;
  final bool suggestCurrentLocation;
  final bool allowLocalSuggestions;

  @override
  State<_EditorTaggingPanel> createState() => _EditorTaggingPanelState();
}

class _EditorTaggingPanelState extends State<_EditorTaggingPanel> {
  late EditorTagKind _kind;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
  }

  @override
  Widget build(BuildContext context) {
    final options = _options
        .where(
          (option) =>
              option.kind == _kind &&
              '${option.label} ${option.detail} ${option.value}'
                  .toLowerCase()
                  .contains(_query.toLowerCase()),
        )
        .toList();
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      padding: EdgeInsets.fromLTRB(
        18,
        14,
        18,
        MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.nightSoft,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Etiquetar contenido',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Conectá tu publicación con personas, lugares y fandoms.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final kind in EditorTagKind.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: ChoiceChip(
                        key: ValueKey('tag-kind-${kind.name}'),
                        selected: _kind == kind,
                        onSelected: (_) => setState(() => _kind = kind),
                        avatar: Icon(_iconFor(kind), size: 17),
                        label: Text(_labelFor(kind)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('tag-panel-search'),
              onChanged: (value) => setState(() => _query = value),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Buscar...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  return Material(
                    color: Colors.transparent,
                    child: ListTile(
                      key: ValueKey('tag-option-${option.id}'),
                      leading: option.avatarAsset.isNotEmpty
                          ? CircleAvatar(
                              backgroundImage: AssetImage(option.avatarAsset),
                            )
                          : CircleAvatar(
                              backgroundColor: AppTheme.violet.withValues(
                                alpha: 0.2,
                              ),
                              child: Icon(option.icon, color: AppTheme.cyan),
                            ),
                      title: Text(
                        option.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        option.detail,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      trailing: const Icon(
                        Icons.add_circle_outline_rounded,
                        color: AppTheme.rose,
                      ),
                      onTap: () => Navigator.of(context).pop(option),
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

  List<EditorTagChoice> get _options {
    if (!widget.allowLocalSuggestions) return const [];
    return [
      for (final profile in demoProfiles)
        EditorTagChoice(
          id: profile.id,
          kind: EditorTagKind.person,
          label: profile.name,
          value: profile.username,
          detail: '${profile.username} · ${profile.fandom}',
          avatarAsset: profile.avatarAsset,
        ),
      const EditorTagChoice(
        id: 'business-hallyu-market',
        kind: EditorTagKind.business,
        label: 'Hallyu Market',
        value: '@hallyumarket',
        detail: 'Negocio verificado · Photocards y álbumes',
        icon: Icons.storefront_outlined,
      ),
      const EditorTagChoice(
        id: 'business-seoul-cafe',
        kind: EditorTagKind.business,
        label: 'Seoul Café',
        value: '@seoulcafe',
        detail: 'Café fan · Cupsleeves y eventos',
        icon: Icons.local_cafe_outlined,
      ),
      if (widget.suggestCurrentLocation)
        const EditorTagChoice(
          id: 'place-current',
          kind: EditorTagKind.place,
          label: 'Ubicación actual',
          value: 'Ubicación actual',
          detail: 'Se solicitará permiso y podés editarla',
          icon: Icons.my_location_rounded,
        ),
      const EditorTagChoice(
        id: 'place-palermo',
        kind: EditorTagKind.place,
        label: 'Palermo',
        value: 'Palermo, Buenos Aires',
        detail: 'Buenos Aires, Argentina',
        icon: Icons.location_on_outlined,
      ),
      const EditorTagChoice(
        id: 'place-barrio-italia',
        kind: EditorTagKind.place,
        label: 'Barrio Italia',
        value: 'Barrio Italia, Santiago',
        detail: 'Santiago, Chile',
        icon: Icons.location_on_outlined,
      ),
      const EditorTagChoice(
        id: 'place-matucana',
        kind: EditorTagKind.place,
        label: 'Centro Cultural Matucana',
        value: 'Centro Cultural Matucana',
        detail: 'Santiago, Chile',
        icon: Icons.location_on_outlined,
      ),
      for (final artist in artistTrends)
        EditorTagChoice(
          id: 'artist-${artist.name}',
          kind: EditorTagKind.artist,
          label: artist.name,
          value: artist.name,
          detail: '${artist.tag} · ${artist.signal}',
          icon: Icons.groups_2_outlined,
        ),
    ];
  }

  String _labelFor(EditorTagKind kind) {
    return switch (kind) {
      EditorTagKind.person => 'Personas',
      EditorTagKind.business => 'Negocios',
      EditorTagKind.place => 'Lugares',
      EditorTagKind.artist => 'Artistas',
    };
  }

  IconData _iconFor(EditorTagKind kind) {
    return switch (kind) {
      EditorTagKind.person => Icons.alternate_email_rounded,
      EditorTagKind.business => Icons.storefront_outlined,
      EditorTagKind.place => Icons.location_on_outlined,
      EditorTagKind.artist => Icons.groups_2_outlined,
    };
  }
}
