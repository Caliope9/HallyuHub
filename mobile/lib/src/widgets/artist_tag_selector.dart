import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/local_artist_tag_service.dart';
import '../theme/app_theme.dart';
import 'hally_feature_tip.dart';

class ArtistTagSelector extends StatefulWidget {
  const ArtistTagSelector({
    super.key,
    required this.artistTagService,
    required this.selectedEntities,
    required this.onChanged,
    this.title = 'Etiquetar grupos o artistas',
    this.subtitle = 'Conectá este contenido con entidades reales.',
    this.compact = false,
  });

  final LocalArtistTagService artistTagService;
  final List<KpopEntity> selectedEntities;
  final ValueChanged<List<KpopEntity>> onChanged;
  final String title;
  final String subtitle;
  final bool compact;

  @override
  State<ArtistTagSelector> createState() => _ArtistTagSelectorState();
}

class _ArtistTagSelectorState extends State<ArtistTagSelector> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<KpopEntity> _suggestions = const [];
  String _query = '';
  bool _loading = false;
  bool _suggesting = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      _search(value);
    });
  }

  Future<void> _search(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _query = '';
        _suggestions = const [];
        _loading = false;
      });
      return;
    }
    setState(() {
      _query = query;
      _loading = true;
    });
    try {
      final selectedIds = widget.selectedEntities
          .map((entity) => entity.id)
          .toSet();
      final results = await widget.artistTagService.searchEntities(
        query: query,
        limit: 20,
      );
      if (!mounted) return;
      setState(() {
        _suggestions = results
            .where((entity) => !selectedIds.contains(entity.id))
            .take(10)
            .toList(growable: false);
        _loading = false;
      });
    } catch (error) {
      debugPrint('ARTIST_TAG_SEARCH_ERROR $error');
      if (!mounted) return;
      setState(() {
        _suggestions = const [];
        _loading = false;
      });
    }
  }

  void _add(KpopEntity entity) {
    if (widget.selectedEntities.length >= 10) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Podés etiquetar hasta 10 artistas o grupos.'),
          ),
        );
      return;
    }
    if (widget.selectedEntities.any((item) => item.id == entity.id)) return;
    widget.onChanged([...widget.selectedEntities, entity]);
    _controller.clear();
    _search('');
  }

  void _remove(KpopEntity entity) {
    widget.onChanged(
      widget.selectedEntities
          .where((item) => item.id != entity.id)
          .toList(growable: false),
    );
    _search(_query);
  }

  Future<void> _suggestMissing() async {
    final name = _query.trim();
    if (name.isEmpty || _suggesting) return;
    setState(() => _suggesting = true);
    try {
      final freshMatches = await widget.artistTagService.searchEntities(
        query: name,
        limit: 8,
      );
      if (freshMatches.isNotEmpty) {
        if (!mounted) return;
        setState(() => _suggestions = freshMatches);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Encontramos coincidencias. Revisalas antes de sugerir otra ficha.',
              ),
            ),
          );
        return;
      }
      if (!mounted) return;
      final type = await showDialog<KpopEntityType>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppTheme.nightSoft,
          title: const Text('¿Qué querés agregar?'),
          content: const Text(
            'Elegí el tipo correcto para evitar confusiones.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton.icon(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(KpopEntityType.group),
              icon: const Icon(Icons.groups_2_outlined),
              label: const Text('Grupo'),
            ),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(KpopEntityType.artist),
              icon: const Icon(Icons.person_search_outlined),
              label: const Text('Artista / Solista'),
            ),
          ],
        ),
      );
      if (!mounted || type == null) return;
      final verifiedMatches = await widget.artistTagService.searchEntities(
        query: name,
        limit: 8,
      );
      if (verifiedMatches.any(
        (entity) => isExactKpopEntityDuplicate(
          entity: entity,
          requestedName: name,
          requestedType: type,
        ),
      )) {
        if (!mounted) return;
        setState(() => _suggestions = verifiedMatches);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Esa ficha ya existe; elegila en los resultados.'),
            ),
          );
        return;
      }
      await widget.artistTagService.submitDetailedEntitySuggestion(
        ArtistSuggestionDraft(
          name: name,
          type: type == KpopEntityType.group
              ? KpopEntitySuggestionType.group
              : KpopEntitySuggestionType.artist,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('$name quedó como sugerencia pendiente.')),
        );
    } catch (error) {
      debugPrint('ARTIST_TAG_SUGGESTION_ERROR $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('No pudimos guardar la sugerencia.')),
        );
    } finally {
      if (mounted) setState(() => _suggesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selectedEntities;
    return Container(
      padding: EdgeInsets.all(widget.compact ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: .1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HallyFeatureTip(
            featureId: 'artist_tags_intro',
            title: 'Etiquetá a tus artistas ✨',
            message:
                'Etiquetá un grupo o artista para que más fans lo encuentren.',
            mascotAsset: 'assets/brand/hally_mascot_groups_lightstick.png',
          ),
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppTheme.amber),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (!widget.compact)
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .58),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (selected.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selected
                  .map(
                    (entity) => InputChip(
                      avatar: _EntityBadge(entity: entity, size: 24),
                      label: Text(entity.name),
                      onDeleted: () => _remove(entity),
                      deleteIconColor: Colors.white70,
                      backgroundColor: AppTheme.violet.withValues(alpha: .18),
                      side: BorderSide(
                        color: AppTheme.cyan.withValues(alpha: .3),
                      ),
                      labelStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            onChanged: _onQueryChanged,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar BTS, Jungkook, Lisa...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: .45)),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppTheme.cyan,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: .07),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: .12),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: .12),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: AppTheme.cyan),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: Colors.transparent,
              ),
            )
          else if (_query.isNotEmpty && _suggestions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'No encontramos ese grupo o artista.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .58),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _suggesting ? null : _suggestMissing,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Agregar a HallyuHub'),
                  ),
                ],
              ),
            )
          else
            ..._suggestions.map((entity) => _EntityTile(entity: entity)),
        ],
      ),
    );
  }
}

class _EntityTile extends StatelessWidget {
  const _EntityTile({required this.entity});

  final KpopEntity entity;

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_ArtistTagSelectorState>()!;
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: _EntityBadge(entity: entity),
        title: Text(
          entity.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          '${entity.typeLabel}${entity.verified ? ' · verificado' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.white.withValues(alpha: .55)),
        ),
        trailing: IconButton(
          tooltip: 'Etiquetar',
          onPressed: () => state._add(entity),
          icon: const Icon(Icons.add_circle_rounded, color: AppTheme.cyan),
        ),
        onTap: () => state._add(entity),
      ),
    );
  }
}

class _EntityBadge extends StatelessWidget {
  const _EntityBadge({required this.entity, this.size = 42});

  final KpopEntity entity;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = entity.name.trim().isEmpty ? 'H' : entity.name.trim()[0];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppTheme.cyan, AppTheme.violet, AppTheme.rose],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.cyan.withValues(alpha: .22),
            blurRadius: 14,
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial.toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontSize: size < 30 ? 11 : 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
