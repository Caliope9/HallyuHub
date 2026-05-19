const state = {
  view: "home",
  communityTab: "global",
  selectedAvatar: "berry",
  ambience: "hallyu",
  selectedGroup: "skz",
  activityTab: "activity",
  profileTab: "posts",
  profileEditorOpen: false,
  homeFilter: "all",
  activePost: null,
  savedPosts: {},
  sharedPosts: {},
  settingsPanel: null,
  viewedProfile: null,
  followedProfiles: {},
  selectedProfileBg: "army",
  activeStory: null,
  likedStories: {},
  storyDirection: 1,
  storyComposerOpen: false,
  ownStoryStatsOpen: false,
  ownStory: null,
  storyInbox: [],
  authMode: "login",
  isAuthenticated: false,
  user: null,
  session: null,
  supabase: null,
  backendMode: "local",
  livePosts: [],
  liveProfiles: [],
  newsItems: [],
  newsLoading: false,
  newsLastUpdated: null,
  newsFilter: {
    artist: "all",
    topic: "recent",
    status: "all",
    language: "all",
  },
};

let storyAutoTimer = null;

const titleByView = {
  home: "Tu universo K-pop latino",
  search: "Buscar",
  trends: "Trends K-pop",
  publish: "Crear publicacion",
  notifications: "Actividad e inbox",
  settings: "Ajustes",
  events: "Eventos fandom",
  market: "Marketplace oficial",
  news: "Noticias actuales",
  groups: "Grupos e idols",
  community: "Comunidades latinas",
  rookie: "Me quiero meter al K-pop",
  messages: "Mensajes privados",
  profile: "Perfil",
};

const storage = {
  get(key, fallback) {
    try {
      const value = localStorage.getItem(key);
      return value ? JSON.parse(value) : fallback;
    } catch {
      return fallback;
    }
  },
  set(key, value) {
    try {
      localStorage.setItem(key, JSON.stringify(value));
    } catch {
      // En la version futura este punto se reemplaza por Firebase/Supabase.
    }
  },
  remove(key) {
    try {
      localStorage.removeItem(key);
    } catch {
      // Sin persistencia disponible.
    }
  },
};

const defaultUser = {
  email: "luna@hallyuhub.app",
  password: "demo123",
  name: "Luna Hallyu",
  username: "lunahallyu",
  bio: "STAY, ARMY y coleccionista de photocards. Santiago, Chile.",
  avatar: "berry",
  ambience: "hallyu",
  accent: "#fbbcdb",
  mode: "dark",
  notifications: true,
  privateProfile: false,
  followers: "8.7K",
  following: "412",
  posts: "48",
  photocards: "286",
  country: "Chile 🇨🇱",
  fandom: "ARMY 💜",
  bias: "Jungkook",
  favoriteGroup: "BTS",
  socials: "Instagram @lunahallyu · TikTok @lunahallyu",
  phrase: "Brillando en cada comeback.",
  fandomLevel: "Level 18 Fandom",
  level: 18,
  starsReceived: "32.8K",
  trendsCreated: "21",
  premium: false,
  phone: "",
  language: "Español",
  themePremium: false,
  onboarded: true,
  profileBg: "army",
};

const futureBackend = {
  provider: "Supabase Auth + Postgres + Storage",
  next: "Firebase o Supabase",
  collections: ["users", "posts", "groups", "followers", "messages", "notifications"],
};

const supabaseBuckets = {
  avatars: "avatars",
  posts: "post-media",
  trends: "trend-media",
};

const art = [
  "linear-gradient(135deg, #fbbcdb, #65e4ff 52%, #ffb86b)",
  "linear-gradient(135deg, #77f4c7, #263d72 50%, #d946ef)",
  "linear-gradient(135deg, #ffb86b, #fbbcdb 45%, #271244)",
  "linear-gradient(135deg, #65e4ff, #a855f7 48%, #0c0616)",
  "linear-gradient(135deg, #fff1f9, #d946ef 44%, #180625)",
];

const ambiences = [
  {
    id: "hallyu",
    name: "Hallyu Pop",
    group: "Color general",
    detail: "Rosa, celeste y durazno para que no se sienta tan violeta.",
  },
  {
    id: "skz",
    name: "Thunder Stage",
    group: "Stray Kids",
    detail: "Rojo neon, negro y luces de escenario.",
  },
  {
    id: "bts",
    name: "Purple Galaxy",
    group: "BTS",
    detail: "Lila suave con cielo de galaxia y brillo fan.",
  },
  {
    id: "bp",
    name: "Pink Venom",
    group: "BLACKPINK",
    detail: "Rosa fuerte, negro glossy y energia fashion.",
  },
  {
    id: "nj",
    name: "Fresh Y2K",
    group: "NewJeans",
    detail: "Celeste, verde menta y vibra retro fresca.",
  },
  {
    id: "svt",
    name: "Rose Quartz",
    group: "SEVENTEEN",
    detail: "Rosa cuarzo, azul serenity y look luminoso.",
  },
];

const news = [
  {
    id: "demo-news-skz",
    artist: "Stray Kids",
    title: "Stray Kids prepara nueva etapa con teaser cinematografico",
    source: "HallyuHub demo",
    date: new Date(Date.now() - 1000 * 60 * 42).toISOString(),
    summary: "Fanbases latinas reunen guias, horarios y links oficiales para seguir la proxima era del grupo.",
    link: "https://news.google.com/search?q=Stray%20Kids%20K-pop",
    status: "approved",
    language: "es",
    country: "LATAM",
    trending: true,
  },
  {
    id: "demo-news-bp",
    artist: "BLACKPINK",
    title: "BLACKPINK impulsa nuevo trend de dance challenge",
    source: "Google News demo",
    date: new Date(Date.now() - 1000 * 60 * 90).toISOString(),
    summary: "El challenge aparece entre los clips mas compartidos por creadores de K-pop en Latinoamerica.",
    link: "https://news.google.com/search?q=BLACKPINK%20K-pop",
    status: "pending",
    language: "es",
    country: "AR",
    trending: true,
  },
  {
    id: "demo-news-nj",
    artist: "NewJeans",
    title: "NewJeans vuelve a ser tema central en foros de estilo K-pop",
    source: "HallyuHub demo",
    date: new Date(Date.now() - 1000 * 60 * 140).toISOString(),
    summary: "Outfits Y2K, fancams y edits mantienen al grupo entre las conversaciones destacadas.",
    link: "https://news.google.com/search?q=NewJeans%20K-pop",
    status: "approved",
    language: "es",
    country: "LATAM",
    trending: false,
  },
];

const NEWS_REFRESH_MS = 3 * 60 * 60 * 1000;
const newsArtists = ["BTS", "BLACKPINK", "Stray Kids", "NewJeans", "TWICE", "SEVENTEEN", "ATEEZ", "IVE", "TXT"];

const userPosts = [
  {
    id: "demo-post-1",
    user: "Luna Hallyu",
    avatar: "berry",
    group: "STAY Chile",
    category: "posts",
    type: "popular",
    time: "hace 2 min",
    badge: "Stay ⭐",
    online: true,
    hashtags: ["#comeback", "#STAYLatam"],
    caption: "Mi setup para ver el comeback con amigas. Ya tengo snacks, light stick y playlist lista.",
    likes: "2.4K",
    comments: "188",
    location: "Santiago, Chile",
    taggedPeople: "@cami.stay, @mika",
    taggedPlace: "Cupsleeve Providencia",
    shares: "84",
    saves: "210",
  },
  {
    id: "demo-post-2",
    user: "Cami.STAY",
    avatar: "star",
    group: "Buenos Aires",
    category: "photocards",
    type: "trade",
    time: "hace 8 min",
    badge: "Blink 🖤💖",
    online: true,
    hashtags: ["#photocard", "#tradeSeguro"],
    caption: "Intercambio de photocards en Palermo. Solo trades con referencias y entrega segura.",
    likes: "918",
    comments: "64",
    location: "Palermo, Buenos Aires",
    taggedPlace: "K-shop local",
    shares: "32",
    saves: "146",
  },
  {
    id: "demo-post-3",
    user: "Vale Multi",
    avatar: "mochi",
    group: "K-pop 101",
    category: "posts",
    type: "guide",
    time: "hace 15 min",
    badge: "Army 💜",
    online: false,
    hashtags: ["#Kpop101", "#bias"],
    caption: "Mini guia para elegir tu primer grupo: empieza por 3 canciones, 1 live stage y 1 entrevista.",
    likes: "4.8K",
    comments: "301",
    shares: "420",
    saves: "1.2K",
  },
  {
    id: "demo-post-4",
    user: "Random Play BA",
    avatar: "neon",
    group: "Challenge",
    category: "trends",
    type: "trending",
    time: "hace 22 min",
    badge: "Blink 🖤💖",
    online: true,
    hashtags: ["#DanceChallenge", "#RandomPlay", "#BLACKPINK"],
    caption: "Nuevo challenge para random play dance: 20 segundos, entrada fuerte y final con pose idol.",
    likes: "9.6K",
    comments: "724",
    location: "Buenos Aires",
    taggedPeople: "@hallyu.ba, @dancecrew",
    taggedPlace: "Parque Centenario",
    shares: "980",
    saves: "2.4K",
  },
  {
    id: "demo-post-5",
    user: "Hallyu Chile",
    avatar: "idol",
    group: "Evento fandom",
    category: "posts",
    type: "event",
    time: "hace 38 min",
    badge: "Army 💜",
    online: true,
    hashtags: ["#EventoKpop", "#Santiago", "#FandomSeguro"],
    caption: "Cupsleeve especial con trade zone, photo spot y playlist de comebacks. Cupos limitados.",
    likes: "6.1K",
    comments: "512",
    location: "Santiago, Chile",
    taggedPlace: "Barrio Italia",
    shares: "550",
    saves: "1.8K",
  },
  {
    id: "demo-post-6",
    user: "Tokki Mood",
    avatar: "cyber",
    group: "Outfit",
    category: "outfits",
    type: "outfit",
    time: "hace 1 h",
    badge: "Tokki 🐰",
    online: false,
    hashtags: ["#KpopOutfit", "#Y2K", "#PastelNeon"],
    caption: "Outfit pastel/neon para grabar fancam: denim claro, lazo cute y brillos suaves.",
    likes: "3.3K",
    comments: "143",
    taggedPeople: "@style.kpop",
    shares: "110",
    saves: "740",
  },
];

const storyViewers = [
  { name: "Cami.STAY", badge: "Stay ⭐", action: "vio tu historia" },
  { name: "Mika", badge: "Army 💜", action: "dio estrella" },
  { name: "Vale Multi", badge: "Tokki 🐰", action: "vio tu historia" },
  { name: "Nico K", badge: "Once 🍭", action: "dio estrella" },
];

const followingStories = [
  { user: "Mika", avatar: "berry", label: "conciertos", time: "Hace 12 min", music: "BTS · live remix", title: "Concierto soñado", detail: "Luces, fan chants y pulsera lista para Santiago.", stars: 248, colors: "linear-gradient(160deg, #ffb703, #ff2d55 48%, #111827)" },
  { user: "Cami.STAY", avatar: "star", label: "fancams", time: "Hace 26 min", music: "Stray Kids · stage cut", title: "Fancam del dia", detail: "Mi toma favorita del dance break.", stars: 918, colors: "linear-gradient(160deg, #65e4ff, #a855f7 50%, #0c0616)" },
  { user: "Vale Multi", avatar: "mochi", label: "outfits", time: "Hace 41 min", music: "NewJeans · Y2K pop", title: "Outfit comeback", detail: "Rosa, denim y brillos para random dance.", stars: 573, colors: "linear-gradient(160deg, #fbbcdb, #65e4ff 52%, #ffb86b)" },
  { user: "Nico K", avatar: "berry", label: "idols", time: "Hace 1 h", music: "IVE · dreamy edit", title: "Idol mood", detail: "Visual board para elegir bias de la semana.", stars: 441, colors: "linear-gradient(160deg, #8b5cf6, #d9b4ff 52%, #101827)" },
  { user: "ARMY Chile", avatar: "star", label: "dance practice", time: "Hace 2 h", music: "BLACKPINK · dance break", title: "Practice night", detail: "Ensayo grupal antes del evento.", stars: 1200, colors: "linear-gradient(160deg, #0d0718, #8b5cf6 52%, #d9b4ff)" },
  { user: "DIVE Lima", avatar: "mochi", label: "photocards", time: "Hace 3 h", music: "SEVENTEEN · fan chant", title: "Trade seguro", detail: "Photocards protegidas y wishlist nueva.", stars: 336, colors: "linear-gradient(160deg, #fff1f9, #ff8ac8 48%, #8b5cf6)" },
];

const homeBanners = [
  { title: "Noticias destacadas", meta: "K-pop al minuto", colors: "linear-gradient(135deg, #1d1024, #fbbcdb 45%, #65e4ff)" },
  { title: "Nuevo trend BLACKPINK", meta: "Trends virales", colors: "linear-gradient(135deg, #09060a, #ff3ea5 52%, #ff8ac8)" },
  { title: "Dance challenge BTS", meta: "Challenge semanal", colors: "linear-gradient(135deg, #0d0718, #8b5cf6 52%, #d9b4ff)" },
  { title: "Evento K-pop Santiago", meta: "Agenda fandom", colors: "linear-gradient(135deg, #ffb703, #ff2d55 48%, #111827)" },
  { title: "Publicidad fan sponsor", meta: "Marcas K-pop", colors: "linear-gradient(135deg, #04131d, #77f4c7 48%, #ffd166)" },
  { title: "Trade de photocards", meta: "Marketplace seguro", colors: "linear-gradient(135deg, #fff1f9, #ff8ac8 48%, #8b5cf6)" },
  { title: "Top fancams del dia", meta: "Fancams premium", colors: "linear-gradient(135deg, #65e4ff, #77f4c7 52%, #0f172a)" },
];

const homeHighlightStories = [
  { label: "Viral", detail: "Top posts", avatar: "neon", filter: "viral", colors: "linear-gradient(160deg, #65e4ff, #d946ef)" },
  { label: "Trends", detail: "Resumen", avatar: "idol", filter: "trends", colors: "linear-gradient(160deg, #ffd166, #ff2d55)" },
  { label: "Outfit", detail: "K-style", avatar: "anime", filter: "outfits", colors: "linear-gradient(160deg, #fff1f9, #ff8ac8)" },
  { label: "Challenges", detail: "Dance", avatar: "cyber", filter: "challenges", colors: "linear-gradient(160deg, #77f4c7, #263d72)" },
  { label: "Eventos", detail: "Latam", avatar: "star", filter: "events", colors: "linear-gradient(160deg, #ffb703, #65e4ff)" },
  { label: "Idols", detail: "Grupos", avatar: "berry", view: "groups", colors: "linear-gradient(160deg, #fbbcdb, #a855f7)" },
];

const storyReactions = [
  "Saranghae 💜",
  "Bias moment ✨",
  "Legend stage 🎤",
  "Cute comeback 🎀",
  "Fancam approved 📸",
  "Main dancer 🔥",
  "Visual king 👑",
  "Stan forever 💿",
];

const storyDecorations = [
  "Corazones coreanos",
  "Neon pastel",
  "Stars glow",
  "Kawaii stickers",
  "Lightsticks",
  "Idol stage",
  "Glitter",
  "Fancam FX",
];

const trendVideos = [
  {
    user: "Cami.STAY",
    challenge: "Dance Challenge BLACKPINK",
    song: "BLACKPINK · dance break",
    description: "Version corta para grabar en plaza o evento fandom.",
    colors: "linear-gradient(160deg, #09060a, #ff3ea5 50%, #ff8ac8)",
  },
  {
    user: "Mika",
    challenge: "Paso viral de BTS",
    song: "BTS · fan edit",
    description: "Paso facil para fans nuevos que quieren sumarse sin presion.",
    colors: "linear-gradient(160deg, #0d0718, #8b5cf6 52%, #d9b4ff)",
  },
  {
    user: "Vale Multi",
    challenge: "Trend NewJeans",
    song: "NewJeans · Y2K pop",
    description: "Movimiento suave con outfit pastel y transicion rapida.",
    colors: "linear-gradient(160deg, #06131a, #65e4ff 46%, #77f4c7)",
  },
  {
    user: "Random Play BA",
    challenge: "Cover random play dance",
    song: "K-pop mix · LATAM",
    description: "Reto para grupos grandes en eventos y juntadas.",
    colors: "linear-gradient(160deg, #ffb703, #ff2d55 48%, #111827)",
  },
  {
    user: "Hallyu Chile",
    challenge: "Challenge K-pop Chile",
    song: "LATAM fandom · stage",
    description: "Trend local para mostrar pasos, light sticks y comunidad.",
    colors: "linear-gradient(160deg, #fbbcdb, #65e4ff 52%, #ffb86b)",
  },
];

const kpopGroups = [
  {
    id: "skz",
    name: "Stray Kids",
    fandom: "STAY",
    company: "JYP Entertainment",
    debut: "2018",
    style: "Rap potente, performance intensa, produccion propia y energia de escenario.",
    bio: "Stray Kids es un grupo conocido por su sonido intenso, letras con identidad propia y una base creativa fuerte. Su atractivo para fans nuevos suele estar en la energia de sus performances, la participacion de miembros en la musica y una comunidad STAY muy activa.",
    latest: "Comebacks, giras y contenido fandom se actualizan desde fuentes conectadas.",
    colors: "linear-gradient(135deg, #ff2d55, #ffb703 48%, #111827)",
    artists: [
      { name: "Bang Chan", role: "Lider · productor · vocal · rap", country: "Australia / Corea" },
      { name: "Lee Know", role: "Dance · vocal", country: "Corea del Sur" },
      { name: "Changbin", role: "Rap · productor", country: "Corea del Sur" },
      { name: "Hyunjin", role: "Dance · rap · visual", country: "Corea del Sur" },
      { name: "Han", role: "Rap · vocal · productor", country: "Corea del Sur" },
      { name: "Felix", role: "Dance · rap", country: "Australia / Corea" },
      { name: "Seungmin", role: "Vocal", country: "Corea del Sur" },
      { name: "I.N", role: "Vocal · maknae", country: "Corea del Sur" },
    ],
  },
  {
    id: "bts",
    name: "BTS",
    fandom: "ARMY",
    company: "BIGHIT MUSIC",
    debut: "2013",
    style: "Hip-hop, pop, mensajes personales, performance y narrativa de albums.",
    bio: "BTS es uno de los grupos mas influyentes del K-pop global. Su historia mezcla crecimiento artistico, mensajes sobre juventud, identidad y salud emocional, ademas de carreras individuales muy seguidas por ARMY.",
    latest: "Ideal para noticias de actividad grupal, proyectos solistas y eventos ARMY.",
    colors: "linear-gradient(135deg, #8b5cf6, #d9b4ff 48%, #101827)",
    artists: [
      { name: "RM", role: "Lider · rap", country: "Corea del Sur" },
      { name: "Jin", role: "Vocal", country: "Corea del Sur" },
      { name: "SUGA", role: "Rap · productor", country: "Corea del Sur" },
      { name: "j-hope", role: "Dance · rap", country: "Corea del Sur" },
      { name: "Jimin", role: "Vocal · dance", country: "Corea del Sur" },
      { name: "V", role: "Vocal", country: "Corea del Sur" },
      { name: "Jung Kook", role: "Vocal · dance · maknae", country: "Corea del Sur" },
    ],
  },
  {
    id: "bp",
    name: "BLACKPINK",
    fandom: "BLINK",
    company: "YG Entertainment",
    debut: "2016",
    style: "Pop global, rap, moda, visual fuerte y shows de alto impacto.",
    bio: "BLACKPINK combina musica pop de alto impacto, moda, presencia escenica y carreras individuales fuertes. Para BLINK, la app puede reunir lanzamientos, campanas, giras y contenido de cada integrante.",
    latest: "Se puede conectar a noticias, lanzamientos individuales y giras.",
    colors: "linear-gradient(135deg, #09060a, #ff3ea5 52%, #ff8ac8)",
    artists: [
      { name: "Jisoo", role: "Vocal · visual", country: "Corea del Sur" },
      { name: "Jennie", role: "Rap · vocal", country: "Corea del Sur" },
      { name: "Rose", role: "Vocal · dance", country: "Nueva Zelanda / Corea" },
      { name: "Lisa", role: "Dance · rap", country: "Tailandia" },
    ],
  },
  {
    id: "nj",
    name: "NewJeans",
    fandom: "Bunnies",
    company: "ADOR",
    debut: "2022",
    style: "Pop fresco, R&B, Y2K, baile natural y estetica juvenil.",
    bio: "NewJeans se reconoce por un sonido fresco, visuales Y2K y canciones faciles de compartir. Sus perfiles sirven mucho para fans que quieren seguir tendencias, videos cortos y lanzamientos visuales.",
    latest: "Perfecto para actualizar playlists, videos y contenido corto.",
    colors: "linear-gradient(135deg, #77f4c7, #65e4ff 52%, #ffd166)",
    artists: [
      { name: "Minji", role: "Vocal · dance", country: "Corea del Sur" },
      { name: "Hanni", role: "Vocal · dance", country: "Australia / Vietnam" },
      { name: "Danielle", role: "Vocal · dance", country: "Australia / Corea" },
      { name: "Haerin", role: "Vocal · dance", country: "Corea del Sur" },
      { name: "Hyein", role: "Vocal · dance · maknae", country: "Corea del Sur" },
    ],
  },
  {
    id: "svt",
    name: "SEVENTEEN",
    fandom: "CARAT",
    company: "PLEDIS Entertainment",
    debut: "2015",
    style: "Performance sincronizada, unidades vocal/hip-hop/performance y variedad.",
    bio: "SEVENTEEN destaca por su organizacion en unidades, performance sincronizada y una relacion cercana con CARAT. Su ficha puede ordenar miembros, unidades, albums, conciertos y contenido de variedad.",
    latest: "Puede tener calendario de albums, unit songs, shows y fan events.",
    colors: "linear-gradient(135deg, #f7cadf, #9ad7ff 50%, #07101f)",
    artists: [
      { name: "S.Coups", role: "Lider · hip-hop", country: "Corea del Sur" },
      { name: "Jeonghan", role: "Vocal", country: "Corea del Sur" },
      { name: "Joshua", role: "Vocal", country: "Estados Unidos / Corea" },
      { name: "Jun", role: "Performance", country: "China" },
      { name: "Hoshi", role: "Performance · lider de unidad", country: "Corea del Sur" },
      { name: "Wonwoo", role: "Hip-hop", country: "Corea del Sur" },
      { name: "Woozi", role: "Vocal · productor", country: "Corea del Sur" },
      { name: "The8", role: "Performance", country: "China" },
      { name: "Mingyu", role: "Hip-hop", country: "Corea del Sur" },
      { name: "DK", role: "Vocal", country: "Corea del Sur" },
      { name: "Seungkwan", role: "Vocal", country: "Corea del Sur" },
      { name: "Vernon", role: "Hip-hop", country: "Estados Unidos / Corea" },
      { name: "Dino", role: "Performance · maknae", country: "Corea del Sur" },
    ],
  },
  {
    id: "txt",
    name: "TXT",
    fandom: "MOA",
    company: "BIGHIT MUSIC",
    debut: "2019",
    style: "Pop emocional, narrativa juvenil y conceptos visuales.",
    bio: "TXT mezcla historias de crecimiento, fantasia y pop moderno. Es una buena puerta de entrada para fans que quieren conceptos fuertes y discografias faciles de recorrer.",
    latest: "Noticias, comeback guides y contenido MOA.",
    colors: "linear-gradient(135deg, #65e4ff, #77f4c7 52%, #0f172a)",
    artists: [
      { name: "Soobin", role: "Lider · vocal", country: "Corea del Sur" },
      { name: "Yeonjun", role: "Dance · rap · vocal", country: "Corea del Sur" },
      { name: "Beomgyu", role: "Vocal · dance", country: "Corea del Sur" },
      { name: "Taehyun", role: "Vocal", country: "Corea del Sur" },
      { name: "Huening Kai", role: "Vocal · maknae", country: "Corea / EE.UU." },
    ],
  },
  {
    id: "ive",
    name: "IVE",
    fandom: "DIVE",
    company: "Starship Entertainment",
    debut: "2021",
    style: "Pop elegante, hooks fuertes y visual premium.",
    bio: "IVE se apoya en canciones directas, visuales elegantes y una identidad pop muy marcada. Su perfil puede destacar eras, outfits, lives y fancams populares.",
    latest: "Noticias de comeback, charts y stages destacados.",
    colors: "linear-gradient(135deg, #fff1f9, #ff8ac8 48%, #8b5cf6)",
    artists: [
      { name: "Yujin", role: "Lider · vocal", country: "Corea del Sur" },
      { name: "Gaeul", role: "Rap · dance", country: "Corea del Sur" },
      { name: "Rei", role: "Rap · vocal", country: "Japon" },
      { name: "Wonyoung", role: "Vocal · visual", country: "Corea del Sur" },
      { name: "Liz", role: "Vocal", country: "Corea del Sur" },
      { name: "Leeseo", role: "Vocal · maknae", country: "Corea del Sur" },
    ],
  },
  {
    id: "ateez",
    name: "ATEEZ",
    fandom: "ATINY",
    company: "KQ Entertainment",
    debut: "2018",
    style: "Performance poderosa, narrativa pirata y energia de concierto.",
    bio: "ATEEZ es fuerte en escenario, con conceptos intensos y una comunidad ATINY muy movilizada. Su ficha funciona perfecto para lives, giras y guias de miembros.",
    latest: "Fechas, performances y noticias ATINY.",
    colors: "linear-gradient(135deg, #ffb703, #ff2d55 48%, #111827)",
    artists: [
      { name: "Hongjoong", role: "Lider · rap", country: "Corea del Sur" },
      { name: "Seonghwa", role: "Vocal · performance", country: "Corea del Sur" },
      { name: "Yunho", role: "Dance · vocal", country: "Corea del Sur" },
      { name: "Yeosang", role: "Vocal · performance", country: "Corea del Sur" },
      { name: "San", role: "Vocal · performance", country: "Corea del Sur" },
      { name: "Mingi", role: "Rap · dance", country: "Corea del Sur" },
      { name: "Wooyoung", role: "Dance · vocal", country: "Corea del Sur" },
      { name: "Jongho", role: "Vocal", country: "Corea del Sur" },
    ],
  },
  {
    id: "twice",
    name: "TWICE",
    fandom: "ONCE",
    company: "JYP Entertainment",
    debut: "2015",
    style: "Pop brillante, coreografias memorables y evolucion madura.",
    bio: "TWICE tiene una historia extensa, gran presencia en Japon y una discografia que va de pop dulce a sonidos mas maduros. ONCE puede seguir eras, photocards y giras.",
    latest: "Eventos ONCE, albums y actividades por unidad.",
    colors: "linear-gradient(135deg, #ff8ac8, #ffd166 48%, #65e4ff)",
    artists: [
      { name: "Nayeon", role: "Vocal", country: "Corea del Sur" },
      { name: "Jeongyeon", role: "Vocal", country: "Corea del Sur" },
      { name: "Momo", role: "Dance", country: "Japon" },
      { name: "Sana", role: "Vocal", country: "Japon" },
      { name: "Jihyo", role: "Lider · vocal", country: "Corea del Sur" },
      { name: "Mina", role: "Dance · vocal", country: "Japon" },
      { name: "Dahyun", role: "Rap", country: "Corea del Sur" },
      { name: "Chaeyoung", role: "Rap", country: "Corea del Sur" },
      { name: "Tzuyu", role: "Vocal · maknae", country: "Taiwan" },
    ],
  },
  {
    id: "aespa",
    name: "aespa",
    fandom: "MY",
    company: "SM Entertainment",
    debut: "2020",
    style: "Pop futurista, voces fuertes y conceptos digitales.",
    bio: "aespa mezcla tecnologia, mundos visuales y canciones de alto impacto. Su perfil puede separar lore, eras, videos y actividades individuales.",
    latest: "Noticias MY, comeback visuals y stages.",
    colors: "linear-gradient(135deg, #65e4ff, #d946ef 50%, #0c0616)",
    artists: [
      { name: "Karina", role: "Lider · dance · rap", country: "Corea del Sur" },
      { name: "Giselle", role: "Rap · vocal", country: "Japon / Corea" },
      { name: "Winter", role: "Vocal · dance", country: "Corea del Sur" },
      { name: "Ningning", role: "Vocal", country: "China" },
    ],
  },
];

const events = [
  {
    day: "24",
    month: "MAY",
    title: "K-pop Night Santiago",
    place: "Teatro Coliseo · Chile",
    status: "Entradas disponibles",
  },
  {
    day: "08",
    month: "JUN",
    title: "STAY Fanmeeting Buenos Aires",
    place: "Palermo · Argentina",
    status: "Cupos limitados",
  },
  {
    day: "19",
    month: "JUL",
    title: "Random Dance CDMX",
    place: "Parque Mexico · Mexico",
    status: "Gratis con registro",
  },
  {
    day: "02",
    month: "AGO",
    title: "Mercadito Hallyu Lima",
    place: "Miraflores · Peru",
    status: "Vendedores confirmando",
  },
];

const products = [
  { name: "Album limited edition", group: "IVE", price: "$32.990" },
  { name: "Light stick oficial", group: "ATEEZ", price: "$64.990" },
  { name: "Photocard sleeve set", group: "BTS", price: "$8.990" },
  { name: "Hoodie fandom drop", group: "BLACKPINK", price: "$39.990" },
];

const localStores = [
  {
    name: "Seoul Corner",
    city: "Santiago",
    detail: "Albums sellados, sleeves y retiro en tienda.",
    trust: "4.9",
  },
  {
    name: "Pink Stage Shop",
    city: "Buenos Aires",
    detail: "Photocards, preventas y compras grupales.",
    trust: "4.8",
  },
];

const communities = {
  global: [
    {
      name: "Hallyu LATAM",
      detail: "Comunidad general para noticias, debates y ayuda fandom.",
      members: "128K miembros",
      activity: "Muy activo",
    },
    {
      name: "Comebacks & votaciones",
      detail: "Organizacion para metas de streaming, apps y premios.",
      members: "44K miembros",
      activity: "Campanas semanales",
    },
  ],
  countries: [
    {
      name: "STAY Argentina",
      detail: "Stray Kids, compras grupales, eventos y proyectos en Argentina.",
      members: "18.4K miembros",
      activity: "Buenos Aires, Cordoba, Rosario",
    },
    {
      name: "ARMY Chile",
      detail: "Actividades BTS, cupsleeves, donaciones y eventos nacionales.",
      members: "36.2K miembros",
      activity: "Santiago, Valparaiso, Concepcion",
    },
    {
      name: "MOA Peru",
      detail: "TXT fanbase con calendario de comeback y juntadas.",
      members: "9.7K miembros",
      activity: "Lima y regiones",
    },
  ],
  cities: [
    {
      name: "ONCE Bogota",
      detail: "Grupo chico para fans de TWICE en Bogota.",
      members: "1.9K miembros",
      activity: "Juntada mensual",
    },
    {
      name: "BLINK CDMX",
      detail: "Random dance, merch local y eventos BLACKPINK.",
      members: "7.3K miembros",
      activity: "Zona centro y Coyoacan",
    },
    {
      name: "CARAT Valparaiso",
      detail: "Comunidad de SEVENTEEN para la quinta region.",
      members: "860 miembros",
      activity: "Grupo cercano",
    },
  ],
  groups: [
    {
      name: "Fanbases verificadas",
      detail: "Directorio de comunidades por grupo: BTS, SKZ, ATEEZ, TXT, IVE.",
      members: "92 fanbases",
      activity: "Moderado",
    },
    {
      name: "Nugu club LATAM",
      detail: "Para descubrir grupos nuevos, rookies y artistas menos conocidos.",
      members: "6.8K miembros",
      activity: "Recomendaciones diarias",
    },
  ],
};

const mentors = [
  {
    name: "Mika",
    role: "Mentora STAY · 7 anos en K-pop",
    help: "Te explica comebacks, photocards y como seguir un grupo sin perderte.",
  },
  {
    name: "Vale",
    role: "Multi stan · especialista en guias",
    help: "Arma rutas de escucha segun tus gustos: pop, rap, R&B o performance.",
  },
  {
    name: "Nico",
    role: "Organizador de eventos",
    help: "Ayuda a encontrar comunidades seguras en tu pais o ciudad.",
  },
];

const avatars = [
  {
    id: "berry",
    name: "Berry Pop",
    mood: "Rosa, dulce y fan de los comebacks brillantes.",
    rarity: "Common",
    minLevel: 1,
    reward: "Gratis",
    gradient: "linear-gradient(145deg, #ffd6eb, #fbbcdb 46%, #a855f7)",
  },
  {
    id: "star",
    name: "Star Seoul",
    mood: "Neon, escenico y perfecto para fans de performance.",
    rarity: "Common",
    minLevel: 1,
    reward: "Gratis",
    gradient: "linear-gradient(145deg, #fff7b3, #65e4ff 42%, #a855f7)",
  },
  {
    id: "mochi",
    name: "Mochi Beat",
    mood: "Suave, pastel y coleccionista de photocards.",
    rarity: "Common",
    minLevel: 1,
    reward: "Gratis",
    gradient: "linear-gradient(145deg, #fff1f9, #77f4c7 44%, #d946ef)",
  },
  {
    id: "neon",
    name: "Neon Idol",
    mood: "Brillo de escenario, comeback night y energia fan.",
    rarity: "Rare",
    minLevel: 6,
    reward: "Publicar 5 veces",
    gradient: "linear-gradient(145deg, #65e4ff, #d946ef 46%, #080b1d)",
  },
  {
    id: "cyber",
    name: "Cyber Hallyu",
    mood: "Cyber, futurista y listo para trends verticales.",
    rarity: "Rare",
    minLevel: 9,
    reward: "Participar en trends",
    gradient: "linear-gradient(145deg, #77f4c7, #65e4ff 38%, #1f1147)",
  },
  {
    id: "anime",
    name: "Anime K-style",
    mood: "K-style suave, cute concept y glow pastel.",
    rarity: "Epic",
    minLevel: 14,
    reward: "Recibir 1K estrellas",
    gradient: "linear-gradient(145deg, #fff1f9, #ff8ac8 42%, #65e4ff)",
  },
  {
    id: "idol",
    name: "Idol Aura",
    mood: "Aura premium, marco brillante y presencia de stage.",
    rarity: "Epic",
    minLevel: 18,
    reward: "Completar evento fandom",
    gradient: "linear-gradient(145deg, #fbbcdb, #ffb703 42%, #a855f7)",
  },
  {
    id: "legend",
    name: "Legend Stage",
    mood: "Avatar legendario con efecto estrella y borde vivo.",
    rarity: "Legendary",
    minLevel: 25,
    reward: "Top fandom mensual",
    gradient: "linear-gradient(145deg, #ffd166, #ff2d55 38%, #65e4ff)",
  },
];

const profileBackgrounds = [
  { id: "army", name: "Army Purple 💜", detail: "Galaxia violeta suave", rarity: "Common", minLevel: 1, art: "linear-gradient(135deg, #14091f, #8b5cf6 48%, #d9b4ff)" },
  { id: "blink", name: "Blink Pink Black 🖤💖", detail: "Negro glossy con rosa fashion", rarity: "Common", minLevel: 1, art: "linear-gradient(135deg, #070509, #ff3ea5 54%, #ff8ac8)" },
  { id: "once", name: "Once Candy 🍭", detail: "Dulce, coral y celeste", rarity: "Common", minLevel: 1, art: "linear-gradient(135deg, #ff8ac8, #ffd166 48%, #65e4ff)" },
  { id: "stay", name: "Stay Star ⭐", detail: "Estrellas y escenario neon", rarity: "Common", minLevel: 1, art: "linear-gradient(135deg, #111827, #ffb703 45%, #ff2d55)" },
  { id: "tokki", name: "Tokki Bunny 🐰", detail: "Y2K menta y cielo pop", rarity: "Rare", minLevel: 6, art: "linear-gradient(135deg, #06131a, #77f4c7 48%, #65e4ff)" },
  { id: "stage", name: "Idol Stage 🎤", detail: "Luces de escenario K-pop", rarity: "Rare", minLevel: 9, art: "linear-gradient(135deg, #0b1020, #65e4ff 48%, #d946ef)" },
  { id: "seoul", name: "Seoul Night 🌃", detail: "Noche coreana premium", rarity: "Epic", minLevel: 14, art: "linear-gradient(135deg, #020617, #263d72 48%, #fbbcdb)" },
  { id: "pastel", name: "Pastel K-pop ✨", detail: "Pastel, glow y photocards", rarity: "Epic", minLevel: 18, art: "linear-gradient(135deg, #fff1f9, #fbbcdb 42%, #77f4c7)" },
  { id: "event", name: "Comeback Event", detail: "Fondo especial por eventos", rarity: "Legendary", minLevel: 22, art: "linear-gradient(135deg, #030712, #ff2d55 38%, #ffd166 72%, #65e4ff)" },
  { id: "lightstick", name: "Lightstick Glow", detail: "Luces y marcos brillantes", rarity: "Legendary", minLevel: 25, art: "linear-gradient(135deg, #050816, #65e4ff 35%, #fbbcdb 68%, #ffffff)" },
];

const profileRewards = [
  ["Comentar", "+5 estrellas", "Ayuda a otros fans"],
  ["Publicar", "+25 estrellas", "Sube posts, outfits o photocards"],
  ["Recibir likes", "+10 estrellas", "Cada fan que reacciona suma"],
  ["Participar en trends", "+40 estrellas", "Challenges y dance covers"],
  ["Completar eventos", "+120 estrellas", "Eventos fandom y misiones"],
];

const profileFolders = [
  { title: "Fotos", count: "148", detail: "Conciertos, outfits y recuerdos fandom." },
  { title: "Albumes", count: "23", detail: "Versiones fisicas, inclusiones y wishlist." },
  { title: "Fotocards", count: "286", detail: "Cartas repetidas, favoritas, trades y wishlist." },
];

const chatChannels = [
  {
    name: "Chat general · ARMY Chile",
    detail: "Para miembros aceptados de la comunidad elegida.",
    last: "Vale: Hay cupsleeve este sabado en Providencia.",
    status: "Abierto",
  },
  {
    name: "Santiago centro",
    detail: "Zona local para juntadas, datos de tiendas y seguridad.",
    last: "Mika: Recomiendo ir en grupo al mercadito.",
    status: "Tu zona",
  },
  {
    name: "Compras verificadas",
    detail: "Solo vendedores revisados por moderadores.",
    last: "Admin: Nuevo local agregado con reseñas.",
    status: "Moderado",
  },
];

const privateRequests = [
  {
    name: "Cami.STAY",
    note: "Quiere preguntarte por un trade de photocards.",
    shared: "2 grupos en comun",
  },
  {
    name: "JaviHallyu",
    note: "Te envio solicitud desde ARMY Chile.",
    shared: "Misma zona",
  },
];

const conversations = [
  {
    name: "Mika mentor",
    last: "Te mande una playlist para entrar a SKZ.",
    time: "12:48",
    status: "Aceptado",
  },
  {
    name: "Vale Multi",
    last: "Vemos juntas que grupo va con tu estilo?",
    time: "Ayer",
    status: "Mentora",
  },
];

const profilePhotos = [
  "Live stage",
  "Outfit",
  "Photocard",
  "Album shelf",
  "Random dance",
  "Cupsleeve",
  "Light stick",
  "Trade day",
  "Fan art",
];

const profileHighlights = ["Conciertos", "Fancams", "Bias", "Photocards", "Dance covers", "Eventos", "Outfits", "Comeback"];

const profileTabs = [
  ["posts", "Publicaciones"],
  ["trends", "Trends"],
  ["outfits", "Outfit"],
  ["photocards", "Photocards"],
  ["saved", "Guardados"],
  ["favorites", "Favoritos"],
];

const fandomBadges = ["Army 💜", "Blink 🖤💖", "Once 🍭", "Stay ⭐", "Tokki 🐰"];

const profileAchievements = [
  ["Lightstick virtual", "BTS · Purple glow"],
  ["Ranking fandom", "Top 4% LATAM"],
  ["Photocards", "286 en coleccion"],
  ["Comeback tracker", "7 activos"],
  ["Achievements", "Mentora K-pop 101"],
];

function setView(nextView) {
  if (nextView !== "settings") state.settingsPanel = null;
  if (nextView !== "profile") {
    state.viewedProfile = null;
    state.profileEditorOpen = false;
  }
  if (nextView !== "home") {
    state.activeStory = null;
    state.activePost = null;
    state.storyComposerOpen = false;
    clearStoryAutoplay();
  }
  if (!state.isAuthenticated && nextView !== "auth") {
    state.view = "auth";
    render();
    return;
  }
  state.view = nextView;
  document.querySelectorAll(".nav-item").forEach((button) => {
    button.classList.toggle("active", button.dataset.view === nextView);
  });
  const appScreen = document.querySelector(".app-screen");
  appScreen.classList.toggle("profile-mode", nextView === "profile");
  appScreen.classList.toggle("auth-mode", nextView === "auth");
  appScreen.classList.toggle("home-mode", nextView === "home");
  appScreen.classList.toggle("light-mode", state.user?.mode === "light");
  appScreen.style.setProperty("--user-accent", state.user?.accent || "#fbbcdb");
  appScreen.dataset.ambience = state.ambience;
  document.getElementById("screen-title").textContent = titleByView[nextView];
  render();
  if (nextView === "news") loadKpopNews(false);
}

function render() {
  const view = document.getElementById("view");
  const appScreen = document.querySelector(".app-screen");
  appScreen.dataset.ambience = state.ambience;
  appScreen.classList.toggle("auth-mode", state.view === "auth");
  appScreen.classList.toggle("home-mode", state.view === "home");
  appScreen.classList.toggle("light-mode", state.user?.mode === "light");
  appScreen.style.setProperty("--user-accent", state.user?.accent || "#fbbcdb");
  document.querySelector(".bottom-nav").classList.toggle("hidden", !state.isAuthenticated);
  document.querySelector(".topbar").classList.toggle("hidden", !state.isAuthenticated || state.view === "profile");
  if (!state.isAuthenticated) {
    view.innerHTML = renderAuth();
    bindDynamicActions();
    return;
  }
  if (state.user && state.user.onboarded === false) {
    document.querySelector(".bottom-nav").classList.add("hidden");
    document.querySelector(".topbar").classList.add("hidden");
    view.innerHTML = renderOnboarding();
    bindDynamicActions();
    return;
  }
  const templates = {
    home: renderHome,
    search: renderSearch,
    trends: renderTrends,
    publish: renderPublish,
    notifications: renderNotifications,
    settings: renderSettings,
    events: renderEvents,
    market: renderMarket,
    news: renderNews,
    groups: renderGroups,
    community: renderCommunity,
    rookie: renderRookie,
    messages: renderMessages,
    profile: renderProfile,
  };
  view.innerHTML = templates[state.view]();
  bindDynamicActions();
  scheduleStoryAutoplay();
}

function clearStoryAutoplay() {
  if (storyAutoTimer) {
    clearTimeout(storyAutoTimer);
    storyAutoTimer = null;
  }
}

function scheduleStoryAutoplay() {
  clearStoryAutoplay();
  if (state.view !== "home" || state.activeStory === null) return;
  storyAutoTimer = setTimeout(() => {
    const total = followingStories.length + (state.ownStory ? 1 : 0);
    const current = state.ownStory ? state.activeStory + 1 : state.activeStory;
    const next = (current + 1) % total;
    state.storyDirection = 1;
    state.activeStory = state.ownStory ? next - 1 : next;
    render();
  }, 5600);
}

function bindDynamicActions() {
  document.querySelectorAll("[data-auth-mode]").forEach((button) => {
    button.addEventListener("click", () => {
      state.authMode = button.dataset.authMode;
      render();
    });
  });

  document.querySelectorAll("[data-auth-submit]").forEach((button) => {
    button.addEventListener("click", () => submitAuth(button.dataset.authSubmit));
  });

  document.querySelectorAll("[data-auth-avatar]").forEach((button) => {
    button.addEventListener("click", () => {
      document.querySelectorAll("[data-auth-avatar]").forEach((option) => option.classList.remove("active"));
      button.classList.add("active");
      state.selectedAvatar = button.dataset.authAvatar;
    });
  });

  document.querySelectorAll("[data-save-settings]").forEach((button) => {
    button.addEventListener("click", saveSettings);
  });

  document.querySelectorAll("[data-save-onboarding]").forEach((button) => {
    button.addEventListener("click", saveOnboarding);
  });

  document.querySelectorAll("[data-settings-panel]").forEach((button) => {
    button.addEventListener("click", () => {
      state.settingsPanel = button.dataset.settingsPanel;
      render();
    });
  });

  document.querySelectorAll("[data-settings-main]").forEach((button) => {
    button.addEventListener("click", () => {
      state.settingsPanel = null;
      render();
    });
  });

  document.querySelectorAll("[data-create-post]").forEach((button) => {
    button.addEventListener("click", createPost);
  });

  document.querySelectorAll("[data-news-filter]").forEach((button) => {
    button.addEventListener("click", () => {
      const [key, value] = button.dataset.newsFilter.split(":");
      state.newsFilter = { ...state.newsFilter, [key]: value };
      render();
    });
  });

  document.querySelectorAll("[data-news-refresh]").forEach((button) => {
    button.addEventListener("click", () => loadKpopNews(true));
  });

  document.querySelectorAll("[data-news-status]").forEach((button) => {
    button.addEventListener("click", () => {
      const [id, status] = button.dataset.newsStatus.split(":");
      updateNewsStatus(id, status);
    });
  });

  document.querySelectorAll("[data-home-filter]").forEach((button) => {
    button.addEventListener("click", () => {
      state.homeFilter = button.dataset.homeFilter;
      state.activePost = null;
      render();
    });
  });

  document.querySelectorAll("[data-open-post]").forEach((button) => {
    button.addEventListener("click", () => {
      state.activePost = button.dataset.openPost;
      render();
    });
  });

  document.querySelectorAll("[data-close-post]").forEach((button) => {
    button.addEventListener("click", () => {
      state.activePost = null;
      render();
    });
  });

  document.querySelectorAll("[data-save-post]").forEach((button) => {
    button.addEventListener("click", () => {
      const id = button.dataset.savePost;
      state.savedPosts[id] = !state.savedPosts[id];
      button.classList.toggle("active", state.savedPosts[id]);
    });
  });

  document.querySelectorAll("[data-share-post]").forEach((button) => {
    button.addEventListener("click", () => {
      const id = button.dataset.sharePost;
      state.sharedPosts[id] = true;
      button.classList.add("active");
      alert("Publicacion lista para compartir en modo demo.");
    });
  });

  document.querySelectorAll("[data-open-feed-profile]").forEach((button) => {
    button.addEventListener("click", () => openFeedProfile(button.dataset.openFeedProfile));
  });

  document.querySelectorAll("[data-story-index]").forEach((button) => {
    button.addEventListener("click", () => {
      state.activeStory = Number(button.dataset.storyIndex);
      state.storyDirection = 1;
      state.storyComposerOpen = false;
      state.ownStoryStatsOpen = false;
      render();
    });
  });

  document.querySelectorAll("[data-own-story]").forEach((button) => {
    button.addEventListener("click", () => {
      if (state.ownStory) {
        state.activeStory = -1;
        state.storyDirection = 1;
      } else {
        createOwnStory();
      }
      state.storyComposerOpen = false;
      state.ownStoryStatsOpen = false;
      render();
    });
  });

  document.querySelectorAll("[data-create-own-story]").forEach((button) => {
    button.addEventListener("click", () => {
      createOwnStory(button.dataset.createOwnStory);
      render();
    });
  });

  document.querySelectorAll("[data-story-close]").forEach((button) => {
    button.addEventListener("click", () => {
      state.activeStory = null;
      state.storyComposerOpen = false;
      state.ownStoryStatsOpen = false;
      clearStoryAutoplay();
      render();
    });
  });

  document.querySelectorAll("[data-story-nav]").forEach((button) => {
    button.addEventListener("click", () => {
      const direction = Number(button.dataset.storyNav);
      const total = followingStories.length + (state.ownStory ? 1 : 0);
      const current = state.ownStory ? state.activeStory + 1 : state.activeStory;
      const next = (current + direction + total) % total;
      state.storyDirection = direction;
      state.activeStory = state.ownStory ? next - 1 : next;
      state.storyComposerOpen = false;
      state.ownStoryStatsOpen = false;
      render();
    });
  });

  document.querySelectorAll("[data-own-story-stats]").forEach((button) => {
    button.addEventListener("click", () => {
      state.ownStoryStatsOpen = !state.ownStoryStatsOpen;
      render();
    });
  });

  document.querySelectorAll("[data-story-star]").forEach((button) => {
    button.addEventListener("click", () => {
      const index = Number(button.dataset.storyStar);
      state.likedStories[index] = !state.likedStories[index];
      button.classList.toggle("active", state.likedStories[index]);
      button.classList.add("popped");
      setTimeout(() => button.classList.remove("popped"), 260);
    });
  });

  document.querySelectorAll("[data-story-message-open]").forEach((button) => {
    button.addEventListener("click", () => {
      state.storyComposerOpen = true;
      render();
    });
  });

  document.querySelectorAll("[data-story-message-close]").forEach((button) => {
    button.addEventListener("click", () => {
      state.storyComposerOpen = false;
      render();
    });
  });

  document.querySelectorAll("[data-story-phrase]").forEach((button) => {
    button.addEventListener("click", () => sendStoryMessage(button.dataset.storyPhrase));
  });

  document.querySelectorAll("[data-story-send]").forEach((button) => {
    button.addEventListener("click", () => {
      const input = document.getElementById("story-message-input");
      sendStoryMessage(input?.value.trim() || "Saranghae 💜");
    });
  });

  document.querySelectorAll("[data-like-post]").forEach((button) => {
    button.addEventListener("click", () => toggleLike(button.dataset.likePost));
  });

  document.querySelectorAll("[data-comment-post]").forEach((button) => {
    button.addEventListener("click", () => {
      const body = prompt("Escribe un comentario");
      if (body) addComment(button.dataset.commentPost, body);
    });
  });

  document.querySelectorAll("[data-follow-user]").forEach((button) => {
    button.addEventListener("click", () => followUser(button.dataset.followUser));
  });

  document.querySelectorAll("[data-profile-follow]").forEach((button) => {
    button.addEventListener("click", () => {
      const id = button.dataset.profileFollow;
      state.followedProfiles[id] = !state.followedProfiles[id];
      render();
    });
  });

  document.querySelectorAll("[data-profile-edit-open]").forEach((button) => {
    button.addEventListener("click", () => {
      state.selectedAvatar = state.user.avatar;
      state.selectedProfileBg = state.user.profileBg;
      state.profileEditorOpen = true;
      render();
    });
  });

  document.querySelectorAll("[data-profile-edit-close]").forEach((button) => {
    button.addEventListener("click", () => {
      state.profileEditorOpen = false;
      render();
    });
  });

  document.querySelectorAll("[data-save-profile-edit]").forEach((button) => {
    button.addEventListener("click", saveProfileEdit);
  });

  document.querySelectorAll("[data-open-profile]").forEach((button) => {
    button.addEventListener("click", () => {
      const profile = state.liveProfiles.find((item) => item.id === button.dataset.openProfile);
      if (!profile) return;
      state.profileEditorOpen = false;
      state.viewedProfile = {
        id: profile.id,
        name: profile.name || "Hallyu fan",
        username: profile.username || "hallyufan",
        avatar: profile.avatar || "star",
        avatarUrl: profile.avatar_url,
        bio: profile.bio || "Fan K-pop en HallyuHub.",
        country: profile.country || "Latam",
        fandom: profile.fandom || "Stay ⭐",
        bias: profile.bias || "Bias secreto",
        favoriteGroup: profile.favorite_group || "Stray Kids",
        phrase: profile.phrase || "Compartiendo mi mundo fandom.",
        followers: "2.1K",
        following: "180",
        posts: "24",
        starsReceived: "8.2K",
        trendsCreated: "6",
        profileBg: "stay",
      };
      state.view = "profile";
      document.querySelectorAll(".nav-item").forEach((nav) => nav.classList.toggle("active", nav.dataset.view === "profile"));
      render();
    });
  });

  document.querySelectorAll("[data-send-message]").forEach((button) => {
    button.addEventListener("click", () => {
      const body = prompt("Escribe un mensaje privado");
      if (body) startPrivateMessage(button.dataset.sendMessage, body);
    });
  });

  document.querySelectorAll("[data-logout]").forEach((button) => {
    button.addEventListener("click", logout);
  });

  document.querySelectorAll("[data-community-tab]").forEach((button) => {
    button.addEventListener("click", () => {
      state.communityTab = button.dataset.communityTab;
      render();
    });
  });

  document.querySelectorAll("[data-activity-tab]").forEach((button) => {
    button.addEventListener("click", () => {
      state.activityTab = button.dataset.activityTab;
      render();
    });
  });

  document.querySelectorAll("[data-profile-tab]").forEach((button) => {
    button.addEventListener("click", () => {
      state.profileTab = button.dataset.profileTab;
      render();
    });
  });

  document.querySelectorAll("[data-toggle-premium]").forEach((button) => {
    button.addEventListener("click", () => {
      state.user = {
        ...state.user,
        premium: !state.user.premium,
        themePremium: !state.user.premium,
      };
      storage.set("hallyuHubUser", state.user);
      render();
    });
  });

  document.querySelectorAll("[data-avatar]").forEach((button) => {
    button.addEventListener("click", () => {
      document.querySelectorAll("[data-avatar]").forEach((option) => option.classList.remove("active"));
      button.classList.add("active");
      state.selectedAvatar = button.dataset.avatar;
    });
  });

  document.querySelectorAll("[data-profile-bg]").forEach((button) => {
    button.addEventListener("click", () => {
      state.selectedProfileBg = button.dataset.profileBg;
      render();
    });
  });

  document.querySelectorAll("[data-ambience]").forEach((button) => {
    button.addEventListener("click", () => {
      document.querySelectorAll("[data-ambience]").forEach((option) => option.classList.remove("active"));
      button.classList.add("active");
      state.ambience = button.dataset.ambience;
      document.querySelector(".app-screen").dataset.ambience = state.ambience;
    });
  });

  document.querySelectorAll("[data-group]").forEach((button) => {
    button.addEventListener("click", () => {
      state.selectedGroup = button.dataset.group;
      render();
    });
  });

  document.querySelectorAll("[data-go-view]").forEach((button) => {
    button.addEventListener("click", () => setView(button.dataset.goView));
  });
}

async function initSupabase() {
  const config = window.HALLYUHUB_SUPABASE_CONFIG || {};
  if (!config.url || !config.anonKey || config.url.includes("YOUR_")) {
    state.backendMode = "local";
    return;
  }

  try {
    const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2");
    state.supabase = createClient(config.url, config.anonKey, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true,
      },
    });
    state.backendMode = "supabase";
    state.supabase.auth.onAuthStateChange(async (_event, session) => {
      state.session = session;
      if (session?.user) {
        state.isAuthenticated = true;
        await loadProfile(session.user);
        await loadPosts();
        await loadProfiles();
        render();
      }
    });
  } catch (error) {
    console.warn("Supabase no disponible, usando modo local.", error);
    state.backendMode = "local";
  }
}

async function initApp() {
  await initSupabase();
  if (state.backendMode === "supabase") {
    const { data } = await state.supabase.auth.getSession();
    state.session = data.session;
    if (data.session?.user) {
      state.isAuthenticated = true;
      await loadProfile(data.session.user);
      await loadPosts();
      await loadProfiles();
      state.view = "home";
      render();
      return;
    }
  }
  const savedUser = storage.get("hallyuHubUser", null);
  const savedSession = storage.get("hallyuHubSession", false);
  state.user = savedUser || defaultUser;
  const savedLocalPosts = storage.get("hallyuHubUserPosts", []);
  if (Array.isArray(savedLocalPosts) && savedLocalPosts.length) {
    userPosts.unshift(...savedLocalPosts.filter((post) => !userPosts.some((item) => item.id === post.id)));
  }
  const savedNews = storage.get("hallyuHubNewsCache", null);
  state.newsItems = savedNews?.items?.length ? mergeNewsStatuses(savedNews.items, news) : news;
  state.newsLastUpdated = savedNews?.updatedAt || null;
  state.ownStory = storage.get("hallyuHubOwnStory", null);
  state.storyInbox = storage.get("hallyuHubStoryInbox", []);
  state.isAuthenticated = Boolean(savedSession);
  state.selectedAvatar = state.user.avatar || "berry";
  state.selectedProfileBg = state.user.profileBg || "army";
  state.ambience = state.user.ambience || "hallyu";
  state.view = state.isAuthenticated ? "home" : "auth";
  render();
}

async function submitAuth(mode) {
  const email = document.getElementById("auth-email")?.value.trim() || defaultUser.email;
  const password = document.getElementById("auth-password")?.value || defaultUser.password;
  const name = document.getElementById("auth-name")?.value.trim() || defaultUser.name;
  const username = document.getElementById("auth-username")?.value.trim() || defaultUser.username;
  const avatar = document.querySelector("[data-auth-avatar].active")?.dataset.authAvatar || state.selectedAvatar;

  if (state.backendMode === "supabase") {
    const authCall =
      mode === "register"
        ? state.supabase.auth.signUp({
            email,
            password,
            options: { data: { name, username, avatar } },
          })
        : state.supabase.auth.signInWithPassword({ email, password });
    const { data, error } = await authCall;
    if (error) {
      alert(error.message);
      return;
    }
    state.session = data.session;
    state.isAuthenticated = true;
  if (data.user) {
      state.user = {
        ...defaultUser,
        email,
        name,
        username,
        avatar,
        onboarded: mode !== "register",
      };
      await upsertProfile(data.user, state.user);
      await loadProfile(data.user);
      await loadPosts();
      await loadProfiles();
    }
    setView("home");
    return;
  }

  state.user = {
    ...defaultUser,
    ...state.user,
    email,
    password,
    name: mode === "register" ? name : state.user?.name || name,
    username: mode === "register" ? username : state.user?.username || username,
    avatar,
    onboarded: mode === "register" ? false : state.user?.onboarded ?? true,
  };
  state.selectedAvatar = avatar;
  state.ambience = state.user.ambience;
  state.isAuthenticated = true;
  storage.set("hallyuHubUser", state.user);
  storage.set("hallyuHubSession", true);
  setView("home");
}

async function saveSettings() {
  const selectedAvatar = document.querySelector("[data-avatar].active")?.dataset.avatar || state.selectedAvatar;
  const selectedAmbience = document.querySelector("[data-ambience].active")?.dataset.ambience || state.ambience;
  const selectedProfileBg = document.querySelector("[data-profile-bg].active")?.dataset.profileBg || state.selectedProfileBg || state.user.profileBg;
  const avatarFile = document.getElementById("settings-avatar-file")?.files?.[0];
  const uploadedAvatarUrl =
    state.backendMode === "supabase" && avatarFile ? await uploadMedia(avatarFile, supabaseBuckets.avatars) : state.user.avatarUrl;
  state.user = {
    ...state.user,
    name: document.getElementById("settings-name")?.value.trim() || state.user.name,
    username: document.getElementById("settings-username")?.value.trim() || state.user.username,
    bio: document.getElementById("settings-bio")?.value.trim() || state.user.bio,
    country: document.getElementById("settings-country")?.value.trim() || state.user.country,
    fandom: document.getElementById("settings-fandom")?.value.trim() || state.user.fandom,
    bias: document.getElementById("settings-bias")?.value.trim() || state.user.bias,
    favoriteGroup: document.getElementById("settings-group")?.value.trim() || state.user.favoriteGroup,
    phrase: document.getElementById("settings-phrase")?.value.trim() || state.user.phrase,
    phone: document.getElementById("settings-phone")?.value.trim() || state.user.phone,
    language: document.getElementById("settings-language")?.value.trim() || state.user.language,
    avatar: selectedAvatar,
    profileBg: selectedProfileBg,
    avatarUrl: uploadedAvatarUrl,
    ambience: selectedAmbience,
    accent: document.getElementById("settings-accent")?.value || state.user.accent,
    mode: document.getElementById("settings-mode")?.checked ? "light" : "dark",
    notifications: Boolean(document.getElementById("settings-notifications")?.checked),
    privateProfile: Boolean(document.getElementById("settings-privacy")?.checked),
  };
  state.selectedAvatar = state.user.avatar;
  state.selectedProfileBg = state.user.profileBg;
  state.ambience = state.user.ambience;
  if (state.backendMode === "supabase" && state.session?.user) {
    await upsertProfile(state.session.user, state.user);
  }
  storage.set("hallyuHubUser", state.user);
  render();
}

async function saveProfileEdit() {
  const selectedAvatar = document.querySelector("[data-avatar].active")?.dataset.avatar || state.selectedAvatar || state.user.avatar;
  const selectedProfileBg = document.querySelector("[data-profile-bg].active")?.dataset.profileBg || state.selectedProfileBg || state.user.profileBg;
  const avatarFile = document.getElementById("profile-edit-avatar-file")?.files?.[0];
  const uploadedAvatarUrl =
    state.backendMode === "supabase" && avatarFile ? await uploadMedia(avatarFile, supabaseBuckets.avatars) : state.user.avatarUrl;

  state.user = {
    ...state.user,
    name: document.getElementById("profile-edit-name")?.value.trim() || state.user.name,
    username: document.getElementById("profile-edit-username")?.value.trim() || state.user.username,
    bio: document.getElementById("profile-edit-bio")?.value.trim() || state.user.bio,
    favoriteGroup: document.getElementById("profile-edit-groups")?.value.trim() || state.user.favoriteGroup,
    socials: document.getElementById("profile-edit-socials")?.value.trim() || state.user.socials || "",
    avatar: selectedAvatar,
    avatarUrl: uploadedAvatarUrl,
    profileBg: selectedProfileBg,
  };

  state.selectedAvatar = state.user.avatar;
  state.selectedProfileBg = state.user.profileBg;
  state.profileEditorOpen = false;
  if (state.backendMode === "supabase" && state.session?.user) {
    await upsertProfile(state.session.user, state.user);
  }
  storage.set("hallyuHubUser", state.user);
  render();
}

function saveOnboarding() {
  const accepted = document.getElementById("onboarding-terms")?.checked;
  if (!accepted) {
    alert("Para continuar debes aceptar terminos y politica de privacidad.");
    return;
  }
  state.user = {
    ...state.user,
    name: document.getElementById("onboarding-name")?.value.trim() || state.user.name,
    username: document.getElementById("onboarding-username")?.value.trim() || state.user.username,
    country: document.getElementById("onboarding-country")?.value.trim() || state.user.country,
    fandom: document.getElementById("onboarding-fandom")?.value.trim() || state.user.fandom,
    bias: document.getElementById("onboarding-bias")?.value.trim() || state.user.bias,
    favoriteGroup: document.getElementById("onboarding-group")?.value.trim() || state.user.favoriteGroup,
    bio: document.getElementById("onboarding-bio")?.value.trim() || state.user.bio,
    onboarded: true,
  };
  storage.set("hallyuHubUser", state.user);
  setView("profile");
}

async function logout() {
  if (state.backendMode === "supabase") {
    await state.supabase.auth.signOut();
  }
  storage.remove("hallyuHubSession");
  state.isAuthenticated = false;
  state.view = "auth";
  render();
}

async function loadProfile(authUser) {
  const { data, error } = await state.supabase.from("profiles").select("*").eq("id", authUser.id).maybeSingle();
  if (error) console.warn(error);
  if (!data) {
    const newProfile = {
      ...defaultUser,
      email: authUser.email,
      name: authUser.user_metadata?.name || defaultUser.name,
      username: authUser.user_metadata?.username || `fan_${authUser.id.slice(0, 6)}`,
      avatar: authUser.user_metadata?.avatar || defaultUser.avatar,
    };
    await upsertProfile(authUser, newProfile);
    state.user = newProfile;
  } else {
    state.user = {
      ...defaultUser,
      email: data.email || authUser.email,
      name: data.name,
      username: data.username,
      bio: data.bio || "",
      avatar: data.avatar || "berry",
      avatarUrl: data.avatar_url,
      ambience: data.ambience || "hallyu",
      accent: data.accent || "#fbbcdb",
      mode: data.mode || "dark",
      notifications: data.notifications,
      privateProfile: data.private_profile,
    };
  }
  state.selectedAvatar = state.user.avatar;
  state.ambience = state.user.ambience;
}

async function upsertProfile(authUser, user) {
  const payload = {
    id: authUser.id,
    email: authUser.email || user.email,
    name: user.name,
    username: user.username,
    bio: user.bio,
    avatar: user.avatar,
    avatar_url: user.avatarUrl || null,
    ambience: user.ambience,
    accent: user.accent,
    mode: user.mode,
    notifications: user.notifications,
    private_profile: user.privateProfile,
    updated_at: new Date().toISOString(),
  };
  const { error } = await state.supabase.from("profiles").upsert(payload);
  if (error) alert(error.message);
}

async function uploadMedia(file, bucket) {
  if (!file || state.backendMode !== "supabase" || !state.session?.user) return null;
  const ext = file.name.split(".").pop();
  const path = `${state.session.user.id}/${crypto.randomUUID()}.${ext}`;
  const { error } = await state.supabase.storage.from(bucket).upload(path, file, { upsert: false });
  if (error) {
    alert(error.message);
    return null;
  }
  const { data } = state.supabase.storage.from(bucket).getPublicUrl(path);
  return data.publicUrl;
}

async function loadPosts() {
  if (state.backendMode !== "supabase") return;
  const { data, error } = await state.supabase
    .from("posts")
    .select("id, caption, media_url, media_type, category, created_at, profiles(name, username, avatar)")
    .order("created_at", { ascending: false })
    .limit(20);
  if (error) {
    console.warn(error);
    return;
  }
  state.livePosts = data || [];
}

async function loadProfiles() {
  if (state.backendMode !== "supabase") return;
  const { data, error } = await state.supabase
    .from("profiles")
    .select("id, name, username, avatar, avatar_url")
    .neq("id", state.session?.user?.id || "00000000-0000-0000-0000-000000000000")
    .limit(20);
  if (error) {
    console.warn(error);
    return;
  }
  state.liveProfiles = data || [];
}

async function createPost() {
  const caption = document.getElementById("post-caption")?.value.trim() || "";
  const file = document.getElementById("post-media")?.files?.[0];
  const category = document.getElementById("post-category")?.value || "posts";
  const optionalFields = {
    location: document.getElementById("post-location")?.value.trim() || "",
    date: document.getElementById("post-date")?.value || "",
    hour: document.getElementById("post-hour")?.value || "",
    taggedPeople: document.getElementById("post-tagged-people")?.value.trim() || "",
    taggedPlace: document.getElementById("post-tagged-place")?.value.trim() || "",
  };
  if (state.backendMode !== "supabase") {
    userPosts.unshift({
      id: `local-${Date.now()}`,
      user: state.user.name,
      group: getPostCategoryLabel(category),
      category,
      time: optionalFields.date || optionalFields.hour ? [optionalFields.date, optionalFields.hour].filter(Boolean).join(" · ") : "Ahora",
      badge: state.user.fandom || "Army 💜",
      online: true,
      caption: caption || "Publicacion nueva en modo demo.",
      likes: "0",
      comments: "0",
      hashtags: ["#HallyuHub", "#KpopLatam"],
      ...optionalFields,
    });
    storage.set("hallyuHubUserPosts", userPosts.filter((post) => String(post.id || "").startsWith("local-")));
    setView("home");
    return;
  }
  const mediaUrl = await uploadMedia(file, supabaseBuckets.posts);
  const mediaType = file?.type?.startsWith("video") ? "video" : file ? "image" : null;
  const { error } = await state.supabase.from("posts").insert({
    user_id: state.session.user.id,
    caption,
    media_url: mediaUrl,
    media_type: mediaType,
    category: getPostCategoryLabel(category),
  });
  if (error) {
    alert(error.message);
    return;
  }
  await loadPosts();
  setView("home");
}

function getPostCategoryLabel(category) {
  const labels = {
    posts: "Publicacion",
    trends: "Trend",
    outfits: "Outfit",
    photocards: "Photocard",
    saved: "Guardado",
    favorites: "Favorito",
  };
  return labels[category] || "Publicacion";
}

async function toggleLike(postId) {
  if (state.backendMode !== "supabase" || !state.session?.user) {
    const baseId = String(postId).replace(/-\d+$/, "");
    const post = userPosts.find((item) => item.id === baseId);
    if (post) post.likes = bumpEngagement(post.likes);
    render();
    return;
  }
  await state.supabase.from("likes").upsert({ post_id: postId, user_id: state.session.user.id });
}

async function addComment(postId, body) {
  if (state.backendMode !== "supabase" || !state.session?.user) {
    const baseId = String(postId).replace(/-\d+$/, "");
    const post = userPosts.find((item) => item.id === baseId);
    if (post) post.comments = bumpEngagement(post.comments);
    render();
    return;
  }
  await state.supabase.from("comments").insert({ post_id: postId, user_id: state.session.user.id, body });
}

function bumpEngagement(value) {
  const text = String(value || "0");
  const number = Number.parseFloat(text.replace(/[^0-9.]/g, "")) || 0;
  if (text.toLowerCase().includes("k")) return `${(number + 0.1).toFixed(1)}K`;
  return String(Math.round(number + 1));
}

function openFeedProfile(name) {
  const post = userPosts.find((item) => item.user === name);
  if (!post) return;
  if (post.user === state.user?.name) {
    state.viewedProfile = null;
  } else {
    state.viewedProfile = {
      id: post.user.toLowerCase().replace(/\s+/g, "-"),
      name: post.user,
      username: post.user.toLowerCase().replace(/[^a-z0-9]+/g, ""),
      avatar: post.avatar || "star",
      bio: post.caption,
      country: post.location || "Latam",
      fandom: post.badge || "Army 💜",
      bias: "Bias secreto",
      favoriteGroup: post.group || "K-pop",
      phrase: "Compartiendo momentos fandom en HallyuHub.",
      followers: "2.8K",
      following: "210",
      posts: "32",
      starsReceived: post.likes || "1.2K",
      profileBg: post.type === "trending" ? "stage" : "pastel",
    };
  }
  setView("profile");
}

async function followUser(userId) {
  if (state.backendMode !== "supabase" || !state.session?.user) return;
  await state.supabase.from("follows").upsert({ follower_id: state.session.user.id, following_id: userId });
}

async function sendPrivateMessage(threadId, body) {
  if (state.backendMode !== "supabase" || !state.session?.user) return;
  await state.supabase.from("private_messages").insert({ thread_id: threadId, sender_id: state.session.user.id, body });
}

async function startPrivateMessage(recipientId, body) {
  if (state.backendMode !== "supabase" || !state.session?.user || !recipientId) return;
  const { data, error } = await state.supabase
    .from("private_threads")
    .insert({ created_by: state.session.user.id, recipient_id: recipientId, accepted: false })
    .select("id")
    .single();
  if (error) {
    alert(error.message);
    return;
  }
  alert("Solicitud enviada. El chat se activa cuando la otra persona acepta.");
  if (body) {
    console.info("Mensaje pendiente hasta aceptacion:", data.id, body);
  }
}

function renderAvatarElement(className, avatarId, imageUrl) {
  if (imageUrl) {
    return `<span class="avatar-photo ${className}" style="background-image:url('${imageUrl}')"></span>`;
  }
  return `<span class="plush-avatar ${className}" style="--avatar:${getAvatarGradient(avatarId)}"><span></span></span>`;
}

function renderAuth() {
  const isRegister = state.authMode === "register";
  const activeAvatar = avatars.find((avatar) => avatar.id === state.selectedAvatar) || avatars[0];
  return `
    <section class="auth-screen">
      <div class="auth-brand">
        <div class="plush-avatar hero" style="--avatar:${activeAvatar.gradient}"><span></span></div>
        <p class="eyebrow">HallyuHub</p>
        <h1>${isRegister ? "Crear cuenta fan" : "Entrar a tu mundo K-pop"}</h1>
        <p class="muted">Prototipo con datos guardados en este dispositivo. Preparado para migrar a ${futureBackend.next}.</p>
      </div>
      <div class="auth-tabs">
        <button class="${!isRegister ? "active" : ""}" data-auth-mode="login">Entrar</button>
        <button class="${isRegister ? "active" : ""}" data-auth-mode="register">Crear cuenta</button>
      </div>
      <div class="form-stack">
        <label>Email<input id="auth-email" type="email" value="${state.user?.email || ""}" placeholder="fan@hallyuhub.app" /></label>
        <label>Contraseña<input id="auth-password" type="password" value="${state.user?.password || ""}" placeholder="********" /></label>
        ${
          isRegister
            ? `<label>Nombre<input id="auth-name" value="${state.user?.name || ""}" placeholder="Luna Hallyu" /></label>
               <label>Usuario<input id="auth-username" value="${state.user?.username || ""}" placeholder="lunahallyu" /></label>`
            : ""
        }
      </div>
      <div class="section-heading small"><h2>Avatar</h2><span>${activeAvatar.name}</span></div>
      <div class="avatar-picker">
        ${avatars
          .map(
            (avatar) => `
            <button class="avatar-choice ${state.selectedAvatar === avatar.id ? "active" : ""}" data-auth-avatar="${avatar.id}">
              <div class="plush-avatar pick" style="--avatar:${avatar.gradient}"><span></span></div>
              <strong>${avatar.name}</strong>
            </button>`,
          )
          .join("")}
      </div>
      <button class="primary-button auth-submit" data-auth-submit="${isRegister ? "register" : "login"}">
        ${isRegister ? "Crear cuenta" : "Entrar"}
      </button>
    </section>
  `;
}

function createOwnStory(style = "Neon pastel") {
  state.ownStory = {
    user: state.user?.name || "Mi historia",
    avatar: state.user?.avatar || "berry",
    label: "mi historia",
    time: "Ahora",
    music: "HallyuHub · fan upload",
    title: "Mi momento K-pop",
    detail: `Historia decorada con ${style}, stickers, brillo idol y detalles asiaticos.`,
    stars: 0,
    views: 37,
    colors: "linear-gradient(160deg, #fbbcdb, #65e4ff 50%, #a855f7)",
    style,
  };
  storage.set("hallyuHubOwnStory", state.ownStory);
}

function sendStoryMessage(message) {
  if (!message) return;
  const story = getActiveStory();
  const item = {
    to: story?.user || "Historia",
    message,
    time: "Ahora",
  };
  state.storyInbox = [item, ...state.storyInbox].slice(0, 12);
  storage.set("hallyuHubStoryInbox", state.storyInbox);
  state.storyComposerOpen = false;
  render();
}

function getActiveStory() {
  if (state.activeStory === -1) return state.ownStory;
  return followingStories[state.activeStory];
}

function renderHome() {
  const feedPosts =
    state.backendMode === "supabase" && state.livePosts.length
      ? state.livePosts.map((post) => ({
          id: post.id,
          userId: post.user_id,
          user: post.profiles?.name || "Hallyu fan",
          group: post.category || "Post",
          category: "posts",
          time: "hace un momento",
          badge: "Tokki 🐰",
          online: true,
          hashtags: ["#HallyuHub", "#KpopLatam"],
          caption: post.caption,
          likes: "0",
          comments: "0",
          mediaUrl: post.media_url,
          mediaType: post.media_type,
        }))
      : userPosts;
  const filteredFeedPosts = filterHomeFeed(feedPosts);
  const infiniteFeedPosts = buildHomeFeed(filteredFeedPosts);
  const filterLabel = getHomeFilterLabel(state.homeFilter);
  return `
    ${renderHomeHighlights()}
    <div class="stories-row" aria-label="Historias de personas que sigo">
      <button class="story-item own-story-item" data-own-story>
        <span class="story-ring own-ring ${state.ownStory ? "has-story" : "empty-story"}">
          ${state.ownStory ? `<span class="plush-avatar story-avatar" style="--avatar:${getAvatarGradient(state.user?.avatar || "berry")}"><span></span></span>` : `<span class="story-plus">+</span>`}
        </span>
        <strong>${state.ownStory ? "Tu historia" : "Crear"}</strong>
        <small>${state.ownStory ? `${state.ownStory.stars}★ · ${state.ownStory.views} vistas` : "Subir"}</small>
      </button>
      ${followingStories
        .map(
          (story, index) => `
          <button class="story-item" data-story-index="${index}">
            <span class="story-ring">
              <span class="plush-avatar story-avatar" style="--avatar:${getAvatarGradient(story.avatar)}"><span></span></span>
            </span>
            <strong>${story.user}</strong>
          </button>`,
        )
        .join("")}
    </div>
    <section class="home-banner-shell" aria-label="Banners destacados">
      <div class="home-banner-track">
        ${homeBanners
          .map(
            (banner, index) => `
            <article class="home-banner" style="--art:${banner.colors}">
              <span>${banner.meta}</span>
              <strong>${banner.title}</strong>
              <div class="banner-actions">
                <button type="button" ${index % 3 === 0 ? `data-go-view="news"` : index % 3 === 1 ? `data-home-filter="viral"` : `data-home-filter="challenges"`}>${index % 3 === 0 ? "Ver noticia" : index % 3 === 1 ? "Ver trend" : "Explorar"}</button>
                <button type="button" data-save-post="banner-${index}">Guardar</button>
              </div>
            </article>`,
          )
          .join("")}
      </div>
      <div class="banner-dots" aria-hidden="true">
        ${homeBanners.map((_, index) => `<span style="--delay:${index}"></span>`).join("")}
      </div>
    </section>
    <div class="home-metric-pills" aria-label="Datos de comunidad">
      <button class="metric-pill" data-home-filter="events"><span class="metric-dot event"></span><strong>42</strong><small>eventos</small></button>
      <button class="metric-pill" data-go-view="community"><span class="metric-dot fans"></span><strong>128K</strong><small>conectados</small></button>
      <button class="metric-pill" data-go-view="market"><span class="metric-dot drops"></span><strong>24h</strong><small>drops</small></button>
    </div>
    <div class="section-heading feed-heading"><h2>${filterLabel}</h2><button class="feed-reset ${state.homeFilter === "all" ? "hidden" : ""}" data-home-filter="all">Ver todo</button></div>
    <div class="social-feed infinite-social-feed">
      ${infiniteFeedPosts
        .map((post, index) => renderSocialPost(post, index, { featured: index === 0 || index % 7 === 3 }))
        .join("")}
      <div class="feed-loader">
        <span></span><span></span><span></span>
        <strong>Cargando más momentos fandom...</strong>
      </div>
    </div>
    ${renderStoryViewer()}
    ${renderPostModal()}
  `;
}

function filterHomeFeed(posts) {
  const filter = state.homeFilter || "all";
  if (filter === "all") return posts;
  if (filter === "viral" || filter === "trends") return posts.filter((post) => post.type === "trending" || post.category === "trends");
  if (filter === "outfits") return posts.filter((post) => post.category === "outfits" || post.type === "outfit");
  if (filter === "challenges") return posts.filter((post) => post.category === "trends" || (post.hashtags || []).some((tag) => tag.toLowerCase().includes("challenge")));
  if (filter === "events") return posts.filter((post) => post.type === "event" || (post.hashtags || []).some((tag) => tag.toLowerCase().includes("evento")));
  if (filter.startsWith("#")) return posts.filter((post) => (post.hashtags || []).some((tag) => tag.toLowerCase() === filter.toLowerCase()));
  return posts;
}

function getHomeFilterLabel(filter) {
  const labels = {
    all: "Feed vivo",
    viral: "Lo más viral",
    trends: "Trends populares",
    outfits: "Outfits K-pop",
    challenges: "Challenges",
    events: "Eventos destacados",
  };
  return labels[filter] || `Hashtag ${filter}`;
}

function buildHomeFeed(posts) {
  const cycles = ["Ahora", "Hace 4 min", "Hace 12 min", "Hace 25 min"];
  return Array.from({ length: 3 }, (_, round) =>
    posts.map((post, index) => ({
      ...post,
      id: `${post.id || "post"}-${round}`,
      time: round === 0 ? post.time : cycles[(index + round) % cycles.length],
      likes: round === 0 ? post.likes : bumpFeedEngagement(post.likes, round + index),
      comments: round === 0 ? post.comments : bumpFeedEngagement(post.comments, round),
    })),
  ).flat();
}

function bumpFeedEngagement(value, amount) {
  const text = String(value || "0");
  const number = Number.parseFloat(text.replace(/[^0-9.]/g, "")) || 0;
  if (text.toLowerCase().includes("k")) return `${(number + amount * 0.2).toFixed(1)}K`;
  return String(Math.round(number + amount * 17));
}

function renderHomeHighlights() {
  return `
    <section class="home-highlights" aria-label="Categorias rapidas del inicio">
      ${homeHighlightStories
        .map(
          (item, index) => `
          <button type="button" class="highlight-story-card ${state.homeFilter === item.filter ? "active" : ""}" style="--art:${item.colors}" ${item.view ? `data-go-view="${item.view}"` : `data-home-filter="${item.filter}"`}>
            <span class="highlight-story-orb">${renderAvatarElement("mini", item.avatar)}</span>
            <strong>${item.label}</strong>
            <small>${item.detail}</small>
          </button>`,
        )
        .join("")}
    </section>`;
}

function renderPostModal() {
  if (!state.activePost) return "";
  const posts = buildHomeFeed(userPosts);
  const post = posts.find((item) => item.id === state.activePost) || userPosts.find((item) => String(state.activePost).startsWith(item.id));
  if (!post) return "";
  return `
    <section class="post-modal" aria-label="Publicacion abierta">
      <button class="post-modal-backdrop" data-close-post aria-label="Cerrar publicacion"></button>
      <article class="post-modal-card">
        <button class="story-close post-modal-close" data-close-post aria-label="Cerrar">X</button>
        ${renderSocialPost(post, 0, { compact: true, featured: true })}
      </article>
    </section>`;
}

function renderStoryViewer() {
  if (state.activeStory === null) return "";
  const story = getActiveStory();
  if (!story) return "";
  const isOwnStory = state.activeStory === -1;
  const liked = state.likedStories[state.activeStory];
  const progressTotal = followingStories.length + (state.ownStory ? 1 : 0);
  const progressIndex = state.ownStory ? state.activeStory + 1 : state.activeStory;
  return `
    <section class="story-viewer story-slide-${state.storyDirection > 0 ? "next" : "prev"} ${isOwnStory ? "own-story-viewer" : ""}" style="--story-art:${story.colors}" aria-label="Historia abierta">
      <div class="story-progress">${Array.from({ length: progressTotal }, (_, index) => `<span class="${index < progressIndex ? "seen" : ""} ${index === progressIndex ? "active" : ""}"></span>`).join("")}</div>
      <button class="story-close" data-story-close aria-label="Cerrar historia">X</button>
      <button class="story-tap-zone left" data-story-nav="-1" aria-label="Historia anterior"></button>
      <button class="story-tap-zone right" data-story-nav="1" aria-label="Historia siguiente"></button>
      <article class="story-full-card" style="--art:${story.colors}">
        <div class="story-full-head">
          <span class="story-ring small-ring"><span class="plush-avatar story-avatar small" style="--avatar:${getAvatarGradient(story.avatar)}"><span></span></span></span>
          <div><h3>${story.user}</h3><p>${story.label} · ${story.time}</p></div>
        </div>
        <div class="story-music-pill"><span>♪</span>${story.music}</div>
        <div class="live-fandom-pill"><span></span>Live fandom activo</div>
        <div class="story-full-copy">
          <h2>${story.title}</h2>
          <p>${story.detail}</p>
        </div>
        ${
          isOwnStory
            ? `<div class="story-interactions own-story-actions">
                <button class="story-star own-info-star ${state.ownStoryStatsOpen ? "active" : ""}" data-own-story-stats aria-label="Ver actividad de mi historia">★</button>
                <strong>${story.views || 0} vistas · tocar estrella para ver actividad</strong>
              </div>
              ${state.ownStoryStatsOpen ? renderOwnStoryStats(story) : ""}`
            : `<div class="story-interactions">
                <div class="story-like-line">
                  <button class="story-star ${liked ? "active" : ""}" data-story-star="${state.activeStory}" aria-label="Me gusto esta historia">★</button>
                  <strong>${story.stars + (liked ? 1 : 0)} estrellas</strong>
                </div>
                <button class="story-reply-trigger" data-story-message-open>Escribir mensaje...</button>
              </div>
              ${state.storyComposerOpen ? renderStoryComposer(story) : ""}`
        }
      </article>
    </section>
  `;
}

function renderSocialPost(post, index, options = {}) {
  return `
    <article class="post-card ${options.compact ? "profile-feed-post" : ""} ${options.featured || post.type === "trending" || post.type === "event" ? "featured-post" : ""}">
      <div class="post-head modern-post-head">
        <button class="post-profile-button" data-open-feed-profile="${post.user}">
          ${renderAvatarElement("mini post-author-avatar", post.avatar || "berry", post.avatarUrl)}
        </button>
        <button class="post-author-copy" data-open-feed-profile="${post.user}">
          <div class="post-user-line">
            <span class="online-dot ${post.online ? "active" : ""}"></span>
            <h3>${post.user}</h3>
            <span class="fandom-badge">${post.badge || "Army 💜"}</span>
          </div>
          <p class="muted">${post.group || getPostCategoryLabel(post.category)}${post.time ? ` · ${post.time}` : ""}${post.location ? ` · ${post.location}` : ""}</p>
        </button>
        <button class="post-menu-button" data-open-post="${post.id}" aria-label="Mas opciones">•••</button>
      </div>
      ${options.featured || post.type === "trending" || post.type === "event" ? `<div class="post-feature-label">${post.type === "event" ? "Evento destacado" : post.type === "trending" ? "Trend popular" : "Destacado"}</div>` : ""}
      <button class="post-open-button" data-open-post="${post.id}" aria-label="Abrir publicacion">
      ${
        post.mediaUrl
          ? post.mediaType === "video"
            ? `<video class="post-media real-media" src="${post.mediaUrl}" controls playsinline></video>`
            : `<img class="post-media real-media" src="${post.mediaUrl}" alt="Publicacion de ${post.user}" />`
          : `<div class="post-media" style="--art:${post.art || art[index % art.length]}"></div>`
      }
      </button>
      <p class="post-caption">${post.caption}</p>
      ${renderPostOptionalMeta(post)}
      <div class="post-hashtags">
        ${(post.hashtags || ["#KpopLatam", "#HallyuHub"]).map((tag) => `<button type="button" data-home-filter="${tag}">${tag}</button>`).join("")}
      </div>
      <div class="post-actions premium-actions">
        <button class="post-action-star" ${post.id ? `data-like-post="${post.id}"` : ""}><span>★</span><strong>${post.likes || "0"}</strong></button>
        <button class="post-action-comment" ${post.id ? `data-comment-post="${post.id}"` : ""}><span></span><strong>${post.comments || "0"}</strong></button>
        <button class="post-action-share" data-share-post="${post.id}"><span></span><strong>${post.shares || index + 24}</strong></button>
        <button class="post-action-save ${state.savedPosts[post.id] ? "active" : ""}" data-save-post="${post.id}"><span></span><strong>${post.saves || index + 12}</strong></button>
      </div>
    </article>`;
}

function renderPostOptionalMeta(post) {
  const items = [
    post.location ? ["Ubicación", post.location] : null,
    post.date || post.hour ? ["Fecha", [post.date, post.hour].filter(Boolean).join(" · ")] : null,
    post.taggedPeople ? ["Personas", post.taggedPeople] : null,
    post.taggedPlace ? ["Lugar", post.taggedPlace] : null,
  ].filter(Boolean);
  if (!items.length) return "";
  return `<div class="post-extra-meta">${items.map(([label, value]) => `<span><strong>${label}</strong>${value}</span>`).join("")}</div>`;
}

function renderOwnStoryStats(story) {
  return `
    <div class="own-story-stats">
      <div class="own-stat-grid">
        <div><strong>${story.views || 0}</strong><span>vistas</span></div>
        <div><strong>${story.stars || 0}</strong><span>estrellas</span></div>
        <div><strong>${storyViewers.length}</strong><span>fans</span></div>
      </div>
      <div class="viewer-list">
        ${storyViewers
          .map(
            (viewer) => `
            <div class="viewer-row">
              <span class="viewer-avatar"></span>
              <div><strong>${viewer.name}</strong><small>${viewer.action}</small></div>
              <span class="fandom-badge">${viewer.badge}</span>
            </div>`,
          )
          .join("")}
      </div>
    </div>
  `;
}

function renderStoryComposer(story) {
  return `
    <div class="story-composer-sheet">
      <div class="sheet-handle"></div>
      <div class="composer-head">
        <strong>Responder a ${story.user}</strong>
        <button data-story-message-close aria-label="Cerrar mensaje">X</button>
      </div>
      <div class="composer-tools">
        <span>💜</span><span>✨</span><span>🫰</span><span>🎀</span><span>📸</span><span>🔥</span>
      </div>
      <div class="quick-reactions story-phrases" aria-label="Frases K-pop rapidas">
        ${storyReactions.map((reaction) => `<button type="button" data-story-phrase="${reaction}">${reaction}</button>`).join("")}
      </div>
      <div class="story-decorations">
        ${storyDecorations.map((item) => `<button type="button" data-create-own-story="${item}">${item}</button>`).join("")}
      </div>
      <div class="story-comment-box expanded">
        <input id="story-message-input" placeholder="Escribir texto K-pop..." />
        <button data-story-send>Enviar</button>
      </div>
      ${
        state.storyInbox.length
          ? `<div class="story-inbox-preview"><strong>Inbox simulado</strong><span>${state.storyInbox[0].to}: ${state.storyInbox[0].message}</span></div>`
          : ""
      }
      <p class="composer-note">Se envia al inbox como conversacion simulada.</p>
    </div>
  `;
}

function renderNews() {
  const items = getFilteredNews();
  const updatedLabel = state.newsLastUpdated ? `Actualizado ${formatNewsDate(state.newsLastUpdated)}` : "Modo demo local";
  return `
    <button class="ghost-button back-button" data-go-view="home">Volver al inicio</button>
    <article class="news-hero-card">
      <div>
        <div class="pill">RSS Google News</div>
        <h2>Noticias K-pop actualizadas</h2>
        <p>Se consultan fuentes RSS por artista/grupo, se evitan duplicados y cada noticia queda con estado de moderacion.</p>
      </div>
      <button class="primary-button" data-news-refresh>${state.newsLoading ? "Actualizando..." : "Actualizar"}</button>
    </article>
    <section class="news-sync-card">
      <div><strong>${state.newsItems.length}</strong><span>noticias cacheadas</span></div>
      <div><strong>${state.newsItems.filter((item) => item.status === "pending").length}</strong><span>pendientes</span></div>
      <div><strong>3h</strong><span>auto refresh</span></div>
      <p>${updatedLabel}</p>
    </section>
    ${renderNewsFilters()}
    <div class="section-heading"><h2>${getNewsHeading()}</h2><span>${items.length}</span></div>
    <div class="news-list">
      ${items.length ? items.map((item, index) => renderNewsCard(item, index)).join("") : `<article class="settings-demo-box">No hay noticias para este filtro. Prueba con otro artista o estado.</article>`}
    </div>
  `;
}

function renderNewsFilters() {
  return `
    <section class="news-filter-panel">
      <div class="filter-row">
        ${["all", ...newsArtists].map((artist) => `<button class="filter-chip ${state.newsFilter.artist === artist ? "active" : ""}" data-news-filter="artist:${artist}">${artist === "all" ? "Todos" : artist}</button>`).join("")}
      </div>
      <div class="filter-row">
        ${[
          ["recent", "Recientes"],
          ["trending", "Trending"],
          ["all", "Todo"],
        ].map(([value, label]) => `<button class="filter-chip ${state.newsFilter.topic === value ? "active" : ""}" data-news-filter="topic:${value}">${label}</button>`).join("")}
      </div>
      <div class="filter-row">
        ${[
          ["all", "Todos los estados"],
          ["pending", "Pendientes"],
          ["approved", "Aprobadas"],
          ["rejected", "Rechazadas"],
        ].map(([value, label]) => `<button class="filter-chip ${state.newsFilter.status === value ? "active" : ""}" data-news-filter="status:${value}">${label}</button>`).join("")}
      </div>
      <div class="filter-row">
        ${[
          ["all", "Todos los idiomas"],
          ["es", "Español"],
          ["en", "Inglés"],
          ["LATAM", "LATAM"],
          ["AR", "Argentina"],
        ].map(([value, label]) => `<button class="filter-chip ${state.newsFilter.language === value ? "active" : ""}" data-news-filter="language:${value}">${label}</button>`).join("")}
      </div>
    </section>`;
}

function renderNewsCard(item, index) {
  return `
    <article class="glass-card news-card modern-news-card ${item.status}">
      ${
        item.image
          ? `<img class="news-image" src="${item.image}" alt="Imagen de ${item.artist}" />`
          : `<div class="cover-art" style="--art:${art[index % art.length]}"></div>`
      }
      <div class="news-copy">
        <div class="news-card-top">
          <span class="tag">${item.trending ? "Trending" : "Reciente"}</span>
          <span class="news-status ${item.status}">${getNewsStatusLabel(item.status)}</span>
        </div>
        <h3 class="card-title">${item.title}</h3>
        <p>${item.summary || "Resumen pendiente de completar desde la fuente RSS."}</p>
        <div class="meta-row"><strong>${item.artist}</strong><span>${item.source}</span><span>${formatNewsDate(item.date)}</span></div>
        <div class="news-actions">
          <a class="ghost-button" href="${item.link}" target="_blank" rel="noreferrer">Leer más</a>
          <button class="ghost-button" data-news-status="${item.id}:approved">Aprobar</button>
          <button class="ghost-button danger-button" data-news-status="${item.id}:rejected">Rechazar</button>
        </div>
      </div>
    </article>`;
}

function getFilteredNews() {
  const filter = state.newsFilter;
  return dedupeNews(state.newsItems.length ? state.newsItems : news)
    .filter((item) => filter.artist === "all" || item.artist === filter.artist)
    .filter((item) => filter.status === "all" || item.status === filter.status)
    .filter((item) => {
      if (filter.language === "all") return true;
      return item.language === filter.language || item.country === filter.language;
    })
    .filter((item) => {
      if (filter.topic === "trending") return item.trending;
      return true;
    })
    .sort((a, b) => new Date(b.date || 0) - new Date(a.date || 0));
}

function getNewsHeading() {
  if (state.newsFilter.topic === "trending") return "Trending K-pop";
  if (state.newsFilter.artist !== "all") return `Noticias de ${state.newsFilter.artist}`;
  return "Noticias recientes";
}

function getNewsStatusLabel(status) {
  return {
    pending: "Pendiente",
    approved: "Aprobada",
    rejected: "Rechazada",
  }[status] || "Pendiente";
}

function formatNewsDate(date) {
  if (!date) return "Sin fecha";
  try {
    return new Intl.DateTimeFormat("es-AR", { day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit" }).format(new Date(date));
  } catch {
    return "Sin fecha";
  }
}

async function loadKpopNews(force = false) {
  if (state.newsLoading) return;
  const cached = storage.get("hallyuHubNewsCache", null);
  const isFresh = cached?.updatedAt && Date.now() - new Date(cached.updatedAt).getTime() < NEWS_REFRESH_MS;
  if (!force && isFresh && cached.items?.length) {
    state.newsItems = mergeNewsStatuses(cached.items, news);
    state.newsLastUpdated = cached.updatedAt;
    if (state.view === "news") render();
    return;
  }

  state.newsLoading = true;
  if (state.view === "news") render();
  try {
    const response = await fetch(`/api/news?artists=${encodeURIComponent(newsArtists.join(","))}&lang=es&country=AR`);
    if (!response.ok) throw new Error("No se pudo leer RSS");
    const payload = await response.json();
    const fetched = Array.isArray(payload.items) ? payload.items : [];
    const merged = mergeNewsStatuses(dedupeNews([...fetched, ...state.newsItems, ...news]), state.newsItems);
    state.newsItems = merged;
    state.newsLastUpdated = payload.updatedAt || new Date().toISOString();
    storage.set("hallyuHubNewsCache", { updatedAt: state.newsLastUpdated, items: state.newsItems });
  } catch (error) {
    console.warn("Noticias RSS no disponibles, usando modo demo.", error);
    state.newsItems = mergeNewsStatuses(state.newsItems.length ? state.newsItems : news, news);
    state.newsLastUpdated = state.newsLastUpdated || new Date().toISOString();
    storage.set("hallyuHubNewsCache", { updatedAt: state.newsLastUpdated, items: state.newsItems });
  } finally {
    state.newsLoading = false;
    if (state.view === "news") render();
  }
}

function updateNewsStatus(id, status) {
  state.newsItems = state.newsItems.map((item) => (item.id === id ? { ...item, status } : item));
  state.newsLastUpdated = state.newsLastUpdated || new Date().toISOString();
  storage.set("hallyuHubNewsCache", { updatedAt: state.newsLastUpdated, items: state.newsItems });
  render();
}

function mergeNewsStatuses(incoming, previous) {
  const statusByKey = new Map((previous || []).map((item) => [getNewsKey(item), item.status || "pending"]));
  return dedupeNews(incoming).map((item) => ({
    ...item,
    status: statusByKey.get(getNewsKey(item)) || item.status || "pending",
  }));
}

function dedupeNews(items) {
  const seen = new Set();
  return (items || []).filter((item) => {
    const key = getNewsKey(item);
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function getNewsKey(item) {
  return String(item?.link || item?.title || "").toLowerCase().replace(/\s+/g, " ").trim();
}

function renderSearch() {
  const users = state.backendMode === "supabase" && state.liveProfiles.length ? state.liveProfiles : [];
  return `
    <div class="search-box">
      <span class="nav-icon search-icon"></span>
      <input placeholder="Buscar idols, grupos, usuarios, hashtags o tendencias" />
    </div>
    <div class="quick-link-grid">
      <button data-go-view="groups"><span class="nav-icon music-icon"></span><strong>Grupos</strong><small>Biografias e idols</small></button>
      <button data-go-view="news"><span class="nav-icon heart-icon"></span><strong>Noticias</strong><small>Actualidad K-pop</small></button>
      <button data-go-view="market"><span class="nav-icon bag-icon"></span><strong>Shop</strong><small>Merch y fotocards</small></button>
      <button data-go-view="community"><span class="nav-icon chat-icon"></span><strong>Comunidad</strong><small>Chats por zona</small></button>
      <button data-go-view="rookie"><span class="nav-icon spark-icon"></span><strong>K-pop 101</strong><small>Para fans nuevos</small></button>
      <button data-go-view="trends"><span class="nav-icon play-icon"></span><strong>Trends</strong><small>Challenges y videos</small></button>
    </div>
    <div class="section-heading"><h2>Tendencias</h2><span>Explorar</span></div>
    <div class="group-story-row">
      ${kpopGroups
        .map(
          (group) => `
          <button class="group-story" data-group="${group.id}" data-go-view="groups">
            <span class="group-story-photo" style="--art:${group.colors}"></span>
            <strong>${group.name}</strong>
          </button>`,
        )
        .join("")}
    </div>
    ${
      users.length
        ? `<div class="section-heading"><h2>Usuarios</h2><span>Supabase</span></div>
          <div class="user-result-list">
            ${users
              .map(
                (profile) => `
                <article class="user-result-card">
                  ${renderAvatarElement("mini", profile.avatar, profile.avatar_url)}
                  <button class="profile-result-main" data-open-profile="${profile.id}">
                    <div><h3>${profile.name}</h3><p class="muted">@${profile.username}</p></div>
                  </button>
                  <button class="ghost-button" data-follow-user="${profile.id}">Seguir</button>
                  <button class="ghost-button" data-send-message="${profile.id}">Mensaje</button>
                </article>`,
              )
              .join("")}
          </div>`
        : ""
    }
  `;
}

function renderTrends() {
  return `
    <div class="trend-tabs">
      <button class="active">Mas virales</button>
      <button>Hacer mi trend</button>
      <button>Buscar trend</button>
    </div>
    <section class="trends-feed" aria-label="Trends estilo reels">
      ${trendVideos
        .map(
          (trend, index) => `
          <article class="trend-card" style="--art:${trend.colors}">
            <div class="trend-overlay">
              <div class="trend-copy">
                <div class="post-head compact-head">
                  <div class="plush-avatar mini" style="--avatar:${avatars[index % avatars.length].gradient}"><span></span></div>
                  <div><h3>${trend.user}</h3><p>${trend.song}</p></div>
                </div>
                <h2>${trend.challenge}</h2>
                <p>${trend.description}</p>
              </div>
              <div class="trend-actions">
                <button><span class="nav-icon heart-icon"></span><small>Like</small></button>
                <button><span class="nav-icon chat-icon"></span><small>Comentar</small></button>
                <button><span class="share-dot"></span><small>Compartir</small></button>
                <button><span class="save-mark"></span><small>Guardar</small></button>
              </div>
            </div>
          </article>`,
        )
        .join("")}
    </section>
  `;
}

function renderPublish() {
  return `
    <section class="publish-card">
      <div class="post-head">
        <div class="plush-avatar mini" style="--avatar:${getAvatarGradient(state.user.avatar)}"><span></span></div>
        <div><h3>${state.user.name}</h3><p class="muted">@${state.user.username}</p></div>
      </div>
      <label>Texto de la publicacion<textarea id="post-caption" placeholder="Comparte una foto, trade, noticia o momento fandom..."></textarea></label>
      <label>Tipo de contenido
        <select id="post-category">
          <option value="posts">Publicacion</option>
          <option value="trends">Trend</option>
          <option value="outfits">Outfit</option>
          <option value="photocards">Photocard</option>
          <option value="favorites">Favorito</option>
        </select>
      </label>
      <div class="upload-zone">
        <span class="nav-icon plus-icon"></span>
        <strong>Agregar foto o video</strong>
        <input id="post-media" type="file" accept="image/*,video/*" />
        <small>${state.backendMode === "supabase" ? "Se sube a Supabase Storage." : "Modo demo local hasta configurar Supabase."}</small>
      </div>
      <details class="optional-post-fields">
        <summary>Agregar datos opcionales</summary>
        <div class="optional-field-grid">
          <label>Ubicación<input id="post-location" placeholder="Santiago, Chile" /></label>
          <label>Fecha<input id="post-date" type="date" /></label>
          <label>Hora<input id="post-hour" type="time" /></label>
          <label>Etiquetar personas<input id="post-tagged-people" placeholder="@cami, @mika" /></label>
          <label>Etiquetar lugares<input id="post-tagged-place" placeholder="Cupsleeve, evento, local" /></label>
        </div>
      </details>
      <div class="filter-row">
        <button class="filter-chip active">Post</button>
        <button class="filter-chip">Historia</button>
        <button class="filter-chip">Trade</button>
        <button class="filter-chip">Noticia</button>
      </div>
      <button class="primary-button" data-create-post>Publicar</button>
    </section>
  `;
}

function renderNotifications() {
  const items = [
    ["Cami.STAY", "empezo a seguirte", "Nuevo seguidor", "Ahora"],
    ["ARMY Chile", "le dio like a tu publicacion", "Like recibido", "12 min"],
    ["Mika mentor", "comento tu pregunta de K-pop 101", "Comentario", "1 h"],
    ["Seoul Corner", "guardo tu wishlist de photocards", "Actividad", "Ayer"],
  ];
  return `
    <div class="inbox-tabs">
      <button class="${state.activityTab === "activity" ? "active" : ""}" data-activity-tab="activity">Actividad</button>
      <button class="${state.activityTab === "messages" ? "active" : ""}" data-activity-tab="messages">Mensajes</button>
    </div>
    ${
      state.activityTab === "activity"
        ? `<div class="notification-list">
            ${items
              .map(
                ([name, action, type, time], index) => `
                <article class="notification-card">
                  <div class="plush-avatar mini" style="--avatar:${avatars[index % avatars.length].gradient}"><span></span></div>
                  <div><h3>${name}</h3><p class="muted">${action}</p><span class="tag">${type}</span></div>
                  <span>${time}</span>
                </article>`,
              )
              .join("")}
          </div>`
        : renderMessages()
    }
  `;
}

function getAvatarGradient(avatarId) {
  return (avatars.find((avatar) => avatar.id === avatarId) || avatars[0]).gradient;
}

function getAvatarMeta(avatarId) {
  return avatars.find((avatar) => avatar.id === avatarId) || avatars[0];
}

function getRarityClass(item) {
  return `rarity-${String(item?.rarity || "Common").toLowerCase()}`;
}

function getFanProgress(user = state.user) {
  const levelFromLabel = String(user?.fandomLevel || "").match(/\d+/)?.[0];
  const stars = parseStars(user?.starsReceived);
  const level = Number(user?.level || levelFromLabel || Math.max(1, Math.floor(stars / 1800) + 1));
  const currentLevelStars = Math.max(0, stars - (level - 1) * 1800);
  return {
    level,
    stars,
    percent: Math.min(98, Math.round((currentLevelStars / 1800) * 100)),
  };
}

function parseStars(value) {
  if (typeof value === "number") return value;
  const text = String(value || "0").trim().toLowerCase();
  const number = Number.parseFloat(text.replace(/[^0-9.]/g, "")) || 0;
  return text.includes("k") ? Math.round(number * 1000) : Math.round(number);
}

function isUnlocked(item, user = state.user) {
  return getFanProgress(user).level >= (item?.minLevel || 1);
}

function getProfileBackground(bgId) {
  return profileBackgrounds.find((bg) => bg.id === (bgId || state.selectedProfileBg || state.user?.profileBg)) || profileBackgrounds[0];
}

function renderProfileBackgroundPicker() {
  const activeBg = getProfileBackground(state.selectedProfileBg || state.user.profileBg);
  return `
    <div class="profile-bg-preview" style="--profile-bg:${activeBg.art}">
      <span>${activeBg.name}</span>
      <strong>Vista previa del perfil</strong>
      <small>${activeBg.detail} · ${activeBg.rarity}</small>
    </div>
    <div class="profile-bg-grid">
      ${profileBackgrounds
        .map((bg) => {
          const unlocked = isUnlocked(bg);
          return `
          <button class="${activeBg.id === bg.id ? "active" : ""} ${unlocked ? "" : "locked"} ${getRarityClass(bg)}" ${unlocked ? `data-profile-bg="${bg.id}"` : "disabled"}>
            <span style="--profile-bg:${bg.art}"></span>
            <strong>${bg.name}</strong>
            <small>${unlocked ? bg.detail : `Se desbloquea en nivel ${bg.minLevel}`}</small>
          </button>`;
        })
        .join("")}
    </div>
  `;
}

function renderEvents() {
  return `
    <div class="filter-row">
      <button class="filter-chip active">Cerca de mi</button>
      <button class="filter-chip">Conciertos</button>
      <button class="filter-chip">Fan meetings</button>
      <button class="filter-chip">Random dance</button>
    </div>
    <article class="hero-card">
      <div class="pill">Agenda fandom</div>
      <h2>Encuentra eventos por ciudad y comunidad</h2>
      <p>Guarda fechas, revisa precios y comparte planes con tu fanbase.</p>
    </article>
    <div class="section-heading"><h2>Proximos eventos</h2><span>Calendario</span></div>
    <div class="event-list">
      ${events
        .map(
          (event) => `
          <article class="event-card">
            <div class="date-box"><div><span>${event.month}</span><strong>${event.day}</strong></div></div>
            <div>
              <h3 class="card-title">${event.title}</h3>
              <p class="muted">${event.place}</p>
              <div class="meta-row"><span class="tag">${event.status}</span><span>Guardar</span></div>
            </div>
          </article>`,
        )
        .join("")}
    </div>
  `;
}

function renderMarket() {
  return `
    <article class="hero-card">
      <div class="pill">Drop verificado</div>
      <h2>Merch, albums y photocards sin drama</h2>
      <p>Marketplace con vendedores revisados, wishlist y compras grupales.</p>
    </article>
    <div class="section-heading"><h2>Ofertas flash</h2><span>Seguro</span></div>
    <div class="market-grid">
      ${products
        .map(
          (product, index) => `
          <article class="product-card">
            <div class="product-visual" style="--art:${art[index + 1] || art[0]}"></div>
            <div class="product-body">
              <span class="tag">${product.group}</span>
              <h3 class="card-title">${product.name}</h3>
              <div class="price-row"><strong>${product.price}</strong><button class="tiny-plus" aria-label="Agregar">+</button></div>
            </div>
          </article>`,
        )
        .join("")}
    </div>
    <div class="section-heading"><h2>Locales verificados</h2><span>Guardar compra</span></div>
    <div class="store-list">
      ${localStores
        .map(
          (store) => `
          <article class="glass-card store-card">
            <div>
              <h3 class="card-title">${store.name}</h3>
              <p class="muted">${store.detail}</p>
              <div class="meta-row"><span>${store.city}</span><span class="tag">${store.trust} confianza</span></div>
            </div>
            <button class="ghost-button">Agregar a carpeta</button>
          </article>`,
        )
        .join("")}
    </div>
  `;
}

function renderGroups() {
  const activeGroup = kpopGroups.find((group) => group.id === state.selectedGroup) || kpopGroups[0];
  return `
    <div class="group-story-row">
      ${kpopGroups
        .map(
          (group) => `
          <button class="group-story ${activeGroup.id === group.id ? "active" : ""}" data-group="${group.id}">
            <span class="group-story-photo" style="--art:${group.colors}"></span>
            <strong>${group.name}</strong>
          </button>`,
        )
        .join("")}
    </div>
    <article class="group-hero" style="--art:${activeGroup.colors}">
      <span class="tag">${activeGroup.fandom}</span>
      <h2>${activeGroup.name}</h2>
      <p>${activeGroup.style}</p>
    </article>
    <button class="primary-button follow-group-button">Seguir ${activeGroup.name}</button>
    <section class="group-info-grid">
      <div class="info-tile"><span>Empresa</span><strong>${activeGroup.company}</strong></div>
      <div class="info-tile"><span>Debut</span><strong>${activeGroup.debut}</strong></div>
      <div class="info-tile"><span>Fandom</span><strong>${activeGroup.fandom}</strong></div>
    </section>
    <div class="group-photo-strip">
      <div style="--art:${activeGroup.colors}">Concept</div>
      <div style="--art:${art[2]}">Stage</div>
      <div style="--art:${art[4]}">Behind</div>
    </div>
    <section class="glass-card update-card">
      <div>
        <h3 class="card-title">Noticias destacadas</h3>
        <p class="muted">${activeGroup.latest}</p>
      </div>
      <span class="tag">Internet ready</span>
    </section>
    <section class="glass-card biography-card">
      <h3 class="card-title">Biografia</h3>
      <p>${activeGroup.bio}</p>
    </section>
    <div class="section-heading"><h2>Artistas</h2><span>${activeGroup.artists.length} perfiles</span></div>
    <div class="artist-list">
      ${activeGroup.artists
        .map(
          (artist, index) => `
          <article class="artist-card">
            <div class="artist-photo" style="--art:${art[index % art.length]}"></div>
            <div>
              <h3>${artist.name}</h3>
              <p class="muted">${artist.role}</p>
              <div class="meta-row"><span>${artist.country}</span><span class="tag">Ver perfil</span></div>
            </div>
          </article>`,
        )
        .join("")}
    </div>
  `;
}

function renderCommunity() {
  const tabs = [
    ["global", "Global"],
    ["countries", "Paises"],
    ["cities", "Ciudades"],
    ["groups", "Por grupo"],
  ];
  const list = communities[state.communityTab];
  return `
    <div class="tabs">
      ${tabs
        .map(
          ([key, label]) =>
            `<button class="tab-button ${state.communityTab === key ? "active" : ""}" data-community-tab="${key}">${label}</button>`,
        )
        .join("")}
    </div>
    <div class="community-list">
      ${list
        .map(
          (community, index) => `
          <article class="community-card">
            <div class="community-top">
              <div class="community-title">
                <div class="community-avatar" style="--art:${art[index]}"></div>
                <div>
                  <h3>${community.name}</h3>
                  <div class="meta-row"><span>${community.members}</span><span>${community.activity}</span></div>
                </div>
              </div>
              <span class="tag">Unirme</span>
            </div>
            <p class="muted">${community.detail}</p>
            <div class="community-actions">
              <button class="ghost-button">Ver chat</button>
              <button class="ghost-button">Eventos</button>
              <button class="ghost-button">Moderadores</button>
            </div>
          </article>`,
        )
        .join("")}
    </div>
    <section class="chat-panel">
      <div class="section-heading"><h2>Chats de mi comunidad</h2><span>Seguro</span></div>
      <div class="chat-list">
        ${chatChannels
          .map(
            (channel, index) => `
            <article class="chat-card">
              <div class="chat-sigil" style="--art:${art[index + 1]}"></div>
              <div>
                <div class="chat-card-head">
                  <h3>${channel.name}</h3>
                  <span class="tag">${channel.status}</span>
                </div>
                <p class="muted">${channel.detail}</p>
                <div class="chat-bubble">${channel.last}</div>
              </div>
            </article>`,
          )
          .join("")}
      </div>
    </section>
    <button class="primary-button">Solicitar grupo de mi ciudad</button>
  `;
}

function renderMessages() {
  return `
    <article class="hero-card">
      <div class="pill">DM privado</div>
      <h2>Mensajes con permiso</h2>
      <p>Como en Instagram: si no aceptas la solicitud, la persona no puede escribirte directo.</p>
    </article>
    <div class="section-heading"><h2>Solicitudes</h2><span>2 pendientes</span></div>
    <div class="request-list">
      ${privateRequests
        .map(
          (request, index) => `
          <article class="request-card">
            <div class="plush-avatar mini" style="--avatar:${avatars[index].gradient}"><span></span></div>
            <div>
              <h3>${request.name}</h3>
              <p class="muted">${request.note}</p>
              <span class="tag">${request.shared}</span>
            </div>
            <div class="request-actions">
              <button class="ghost-button">Rechazar</button>
              <button class="ghost-button accept">Aceptar</button>
            </div>
          </article>`,
        )
        .join("")}
    </div>
    <div class="section-heading"><h2>Chats</h2><span>Aceptados</span></div>
    <div class="chat-list">
      ${conversations
        .map(
          (chat, index) => `
          <article class="dm-card">
            <div class="plush-avatar mini" style="--avatar:${avatars[(index + 1) % avatars.length].gradient}"><span></span></div>
            <div>
              <div class="chat-card-head"><h3>${chat.name}</h3><span>${chat.time}</span></div>
              <p class="muted">${chat.last}</p>
              <span class="tag">${chat.status}</span>
            </div>
          </article>`,
        )
        .join("")}
    </div>
  `;
}

function renderSettings() {
  const activeAvatar = avatars.find((avatar) => avatar.id === state.user.avatar) || avatars[0];
  const activeAmbience = ambiences.find((ambience) => ambience.id === state.user.ambience) || ambiences[0];
  const premiumLabel = state.user.premium ? "Plus activo" : "Plan gratuito";
  const settingsGroups = getSettingsGroups();
  if (state.settingsPanel) return renderSettingsPanel(state.settingsPanel, activeAvatar, activeAmbience, premiumLabel);
  return `
    <button class="ghost-button back-button" data-go-view="profile">Volver al perfil</button>
    <section class="settings-header">
      <div class="plush-avatar hero" style="--avatar:${activeAvatar.gradient}"><span></span></div>
      <div>
        <p class="eyebrow">Configuración</p>
        <h2>Centro de cuenta</h2>
        <p class="muted">Cuenta, privacidad, actividad, archivo, guardados, tema y seguridad.</p>
      </div>
    </section>
    <section class="backend-card">
      <strong>${state.backendMode === "supabase" ? "Supabase conectado" : "Modo demo local"}</strong>
      <p>${state.backendMode === "supabase" ? "Login, perfiles, posts y media usan Supabase." : "Agrega URL y anon key en supabase-config.js para activar usuarios reales."}</p>
    </section>
    ${settingsGroups
      .map(
        ({ title, items }) => `
        <section class="profile-panel settings-section">
          <div class="section-heading"><h2>${title}</h2><span>${items.length}</span></div>
          <div class="settings-menu-list dense">
            ${items
              .map(
                (item, index) => `
                <button data-settings-panel="${item.key}">
                  <span class="setting-icon">${item.icon || "•"}</span>
                  <span class="setting-copy"><strong>${item.label}</strong><small>${item.detail}</small></span>
                  <span class="setting-arrow">›</span>
                </button>`,
              )
              .join("")}
          </div>
        </section>`,
      )
      .join("")}
  `;
}

function getSettingsGroups() {
  return [
    {
      title: "Cuenta",
      items: [
        { key: "personal-data", label: "Datos personales", detail: "Email, telefono, idioma y pais", icon: "ID" },
        { key: "password", label: "Cambiar contraseña", detail: "Seguridad de acceso", icon: "PW" },
        { key: "language", label: "Idioma", detail: state.user.language || "Espanol", icon: "文" },
      ],
    },
    {
      title: "Perfil",
      items: [
        { key: "edit-profile", label: "Editar perfil", detail: "Nombre, usuario, bio, avatar y fandom", icon: "PF" },
        { key: "profile-background", label: "Fondo del perfil", detail: "Fandom, comeback, lightstick y pastel", icon: "BG" },
      ],
    },
    {
      title: "Privacidad",
      items: [
        { key: "private-account", label: "Cuenta privada", detail: "Controla quién te ve", icon: "PR" },
        { key: "message-privacy", label: "Quién puede escribirme", detail: "Solicitudes y permisos", icon: "DM" },
        { key: "story-privacy", label: "Quién puede ver mis historias", detail: "Fans, seguidores o privado", icon: "ST" },
        { key: "blocked-users", label: "Usuarios bloqueados", detail: "Ver y administrar bloqueos", icon: "BL" },
      ],
    },
    {
      title: "Notificaciones",
      items: [
        { key: "notif-messages", label: "Mensajes", detail: "DM y solicitudes", icon: "✉" },
        { key: "notif-stars", label: "Estrellas", detail: "Likes y reacciones", icon: "★" },
        { key: "notif-comments", label: "Comentarios", detail: "Respuestas y menciones", icon: "··" },
        { key: "notif-followers", label: "Seguidores", detail: "Nuevos fans", icon: "+" },
        { key: "notif-trends", label: "Trends", detail: "Challenges y eventos", icon: "▶" },
      ],
    },
    {
      title: "Seguridad",
      items: [
        { key: "private-account", label: "Verificacion de cuenta", detail: "Estado y confianza", icon: "✓" },
        { key: "password", label: "Sesiones activas", detail: "Dispositivos conectados", icon: "SE" },
        { key: "blocked-users", label: "Bloquear usuarios", detail: "Control de seguridad", icon: "!" },
      ],
    },
    {
      title: "Soporte",
      items: [
        { key: "report-problem", label: "Reportar problema", detail: "Ayuda y seguridad", icon: "?" },
        { key: "plus", label: "HallyuHub Plus", detail: state.user.premium ? "Plus activo" : "Plan gratuito", icon: "＋" },
        { key: "payment-methods", label: "Métodos de pago", detail: "Tarjetas y medios demo", icon: "$" },
      ],
    },
    {
      title: "Legal",
      items: [
        { key: "privacy-policy", label: "Política de privacidad", detail: "Uso de datos y seguridad", icon: "PV" },
        { key: "terms", label: "Términos y condiciones", detail: "Reglas de uso", icon: "TC" },
        { key: "community-rules", label: "Normas de comunidad", detail: "Convivencia fandom", icon: "NC" },
        { key: "copyright", label: "Copyright", detail: "Derechos de autor", icon: "©" },
        { key: "fan-policy", label: "Política de contenido fan", detail: "UGC y fan edits", icon: "FN" },
        { key: "delete-account", label: "Eliminar cuenta", detail: "Accion sensible", icon: "×" },
      ],
    },
    {
      title: "Cerrar sesión",
      items: [
        { key: "logout", label: "Cerrar sesión", detail: "Salir de HallyuHub", icon: "↗" },
      ],
    },
  ];
}

function renderSettingsPanel(panel, activeAvatar, activeAmbience, premiumLabel) {
  const titles = {
    "edit-profile": "Editar perfil",
    "personal-data": "Datos personales",
    password: "Cambiar contrasena",
    language: "Idioma",
    logout: "Cerrar sesion",
    "private-account": "Cuenta privada",
    "message-privacy": "Quien puede escribirme",
    "story-privacy": "Quien puede ver mis historias",
    "blocked-users": "Usuarios bloqueados",
    appearance: "Apariencia",
    "profile-background": "Fondo del perfil",
    "premium-theme": "Tema premium",
    plus: "HallyuHub Plus",
    "payment-methods": "Metodos de pago",
    "payment-history": "Historial de pagos",
    "cancel-subscription": "Cancelar suscripcion",
    "privacy-policy": "Politica de privacidad",
    terms: "Terminos y condiciones",
    "community-rules": "Normas de comunidad",
    copyright: "Copyright",
    "fan-policy": "Politica de contenido fan",
    "report-problem": "Reportar problema",
    "delete-account": "Eliminar cuenta",
  };
  const notificationPanels = ["notif-messages", "notif-stars", "notif-comments", "notif-followers", "notif-trends"];
  const title = titles[panel] || (notificationPanels.includes(panel) ? "Notificaciones" : "Configuracion");
  return `
    <button class="ghost-button back-button" data-settings-main>Volver a configuracion</button>
    <section class="settings-detail">
      <div class="section-heading"><h2>${title}</h2><span>Demo</span></div>
      ${renderSettingsPanelBody(panel, activeAvatar, activeAmbience, premiumLabel)}
    </section>
  `;
}

function renderSettingsPanelBody(panel, activeAvatar, activeAmbience, premiumLabel) {
  if (panel === "edit-profile") {
    return `
      <div class="form-stack">
        <label>Nombre<input id="settings-name" value="${state.user.name}" /></label>
        <label>Usuario<input id="settings-username" value="${state.user.username}" /></label>
        <label>Biografia<textarea id="settings-bio">${state.user.bio}</textarea></label>
        <label>Fandom<input id="settings-fandom" value="${state.user.fandom || ""}" /></label>
        <label>Bias<input id="settings-bias" value="${state.user.bias || ""}" /></label>
        <label>Grupo favorito<input id="settings-group" value="${state.user.favoriteGroup || ""}" /></label>
        <label>Frase destacada<input id="settings-phrase" value="${state.user.phrase || ""}" /></label>
        <label>Subir foto real<input id="settings-avatar-file" type="file" accept="image/*" /></label>
      </div>
      <div class="section-heading small"><h2>Avatar prediseñado</h2><span>${activeAvatar.name}</span></div>
      <div class="avatar-picker">
        ${avatars
          .map(
            (avatar) => `
            <button class="avatar-choice ${state.user.avatar === avatar.id ? "active" : ""}" data-avatar="${avatar.id}">
              <div class="plush-avatar pick" style="--avatar:${avatar.gradient}"><span></span></div>
              <strong>${avatar.name}</strong>
            </button>`,
          )
          .join("")}
      </div>
      <div class="section-heading small"><h2>Personalizar perfil</h2><span>Fondo</span></div>
      ${renderProfileBackgroundPicker()}
      <button class="primary-button" data-save-settings>Guardar cambios</button>
    `;
  }
  if (panel === "personal-data") {
    return `
      <div class="form-stack">
        <label>Email<input value="${state.user.email}" /></label>
        <label>Telefono<input id="settings-phone" value="${state.user.phone || ""}" /></label>
        <label>Pais<input id="settings-country" value="${state.user.country || ""}" /></label>
        <label>Idioma<input id="settings-language" value="${state.user.language || "Espanol"}" /></label>
      </div>
      <button class="primary-button" data-save-settings>Guardar datos</button>
    `;
  }
  if (panel === "appearance" || panel === "premium-theme" || panel === "profile-background") {
    return `
      <div class="section-heading small"><h2>Fondo del perfil</h2><span>Vista previa</span></div>
      ${renderProfileBackgroundPicker()}
      <div class="ambience-grid">
        ${ambiences
          .map(
            (ambience) => `
            <button class="ambience-choice ${state.user.ambience === ambience.id ? "active" : ""}" data-ambience="${ambience.id}">
              <span class="ambience-preview ${ambience.id}"></span>
              <strong>${ambience.name}</strong>
              <small>${ambience.group}</small>
            </button>`,
          )
          .join("")}
      </div>
      <div class="form-stack settings-form">
        <label>Color principal<input id="settings-accent" type="color" value="${state.user.accent}" /></label>
        <label class="switch-row">Modo claro<input id="settings-mode" type="checkbox" ${state.user.mode === "light" ? "checked" : ""} /></label>
        <label class="switch-row">Notificaciones<input id="settings-notifications" type="checkbox" ${state.user.notifications ? "checked" : ""} /></label>
        <label class="switch-row">Perfil privado<input id="settings-privacy" type="checkbox" ${state.user.privateProfile ? "checked" : ""} /></label>
      </div>
      <button class="primary-button" data-save-settings>Guardar apariencia</button>
    `;
  }
  if (panel === "plus") {
    return `
      <section class="plus-panel">
        <span class="tag">${premiumLabel}</span>
        <h2>HallyuHub Plus</h2>
        <p>Incluye badges exclusivos, temas premium, filtros, mas espacio para photocards y estadisticas avanzadas.</p>
        <button class="primary-button" data-toggle-premium>${state.user.premium ? "Desactivar demo" : "Suscribirme"}</button>
      </section>
    `;
  }
  if (panel === "logout") return `<p class="muted">Cierra la sesion actual en este dispositivo.</p><button class="ghost-button danger-button" data-logout>Cerrar sesion</button>`;
  if (panel === "delete-account") return `<p class="muted">Esta pantalla demo muestra la opcion visible para eliminar cuenta, requerida para apps con usuarios.</p><button class="ghost-button danger-button">Solicitar eliminacion de cuenta</button>`;
  if (panel === "report-problem") return `<div class="form-stack"><label>Describe el problema<textarea>Quiero reportar contenido o usuario...</textarea></label></div><button class="primary-button">Enviar reporte demo</button>`;
  const legalText = {
    "privacy-policy": "Explicamos que HallyuHub protege datos personales, usa localStorage en modo demo y luego Supabase para sesiones reales.",
    terms: "Reglas demo de uso: respeto, seguridad, nada de acoso, spam, suplantacion ni contenido ilegal.",
    "community-rules": "Normas: cuidar a fans menores, no doxxing, no bullying, no ventas inseguras y reportar contenido riesgoso.",
    copyright: "Respeto por derechos de autor, marcas, fancams, fotos oficiales y contenido de terceros.",
    "fan-policy": "Contenido fan permitido si respeta creditos, privacidad, derechos y normas de comunidad.",
    "payment-methods": "Metodo de pago demo: tarjeta terminada en 4242. No se procesa dinero real.",
    "payment-history": "Historial demo: HallyuHub Plus - pendiente de activar.",
    "cancel-subscription": "Puedes cancelar la suscripcion demo en cualquier momento desde esta pantalla.",
  };
  return `<p class="muted">${legalText[panel] || "Configuracion demo lista para conectarse a funciones reales mas adelante."}</p><div class="settings-demo-box">Pantalla funcional demo sin acciones reales todavia.</div>`;
}

function renderOnboarding() {
  return `
    <section class="onboarding-screen">
      <p class="eyebrow">Bienvenida a HallyuHub</p>
      <h2>Completa tu perfil fandom</h2>
      <p class="muted">Esto aparece solo la primera vez. Despues puedes editarlo desde Configuracion.</p>
      <div class="form-stack">
        <label>Nombre<input id="onboarding-name" value="${state.user.name}" /></label>
        <label>Usuario<input id="onboarding-username" value="${state.user.username}" /></label>
        <label>Foto<input type="file" accept="image/*" /></label>
        <label>Pais<input id="onboarding-country" value="${state.user.country || ""}" /></label>
        <label>Fandom principal<input id="onboarding-fandom" value="${state.user.fandom || ""}" /></label>
        <label>Bias<input id="onboarding-bias" value="${state.user.bias || ""}" /></label>
        <label>Grupo favorito<input id="onboarding-group" value="${state.user.favoriteGroup || ""}" /></label>
        <label>Biografia<textarea id="onboarding-bio">${state.user.bio}</textarea></label>
        <label class="switch-row">Acepto terminos y politica de privacidad<input id="onboarding-terms" type="checkbox" /></label>
      </div>
      <button class="primary-button" data-save-onboarding>Entrar a mi perfil</button>
    </section>
  `;
}

function renderRookie() {
  return `
    <article class="rookie-hero">
      <div class="pill">K-pop 101</div>
      <h2>Quiero entrar al mundo del K-pop</h2>
      <p>Fans con experiencia te acompanan, recomiendan musica y explican la cultura fandom.</p>
    </article>
    <div class="section-heading"><h2>Ruta para empezar</h2><span>Principiante</span></div>
    <div class="guide-list">
      ${[
        ["01", "Elige tu vibra", "Dinos si te gusta pop brillante, rap fuerte, baladas o performance."],
        ["02", "Recibe 5 canciones", "Una mentora te arma una mini playlist para escuchar sin saturarte."],
        ["03", "Aprende palabras clave", "Bias, comeback, era, photocard, fancam y mas sin sentirse perdido."],
      ]
        .map(
          ([number, title, detail]) => `
          <article class="glass-card guide-card">
            <div class="guide-number">${number}</div>
            <div><h3 class="card-title">${title}</h3><p class="muted">${detail}</p></div>
          </article>`,
        )
        .join("")}
    </div>
    <div class="section-heading"><h2>Mentores disponibles</h2><span>Hablar ahora</span></div>
    <div class="mentor-list">
      ${mentors
        .map(
          (mentor, index) => `
          <article class="mentor-card">
            <div class="mentor-avatar" style="--art:${art[index + 2]}"></div>
            <div>
              <h3>${mentor.name}</h3>
              <p class="muted">${mentor.role}</p>
              <p>${mentor.help}</p>
              <button class="ghost-button">Pedir consejo</button>
            </div>
          </article>`,
        )
        .join("")}
    </div>
  `;
}

function renderProfile() {
  const profileUser = state.viewedProfile || state.user;
  const isOwnProfile = !state.viewedProfile || profileUser.username === state.user.username || profileUser.id === state.session?.user?.id;
  if (isOwnProfile && state.profileEditorOpen) return renderProfileEditor();
  const isPlus = Boolean(profileUser.premium);
  const activeTab = profileTabs.find(([key]) => key === state.profileTab) || profileTabs[0];
  const profileBg = getProfileBackground(profileUser.profileBg);
  const avatarMeta = getAvatarMeta(profileUser.avatar);
  const progress = getFanProgress(profileUser);
  const isFollowing = Boolean(state.followedProfiles[profileUser.id || profileUser.username]);
  return `
    <section class="premium-profile-hero ${isPlus ? "plus" : ""}" style="--profile-bg:${profileBg.art}">
      ${
        isOwnProfile
          ? `<div class="profile-header-bar">
              <span></span>
              <span></span>
              <button class="settings-button modern-settings" data-go-view="settings" aria-label="Abrir ajustes"><span class="settings-tune-icon"></span></button>
            </div>`
          : ""
      }
      <div class="profile-hero-top">
        ${renderAvatarElement(`profile-avatar premium-avatar ${getRarityClass(avatarMeta)}`, profileUser.avatar, profileUser.avatarUrl)}
        <div class="profile-name-block">
          <div class="profile-title-line"><h1>${profileUser.name}</h1><span class="verified-badge">${isPlus ? "Plus" : "Verificado"}</span></div>
          <p>@${profileUser.username} · ${profileUser.country || "Chile 🇨🇱"}</p>
          <p class="profile-bio-line">${profileUser.bio || profileUser.phrase || "Fan K-pop en HallyuHub."}</p>
          <div class="fandom-line"><span>${profileUser.fandom || "ARMY 💜"}</span><span>Bias: ${profileUser.bias || "Jungkook"}</span></div>
          <div class="fandom-line"><span>${profileUser.favoriteGroup || "BTS"}</span><span>${profileUser.fandomLevel || "Level 18 Fandom"}</span></div>
        </div>
      </div>
      <div class="premium-stats">
        <div><strong>${profileUser.posts}</strong><span>posts</span></div>
        <div><strong>${profileUser.followers}</strong><span>seguidores</span></div>
        <div><strong>${profileUser.following}</strong><span>siguiendo</span></div>
        <div><strong>${profileUser.starsReceived || "32.8K"}</strong><span>estrellas</span></div>
      </div>
      <div class="profile-progress-card">
        <div>
          <span>Level ${progress.level}</span>
          <strong>${avatarMeta.rarity} · ${avatarMeta.name}</strong>
          <small>${progress.stars.toLocaleString("es")} estrellas acumuladas</small>
        </div>
        <div class="progress-ring" style="--progress:${progress.percent}%"><span></span></div>
      </div>
      <div class="premium-profile-actions ${isOwnProfile ? "own-actions" : "other-actions"}">
        ${
          isOwnProfile
            ? `<button class="primary-button profile-main-action" data-profile-edit-open>Editar perfil</button>`
            : `<button class="primary-button profile-main-action" data-profile-follow="${profileUser.id || profileUser.username}">${isFollowing ? "Siguiendo" : "Seguir"}</button>
               <button class="ghost-button profile-share-action">Compartir perfil</button>`
        }
      </div>
    </section>
    <section class="highlight-row">
      ${profileHighlights
        .map(
          (item, index) => `
          <button>
            <span class="highlight-orb" style="--art:${art[index % art.length]}"></span>
            <strong>${item}</strong>
          </button>`,
        )
        .join("")}
    </section>
    <section class="profile-panel slim-panel">
      <div class="profile-tabs">
        ${profileTabs
          .map(([key, label]) => `<button class="${state.profileTab === key ? "active" : ""}" data-profile-tab="${key}">${label}</button>`)
          .join("")}
      </div>
      <div class="profile-feed-list">
        ${renderProfileFeed(activeTab[0], profileUser)}
      </div>
    </section>
  `;
}

function renderProfileEditor() {
  const activeAvatar = avatars.find((avatar) => avatar.id === (state.selectedAvatar || state.user.avatar)) || avatars[0];
  const progress = getFanProgress();
  return `
    <section class="profile-editor-card">
      <button class="ghost-button back-button" data-profile-edit-close>Volver al perfil</button>
      <div class="profile-edit-cover" style="--profile-bg:${getProfileBackground(state.selectedProfileBg || state.user.profileBg).art}">
        ${renderAvatarElement(`profile-avatar premium-avatar edit-avatar ${getRarityClass(activeAvatar)}`, state.selectedAvatar || state.user.avatar, state.user.avatarUrl)}
        <div>
          <p class="eyebrow">Editar perfil</p>
          <h2>Tu identidad HallyuHub</h2>
          <p class="muted">Solo datos visibles en tu perfil. Cuenta, privacidad y legal quedan en Ajustes.</p>
        </div>
      </div>
      <section class="unlock-summary">
        <div><strong>Level ${progress.level}</strong><span>${progress.stars.toLocaleString("es")} estrellas</span></div>
        <div><strong>${avatars.filter((avatar) => isUnlocked(avatar)).length}/${avatars.length}</strong><span>avatares</span></div>
        <div><strong>${profileBackgrounds.filter((bg) => isUnlocked(bg)).length}/${profileBackgrounds.length}</strong><span>fondos</span></div>
      </section>
      <div class="form-stack profile-edit-form">
        <label>Cambiar foto real<input id="profile-edit-avatar-file" type="file" accept="image/*" /></label>
        <label>Nombre visible<input id="profile-edit-name" value="${state.user.name}" /></label>
        <label>Nombre de usuario<input id="profile-edit-username" value="${state.user.username}" /></label>
        <label>Bio / descripción<textarea id="profile-edit-bio">${state.user.bio}</textarea></label>
        <label>Grupos favoritos<input id="profile-edit-groups" value="${state.user.favoriteGroup || ""}" placeholder="BTS, Stray Kids, BLACKPINK" /></label>
        <label>Redes sociales<input id="profile-edit-socials" value="${state.user.socials || ""}" placeholder="Instagram, TikTok, YouTube..." /></label>
      </div>
      <div class="section-heading small"><h2>Avatares desbloqueables</h2><span>${activeAvatar.rarity}</span></div>
      <div class="avatar-picker compact-picker">
        ${avatars
          .map((avatar) => {
            const unlocked = isUnlocked(avatar);
            return `
            <button class="avatar-choice ${(state.selectedAvatar || state.user.avatar) === avatar.id ? "active" : ""} ${unlocked ? "" : "locked"} ${getRarityClass(avatar)}" ${unlocked ? `data-avatar="${avatar.id}"` : "disabled"}>
              <div class="plush-avatar pick" style="--avatar:${avatar.gradient}"><span></span></div>
              <strong>${avatar.name}</strong>
              <small class="rarity-chip">${avatar.rarity}</small>
              <em>${unlocked ? avatar.reward : `Nivel ${avatar.minLevel}`}</em>
            </button>`;
          })
          .join("")}
      </div>
      <div class="section-heading small"><h2>Cómo desbloquear más</h2><span>Actividad</span></div>
      <div class="reward-grid">
        ${profileRewards.map(([action, points, detail]) => `<article><strong>${action}</strong><span>${points}</span><small>${detail}</small></article>`).join("")}
      </div>
      <div class="section-heading small"><h2>Cambiar portada / fondo</h2><span>Perfil</span></div>
      ${renderProfileBackgroundPicker()}
      <button class="primary-button" data-save-profile-edit>Guardar cambios</button>
    </section>
  `;
}

function renderProfileFeed(tab, profileUser) {
  const ownUser = !state.viewedProfile || profileUser.username === state.user.username;
  const localPosts = ownUser ? userPosts.filter((post) => (post.category || "posts") === tab) : [];
  const posts = localPosts.length ? localPosts : getProfileDemoPosts(tab, profileUser);
  return posts.map((post, index) => renderSocialPost(post, index, { compact: true })).join("");
}

function getProfileDemoPosts(tab, profileUser) {
  const common = {
    user: profileUser.name,
    badge: profileUser.fandom || "Army 💜",
    online: true,
    likes: "1.2K",
    comments: "86",
  };
  const sets = {
    posts: [
      { ...common, id: "profile-post-1", category: "posts", group: "Publicacion", time: "hace 20 min", caption: "Nuevo moodboard para el comeback y playlist lista para estudiar.", hashtags: ["#comeback", "#HallyuHub"], location: profileUser.country || "" },
      { ...common, id: "profile-post-2", category: "posts", group: "Publicacion", time: "ayer", caption: "Fotos del encuentro fandom con luces pastel y photocards protegidas.", hashtags: ["#KpopLatam", "#fandom"] },
    ],
    trends: [
      { ...common, id: "profile-trend-1", category: "trends", group: "Trend", time: "hace 1 h", caption: "Paso corto para un random play dance con transicion de luz neon.", hashtags: ["#DanceChallenge", "#TrendKpop"], taggedPeople: "@mika, @vale" },
      { ...common, id: "profile-trend-2", category: "trends", group: "Trend", time: "hace 3 h", caption: "Mini cover inspirado en stage idol, pensado para grabar vertical.", hashtags: ["#cover", "#fancam"] },
    ],
    outfits: [
      { ...common, id: "profile-outfit-1", category: "outfits", group: "Outfit", time: "hoy", caption: "Look pastel/neon para evento K-pop: denim, brillos suaves y accesorios cute.", hashtags: ["#outfit", "#KpopStyle"], location: "Evento fandom" },
      { ...common, id: "profile-outfit-2", category: "outfits", group: "Outfit", time: "domingo", caption: "Inspiracion comeback con lazo, gloss y colores fandom.", hashtags: ["#CuteConcept", "#comeback"] },
    ],
    photocards: [
      { ...common, id: "profile-card-1", category: "photocards", group: "Photocard", time: "hace 2 dias", caption: "Nueva carpeta de photocards con sleeves holograficos.", hashtags: ["#photocard", "#tradeSeguro"], taggedPlace: "Trade meet" },
      { ...common, id: "profile-card-2", category: "photocards", group: "Photocard", time: "esta semana", caption: "Wishlist actualizada para futuros intercambios.", hashtags: ["#wishlist", "#collector"] },
    ],
    saved: [
      { ...common, id: "profile-saved-1", category: "saved", group: "Guardado", time: "guardado hoy", caption: "Guia de comeback para votar, streamear y seguir horarios.", hashtags: ["#guia", "#Kpop101"] },
      { ...common, id: "profile-saved-2", category: "saved", group: "Guardado", time: "guardado ayer", caption: "Lista de eventos seguros por ciudad y comunidades verificadas.", hashtags: ["#eventos", "#Latam"] },
    ],
    favorites: [
      { ...common, id: "profile-fav-1", category: "favorites", group: "Favorito", time: "top semanal", caption: `${profileUser.favoriteGroup || "BTS"} sigue primero en mi ranking fandom personal.`, hashtags: ["#favoritos", "#bias"] },
      { ...common, id: "profile-fav-2", category: "favorites", group: "Favorito", time: "top mensual", caption: "Stages, fancams y momentos que quiero volver a ver.", hashtags: ["#fancam", "#idol"] },
    ],
  };
  return sets[tab] || sets.posts;
}

document.querySelectorAll(".nav-item").forEach((button) => {
  button.addEventListener("click", () => {
    if (button.dataset.view === "profile") {
      state.viewedProfile = null;
      state.profileEditorOpen = false;
    }
    setView(button.dataset.view);
  });
});

document.querySelectorAll("[data-go-view]").forEach((button) => {
  button.addEventListener("click", () => setView(button.dataset.goView));
});

initApp();
