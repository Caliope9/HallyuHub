enum DiscoverSection {
  all('Todo'),
  groups('Grupos'),
  idols('Idols'),
  news('Noticias'),
  communities('Comunidades'),
  events('Eventos'),
  rookie('K-pop 101'),
  shop('Tiendas');

  const DiscoverSection(this.label);

  final String label;
}

enum DiscoverEntityType {
  idolGroup('Grupo idol'),
  soloist('Solista'),
  rookie('Rookie'),
  fanCrew('Fan project'),
  project('Proyecto global'),
  localKpop('K-pop local'),
  coverCrew('Cover crew');

  const DiscoverEntityType(this.label);

  final String label;
}

enum DiscoverEntityStatus {
  verified('Grupo verificado'),
  emerging('Emergente'),
  communitySuggested('Sugerido por la comunidad'),
  pendingReview('Pendiente de revisión');

  const DiscoverEntityStatus(this.label);

  final String label;
}

enum DiscoverActivityStatus {
  active('Activo'),
  hiatus('Hiatus'),
  rookie('Rookie'),
  disbanded('Disuelto');

  const DiscoverActivityStatus(this.label);

  final String label;
}

class DiscoverIdol {
  const DiscoverIdol({
    required this.id,
    required this.groupId,
    required this.name,
    required this.role,
    required this.country,
    required this.imageAsset,
    required this.bio,
    this.realName = '',
    this.fullName = '',
    this.birth = '',
    this.nationality = '',
    this.fullBio = '',
    this.highlights = const [],
    this.relatedPostIds = const [],
    this.aliases = const [],
    this.tags = const [],
    this.imageUrl = '',
    this.imageSource = '',
    this.imageLicense = 'HallyuHub placeholder',
    this.attribution = 'Visual abstracto generado por HallyuHub',
    this.author = 'HallyuHub',
    this.licenseUrl = '',
    this.officialUrl = '',
  });

  final String id;
  final String groupId;
  final String name;
  final String role;
  final String country;
  final String imageAsset;
  final String bio;
  final String realName;
  final String fullName;
  final String birth;
  final String nationality;
  final String fullBio;
  final List<String> highlights;
  final List<String> relatedPostIds;
  final List<String> aliases;
  final List<String> tags;
  final String imageUrl;
  final String imageSource;
  final String imageLicense;
  final String attribution;
  final String author;
  final String licenseUrl;
  final String officialUrl;
}

class DiscoverGroup {
  const DiscoverGroup({
    required this.id,
    required this.name,
    required this.fandom,
    required this.company,
    required this.debut,
    required this.style,
    required this.bio,
    required this.latest,
    required this.imageAsset,
    required this.idols,
    this.aliases = const [],
    this.country = 'Corea del Sur',
    this.region = 'Asia',
    this.type = DiscoverEntityType.idolGroup,
    this.status = DiscoverEntityStatus.verified,
    this.activityStatus = DiscoverActivityStatus.active,
    this.concept = '',
    this.fullBio = '',
    this.recommendedSongs = const [],
    this.featuredEras = const [],
    this.officialLinks = const {},
    this.sources = const [],
    this.tags = const [],
    this.source = 'demo_prototype',
    this.createdBy = 'HallyuHub demo',
    this.lastUpdated = '2026-06-03',
    this.relatedNewsIds = const [],
    this.relatedFancamIds = const [],
    this.imageUrl = '',
    this.imageSource = '',
    this.imageLicense = 'HallyuHub placeholder',
    this.attribution = 'Visual abstracto generado por HallyuHub',
    this.author = 'HallyuHub',
    this.licenseUrl = '',
    this.officialUrl = '',
  });

  final String id;
  final String name;
  final String fandom;
  final String company;
  final String debut;
  final String style;
  final String bio;
  final String latest;
  final String imageAsset;
  final List<DiscoverIdol> idols;
  final List<String> aliases;
  final String country;
  final String region;
  final DiscoverEntityType type;
  final DiscoverEntityStatus status;
  final DiscoverActivityStatus activityStatus;
  final String concept;
  final String fullBio;
  final List<String> recommendedSongs;
  final List<String> featuredEras;
  final Map<String, String> officialLinks;
  final List<String> sources;
  final List<String> tags;
  final String source;
  final String createdBy;
  final String lastUpdated;
  final List<String> relatedNewsIds;
  final List<String> relatedFancamIds;
  final String imageUrl;
  final String imageSource;
  final String imageLicense;
  final String attribution;
  final String author;
  final String licenseUrl;
  final String officialUrl;
}

class DiscoverArtistEntity {
  const DiscoverArtistEntity({
    required this.groupId,
    required this.name,
    required this.aliases,
    required this.country,
    required this.region,
    required this.type,
    required this.status,
    required this.fandom,
    required this.description,
    required this.members,
    required this.relatedNewsIds,
    required this.relatedFancamIds,
    required this.tags,
    required this.source,
    required this.createdBy,
    required this.lastUpdated,
    required this.imageAsset,
    this.demoFeatured = false,
    this.referenceUrl = '',
    this.officialUrl = '',
    this.imageUrl = '',
    this.imageSource = '',
    this.imageLicense = 'HallyuHub placeholder',
    this.attribution = 'Visual abstracto generado por HallyuHub',
    this.author = 'HallyuHub',
    this.licenseUrl = '',
  });

  final String groupId;
  final String name;
  final List<String> aliases;
  final String country;
  final String region;
  final DiscoverEntityType type;
  final DiscoverEntityStatus status;
  final String fandom;
  final String description;
  final List<String> members;
  final List<String> relatedNewsIds;
  final List<String> relatedFancamIds;
  final List<String> tags;
  final String source;
  final String createdBy;
  final String lastUpdated;
  final String imageAsset;
  final bool demoFeatured;
  final String referenceUrl;
  final String officialUrl;
  final String imageUrl;
  final String imageSource;
  final String imageLicense;
  final String attribution;
  final String author;
  final String licenseUrl;

  String get searchableText => [
    groupId,
    name,
    ...aliases,
    country,
    region,
    type.label,
    status.label,
    fandom,
    description,
    ...members,
    ...tags,
    source,
    createdBy,
    referenceUrl,
    officialUrl,
    imageSource,
    imageLicense,
    attribution,
  ].join(' ');
}

class DiscoverNews {
  const DiscoverNews({
    required this.id,
    required this.artist,
    required this.title,
    required this.source,
    required this.summary,
    required this.time,
    required this.status,
    required this.imageAsset,
    this.originalTitle = '',
    this.originalUrl = '',
    this.publishedAt = '',
    this.generatedSummary = '',
    this.language = 'es',
    this.relatedGroups = const [],
    this.relatedArtists = const [],
    this.confidence = 'demo-curated',
    this.lastUpdated = '',
    this.tags = const [],
    this.imageUrl = '',
    this.imageSource = 'HallyuHub placeholder',
    this.imageLicense = 'HallyuHub placeholder',
    this.attribution = 'Visual editorial abstracto generado por HallyuHub',
    this.author = 'HallyuHub',
    this.licenseUrl = '',
    this.trending = false,
    this.relatedEntityIds = const [],
    this.detectedEntityTags = const [],
    this.articleUrl = '',
    this.canonicalUrl = '',
    this.googleNewsUrl = '',
    this.sourceName = '',
    this.sourceDomain = '',
    this.ingestionSource = '',
    this.whyItMatters = '',
  });

  final String id;
  final String artist;
  final String title;
  final String source;
  final String summary;
  final String time;
  final String status;
  final String imageAsset;
  final String originalTitle;
  final String originalUrl;
  final String publishedAt;
  final String generatedSummary;
  final String language;
  final List<String> relatedGroups;
  final List<String> relatedArtists;
  final String confidence;
  final String lastUpdated;
  final List<String> tags;
  final String imageUrl;
  final String imageSource;
  final String imageLicense;
  final String attribution;
  final String author;
  final String licenseUrl;
  final bool trending;
  final List<String> relatedEntityIds;
  final List<String> detectedEntityTags;
  final String articleUrl;
  final String canonicalUrl;
  final String googleNewsUrl;
  final String sourceName;
  final String sourceDomain;
  final String ingestionSource;
  final String whyItMatters;

  String get displayTitle => originalTitle.isNotEmpty ? originalTitle : title;

  String get displaySummary => _cleanNewsText(
    generatedSummary.trim().isNotEmpty ? generatedSummary : summary,
  );

  String get cardSummary => _truncateNewsSummary(displaySummary, 160);

  String get displaySource {
    final preferred = sourceName.trim().isNotEmpty ? sourceName : source;
    final cleaned = preferred
        .replaceAll(RegExp(r'\s+demo\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'demo\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+rss\b', caseSensitive: false), '')
        .trim();
    final normalized = cleaned.toLowerCase();
    if (normalized.isEmpty ||
        normalized == 'google news' ||
        normalized.contains('google news rss')) {
      final domain = sourceDomain.trim();
      if (domain.isNotEmpty && !domain.toLowerCase().contains('google')) {
        return domain;
      }
      return 'Fuente por confirmar';
    }
    return cleaned;
  }

  String get displayConfidence {
    final normalized = confidence.toLowerCase();
    if (normalized.contains('high')) return 'Resumen Hally preparado';
    if (normalized.contains('medium')) return 'Resumen Hally en revisión';
    if (normalized.contains('low')) return 'Resumen Hally inicial';
    return 'Resumen Hally';
  }

  DateTime? get publishedDate => DateTime.tryParse(publishedAt.trim());

  String get publishedLabel => publishedLabelAt(DateTime.now());

  String publishedLabelAt(DateTime now) {
    final published = publishedDate;
    if (published == null) return 'Fecha no disponible';
    final localPublished = published.toLocal();
    final difference = now.toLocal().difference(localPublished);
    if (difference.isNegative || difference.inMinutes < 1) return 'ahora';
    if (difference.inMinutes < 60) return 'hace ${difference.inMinutes} min';
    if (difference.inHours < 24) return 'hace ${difference.inHours} h';
    if (difference.inDays < 7) return 'hace ${difference.inDays} días';
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${localPublished.day} ${months[localPublished.month - 1]} ${localPublished.year}';
  }

  String get directArticleUrl {
    for (final candidate in [canonicalUrl, articleUrl, originalUrl]) {
      final uri = Uri.tryParse(candidate.trim());
      if (uri == null ||
          (uri.scheme != 'https' && uri.scheme != 'http') ||
          uri.host.isEmpty ||
          uri.host.toLowerCase().endsWith('news.google.com')) {
        continue;
      }
      return uri.toString();
    }
    return '';
  }

  String get relatedResultsUrl {
    for (final candidate in [googleNewsUrl, originalUrl]) {
      final uri = Uri.tryParse(candidate.trim());
      if (uri == null ||
          (uri.scheme != 'https' && uri.scheme != 'http') ||
          uri.host.isEmpty) {
        continue;
      }
      if (uri.host.toLowerCase().endsWith('news.google.com')) {
        return uri.toString();
      }
    }
    return '';
  }

  bool get hasDirectArticleLink => directArticleUrl.isNotEmpty;

  bool get hasRelatedResultsLink => relatedResultsUrl.isNotEmpty;

  bool get hasOriginalLink => hasDirectArticleLink || hasRelatedResultsLink;

  bool get hasAuthorizedImage {
    if (imageUrl.trim().isEmpty) return false;
    final license = imageLicense.trim().toLowerCase();
    final sourceValue = imageSource.trim().toLowerCase();
    return license.isNotEmpty &&
        !license.contains('placeholder') &&
        sourceValue.isNotEmpty &&
        !sourceValue.contains('placeholder');
  }

  String get editorialBadge {
    final normalized = status.trim().toLowerCase();
    if (normalized == 'official' || normalized.contains('oficial')) {
      return 'Oficial';
    }
    if (normalized.contains('confirm')) return 'Confirmado';
    if (normalized.contains('desarrollo') ||
        normalized.contains('developing')) {
      return 'En desarrollo';
    }
    if (normalized.contains('rumor')) return 'Rumor';
    if (trending || normalized.contains('tendencia')) return 'Tendencia';
    return 'Actualidad';
  }

  List<String> get displayTags {
    final seen = <String>{};
    final result = <String>[];
    final statusToken = editorialBadge.toLowerCase();
    for (final raw in [...tags, ...relatedGroups, ...relatedArtists]) {
      final value = _cleanNewsText(raw);
      final key = value.toLowerCase();
      if (value.isEmpty || key == statusToken || !seen.add(key)) continue;
      result.add(value);
      if (result.length == 3) break;
    }
    return result;
  }

  String get entityLabel {
    if (artist.trim().isNotEmpty) return artist.trim();
    if (relatedGroups.isNotEmpty) return relatedGroups.first;
    if (relatedArtists.isNotEmpty) return relatedArtists.first;
    return 'K-pop';
  }

  String get searchableText => [
    title,
    originalTitle,
    artist,
    source,
    sourceName,
    sourceDomain,
    summary,
    generatedSummary,
    status,
    language,
    confidence,
    whyItMatters,
    ...tags,
    ...relatedGroups,
    ...relatedArtists,
    ...relatedEntityIds,
    ...detectedEntityTags,
  ].join(' ');
}

String _cleanNewsText(String value) {
  return value
      .replaceAll(RegExp(r'\bdemo\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\bverificad[oa]s?\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _truncateNewsSummary(String value, int maxLength) {
  final cleaned = _cleanNewsText(value);
  if (cleaned.length <= maxLength) return cleaned;
  final slice = cleaned.substring(0, maxLength - 1);
  final lastSpace = slice.lastIndexOf(' ');
  final safeSlice = lastSpace > maxLength * 0.72
      ? slice.substring(0, lastSpace)
      : slice;
  return '${safeSlice.trimRight()}…';
}

class DiscoverCommunity {
  const DiscoverCommunity({
    required this.id,
    required this.name,
    required this.region,
    required this.members,
    required this.activity,
    required this.fandom,
    required this.description,
    required this.posts,
    this.country = '',
    this.province = '',
    this.city = '',
    this.privacy = 'Pública',
    this.createdBy = 'demo',
    this.createdAt,
  });

  final String id;
  final String name;
  final String region;
  final String members;
  final String activity;
  final String fandom;
  final String description;
  final List<String> posts;
  final String country;
  final String province;
  final String city;
  final String privacy;
  final String createdBy;
  final DateTime? createdAt;
}

class DiscoverEvent {
  const DiscoverEvent({
    required this.id,
    required this.title,
    required this.communityId,
    required this.city,
    required this.country,
    required this.date,
    required this.location,
    required this.description,
    required this.organizer,
    required this.fandom,
    required this.imageAsset,
  });

  final String id;
  final String title;
  final String communityId;
  final String city;
  final String country;
  final String date;
  final String location;
  final String description;
  final String organizer;
  final String fandom;
  final String imageAsset;
}

class DiscoverGuide {
  const DiscoverGuide({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.body,
  });

  final String id;
  final String title;
  final String category;
  final String summary;
  final String body;
}

class DiscoverStore {
  const DiscoverStore({
    required this.id,
    required this.name,
    required this.city,
    required this.country,
    required this.category,
    required this.rating,
    required this.description,
    required this.products,
    required this.imageAsset,
    this.verified = true,
  });

  final String id;
  final String name;
  final String city;
  final String country;
  final String category;
  final String rating;
  final String description;
  final List<String> products;
  final String imageAsset;
  final bool verified;
}

class _IdolSeed {
  const _IdolSeed(
    this.name,
    this.role,
    this.country, {
    this.realName = '',
    this.birth = '',
  });

  final String name;
  final String role;
  final String country;
  final String realName;
  final String birth;
}

DiscoverGroup _group({
  required String id,
  required String name,
  required String fandom,
  required String company,
  required String debut,
  required String style,
  required String bio,
  required String latest,
  required int image,
  required List<_IdolSeed> members,
}) {
  return DiscoverGroup(
    id: id,
    name: name,
    fandom: fandom,
    company: company,
    debut: debut,
    style: style,
    bio: bio,
    latest: latest,
    imageAsset: _postAsset(image),
    aliases: _groupAliases(name),
    concept: style,
    fullBio: _groupFullBio(name: name, fandom: fandom, company: company),
    recommendedSongs: _recommendedSongsFor(name),
    featuredEras: _featuredErasFor(name),
    officialLinks: const {
      'Sitio oficial': 'Pendiente de URL autorizada',
      'YouTube': 'Pendiente de URL autorizada',
      'Instagram/X': 'Pendiente de URL autorizada',
    },
    sources: const [
      'Resumen redactado por HallyuHub',
      'Validar con fuente oficial antes de producción',
    ],
    tags: [
      name,
      fandom,
      company,
      ...style.split(RegExp(r'[,·]')).map((item) => item.trim()),
    ],
    idols: [
      for (var index = 0; index < members.length; index++)
        DiscoverIdol(
          id: '$id-${_key(members[index].name)}',
          groupId: id,
          name: members[index].name,
          role: members[index].role,
          country: members[index].country,
          realName: members[index].realName,
          fullName: members[index].realName,
          birth: members[index].birth,
          nationality: members[index].country,
          imageAsset: _userAsset(image + index),
          bio:
              '${members[index].name} forma parte de $name. En HallyuHub su perfil reúne rol, actividad fandom y contenido etiquetado por la comunidad.',
          fullBio: _idolFullBio(
            idolName: members[index].name,
            groupName: name,
            role: members[index].role,
            fandom: fandom,
          ),
          highlights: _idolHighlights(
            name: members[index].name,
            groupName: name,
            role: members[index].role,
          ),
          tags: [
            name,
            fandom,
            members[index].name,
            ...members[index].role.split('·').map((item) => item.trim()),
          ],
        ),
    ],
  );
}

List<String> _groupAliases(String name) {
  switch (name) {
    case 'BTS':
      return const ['Bangtan Sonyeondan', 'Beyond The Scene'];
    case 'BLACKPINK':
      return const ['BP'];
    case 'Tomorrow X Together':
      return const ['TXT', '투모로우바이투게더'];
    case 'LE SSERAFIM':
      return const ['LESSERAFIM'];
    default:
      return [name.replaceAll(' ', '').toUpperCase()];
  }
}

String _groupFullBio({
  required String name,
  required String fandom,
  required String company,
}) {
  return '$name es un perfil curado para explorar música, integrantes, actividad fandom y contenido relacionado dentro de HallyuHub. La biografía está redactada con palabras propias y pensada para fans nuevos y avanzados: resume identidad, comunidad y contexto sin copiar textos oficiales. En producción, esta ficha debe validarse con fuentes autorizadas y puede enriquecerse con links oficiales, press kits con permiso o contenido subido por usuarios.';
}

List<String> _recommendedSongsFor(String name) {
  switch (name) {
    case 'BTS':
      return const ['DNA', 'IDOL', 'Dynamite', 'Spring Day'];
    case 'Stray Kids':
      return const ['God’s Menu', 'MANIAC', 'S-Class', 'LALALALA'];
    case 'BLACKPINK':
      return const ['DDU-DU DDU-DU', 'How You Like That', 'Pink Venom'];
    case 'NewJeans':
      return const ['Attention', 'Hype Boy', 'OMG', 'Super Shy'];
    case 'TWICE':
      return const ['Fancy', 'Feel Special', 'The Feels'];
    case 'SEVENTEEN':
      return const ['VERY NICE', 'HOT', 'Super'];
    default:
      return ['Canción para descubrir', 'Stage recomendado', 'Fancam popular'];
  }
}

List<String> _featuredErasFor(String name) {
  switch (name) {
    case 'BTS':
      return const ['HYYH', 'Love Yourself', 'Map of the Soul'];
    case 'Stray Kids':
      return const ['Noeasy', '5-Star', 'Rock-Star'];
    case 'BLACKPINK':
      return const ['The Album', 'Born Pink'];
    case 'NewJeans':
      return const ['New Jeans', 'OMG', 'Get Up'];
    default:
      return const ['Debut', 'Comeback destacado', 'Era fandom'];
  }
}

String _idolFullBio({
  required String idolName,
  required String groupName,
  required String role,
  required String fandom,
}) {
  return '$idolName forma parte de $groupName y aparece en HallyuHub como un perfil vivo de descubrimiento: rol principal, datos clave, fancams etiquetadas, posts relacionados y actividad de $fandom. Esta descripción es original, breve y editable; no reemplaza una fuente oficial ni copia biografías externas.';
}

List<String> _idolHighlights({
  required String name,
  required String groupName,
  required String role,
}) {
  return [
    'Rol destacado: $role',
    'Contenido etiquetado por fans de $groupName',
    'Perfil preparado para fancams, posts y fuentes verificadas',
  ];
}

String _key(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

String _postAsset(int index) =>
    'assets/demo-posts/post-${((index - 1) % 12 + 1).toString().padLeft(2, '0')}.jpg';

String _userAsset(int index) =>
    'assets/demo-users/user-${((index - 1) % 20 + 1).toString().padLeft(2, '0')}.jpg';

final discoverGroups = <DiscoverGroup>[
  _group(
    id: 'skz',
    name: 'Stray Kids',
    fandom: 'STAY',
    company: 'JYP Entertainment',
    debut: '2018',
    style: 'Rap potente, producción propia y performance intensa.',
    bio:
        'Stray Kids combina identidad creativa, letras personales y una comunidad STAY muy activa.',
    latest: 'Comebacks, giras y contenido fandom.',
    image: 1,
    members: const [
      _IdolSeed(
        'Bang Chan',
        'Líder · productor · vocal · rap',
        'Australia / Corea',
      ),
      _IdolSeed('Lee Know', 'Dance · vocal', 'Corea del Sur'),
      _IdolSeed('Changbin', 'Rap · productor', 'Corea del Sur'),
      _IdolSeed('Hyunjin', 'Dance · rap · visual', 'Corea del Sur'),
      _IdolSeed('Han', 'Rap · vocal · productor', 'Corea del Sur'),
      _IdolSeed('Felix', 'Dance · rap', 'Australia / Corea'),
      _IdolSeed('Seungmin', 'Vocal', 'Corea del Sur'),
      _IdolSeed('I.N', 'Vocal · maknae', 'Corea del Sur'),
    ],
  ),
  _group(
    id: 'bts',
    name: 'BTS',
    fandom: 'ARMY',
    company: 'BIGHIT MUSIC',
    debut: '2013',
    style: 'Hip-hop, pop, mensajes personales y narrativa de álbumes.',
    bio:
        'BTS es uno de los grupos más influyentes del K-pop global, con una historia artística seguida de cerca por ARMY.',
    latest: 'Actividad grupal, proyectos solistas y eventos ARMY.',
    image: 2,
    members: const [
      _IdolSeed(
        'RM',
        'Líder · rap',
        'Corea del Sur',
        realName: 'Kim Nam-joon',
        birth: '1994-09-12',
      ),
      _IdolSeed(
        'Jin',
        'Vocal',
        'Corea del Sur',
        realName: 'Kim Seok-jin',
        birth: '1992-12-04',
      ),
      _IdolSeed(
        'SUGA',
        'Rap · productor',
        'Corea del Sur',
        realName: 'Min Yoon-gi',
        birth: '1993-03-09',
      ),
      _IdolSeed(
        'j-hope',
        'Dance · rap',
        'Corea del Sur',
        realName: 'Jung Ho-seok',
        birth: '1994-02-18',
      ),
      _IdolSeed(
        'Jimin',
        'Vocal · dance',
        'Corea del Sur',
        realName: 'Park Ji-min',
        birth: '1995-10-13',
      ),
      _IdolSeed(
        'V',
        'Vocal',
        'Corea del Sur',
        realName: 'Kim Tae-hyung',
        birth: '1995-12-30',
      ),
      _IdolSeed(
        'Jung Kook',
        'Vocal · dance · maknae',
        'Corea del Sur',
        realName: 'Jeon Jung-kook',
        birth: '1997-09-01',
      ),
    ],
  ),
  _group(
    id: 'bp',
    name: 'BLACKPINK',
    fandom: 'BLINK',
    company: 'YG Entertainment',
    debut: '2016',
    style: 'Pop global, rap, moda y visual de alto impacto.',
    bio:
        'BLACKPINK reúne música pop, moda, presencia escénica y carreras individuales fuertes.',
    latest: 'Lanzamientos, campañas y giras.',
    image: 3,
    members: const [
      _IdolSeed('Jisoo', 'Vocal · visual', 'Corea del Sur'),
      _IdolSeed('Jennie', 'Rap · vocal', 'Corea del Sur'),
      _IdolSeed('Rosé', 'Vocal · dance', 'Nueva Zelanda / Corea'),
      _IdolSeed('Lisa', 'Dance · rap', 'Tailandia'),
    ],
  ),
  _group(
    id: 'newjeans',
    name: 'NewJeans',
    fandom: 'Bunnies',
    company: 'ADOR',
    debut: '2022',
    style: 'Pop fresco, R&B, Y2K y baile natural.',
    bio:
        'NewJeans se reconoce por un sonido fresco, visuales Y2K y canciones fáciles de compartir.',
    latest: 'Playlists, videos y contenido corto.',
    image: 4,
    members: const [
      _IdolSeed('Minji', 'Vocal · dance', 'Corea del Sur'),
      _IdolSeed('Hanni', 'Vocal · dance', 'Australia / Vietnam'),
      _IdolSeed('Danielle', 'Vocal · dance', 'Australia / Corea'),
      _IdolSeed('Haerin', 'Vocal · dance', 'Corea del Sur'),
      _IdolSeed('Hyein', 'Vocal · dance · maknae', 'Corea del Sur'),
    ],
  ),
  _group(
    id: 'svt',
    name: 'SEVENTEEN',
    fandom: 'CARAT',
    company: 'PLEDIS Entertainment',
    debut: '2015',
    style: 'Unidades vocal, hip-hop y performance sincronizada.',
    bio:
        'SEVENTEEN destaca por sus unidades, sus coreografías precisas y su vínculo cercano con CARAT.',
    latest: 'Álbumes, unit songs, shows y fan events.',
    image: 5,
    members: const [
      _IdolSeed('S.Coups', 'Líder · hip-hop', 'Corea del Sur'),
      _IdolSeed('Jeonghan', 'Vocal', 'Corea del Sur'),
      _IdolSeed('Joshua', 'Vocal', 'Estados Unidos / Corea'),
      _IdolSeed('Jun', 'Performance', 'China'),
      _IdolSeed('Hoshi', 'Performance · líder de unidad', 'Corea del Sur'),
      _IdolSeed('Wonwoo', 'Hip-hop', 'Corea del Sur'),
      _IdolSeed('Woozi', 'Vocal · productor', 'Corea del Sur'),
      _IdolSeed('The8', 'Performance', 'China'),
      _IdolSeed('Mingyu', 'Hip-hop', 'Corea del Sur'),
      _IdolSeed('DK', 'Vocal', 'Corea del Sur'),
      _IdolSeed('Seungkwan', 'Vocal', 'Corea del Sur'),
      _IdolSeed('Vernon', 'Hip-hop', 'Estados Unidos / Corea'),
      _IdolSeed('Dino', 'Performance · maknae', 'Corea del Sur'),
    ],
  ),
  _group(
    id: 'txt',
    name: 'TXT',
    fandom: 'MOA',
    company: 'BIGHIT MUSIC',
    debut: '2019',
    style: 'Pop emocional, narrativa juvenil y conceptos visuales.',
    bio:
        'TXT mezcla historias de crecimiento, fantasía y pop moderno con una discografía accesible.',
    latest: 'Comeback guides y contenido MOA.',
    image: 6,
    members: const [
      _IdolSeed('Soobin', 'Líder · vocal', 'Corea del Sur'),
      _IdolSeed('Yeonjun', 'Dance · rap · vocal', 'Corea del Sur'),
      _IdolSeed('Beomgyu', 'Vocal · dance', 'Corea del Sur'),
      _IdolSeed('Taehyun', 'Vocal', 'Corea del Sur'),
      _IdolSeed('Huening Kai', 'Vocal · maknae', 'Corea / EE.UU.'),
    ],
  ),
  _group(
    id: 'ive',
    name: 'IVE',
    fandom: 'DIVE',
    company: 'Starship Entertainment',
    debut: '2021',
    style: 'Pop elegante, hooks fuertes y visual premium.',
    bio:
        'IVE combina canciones directas, visuales elegantes y una identidad pop reconocible.',
    latest: 'Charts, stages y fancams populares.',
    image: 7,
    members: const [
      _IdolSeed('Yujin', 'Líder · vocal', 'Corea del Sur'),
      _IdolSeed('Gaeul', 'Rap · dance', 'Corea del Sur'),
      _IdolSeed('Rei', 'Rap · vocal', 'Japón'),
      _IdolSeed('Wonyoung', 'Vocal · visual', 'Corea del Sur'),
      _IdolSeed('Liz', 'Vocal', 'Corea del Sur'),
      _IdolSeed('Leeseo', 'Vocal · maknae', 'Corea del Sur'),
    ],
  ),
  _group(
    id: 'ateez',
    name: 'ATEEZ',
    fandom: 'ATINY',
    company: 'KQ Entertainment',
    debut: '2018',
    style: 'Performance poderosa, narrativa intensa y energía de concierto.',
    bio:
        'ATEEZ tiene una identidad escénica fuerte y una comunidad ATINY muy movilizada.',
    latest: 'Fechas, performances y noticias ATINY.',
    image: 8,
    members: const [
      _IdolSeed('Hongjoong', 'Líder · rap', 'Corea del Sur'),
      _IdolSeed('Seonghwa', 'Vocal · performance', 'Corea del Sur'),
      _IdolSeed('Yunho', 'Dance · vocal', 'Corea del Sur'),
      _IdolSeed('Yeosang', 'Vocal · performance', 'Corea del Sur'),
      _IdolSeed('San', 'Vocal · performance', 'Corea del Sur'),
      _IdolSeed('Mingi', 'Rap · dance', 'Corea del Sur'),
      _IdolSeed('Wooyoung', 'Dance · vocal', 'Corea del Sur'),
      _IdolSeed('Jongho', 'Vocal', 'Corea del Sur'),
    ],
  ),
  _group(
    id: 'twice',
    name: 'TWICE',
    fandom: 'ONCE',
    company: 'JYP Entertainment',
    debut: '2015',
    style: 'Pop brillante, coreografías memorables y evolución madura.',
    bio:
        'TWICE tiene una discografía extensa y una gran presencia regional seguida por ONCE.',
    latest: 'Eventos ONCE, álbumes y giras.',
    image: 9,
    members: const [
      _IdolSeed('Nayeon', 'Vocal', 'Corea del Sur'),
      _IdolSeed('Jeongyeon', 'Vocal', 'Corea del Sur'),
      _IdolSeed('Momo', 'Dance', 'Japón'),
      _IdolSeed('Sana', 'Vocal', 'Japón'),
      _IdolSeed('Jihyo', 'Líder · vocal', 'Corea del Sur'),
      _IdolSeed('Mina', 'Dance · vocal', 'Japón'),
      _IdolSeed('Dahyun', 'Rap', 'Corea del Sur'),
      _IdolSeed('Chaeyoung', 'Rap', 'Corea del Sur'),
      _IdolSeed('Tzuyu', 'Vocal · maknae', 'Taiwán'),
    ],
  ),
  _group(
    id: 'aespa',
    name: 'aespa',
    fandom: 'MY',
    company: 'SM Entertainment',
    debut: '2020',
    style: 'Pop futurista, voces fuertes y conceptos digitales.',
    bio:
        'aespa mezcla tecnología, mundos visuales y canciones de alto impacto.',
    latest: 'Comeback visuals y stages MY.',
    image: 10,
    members: const [
      _IdolSeed('Karina', 'Líder · dance · rap', 'Corea del Sur'),
      _IdolSeed('Giselle', 'Rap · vocal', 'Japón / Corea'),
      _IdolSeed('Winter', 'Vocal · dance', 'Corea del Sur'),
      _IdolSeed('Ningning', 'Vocal', 'China'),
    ],
  ),
  _group(
    id: 'enhypen',
    name: 'ENHYPEN',
    fandom: 'ENGENE',
    company: 'BELIFT LAB',
    debut: '2020',
    style: 'Pop oscuro, narrativa dramática y baile preciso.',
    bio:
        'ENHYPEN construyó una identidad visual intensa y una comunidad global muy conectada.',
    latest: 'Giras, stages y contenido ENGENE.',
    image: 11,
    members: const [
      _IdolSeed('Jungwon', 'Líder · vocal · dance', 'Corea del Sur'),
      _IdolSeed('Jay', 'Rap · vocal · dance', 'Corea / EE.UU.'),
      _IdolSeed('Jake', 'Vocal · dance', 'Australia / Corea'),
      _IdolSeed('Sunghoon', 'Vocal · dance', 'Corea del Sur'),
      _IdolSeed('Sunoo', 'Vocal', 'Corea del Sur'),
      _IdolSeed('Ni-ki', 'Dance · maknae', 'Japón'),
    ],
  ),
  _group(
    id: 'lesserafim',
    name: 'LE SSERAFIM',
    fandom: 'FEARNOT',
    company: 'SOURCE MUSIC',
    debut: '2022',
    style: 'Pop elegante, confianza y performance fuerte.',
    bio:
        'LE SSERAFIM conecta mensajes de avance personal con una presencia escénica clara.',
    latest: 'Stages, fancams y actividad FEARNOT.',
    image: 12,
    members: const [
      _IdolSeed('Sakura', 'Vocal · performance', 'Japón'),
      _IdolSeed('Kim Chaewon', 'Líder · vocal', 'Corea del Sur'),
      _IdolSeed('Huh Yunjin', 'Vocal', 'Corea / EE.UU.'),
      _IdolSeed('Kazuha', 'Dance · vocal', 'Japón'),
      _IdolSeed('Hong Eunchae', 'Vocal · dance · maknae', 'Corea del Sur'),
    ],
  ),
  _group(
    id: 'nct',
    name: 'NCT',
    fandom: 'NCTzen',
    company: 'SM Entertainment',
    debut: '2016',
    style: 'Sistema de unidades, pop experimental y performance urbana.',
    bio:
        'NCT funciona como un universo de unidades con sonidos variados y muchos perfiles para explorar.',
    latest: 'Noticias de unidades y actividades individuales.',
    image: 1,
    members: const [
      _IdolSeed('Taeyong', 'Líder · rap · dance', 'Corea del Sur'),
      _IdolSeed('Johnny', 'Rap · vocal', 'Estados Unidos / Corea'),
      _IdolSeed('Yuta', 'Vocal · dance', 'Japón'),
      _IdolSeed('Kun', 'Líder WayV · vocal', 'China'),
      _IdolSeed('Doyoung', 'Vocal', 'Corea del Sur'),
      _IdolSeed('Ten', 'Dance · vocal', 'Tailandia'),
      _IdolSeed('Jaehyun', 'Vocal · rap', 'Corea del Sur'),
      _IdolSeed('Jungwoo', 'Vocal · dance', 'Corea del Sur'),
      _IdolSeed('Mark', 'Rap · dance', 'Canadá / Corea'),
      _IdolSeed('Haechan', 'Vocal · dance', 'Corea del Sur'),
      _IdolSeed('Jeno', 'Rap · dance', 'Corea del Sur'),
      _IdolSeed('Jaemin', 'Rap · dance', 'Corea del Sur'),
      _IdolSeed('Chenle', 'Vocal', 'China'),
      _IdolSeed('Jisung', 'Dance · vocal', 'Corea del Sur'),
    ],
  ),
  _group(
    id: 'riize',
    name: 'RIIZE',
    fandom: 'BRIIZE',
    company: 'SM Entertainment',
    debut: '2023',
    style: 'Emotional pop, performance fresca y estilo juvenil.',
    bio: 'RIIZE propone canciones cercanas y momentos fáciles de compartir.',
    latest: 'Clips virales y actividad BRIIZE.',
    image: 2,
    members: const [
      _IdolSeed('Shotaro', 'Dance · performance', 'Japón'),
      _IdolSeed('Eunseok', 'Vocal', 'Corea del Sur'),
      _IdolSeed('Sungchan', 'Rap · performance', 'Corea del Sur'),
      _IdolSeed('Wonbin', 'Vocal · dance', 'Corea del Sur'),
      _IdolSeed('Sohee', 'Vocal', 'Corea del Sur'),
      _IdolSeed('Anton', 'Vocal · maknae', 'Estados Unidos / Corea'),
    ],
  ),
  _group(
    id: 'babymonster',
    name: 'BABYMONSTER',
    fandom: 'MONSTIEZ',
    company: 'YG Entertainment',
    debut: '2024',
    style: 'Rap, vocal potente y performance YG.',
    bio: 'BABYMONSTER combina voces fuertes, rap y una energía rookie global.',
    latest: 'Challenges, fancams y actividad MONSTIEZ.',
    image: 3,
    members: const [
      _IdolSeed('Ruka', 'Rap · dance', 'Japón'),
      _IdolSeed('Pharita', 'Vocal', 'Tailandia'),
      _IdolSeed('Asa', 'Rap · dance', 'Japón'),
      _IdolSeed('Ahyeon', 'Vocal · rap · dance', 'Corea del Sur'),
      _IdolSeed('Rami', 'Vocal', 'Corea del Sur'),
      _IdolSeed('Rora', 'Vocal', 'Corea del Sur'),
      _IdolSeed('Chiquita', 'Vocal · dance · maknae', 'Tailandia'),
    ],
  ),
  _group(
    id: 'itzy',
    name: 'ITZY',
    fandom: 'MIDZY',
    company: 'JYP Entertainment',
    debut: '2019',
    style: 'Pop directo, coreografías marcadas y seguridad personal.',
    bio:
        'ITZY propone mensajes de confianza y una identidad de performance reconocible.',
    latest: 'Comebacks, dance practices y contenido MIDZY.',
    image: 4,
    members: const [
      _IdolSeed('Yeji', 'Líder · dance · vocal', 'Corea del Sur'),
      _IdolSeed('Lia', 'Vocal', 'Corea del Sur'),
      _IdolSeed('Ryujin', 'Rap · dance', 'Corea del Sur'),
      _IdolSeed('Chaeryeong', 'Dance · vocal', 'Corea del Sur'),
      _IdolSeed('Yuna', 'Rap · dance · maknae', 'Corea del Sur'),
    ],
  ),
  _group(
    id: 'gidle',
    name: '(G)I-DLE',
    fandom: 'NEVERLAND',
    company: 'CUBE Entertainment',
    debut: '2018',
    style: 'Pop conceptual, identidad autoral y voces distintivas.',
    bio:
        '(G)I-DLE reúne conceptos fuertes y participación creativa de sus integrantes.',
    latest: 'Comebacks y proyectos individuales.',
    image: 5,
    members: const [
      _IdolSeed('Miyeon', 'Vocal', 'Corea del Sur'),
      _IdolSeed('Minnie', 'Vocal', 'Tailandia'),
      _IdolSeed('Soyeon', 'Líder · rap · productora', 'Corea del Sur'),
      _IdolSeed('Yuqi', 'Vocal · dance', 'China'),
      _IdolSeed('Shuhua', 'Vocal · visual · maknae', 'Taiwán'),
    ],
  ),
  _group(
    id: 'zerobaseone',
    name: 'ZEROBASEONE',
    fandom: 'ZEROSE',
    company: 'WAKEONE',
    debut: '2023',
    style: 'Pop brillante, performance y energía global.',
    bio: 'ZEROBASEONE reúne integrantes con una base ZEROSE muy participativa.',
    latest: 'Comebacks, eventos y clips ZEROSE.',
    image: 6,
    members: const [
      _IdolSeed('Sung Hanbin', 'Líder · dance · vocal', 'Corea del Sur'),
      _IdolSeed('Kim Jiwoong', 'Vocal · visual', 'Corea del Sur'),
      _IdolSeed('Zhang Hao', 'Vocal', 'China'),
      _IdolSeed('Seok Matthew', 'Vocal · dance', 'Canadá / Corea'),
      _IdolSeed('Kim Taerae', 'Vocal', 'Corea del Sur'),
      _IdolSeed('Ricky', 'Vocal · visual', 'China'),
      _IdolSeed('Kim Gyuvin', 'Dance · vocal', 'Corea del Sur'),
      _IdolSeed('Park Gunwook', 'Rap · dance', 'Corea del Sur'),
      _IdolSeed('Han Yujin', 'Dance · maknae', 'Corea del Sur'),
    ],
  ),
  _group(
    id: 'nmixx',
    name: 'NMIXX',
    fandom: 'NSWER',
    company: 'JYP Entertainment',
    debut: '2022',
    style: 'Mixx pop, voces potentes y cambios de ritmo.',
    bio:
        'NMIXX se caracteriza por sus voces fuertes y canciones que mezclan estilos.',
    latest: 'Stages vocales y dance practices.',
    image: 7,
    members: const [
      _IdolSeed('Lily', 'Vocal', 'Australia / Corea'),
      _IdolSeed('Haewon', 'Líder · vocal', 'Corea del Sur'),
      _IdolSeed('Sullyoon', 'Vocal · visual', 'Corea del Sur'),
      _IdolSeed('Bae', 'Vocal · dance', 'Corea del Sur'),
      _IdolSeed('Jiwoo', 'Rap · dance · vocal', 'Corea del Sur'),
      _IdolSeed('Kyujin', 'Dance · vocal · maknae', 'Corea del Sur'),
    ],
  ),
  _group(
    id: 'treasure',
    name: 'TREASURE',
    fandom: 'Treasure Maker',
    company: 'YG Entertainment',
    debut: '2020',
    style: 'Pop energético, rap YG y variedad juvenil.',
    bio: 'TREASURE combina performance, rap y una dinámica grupal amplia.',
    latest: 'Giras, lives y publicaciones Treasure Maker.',
    image: 8,
    members: const [
      _IdolSeed('Choi Hyunsuk', 'Líder · rap', 'Corea del Sur'),
      _IdolSeed('Jihoon', 'Líder · vocal · dance', 'Corea del Sur'),
      _IdolSeed('Yoshi', 'Rap', 'Japón'),
      _IdolSeed('Junkyu', 'Vocal', 'Corea del Sur'),
      _IdolSeed('Yoon Jaehyuk', 'Vocal · dance', 'Corea del Sur'),
      _IdolSeed('Asahi', 'Vocal', 'Japón'),
      _IdolSeed('Doyoung', 'Dance · vocal', 'Corea del Sur'),
      _IdolSeed('Haruto', 'Rap', 'Japón'),
      _IdolSeed('Park Jeongwoo', 'Vocal', 'Corea del Sur'),
      _IdolSeed('So Junghwan', 'Dance · vocal · maknae', 'Corea del Sur'),
    ],
  ),
  _group(
    id: 'boynextdoor',
    name: 'BOYNEXTDOOR',
    fandom: 'ONEDOOR',
    company: 'KOZ Entertainment',
    debut: '2023',
    style: 'Pop cercano, historias cotidianas y performance fresca.',
    bio: 'BOYNEXTDOOR trabaja una identidad amigable y expresiva.',
    latest: 'Challenges y actividad ONEDOOR.',
    image: 9,
    members: const [
      _IdolSeed('Sungho', 'Vocal', 'Corea del Sur'),
      _IdolSeed('Riwoo', 'Dance · vocal', 'Corea del Sur'),
      _IdolSeed('Jaehyun', 'Líder · rap · vocal', 'Corea del Sur'),
      _IdolSeed('Taesan', 'Vocal · rap', 'Corea del Sur'),
      _IdolSeed('Leehan', 'Vocal', 'Corea del Sur'),
      _IdolSeed('Woonhak', 'Vocal · maknae', 'Corea del Sur'),
    ],
  ),
  _group(
    id: 'tws',
    name: 'TWS',
    fandom: '42',
    company: 'PLEDIS Entertainment',
    debut: '2024',
    style: 'Boyhood pop, coreografías limpias y energía escolar.',
    bio: 'TWS presenta una estética clara, fresca y juvenil.',
    latest: 'Stages y actividad fandom 42.',
    image: 10,
    members: const [
      _IdolSeed('Shinyu', 'Líder · rap', 'Corea del Sur'),
      _IdolSeed('Dohoon', 'Vocal · dance', 'Corea del Sur'),
      _IdolSeed('Youngjae', 'Vocal', 'Corea del Sur'),
      _IdolSeed('Hanjin', 'Vocal', 'China'),
      _IdolSeed('Jihoon', 'Dance · vocal', 'Corea del Sur'),
      _IdolSeed('Kyungmin', 'Vocal · maknae', 'Corea del Sur'),
    ],
  ),
  _group(
    id: 'cortis',
    name: 'CORTIS',
    fandom: 'COER',
    company: 'BIGHIT MUSIC',
    debut: '2025',
    style: 'Young creator crew, pop global y energía rookie.',
    bio:
        'CORTIS se organiza como ficha ampliable para seguir integrantes, clips y noticias oficiales.',
    latest: 'Debut, clips y actividad COER.',
    image: 11,
    members: const [
      _IdolSeed('Martin', 'Líder · creador · performance', 'Corea / Canadá'),
      _IdolSeed('James', 'Performance · creativo', 'Internacional'),
      _IdolSeed('Juhoon', 'Vocal · performance', 'Corea del Sur'),
      _IdolSeed('Seonghyeon', 'Vocal · performance', 'Corea del Sur'),
      _IdolSeed('Keonho', 'Vocal · maknae', 'Corea del Sur'),
    ],
  ),
];

final discoverIdols = discoverGroups.expand((group) => group.idols).toList();

DiscoverArtistEntity _entityFromGroup(DiscoverGroup group) {
  return DiscoverArtistEntity(
    groupId: group.id,
    name: group.name,
    aliases: group.aliases,
    country: group.country,
    region: group.region,
    type: group.type,
    status: group.status,
    fandom: group.fandom,
    description: group.bio,
    members: group.idols.map((idol) => idol.name).toList(),
    relatedNewsIds: group.relatedNewsIds,
    relatedFancamIds: group.relatedFancamIds,
    tags: [
      group.fandom,
      group.company,
      group.debut,
      group.style,
      ...group.tags,
    ],
    source: group.source,
    createdBy: group.createdBy,
    lastUpdated: group.lastUpdated,
    imageAsset: group.imageAsset,
    officialUrl: group.officialUrl,
    imageUrl: group.imageUrl,
    imageSource: group.imageSource,
    imageLicense: group.imageLicense,
    attribution: group.attribution,
    author: group.author,
    licenseUrl: group.licenseUrl,
    demoFeatured: true,
  );
}

final discoverFeaturedEntities = discoverGroups
    .map(_entityFromGroup)
    .toList(growable: false);

const discoverEmergingEntities = <DiscoverArtistEntity>[
  DiscoverArtistEntity(
    groupId: 'entity-xg-global',
    name: 'XG',
    aliases: ['Xtraordinary Girls', 'ALPHAZ'],
    country: 'Japón / Global',
    region: 'Asia · Global',
    type: DiscoverEntityType.project,
    status: DiscoverEntityStatus.verified,
    fandom: 'ALPHAZ',
    description:
        'Proyecto global conectado con la conversación Hallyu por performance, rap, vocal y fandom internacional.',
    members: ['Jurin', 'Chisa', 'Hinata', 'Harvey', 'Juria', 'Maya', 'Cocona'],
    relatedNewsIds: ['news-xg-detected'],
    relatedFancamIds: [],
    tags: ['global pop', 'performance', 'rap', 'girl group'],
    source: 'demo_scalable_catalog',
    createdBy: 'HallyuHub editorial',
    lastUpdated: '2026-06-04',
    imageAsset: 'assets/demo-posts/post-12.jpg',
  ),
  DiscoverArtistEntity(
    groupId: 'entity-palermo-cover-crew',
    name: 'Palermo Cover Crew',
    aliases: ['PCC', 'K-pop Palermo'],
    country: 'Argentina',
    region: 'Buenos Aires · Palermo',
    type: DiscoverEntityType.coverCrew,
    status: DiscoverEntityStatus.communitySuggested,
    fandom: 'Multi fandom',
    description:
        'Crew local de dance cover para eventos, random play dance y proyectos colaborativos de fans.',
    members: ['Equipo abierto'],
    relatedNewsIds: ['news-palermo-cover'],
    relatedFancamIds: [],
    tags: ['Argentina', 'Palermo', 'dance cover', 'crew local'],
    source: 'community_suggestions',
    createdBy: '@cami.stay',
    lastUpdated: '2026-06-04',
    imageAsset: 'assets/demo-posts/post-06.jpg',
  ),
  DiscoverArtistEntity(
    groupId: 'entity-rosario-kpop-lab',
    name: 'Rosario K-pop Lab',
    aliases: ['RKL', 'K-pop Rosario'],
    country: 'Argentina',
    region: 'Santa Fe · Rosario',
    type: DiscoverEntityType.localKpop,
    status: DiscoverEntityStatus.emerging,
    fandom: 'Multi fandom',
    description:
        'Proyecto local para ensayos abiertos, showcases y contenido K-pop hecho por fans de la región.',
    members: ['Productores fan', 'Dance teams', 'Vocal covers'],
    relatedNewsIds: [],
    relatedFancamIds: [],
    tags: ['Argentina', 'Rosario', 'local K-pop', 'showcase'],
    source: 'demo_scalable_catalog',
    createdBy: 'HallyuHub local',
    lastUpdated: '2026-06-04',
    imageAsset: 'assets/demo-posts/post-01.jpg',
  ),
  DiscoverArtistEntity(
    groupId: 'entity-rookie-radar-latam',
    name: 'Rookie Radar LATAM',
    aliases: ['Nugu Radar', 'Rookie Watch'],
    country: 'Latinoamérica',
    region: 'LATAM',
    type: DiscoverEntityType.fanCrew,
    status: DiscoverEntityStatus.communitySuggested,
    fandom: 'Rookies',
    description:
        'Fan project para descubrir rookies, artistas menos conocidos y debuts recomendados por la comunidad.',
    members: ['Curadores fan'],
    relatedNewsIds: [],
    relatedFancamIds: [],
    tags: ['rookies', 'nugu', 'descubrimiento', 'LATAM'],
    source: 'community_suggestions',
    createdBy: 'Nugu club LATAM',
    lastUpdated: '2026-06-04',
    imageAsset: 'assets/demo-posts/post-02.jpg',
  ),
  DiscoverArtistEntity(
    groupId: 'entity-haneul-project',
    name: 'Haneul Project',
    aliases: ['Haneul', 'Proyecto Haneul'],
    country: 'Chile',
    region: 'Santiago · Chile',
    type: DiscoverEntityType.project,
    status: DiscoverEntityStatus.pendingReview,
    fandom: 'Por definir',
    description:
        'Proyecto emergente sugerido por fans. Está pendiente de revisión antes de tener ficha completa.',
    members: ['Pendiente'],
    relatedNewsIds: [],
    relatedFancamIds: [],
    tags: ['Chile', 'proyecto emergente', 'pendiente'],
    source: 'community_suggestions',
    createdBy: '@hallyu.latam',
    lastUpdated: '2026-06-04',
    imageAsset: 'assets/demo-posts/post-04.jpg',
  ),
];

final discoverArtistEntities = <DiscoverArtistEntity>[
  ...discoverFeaturedEntities,
  ...discoverEmergingEntities,
];

const discoverFutureSupabaseTables = <String>[
  'groups',
  'artists',
  'group_members',
  'artist_aliases',
  'news_items',
  'community_suggestions',
  'fancams',
];

const discoverNews = <DiscoverNews>[
  DiscoverNews(
    id: 'news-skz',
    artist: 'Stray Kids',
    title: 'Stray Kids prepara una nueva etapa con teaser cinematográfico',
    source: 'Google News RSS demo',
    summary:
        'Fanbases latinas reúnen guías, horarios y enlaces oficiales para acompañar la próxima era.',
    time: 'hace 42 min',
    status: 'Confirmado',
    imageAsset: 'assets/demo-posts/post-03.jpg',
    originalTitle:
        'Stray Kids prepara una nueva etapa con teaser cinematográfico',
    originalUrl:
        'https://news.google.com/search?q=Stray%20Kids%20K-pop%20comeback',
    publishedAt: '2026-06-04T13:20:00-04:00',
    generatedSummary:
        'Hally resume la novedad: Stray Kids está generando conversación por teasers, guías de streaming y actividades que fanbases de Latinoamérica empiezan a ordenar para acompañar la próxima etapa.',
    relatedGroups: ['Stray Kids'],
    relatedArtists: ['Bang Chan', 'Felix', 'Hyunjin'],
    tags: ['comeback', 'teaser', 'confirmado', 'fandom'],
    confidence: 'demo-summary/high',
    lastUpdated: '2026-06-04T14:00:00-04:00',
    trending: true,
  ),
  DiscoverNews(
    id: 'news-bp',
    artist: 'BLACKPINK',
    title: 'BLACKPINK impulsa un nuevo dance challenge',
    source: 'Google News demo',
    summary:
        'El challenge aparece entre los clips más compartidos por creadores de K-pop en Latinoamérica.',
    time: 'hace 1 h',
    status: 'Tendencia',
    imageAsset: 'assets/demo-posts/post-07.jpg',
    originalTitle: 'BLACKPINK impulsa un nuevo dance challenge',
    originalUrl:
        'https://news.google.com/search?q=BLACKPINK%20dance%20challenge%20K-pop',
    publishedAt: '2026-06-04T12:45:00-04:00',
    generatedSummary:
        'Hally vio que BLACKPINK vuelve a moverse fuerte entre clips, baile y comunidades multi fandom. Es una novedad para seguir si te interesan challenges y tendencias visuales.',
    relatedGroups: ['BLACKPINK'],
    relatedArtists: ['Jennie', 'Lisa', 'Jisoo', 'Rosé'],
    tags: ['tendencia', 'dance challenge', 'fandom', 'videos'],
    confidence: 'demo-summary/high',
    lastUpdated: '2026-06-04T14:00:00-04:00',
    trending: true,
  ),
  DiscoverNews(
    id: 'news-nj',
    artist: 'NewJeans',
    title: 'NewJeans vuelve a ser tema central en foros de estilo K-pop',
    source: 'Google News RSS demo',
    summary:
        'Outfits Y2K, fancams y edits mantienen al grupo entre las conversaciones destacadas.',
    time: 'hace 2 h',
    status: 'Reciente',
    imageAsset: 'assets/demo-posts/post-09.jpg',
    originalTitle:
        'NewJeans vuelve a ser tema central en foros de estilo K-pop',
    originalUrl:
        'https://news.google.com/search?q=NewJeans%20fashion%20K-pop%20Y2K',
    publishedAt: '2026-06-04T11:55:00-04:00',
    generatedSummary:
        'Hally agrupa la conversación sobre NewJeans alrededor de estética, moda, fancams y edits. La idea es darte contexto rápido sin copiar notas ni publicaciones originales.',
    relatedGroups: ['NewJeans'],
    relatedArtists: ['Hanni', 'Danielle', 'Minji'],
    tags: ['reciente', 'moda', 'fancams', 'estilo'],
    confidence: 'demo-summary/medium',
    lastUpdated: '2026-06-04T14:00:00-04:00',
  ),
  DiscoverNews(
    id: 'news-ive',
    artist: 'IVE',
    title: 'DIVE LATAM arma una guía visual para seguir los próximos stages',
    source: 'HallyuHub comunidad demo',
    summary:
        'La comunidad ordenó presentaciones, clips y espacios seguros para fans nuevos.',
    time: 'hace 3 h',
    status: 'Confirmado',
    imageAsset: 'assets/demo-posts/post-04.jpg',
    originalTitle:
        'DIVE LATAM arma una guía visual para seguir los próximos stages',
    originalUrl: 'https://news.google.com/search?q=IVE%20K-pop%20stages',
    publishedAt: '2026-06-04T10:50:00-04:00',
    generatedSummary:
        'Hally ordena esta guía de comunidad para seguir presentaciones de IVE con horarios, enlaces y recomendaciones útiles para fans que quieren acompañar los próximos stages.',
    relatedGroups: ['IVE'],
    relatedArtists: ['Wonyoung', 'Yujin', 'Rei'],
    tags: ['fandom', 'guía', 'confirmado', 'stages'],
    confidence: 'community-demo/medium',
    lastUpdated: '2026-06-04T14:00:00-04:00',
  ),
  DiscoverNews(
    id: 'news-ateez',
    artist: 'ATEEZ',
    title: 'ATINY organiza encuentros previos al próximo streaming party',
    source: 'HallyuHub comunidad demo',
    summary:
        'Comunidades de Chile, Argentina y Uruguay coordinan horarios y actividades.',
    time: 'hace 5 h',
    status: 'Comunidad',
    imageAsset: 'assets/demo-posts/post-11.jpg',
    originalTitle:
        'ATINY organiza encuentros previos al próximo streaming party',
    originalUrl:
        'https://news.google.com/search?q=ATEEZ%20ATINY%20streaming%20party',
    publishedAt: '2026-06-04T08:30:00-04:00',
    generatedSummary:
        'Hally resume la actividad ATINY en Latinoamérica: encuentros, horarios y organización previa para que los fans puedan sumarse con más claridad.',
    relatedGroups: ['ATEEZ'],
    relatedArtists: ['Hongjoong', 'San', 'Mingi'],
    tags: ['comunidad', 'streaming party', 'latam', 'fandom'],
    confidence: 'community-demo/medium',
    lastUpdated: '2026-06-04T14:00:00-04:00',
  ),
  DiscoverNews(
    id: 'news-palermo-cover',
    artist: 'Palermo Cover Crew',
    title: 'Cover crews de Palermo preparan una muestra abierta multi fandom',
    source: 'HallyuHub comunidad demo',
    summary:
        'Hally encontró un proyecto local para seguir dentro de la comunidad fan.',
    time: 'hace 7 h',
    status: 'Pendiente',
    imageAsset: 'assets/demo-posts/post-06.jpg',
    originalTitle:
        'Cover crews de Palermo preparan una muestra abierta multi fandom',
    originalUrl:
        'https://news.google.com/search?q=K-pop%20cover%20crew%20Palermo%20Argentina',
    publishedAt: '2026-06-04T06:15:00-04:00',
    generatedSummary:
        'Hally encontró una movida local en Palermo y la deja como tema comunitario para seguir. Todavía no es una ficha completa, pero ayuda a descubrir proyectos cercanos.',
    relatedGroups: [],
    relatedArtists: ['Palermo Cover Crew'],
    tags: ['local', 'cover crew', 'pendiente', 'Argentina'],
    confidence: 'community-detected/medium',
    lastUpdated: '2026-06-04T14:00:00-04:00',
    relatedEntityIds: ['entity-palermo-cover-crew'],
    detectedEntityTags: ['Palermo Cover Crew', 'K-pop Palermo'],
  ),
  DiscoverNews(
    id: 'news-xg-detected',
    artist: 'XG',
    title: 'Fans latinos piden una ficha ampliada para XG y proyectos globales',
    source: 'HallyuHub comunidad demo',
    summary:
        'El buscador ya puede tratar artistas globales, solistas y proyectos como entidades separadas del catálogo original.',
    time: 'hace 9 h',
    status: 'Entidad detectada',
    imageAsset: 'assets/demo-posts/post-12.jpg',
    originalTitle:
        'Fans latinos piden una ficha ampliada para XG y proyectos globales',
    originalUrl: 'https://news.google.com/search?q=XG%20global%20K-pop',
    publishedAt: '2026-06-04T04:45:00-04:00',
    generatedSummary:
        'Hally marca a XG como tema global para seguir dentro del fandom latino. La ficha puede ampliarse más adelante con información revisada y enlaces originales.',
    relatedGroups: [],
    relatedArtists: ['XG'],
    tags: ['entidad detectada', 'global', 'pendiente', 'sugerencia'],
    confidence: 'entity-detected/medium',
    lastUpdated: '2026-06-04T14:00:00-04:00',
    relatedEntityIds: ['entity-xg-global'],
    detectedEntityTags: ['XG', 'ALPHAZ', 'proyecto global'],
  ),
];

const discoverCommunities = <DiscoverCommunity>[
  DiscoverCommunity(
    id: 'hallyu-latam',
    name: 'Hallyu LATAM',
    region: 'Latinoamérica',
    members: '128K',
    activity: 'Muy activa',
    fandom: 'Multi fandom',
    description: 'Comunidad general para noticias, debates y ayuda fandom.',
    posts: [
      '¿Qué comeback esperan este mes?',
      'Armamos una guía de eventos seguros por ciudad.',
    ],
  ),
  DiscoverCommunity(
    id: 'stay-argentina',
    name: 'STAY Argentina',
    region: 'Argentina',
    members: '18.4K',
    activity: 'Activa hoy',
    fandom: 'Stray Kids',
    description: 'Compras grupales, eventos y proyectos STAY en Argentina.',
    posts: [
      'Random dance en Palermo este sábado.',
      'Checklist para la próxima era.',
    ],
  ),
  DiscoverCommunity(
    id: 'army-chile',
    name: 'ARMY Chile',
    region: 'Chile',
    members: '36.2K',
    activity: 'Muy activa',
    fandom: 'BTS',
    description: 'Cupsleeves, donaciones y eventos nacionales.',
    posts: [
      'Nuevo cupsleeve confirmado en Santiago.',
      'Compartimos playlist para fans nuevas.',
    ],
  ),
  DiscoverCommunity(
    id: 'moa-peru',
    name: 'MOA Perú',
    region: 'Perú',
    members: '9.7K',
    activity: 'Semanal',
    fandom: 'TXT',
    description: 'Calendario de comeback y juntadas en Lima y regiones.',
    posts: [
      'Guía para conocer las eras de TXT.',
      '¿Quién se suma al meetup de Lima?',
    ],
  ),
  DiscoverCommunity(
    id: 'once-bogota',
    name: 'ONCE Bogotá',
    region: 'Bogotá, Colombia',
    members: '1.9K',
    activity: 'Mensual',
    fandom: 'TWICE',
    description: 'Encuentros cercanos para fans de TWICE.',
    posts: ['Trade meet con referencias verificadas.'],
  ),
  DiscoverCommunity(
    id: 'blink-cdmx',
    name: 'BLINK CDMX',
    region: 'CDMX, México',
    members: '7.3K',
    activity: 'Activa hoy',
    fandom: 'BLACKPINK',
    description: 'Random dance, merch local y eventos BLINK.',
    posts: ['Ensayo abierto para dance cover.'],
  ),
  DiscoverCommunity(
    id: 'carat-valpo',
    name: 'CARAT Valparaíso',
    region: 'Valparaíso, Chile',
    members: '860',
    activity: 'Grupo cercano',
    fandom: 'SEVENTEEN',
    description: 'Comunidad regional para CARAT.',
    posts: ['Escuchamos unit songs este viernes.'],
  ),
  DiscoverCommunity(
    id: 'nugu-club',
    name: 'Nugu club LATAM',
    region: 'Latinoamérica',
    members: '6.8K',
    activity: 'Diaria',
    fandom: 'Rookies',
    description: 'Descubrimiento de grupos nuevos y artistas menos conocidos.',
    posts: ['Cinco debuts para escuchar esta semana.'],
  ),
  DiscoverCommunity(
    id: 'atiny-uy',
    name: 'ATINY Uruguay',
    region: 'Montevideo, Uruguay',
    members: '3.2K',
    activity: 'Activa hoy',
    fandom: 'ATEEZ',
    description: 'Stages, streaming parties y encuentros ATINY.',
    posts: ['Previa del próximo streaming party.'],
  ),
  DiscoverCommunity(
    id: 'dive-lima',
    name: 'DIVE Lima',
    region: 'Lima, Perú',
    members: '4.1K',
    activity: 'Semanal',
    fandom: 'IVE',
    description: 'Fancams, outfits y eventos DIVE.',
    posts: ['Intercambio de photocards este domingo.'],
  ),
];

const discoverEvents = <DiscoverEvent>[
  DiscoverEvent(
    id: 'event-dance-scl',
    title: 'Random play dance',
    communityId: 'hallyu-latam',
    city: 'Santiago',
    country: 'Chile',
    date: 'Sáb 13 jun · 16:00',
    location: 'Parque Bustamante',
    description:
        'Encuentro abierto con playlists por generación y zona tranquila para conocer gente.',
    organizer: '@agus.random',
    fandom: 'Multi fandom',
    imageAsset: 'assets/demo-posts/post-06.jpg',
  ),
  DiscoverEvent(
    id: 'event-stay-ba',
    title: 'STAY fanmeeting',
    communityId: 'stay-argentina',
    city: 'Buenos Aires',
    country: 'Argentina',
    date: 'Dom 21 jun · 15:30',
    location: 'Palermo',
    description: 'Merienda, juegos y espacio de trades con referencias.',
    organizer: '@cami.stay',
    fandom: 'Stray Kids',
    imageAsset: 'assets/demo-posts/post-03.jpg',
  ),
  DiscoverEvent(
    id: 'event-army-cup',
    title: 'Cupsleeve de aniversario',
    communityId: 'army-chile',
    city: 'Santiago',
    country: 'Chile',
    date: 'Sáb 27 jun · 12:00',
    location: 'Barrio Italia',
    description:
        'Café fandom con freebies, playlist y punto de encuentro ARMY.',
    organizer: '@mika.army',
    fandom: 'BTS',
    imageAsset: 'assets/demo-posts/post-08.jpg',
  ),
  DiscoverEvent(
    id: 'event-dive-trade',
    title: 'Trade meet DIVE',
    communityId: 'dive-lima',
    city: 'Lima',
    country: 'Perú',
    date: 'Dom 05 jul · 14:00',
    location: 'Miraflores',
    description: 'Intercambio de photocards con checklist de seguridad.',
    organizer: '@isa.dive',
    fandom: 'IVE',
    imageAsset: 'assets/demo-posts/post-10.jpg',
  ),
  DiscoverEvent(
    id: 'event-atiny-stream',
    title: 'Streaming party ATINY',
    communityId: 'atiny-uy',
    city: 'Montevideo',
    country: 'Uruguay',
    date: 'Vie 10 jul · 20:00',
    location: 'Online + punto local',
    description: 'Actividad coordinada con guías para fans nuevas.',
    organizer: '@thiago.atiny',
    fandom: 'ATEEZ',
    imageAsset: 'assets/demo-posts/post-11.jpg',
  ),
];

const discoverGuides = <DiscoverGuide>[
  DiscoverGuide(
    id: 'guide-comeback',
    title: '¿Qué es un comeback?',
    category: 'Vocabulario',
    summary: 'Cómo seguir un regreso musical sin perderte.',
    body:
        'Un comeback es el regreso promocional de un artista con canción, álbum o single nuevo. Puede incluir teasers, fotos conceptuales, MV y presentaciones en programas musicales. Empezá guardando la fecha del lanzamiento y elegí pocas fuentes oficiales.',
  ),
  DiscoverGuide(
    id: 'guide-bias',
    title: '¿Qué significa bias?',
    category: 'Vocabulario',
    summary: 'Tu integrante favorito y por qué no hace falta elegir rápido.',
    body:
        'Bias es el integrante que más te llama la atención dentro de un grupo. Puede cambiar con el tiempo. Bias wrecker es quien te hace dudar de tu favorito. No es obligatorio elegir uno.',
  ),
  DiscoverGuide(
    id: 'guide-fandom',
    title: '¿Qué es un fandom?',
    category: 'Comunidad',
    summary: 'Cómo encontrar espacios sanos para compartir.',
    body:
        'Un fandom es la comunidad de fans de un artista. Buscá espacios con reglas claras, moderación y referencias verificables antes de sumarte a eventos o compras.',
  ),
  DiscoverGuide(
    id: 'guide-photocard',
    title: 'Photocards y trades seguros',
    category: 'Colección',
    summary: 'Primeros pasos para coleccionar e intercambiar.',
    body:
        'Una photocard es una tarjeta coleccionable. Para tradear: armá una wishlist, pedí referencias, protegé cada tarjeta con sleeve y acordá claramente envío o entrega.',
  ),
  DiscoverGuide(
    id: 'guide-lightstick',
    title: '¿Qué es un lightstick?',
    category: 'Conciertos',
    summary: 'El objeto luminoso que identifica a un fandom.',
    body:
        'Un lightstick es un dispositivo luminoso oficial o inspirado en el fandom. Para conciertos revisá baterías, reglas del recinto y autenticidad antes de comprar.',
  ),
  DiscoverGuide(
    id: 'guide-fancam',
    title: 'Cómo mirar una fancam',
    category: 'Contenido',
    summary: 'Videos enfocados en un idol o performance.',
    body:
        'Una fancam suele seguir a un integrante durante una presentación. Sirve para descubrir presencia escénica, baile y detalles que no siempre entran en la cámara principal.',
  ),
  DiscoverGuide(
    id: 'guide-practice',
    title: 'Dance practice',
    category: 'Contenido',
    summary: 'La coreografía completa, sin cortes de escenario.',
    body:
        'Un dance practice muestra la coreografía con una cámara más estable. Es un buen lugar para entender posiciones, transiciones y estilo del grupo.',
  ),
  DiscoverGuide(
    id: 'guide-show',
    title: 'Music shows y comeback stages',
    category: 'Contenido',
    summary: 'Dónde aparecen las promociones nuevas.',
    body:
        'Los music shows son programas donde los artistas presentan canciones promocionales. Un comeback stage es una de las primeras presentaciones del lanzamiento nuevo.',
  ),
  DiscoverGuide(
    id: 'guide-stream',
    title: '¿Qué significa stream?',
    category: 'Comunidad',
    summary: 'Escuchar contenido de forma organizada y saludable.',
    body:
        'Stream significa reproducir música o videos. Usá plataformas oficiales y mantené una experiencia saludable: escuchar K-pop debe seguir siendo disfrutable.',
  ),
  DiscoverGuide(
    id: 'guide-start-group',
    title: 'Cómo empezar con un grupo',
    category: 'Primeros pasos',
    summary: 'Una ruta corta para no saturarte.',
    body:
        'Elegí tres canciones distintas, un live stage y una entrevista. Después recorré integrantes y guardá lo que realmente te interese. No hace falta aprender todo en un día.',
  ),
  DiscoverGuide(
    id: 'guide-follow-comeback',
    title: 'Cómo seguir un comeback',
    category: 'Primeros pasos',
    summary: 'Teasers, estreno y stage en una checklist sencilla.',
    body:
        'Guardá tres momentos: calendario de teasers, estreno del MV y primer stage. Sumá contenido extra solo si te divierte.',
  ),
  DiscoverGuide(
    id: 'guide-find-community',
    title: 'Encontrar comunidad en tu país',
    category: 'Comunidad',
    summary: 'País, región y ciudad con seguridad primero.',
    body:
        'Empezá por una comunidad nacional, revisá reglas y moderación, y después explorá grupos locales. Para eventos presenciales compartí planes con alguien de confianza.',
  ),
];

const discoverStores = <DiscoverStore>[
  DiscoverStore(
    id: 'store-seoul-corner',
    name: 'Seoul Corner',
    city: 'Santiago',
    country: 'Chile',
    category: 'Álbumes y accesorios',
    rating: '4.9',
    description: 'Álbumes sellados, sleeves y retiro en tienda.',
    products: ['Álbum edición limitada', 'Sleeves holográficos', 'Carpetas A5'],
    imageAsset: 'assets/demo-posts/post-10.jpg',
  ),
  DiscoverStore(
    id: 'store-pink-stage',
    name: 'Pink Stage Shop',
    city: 'Buenos Aires',
    country: 'Argentina',
    category: 'Photocards y preventas',
    rating: '4.8',
    description: 'Photocards, preventas y compras grupales con referencias.',
    products: ['Preventa de álbum', 'Photocard oficial', 'Set fanmade'],
    imageAsset: 'assets/demo-posts/post-05.jpg',
  ),
  DiscoverStore(
    id: 'store-mochi-market',
    name: 'Mochi Market',
    city: 'Lima',
    country: 'Perú',
    category: 'Lightsticks y merch',
    rating: '4.7',
    description: 'Lightsticks, pilas y accesorios para conciertos.',
    products: ['Lightstick oficial', 'Funda protectora', 'Strap fandom'],
    imageAsset: 'assets/demo-posts/post-12.jpg',
  ),
  DiscoverStore(
    id: 'store-cute-seoul',
    name: 'Cute Seoul Studio',
    city: 'CDMX',
    country: 'México',
    category: 'Ropa y fanmade',
    rating: '4.6',
    description: 'Ropa, tote bags y accesorios creados por fans.',
    products: ['Hoodie fandom', 'Tote bag', 'Pins esmaltados'],
    imageAsset: 'assets/demo-posts/post-08.jpg',
  ),
];
