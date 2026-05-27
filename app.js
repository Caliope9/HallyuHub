const state = {
  view: "home",
  communityTab: "global",
  selectedAvatar: "berry",
  ambience: "hallyu",
  selectedGroup: "skz",
  groupSearch: "",
  groupFilter: "all",
  selectedArtist: null,
  fanContentFilter: "recent",
  activityTab: "activity",
  profileTab: "posts",
  profileEditorOpen: false,
  profileAvatarPreviewUrl: "",
  settingsAvatarPreviewUrl: "",
  homeFilter: "all",
  selectedHashtag: null,
  hashtagSort: "recent",
  expandedPosts: {},
  openPostMenu: null,
  reportTarget: null,
  mediaEmbed: null,
  hiddenPosts: {},
  hiddenFanContent: {},
  mutedUsers: {},
  socialReports: [],
  toast: null,
  openComments: {},
  commentDrafts: {},
  replyTo: {},
  likedComments: {},
  likedPosts: {},
  savedPosts: {},
  sharedPosts: {},
  sharePostTarget: null,
  settingsPanel: null,
  viewedProfile: null,
  followedProfiles: {},
  dropFeedFilter: "popular",
  dropSearchOpen: false,
  dropSearchQuery: "",
  dropSearchSelection: "",
  dropCreatorOpen: false,
  dropEffect: "kpop-stage",
  dropFollowed: {},
  dropLiked: {},
  dropSaved: {},
  dropCommentsOpen: {},
  dropVideoComments: {},
  dropShareOpen: {},
  dropMusicOpen: {},
  dropPaused: {},
  dropFeedback: {},
  videoProfileOverlay: null,
  videoFullscreen: null,
  videoMuted: true,
  videoCommentDrafts: {},
  videoCommentReplyTo: {},
  videoCommentLikes: {},
  soundEnabled: true,
  permissionPrompt: null,
  fancamGroupFilter: "all",
  fancamArtistFilter: "all",
  fancamSort: "recommended",
  fancamSearchQuery: "",
  fancamFilterOpen: false,
  likedFancams: {},
  savedFancams: {},
  followedArtists: {},
  fancamCommentsOpen: {},
  fancamVideoComments: {},
  fancamShareOpen: {},
  fancamMusicOpen: {},
  fancamPaused: {},
  fancamFeedback: {},
  fancamCreatorOpen: false,
  videoEditorDraft: {
    kind: "trends",
    mediaUrl: "",
    mediaType: "",
    mediaName: "",
    coverUrl: "",
    coverName: "",
    description: "",
    hashtags: "",
    music: "",
    group: "",
    artist: "",
    show: "",
    city: "",
    eventDate: "",
    location: "",
    start: "0",
    end: "60",
    duration: "60",
    muted: false,
    soundOn: true,
    overlayText: "",
    sticker: "✨",
    filter: "original",
    privacy: "Seguidores",
    allowComments: true,
    rightsConfirmed: false,
    vertical: true,
    loading: false,
    error: "",
    result: null,
  },
  publishDraft: {
    type: "posts",
    mediaUrl: "",
    mediaType: "",
    mediaName: "",
    caption: "",
    hashtags: "",
    taggedPeople: "",
    taggedGroup: "",
    taggedArtist: "",
    taggedShow: "",
    city: "",
    eventDate: "",
    location: "",
    taggedPlace: "",
    audio: "",
    privacy: "Seguidores",
    allowComments: true,
    rightsConfirmed: false,
    filter: "original",
    result: null,
  },
  selectedProfileBg: "army",
  activeStory: null,
  likedStories: {},
  viewedStories: {},
  storyPaused: false,
  storyDirection: 1,
  activeOwnStoryIndex: 0,
  storyComposerOpen: false,
  storyMusicInfoOpen: false,
  storyEditorOpen: false,
  storyToolPanel: null,
  storyDraft: {
    type: "text",
    text: "",
    sticker: "✨",
    elements: [{ id: "sticker-1", type: "sticker", content: "✨", x: 72, y: 18, size: 38, rotation: 0 }],
    selectedElementId: "sticker-1",
    mention: "",
    location: "",
    music: "Basic beat · safe loop",
    musicCategory: "Viral",
    background: "Neon pastel",
    mediaName: "",
    mediaUrl: "",
    mediaType: "",
    mediaScale: 1,
    mediaX: 0,
    mediaY: 0,
    mediaRotation: 0,
    font: "Inter",
    textColor: "#ffffff",
    textStyle: "glow",
    stickerCategory: "Cute",
  },
  ownStoryStatsOpen: false,
  ownStory: null,
  ownStories: [],
  storyArchive: [],
  storyInbox: [],
  authMode: "start",
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
let swipeStart = null;
let swipeSuppressClickUntil = 0;

const swipeNavigationViews = ["home", "search", "trends", "fancams", "profile"];

const titleByView = {
  home: "Tu universo K-pop latino",
  search: "Buscar",
  trends: "Drops",
  fancams: "Fancams",
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

const storageService = {
  get: (key, fallback) => storage.get(key, fallback),
  set: (key, value) => storage.set(key, value),
  remove: (key) => storage.remove(key),
};

function createLocalUserId(email = "", username = "") {
  const seed = normalizeProfileKey(email || username || `fan-${Date.now()}`);
  return `local-${seed || Date.now()}`;
}

function ensureUserShape(user = {}) {
  const createdAt = user.createdAt || new Date().toISOString();
  const email = user.email || defaultUser.email;
  const username = user.username || defaultUser.username;
  const favoriteGroup = user.favoriteGroup || defaultUser.favoriteGroup;
  const fandom = user.fandom || defaultUser.fandom;
  return {
    ...defaultUser,
    ...user,
    id: user.id || createLocalUserId(email, username),
    email,
    username,
    name: user.name || defaultUser.name,
    avatarUrl: user.avatarUrl || defaultUser.avatarUrl || getDemoUserImage(0),
    bio: user.bio || defaultUser.bio,
    country: user.country || defaultUser.country,
    fandom,
    favoriteGroup,
    favoriteFandoms: Array.isArray(user.favoriteFandoms) ? user.favoriteFandoms : [fandom].filter(Boolean),
    favoriteGroups: Array.isArray(user.favoriteGroups) ? user.favoriteGroups : [favoriteGroup].filter(Boolean),
    createdAt,
  };
}

const userService = {
  getUsers() {
    const users = storageService.get("users", []);
    if (Array.isArray(users) && users.length) return users.map(ensureUserShape);
    const legacyUser = storageService.get("hallyuHubUser", null);
    const seededUser = ensureUserShape(legacyUser || defaultUser);
    this.saveUsers([seededUser]);
    return [seededUser];
  },
  saveUsers(users) {
    storageService.set("users", users.map(ensureUserShape));
  },
  findByLogin(login = "") {
    const normalized = String(login).trim().toLowerCase();
    return this.getUsers().find((user) => user.email.toLowerCase() === normalized || user.username.toLowerCase() === normalized);
  },
  createUser(payload) {
    const users = this.getUsers();
    const email = String(payload.email || "").trim().toLowerCase();
    const username = String(payload.username || "").trim();
    if (users.some((user) => user.email.toLowerCase() === email || user.username.toLowerCase() === username.toLowerCase())) {
      throw new Error("Ya existe una cuenta con ese email o usuario.");
    }
    const user = ensureUserShape({
      ...payload,
      email,
      username,
      id: createLocalUserId(email, username),
      createdAt: new Date().toISOString(),
      onboarded: false,
    });
    this.saveUsers([user, ...users]);
    return user;
  },
  saveCurrentUser(user) {
    const current = ensureUserShape(user);
    const users = this.getUsers();
    const nextUsers = users.some((item) => item.id === current.id)
      ? users.map((item) => (item.id === current.id ? current : item))
      : [current, ...users];
    this.saveUsers(nextUsers);
    storageService.set("currentUser", current);
    storageService.set("hallyuHubUser", current);
    return current;
  },
  updateCurrentUserAvatar(avatarUrl) {
    if (!avatarUrl) return this.getCurrentUser();
    const current = this.getCurrentUser();
    if (!current) return null;
    return this.saveCurrentUser({ ...current, avatarUrl });
  },
  getCurrentUser() {
    const current = storageService.get("currentUser", null) || storageService.get("hallyuHubUser", null);
    return current ? ensureUserShape(current) : null;
  },
};

const authService = {
  getSession() {
    const isLoggedIn = Boolean(storageService.get("isLoggedIn", false) || storageService.get("hallyuHubSession", false));
    const currentUser = userService.getCurrentUser();
    if (!isLoggedIn || !currentUser) return null;
    const sessionCreatedAt = storageService.get("sessionCreatedAt", new Date().toISOString());
    storageService.set("currentUser", currentUser);
    storageService.set("isLoggedIn", true);
    storageService.set("sessionCreatedAt", sessionCreatedAt);
    return {
      user: currentUser,
      sessionCreatedAt,
    };
  },
  createSession(user) {
    const currentUser = userService.saveCurrentUser(user);
    const sessionCreatedAt = new Date().toISOString();
    storageService.set("currentUser", currentUser);
    storageService.set("isLoggedIn", true);
    storageService.set("sessionCreatedAt", sessionCreatedAt);
    storageService.set("hallyuHubSession", true);
    return { user: currentUser, sessionCreatedAt };
  },
  register(payload) {
    const user = userService.createUser(payload);
    return this.createSession(user);
  },
  login(login, password) {
    const user = userService.findByLogin(login);
    if (!user) throw new Error("No encontramos una cuenta con esos datos.");
    if (user.password && password && user.password !== password) throw new Error("La contraseña no coincide.");
    return this.createSession(user);
  },
  logout() {
    storageService.remove("currentUser");
    storageService.remove("isLoggedIn");
    storageService.remove("sessionCreatedAt");
    storageService.remove("hallyuHubSession");
  },
};

const defaultUser = {
  id: "local-lunahallyu",
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
  favoriteFandoms: ["ARMY 💜", "Stay ⭐"],
  favoriteGroups: ["BTS", "Stray Kids"],
  createdAt: "2026-05-15T00:00:00.000Z",
};

const futureBackend = {
  provider: "Supabase Auth + Postgres + Storage",
  next: "Firebase o Supabase",
  collections: ["users", "sessions", "profiles", "posts", "groups", "followers", "messages", "notifications"],
  services: ["authService", "userService", "storageService"],
  mobileReady: ["PWA", "responsive", "permissions on demand", "Expo/React Native wrapper"],
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
    title: "BLACKPINK impulsa nuevo Drop de dance challenge",
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
const PERMISSION_PROMPT_INTERVAL_MS = 30 * 24 * 60 * 60 * 1000;
const newsArtists = ["BTS", "BLACKPINK", "Stray Kids", "NewJeans", "TWICE", "SEVENTEEN", "ATEEZ", "IVE", "TXT"];
const demoAssetCounts = {
  users: 20,
  posts: 15,
  stories: 10,
};

const DEMO_USER_IMAGES = [
  "https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=640&q=80",
  "https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=640&q=80",
  "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=640&q=80",
  "https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=640&q=80",
  "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=640&q=80",
  "https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?auto=format&fit=crop&w=640&q=80",
  "https://images.unsplash.com/photo-1527980965255-d3b416303d12?auto=format&fit=crop&w=640&q=80",
  "https://images.unsplash.com/photo-1531123897727-8f129e1688ce?auto=format&fit=crop&w=640&q=80",
  "https://images.unsplash.com/photo-1519345182560-3f2917c472ef?auto=format&fit=crop&w=640&q=80",
  "https://images.unsplash.com/photo-1520813792240-56fc4a3765a7?auto=format&fit=crop&w=640&q=80",
];

const DEMO_POST_IMAGES = [
  "https://images.unsplash.com/photo-1517154421773-0529f29ea451?auto=format&fit=crop&w=1200&q=80",
  "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=80",
  "https://images.unsplash.com/photo-1526948128573-703ee1aeb6fa?auto=format&fit=crop&w=1200&q=80",
  "https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?auto=format&fit=crop&w=1200&q=80",
  "https://images.unsplash.com/photo-1540039155733-5bb30b53aa14?auto=format&fit=crop&w=1200&q=80",
  "https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&w=1200&q=80",
  "https://images.pexels.com/photos/2113566/pexels-photo-2113566.jpeg?auto=compress&cs=tinysrgb&w=1200",
  "https://images.pexels.com/photos/1858175/pexels-photo-1858175.jpeg?auto=compress&cs=tinysrgb&w=1200",
  "https://images.pexels.com/photos/1640777/pexels-photo-1640777.jpeg?auto=compress&cs=tinysrgb&w=1200",
  "https://images.pexels.com/photos/1763075/pexels-photo-1763075.jpeg?auto=compress&cs=tinysrgb&w=1200",
  "https://images.pexels.com/photos/3735641/pexels-photo-3735641.jpeg?auto=compress&cs=tinysrgb&w=1200",
  "https://images.pexels.com/photos/3777943/pexels-photo-3777943.jpeg?auto=compress&cs=tinysrgb&w=1200",
  "https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?auto=format&fit=crop&w=1200&q=80",
  "https://images.unsplash.com/photo-1522202176988-66273c2fd55f?auto=format&fit=crop&w=1200&q=80",
  "https://images.unsplash.com/photo-1521334884684-d80222895322?auto=format&fit=crop&w=1200&q=80",
];

const DEMO_STORY_IMAGES = [
  "https://images.unsplash.com/photo-1501386761578-eac5c94b800a?auto=format&fit=crop&w=900&q=80",
  "https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=900&q=80",
  "https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&w=900&q=80",
  "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=900&q=80",
  "https://images.unsplash.com/photo-1526948128573-703ee1aeb6fa?auto=format&fit=crop&w=900&q=80",
  "https://images.pexels.com/photos/2113566/pexels-photo-2113566.jpeg?auto=compress&cs=tinysrgb&w=900",
  "https://images.pexels.com/photos/1763075/pexels-photo-1763075.jpeg?auto=compress&cs=tinysrgb&w=900",
  "https://images.pexels.com/photos/1858175/pexels-photo-1858175.jpeg?auto=compress&cs=tinysrgb&w=900",
  "https://images.pexels.com/photos/3777943/pexels-photo-3777943.jpeg?auto=compress&cs=tinysrgb&w=900",
  "https://images.unsplash.com/photo-1517154421773-0529f29ea451?auto=format&fit=crop&w=900&q=80",
];

const DEMO_DROP_MEDIA = [
  "https://images.unsplash.com/photo-1501386761578-eac5c94b800a?auto=format&fit=crop&w=1080&q=80",
  "https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=1080&q=80",
  "https://images.unsplash.com/photo-1540039155733-5bb30b53aa14?auto=format&fit=crop&w=1080&q=80",
  "https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&w=1080&q=80",
  "https://images.pexels.com/photos/1763075/pexels-photo-1763075.jpeg?auto=compress&cs=tinysrgb&w=1080",
  "https://images.pexels.com/photos/2113566/pexels-photo-2113566.jpeg?auto=compress&cs=tinysrgb&w=1080",
  "https://images.pexels.com/photos/1858175/pexels-photo-1858175.jpeg?auto=compress&cs=tinysrgb&w=1080",
  "https://images.pexels.com/photos/3735641/pexels-photo-3735641.jpeg?auto=compress&cs=tinysrgb&w=1080",
];

// Demo users are fictional and generated for prototype visualization.
const DEMO_USERS = [
  { id: "demo-luna", name: "Luna Rivas", username: "luna.hallyu", city: "Santiago", country: "Chile 🇨🇱", fandom: "Stay ⭐", favoriteGroup: "Stray Kids", bio: "Creadora de playlists, comeback nights y trades seguros.", level: 18, starsReceived: "32.8K", posts: "48", followers: "8.7K", following: "412", colors: ["#fbbcdb", "#65e4ff"], accent: "#fbbcdb" },
  { id: "demo-cami", name: "Camila Seo", username: "cami.stay", city: "Buenos Aires", country: "Argentina 🇦🇷", fandom: "Blink 🖤💖", favoriteGroup: "BLACKPINK", bio: "Outfits, random dance y photocards en Palermo.", level: 14, starsReceived: "18.6K", posts: "36", followers: "5.2K", following: "330", colors: ["#ff3ea5", "#111827"], accent: "#ff8ac8" },
  { id: "demo-mika", name: "Mika Torres", username: "mika.army", city: "Montevideo", country: "Uruguay 🇺🇾", fandom: "Army 💜", favoriteGroup: "BTS", bio: "Fan edits, lives y guías para ARMY Latam.", level: 21, starsReceived: "41.1K", posts: "64", followers: "12.4K", following: "520", colors: ["#8b5cf6", "#d9b4ff"], accent: "#a855f7" },
  { id: "demo-vale", name: "Valentina Park", username: "vale.multi", city: "Lima", country: "Perú 🇵🇪", fandom: "Tokki 🐰", favoriteGroup: "NewJeans", bio: "K-pop 101, moodboards y cute concepts.", level: 16, starsReceived: "24.9K", posts: "42", followers: "6.8K", following: "294", colors: ["#77f4c7", "#65e4ff"], accent: "#77f4c7" },
  { id: "demo-nico", name: "Nico Kim", username: "nico.trades", city: "Córdoba", country: "Argentina 🇦🇷", fandom: "Once 🍭", favoriteGroup: "TWICE", bio: "Trades con referencias, álbumes y sleeves.", level: 12, starsReceived: "11.3K", posts: "29", followers: "3.1K", following: "188", colors: ["#ffd166", "#ff8ac8"], accent: "#ffd166" },
  { id: "demo-sofi", name: "Sofi Moon", username: "sofi.tokki", city: "Santiago", country: "Chile 🇨🇱", fandom: "Tokki 🐰", favoriteGroup: "NewJeans", bio: "Y2K, fancams suaves y outfits pastel.", level: 15, starsReceived: "19.2K", posts: "34", followers: "4.6K", following: "260", colors: ["#65e4ff", "#fbbcdb"], accent: "#65e4ff" },
  { id: "demo-agus", name: "Agus Han", username: "agus.random", city: "Buenos Aires", country: "Argentina 🇦🇷", fandom: "Stay ⭐", favoriteGroup: "Stray Kids", bio: "Organizo random play dance y cover crews.", level: 17, starsReceived: "26.4K", posts: "51", followers: "7.9K", following: "402", colors: ["#ff2d55", "#ffb703"], accent: "#ff2d55" },
  { id: "demo-renata", name: "Renata Vega", username: "ren.fancam", city: "CDMX", country: "México 🇲🇽", fandom: "DIVE 💎", favoriteGroup: "IVE", bio: "Fancams, visual boards y stage edits.", level: 13, starsReceived: "14.7K", posts: "31", followers: "3.9K", following: "216", colors: ["#fff1f9", "#8b5cf6"], accent: "#fbbcdb" },
  { id: "demo-juli", name: "Julieta Min", username: "juli.cards", city: "Rosario", country: "Argentina 🇦🇷", fandom: "CARAT 💎", favoriteGroup: "SEVENTEEN", bio: "Colección de photocards y wishlist semanal.", level: 19, starsReceived: "33.4K", posts: "57", followers: "9.1K", following: "440", colors: ["#f7cadf", "#9ad7ff"], accent: "#9ad7ff" },
  { id: "demo-emi", name: "Emi Sol", username: "emi.blink", city: "Medellín", country: "Colombia 🇨🇴", fandom: "Blink 🖤💖", favoriteGroup: "BLACKPINK", bio: "Fashion fandom, dance breaks y covers.", level: 11, starsReceived: "9.8K", posts: "25", followers: "2.7K", following: "172", colors: ["#ff8ac8", "#09060a"], accent: "#ff8ac8" },
  { id: "demo-dani", name: "Dani Lee", username: "dani.cover", city: "Bogotá", country: "Colombia 🇨🇴", fandom: "ATINY 🏴", favoriteGroup: "ATEEZ", bio: "Cover dance, stage energy y eventos.", level: 15, starsReceived: "17.5K", posts: "38", followers: "4.8K", following: "256", colors: ["#ffb703", "#111827"], accent: "#ffb703" },
  { id: "demo-martu", name: "Martina Kwon", username: "martu.once", city: "Córdoba", country: "Argentina 🇦🇷", fandom: "Once 🍭", favoriteGroup: "TWICE", bio: "Comebacks cute, álbumes y meetups.", level: 10, starsReceived: "8.4K", posts: "21", followers: "2.2K", following: "140", colors: ["#ff8ac8", "#ffd166"], accent: "#ffd166" },
  { id: "demo-ara", name: "Ara Chen", username: "ara.aespa", city: "Quito", country: "Ecuador 🇪🇨", fandom: "MY ✨", favoriteGroup: "aespa", bio: "Cyber Seoul, edits futuristas y lore.", level: 18, starsReceived: "28.1K", posts: "44", followers: "6.3K", following: "300", colors: ["#65e4ff", "#d946ef"], accent: "#65e4ff" },
  { id: "demo-thiago", name: "Thiago Baek", username: "thiago.atiny", city: "Montevideo", country: "Uruguay 🇺🇾", fandom: "ATINY 🏴", favoriteGroup: "ATEEZ", bio: "Lightsticks, stages y fan chants.", level: 12, starsReceived: "12.6K", posts: "28", followers: "3.4K", following: "220", colors: ["#ffb703", "#ff2d55"], accent: "#ffb703" },
  { id: "demo-noa", name: "Noa Rivera", username: "noa.carat", city: "Asunción", country: "Paraguay 🇵🇾", fandom: "CARAT 💎", favoriteGroup: "SEVENTEEN", bio: "Unit songs, fanart y rankings fandom.", level: 13, starsReceived: "13.9K", posts: "30", followers: "3.7K", following: "198", colors: ["#f7cadf", "#65e4ff"], accent: "#f7cadf" },
  { id: "demo-isa", name: "Isabella Ryu", username: "isa.dive", city: "Lima", country: "Perú 🇵🇪", fandom: "DIVE 💎", favoriteGroup: "IVE", bio: "Outfits elegantes y fancam mode.", level: 14, starsReceived: "16.2K", posts: "33", followers: "4.1K", following: "230", colors: ["#fff1f9", "#ff8ac8"], accent: "#ff8ac8" },
  { id: "demo-mateo", name: "Mateo Song", username: "mateo.lightstick", city: "Santiago", country: "Chile 🇨🇱", fandom: "ENGENE", favoriteGroup: "ENHYPEN", bio: "Reviews de lightsticks y conciertos.", level: 9, starsReceived: "7.1K", posts: "18", followers: "1.9K", following: "122", colors: ["#a855f7", "#65e4ff"], accent: "#a855f7" },
  { id: "demo-flor", name: "Flor Kim", username: "flor.fanart", city: "La Plata", country: "Argentina 🇦🇷", fandom: "FEARNOT", favoriteGroup: "LE SSERAFIM", bio: "Fanart, comeback posters y cute drops.", level: 15, starsReceived: "20.7K", posts: "40", followers: "5.5K", following: "310", colors: ["#f8fafc", "#ff8ac8"], accent: "#ff8ac8" },
  { id: "demo-zoe", name: "Zoe Choi", username: "zoe.comeback", city: "Valparaíso", country: "Chile 🇨🇱", fandom: "BRIIZE", favoriteGroup: "RIIZE", bio: "Noticias, comeback tracker y playlists.", level: 11, starsReceived: "10.5K", posts: "24", followers: "2.8K", following: "176", colors: ["#ffb703", "#65e4ff"], accent: "#65e4ff" },
  { id: "demo-bruno", name: "Bruno Park", username: "bruno.album", city: "Mendoza", country: "Argentina 🇦🇷", fandom: "Treasure Maker", favoriteGroup: "TREASURE", bio: "Unboxings, álbumes y compras grupales.", level: 10, starsReceived: "8.9K", posts: "20", followers: "2.4K", following: "150", colors: ["#2563eb", "#65e4ff"], accent: "#2563eb" },
].slice(0, 10).map((user, index) => ({
  ...user,
  avatarUrl: getDemoUserImage(index),
  imageUrl: getDemoUserImage(index),
  coverUrl: getDemoPostImage(index),
  mediaUrl: getDemoStoryImage(index),
  profileBg: index % 2 ? "stage" : "pastel",
}));

const demoUsers = DEMO_USERS;

const DEMO_POSTS = [
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
    commentList: [
      { id: "c1", user: "Cami.STAY", username: "cami", avatar: "star", time: "2m", body: "Ese setup quedó precioso 💜", likes: 18, replies: [{ id: "c1r1", user: "Luna Hallyu", username: "lunahallyu", avatar: "berry", time: "1m", body: "@cami gracias, falta el lightstick ✨", likes: 6 }] },
      { id: "c2", user: "Mika", username: "mika", avatar: "mochi", time: "8m", body: "Playlist obligatoria para comeback 🔥", likes: 31, replies: [] },
    ],
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
    commentList: [
      { id: "c3", user: "Nico K", username: "nico", avatar: "cyber", time: "12m", body: "¿Aceptan trade por correo?", likes: 9, replies: [] },
    ],
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
    commentList: [
      { id: "c4", user: "Vale Multi", username: "vale", avatar: "anime", time: "1h", body: "@lunahallyu esta guía sirve mucho para fans nuevos", likes: 44, replies: [] },
    ],
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
    commentList: [
      { id: "c5", user: "Dance Crew", username: "dancecrew", avatar: "neon", time: "5m", body: "El paso final está adictivo 🪩", likes: 102, replies: [] },
    ],
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
    commentList: [
      { id: "c6", user: "ARMY Chile", username: "armychile", avatar: "idol", time: "20m", body: "Vamos a armar zona segura para trades", likes: 88, replies: [] },
    ],
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
    commentList: [
      { id: "c7", user: "Style K-pop", username: "stylekpop", avatar: "anime", time: "35m", body: "El lazo cute concept quedó perfecto 🎀", likes: 26, replies: [] },
    ],
    taggedPeople: "@style.kpop",
    shares: "110",
    saves: "740",
  },
  {
    id: "demo-post-7",
    user: "Renata Vega",
    group: "Fancam",
    category: "posts",
    type: "popular",
    time: "hace 2 h",
    badge: "DIVE 💎",
    online: true,
    hashtags: ["#IVE", "#fancam", "#DIVE"],
    caption: "Armé un moodboard de fancams para estudiar luces, poses y cámara vertical.",
    likes: "2.1K",
    comments: "86",
    commentList: [],
    location: "CDMX",
    shares: "76",
    saves: "410",
  },
  {
    id: "demo-post-8",
    user: "Julieta Min",
    group: "Photocard",
    category: "photocards",
    type: "trade",
    time: "hace 3 h",
    badge: "CARAT 💎",
    online: false,
    hashtags: ["#photocard", "#collector", "#CARAT"],
    caption: "Nueva carpeta con sleeves holográficos, separadores por era y wishlist ordenada.",
    likes: "1.8K",
    comments: "73",
    commentList: [],
    shares: "58",
    saves: "390",
  },
  {
    id: "demo-post-9",
    user: "Emi Sol",
    group: "Outfit",
    category: "outfits",
    type: "outfit",
    time: "hace 4 h",
    badge: "Blink 🖤💖",
    online: true,
    hashtags: ["#BLACKPINK", "#KpopOutfit", "#Blink"],
    caption: "Look black-pink para random dance: brillo suave, botas y detalle cute.",
    likes: "3.7K",
    comments: "120",
    commentList: [],
    location: "Medellín",
    shares: "140",
    saves: "820",
  },
  {
    id: "demo-post-10",
    user: "Ara Chen",
    group: "Fanart",
    category: "posts",
    type: "popular",
    time: "hace 5 h",
    badge: "MY ✨",
    online: true,
    hashtags: ["#aespa", "#CyberSeoul", "#fanart"],
    caption: "Edit cyber Seoul con neón azul, tipografía futurista y energía de stage.",
    likes: "2.9K",
    comments: "98",
    commentList: [],
    shares: "118",
    saves: "605",
  },
  {
    id: "demo-post-11",
    user: "Mateo Song",
    group: "Evento fandom",
    category: "posts",
    type: "event",
    time: "hace 6 h",
    badge: "ENGENE",
    online: false,
    hashtags: ["#ENHYPEN", "#lightstick", "#ENGENE"],
    caption: "Probé batería, funda y modo concierto del lightstick antes del evento.",
    likes: "1.3K",
    comments: "51",
    commentList: [],
    location: "Santiago, Chile",
    shares: "39",
    saves: "260",
  },
  {
    id: "demo-post-12",
    user: "Bruno Park",
    group: "Album",
    category: "posts",
    type: "popular",
    time: "hace 7 h",
    badge: "Treasure Maker",
    online: true,
    hashtags: ["#album", "#unboxing", "#KpopLatam"],
    caption: "Llegó el álbum y el photobook se ve increíble. Dejo mini review para quienes dudan.",
    likes: "980",
    comments: "44",
    commentList: [],
    shares: "32",
    saves: "180",
  },
  {
    id: "demo-post-13",
    user: "Sofi Moon",
    group: "Café fandom",
    category: "posts",
    type: "event",
    time: "hace 8 h",
    badge: "Tokki 🐰",
    online: true,
    hashtags: ["#cafe", "#KpopLatam", "#Tokki"],
    caption: "Café temático con playlist suave, stickers y photospot pastel.",
    likes: "2.5K",
    comments: "89",
    commentList: [],
    location: "Santiago, Chile",
    shares: "101",
    saves: "510",
  },
  {
    id: "demo-post-14",
    user: "Agus Han",
    group: "Random dance",
    category: "trends",
    type: "trending",
    time: "hace 9 h",
    badge: "Stay ⭐",
    online: true,
    hashtags: ["#RandomDance", "#Challenge", "#STAY"],
    caption: "La ronda explotó cuando sonó el dance break. Próxima juntada con lista abierta.",
    likes: "5.4K",
    comments: "230",
    commentList: [],
    location: "Buenos Aires",
    shares: "320",
    saves: "1.1K",
  },
  {
    id: "demo-post-15",
    user: "Flor Kim",
    group: "Comeback poster",
    category: "posts",
    type: "popular",
    time: "hace 10 h",
    badge: "FEARNOT",
    online: false,
    hashtags: ["#comeback", "#LE_SSERAFIM", "#fanart"],
    caption: "Poster fanmade para comeback night con glitter, luces suaves y concepto editorial.",
    likes: "1.9K",
    comments: "77",
    commentList: [],
    shares: "88",
    saves: "430",
  },
].map((post, index) => ({
  ...post,
  avatarUrl: post.avatarUrl || getDemoUser(index).avatarUrl,
  imageUrl: getDemoPostImage(index),
  coverUrl: getDemoPostImage(index),
  mediaUrl: getDemoPostImage(index),
  mediaType: "image",
}));

const userPosts = [...DEMO_POSTS];

const storyViewers = [
  { name: "Cami.STAY", badge: "Stay ⭐", action: "vio tu historia" },
  { name: "Mika", badge: "Army 💜", action: "dio estrella" },
  { name: "Vale Multi", badge: "Tokki 🐰", action: "vio tu historia" },
  { name: "Nico K", badge: "Once 🍭", action: "dio estrella" },
];

const DEMO_STORIES = [
  { user: "Mika", avatar: "berry", label: "conciertos", time: "Hace 12 min", music: "BTS · live remix", title: "Concierto soñado", detail: "Luces, fan chants y pulsera lista para Santiago.", stars: 248, colors: "linear-gradient(160deg, #ffb703, #ff2d55 48%, #111827)" },
  { user: "Cami.STAY", avatar: "star", label: "fancams", time: "Hace 26 min", music: "Stray Kids · stage cut", title: "Fancam del dia", detail: "Mi toma favorita del dance break.", stars: 918, colors: "linear-gradient(160deg, #65e4ff, #a855f7 50%, #0c0616)" },
  { user: "Vale Multi", avatar: "mochi", label: "outfits", time: "Hace 41 min", music: "NewJeans · Y2K pop", title: "Outfit comeback", detail: "Rosa, denim y brillos para random dance.", stars: 573, colors: "linear-gradient(160deg, #fbbcdb, #65e4ff 52%, #ffb86b)" },
  { user: "Nico K", avatar: "berry", label: "idols", time: "Hace 1 h", music: "IVE · dreamy edit", title: "Idol mood", detail: "Visual board para elegir bias de la semana.", stars: 441, colors: "linear-gradient(160deg, #8b5cf6, #d9b4ff 52%, #101827)" },
  { user: "ARMY Chile", avatar: "star", label: "dance practice", time: "Hace 2 h", music: "BLACKPINK · dance break", title: "Practice night", detail: "Ensayo grupal antes del evento.", stars: 1200, colors: "linear-gradient(160deg, #0d0718, #8b5cf6 52%, #d9b4ff)" },
  { user: "DIVE Lima", avatar: "mochi", label: "photocards", time: "Hace 3 h", music: "SEVENTEEN · fan chant", title: "Trade seguro", detail: "Photocards protegidas y wishlist nueva.", stars: 336, colors: "linear-gradient(160deg, #fff1f9, #ff8ac8 48%, #8b5cf6)" },
  { user: "Agus Han", avatar: "neon", label: "random dance", time: "Hace 4 h", music: "K-pop mix · crowd", title: "Random play", detail: "La ronda se lleno en el primer chorus.", stars: 801, colors: "linear-gradient(160deg, #ff2d55, #ffb703 52%, #111827)" },
  { user: "Renata Vega", avatar: "idol", label: "stage", time: "Hace 5 h", music: "IVE · stage focus", title: "Stage lights", detail: "Luces frias y camara vertical lista.", stars: 690, colors: "linear-gradient(160deg, #fff1f9, #65e4ff 52%, #8b5cf6)" },
  { user: "Julieta Min", avatar: "cyber", label: "albums", time: "Hace 6 h", music: "SEVENTEEN · soft loop", title: "Album shelf", detail: "Nueva organizacion por era y bias.", stars: 512, colors: "linear-gradient(160deg, #f7cadf, #9ad7ff 50%, #07101f)" },
  { user: "Emi Sol", avatar: "anime", label: "fashion", time: "Hace 7 h", music: "BLACKPINK · fashion cut", title: "Street fashion", detail: "Look inspirado en concierto y cafe.", stars: 740, colors: "linear-gradient(160deg, #09060a, #ff3ea5 52%, #ff8ac8)" },
].map((story, index) => ({
  ...story,
  id: story.id || `demo-story-${index}-${normalizeProfileKey(story.user)}-${normalizeProfileKey(story.time)}`,
  avatarUrl: getDemoUser(index).avatarUrl,
  imageUrl: getDemoStoryImage(index),
  coverUrl: getDemoStoryImage(index),
  mediaUrl: getDemoStoryImage(index),
  mediaType: "image",
}));

const followingStories = DEMO_STORIES;

const homeBanners = [
  { title: "Noticias destacadas", meta: "K-pop al minuto", colors: "linear-gradient(135deg, #1d1024, #fbbcdb 45%, #65e4ff)" },
  { title: "Nuevo Drop BLACKPINK", meta: "Clips virales", colors: "linear-gradient(135deg, #09060a, #ff3ea5 52%, #ff8ac8)" },
  { title: "Dance challenge BTS", meta: "Challenge semanal", colors: "linear-gradient(135deg, #0d0718, #8b5cf6 52%, #d9b4ff)" },
  { title: "Evento K-pop Santiago", meta: "Agenda fandom", colors: "linear-gradient(135deg, #ffb703, #ff2d55 48%, #111827)" },
  { title: "Publicidad fan sponsor", meta: "Marcas K-pop", colors: "linear-gradient(135deg, #04131d, #77f4c7 48%, #ffd166)" },
  { title: "Trade de photocards", meta: "Marketplace seguro", colors: "linear-gradient(135deg, #fff1f9, #ff8ac8 48%, #8b5cf6)" },
  { title: "Top fancams del dia", meta: "Fancams premium", colors: "linear-gradient(135deg, #65e4ff, #77f4c7 52%, #0f172a)" },
];

function getBannerActionAttrs(banner) {
  const title = normalizeProfileKey(`${banner.title} ${banner.meta}`);
  if (title.includes("noticia")) return `data-go-view="news"`;
  if (title.includes("fancam")) return `data-go-view="fancams"`;
  if (title.includes("drop") || title.includes("challenge")) return `data-go-view="trends"`;
  if (title.includes("evento")) return `data-home-filter="events"`;
  if (title.includes("trade") || title.includes("publicidad") || title.includes("market")) return `data-go-view="market"`;
  return `data-home-filter="all"`;
}

const homeHighlightStories = [
  { label: "Viral", detail: "Top posts", avatar: "neon", filter: "viral", colors: "linear-gradient(160deg, #65e4ff, #d946ef)" },
  { label: "Drops", detail: "Clips", avatar: "idol", filter: "trends", colors: "linear-gradient(160deg, #ffd166, #ff2d55)" },
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

const DEMO_DROPS = [
  {
    id: "blackpink-dance",
    user: "Cami.STAY",
    challenge: "Dance Challenge BLACKPINK",
    song: "BLACKPINK · dance break",
    description: "Version corta para grabar en plaza o evento fandom.",
    colors: "linear-gradient(160deg, #09060a, #ff3ea5 50%, #ff8ac8)",
  },
  {
    id: "bts-viral-step",
    user: "Mika",
    challenge: "Paso viral de BTS",
    song: "BTS · fan edit",
    description: "Paso facil para fans nuevos que quieren sumarse sin presion.",
    colors: "linear-gradient(160deg, #0d0718, #8b5cf6 52%, #d9b4ff)",
  },
  {
    id: "newjeans-drop",
    user: "Vale Multi",
    challenge: "Drop NewJeans",
    song: "NewJeans · Y2K pop",
    description: "Movimiento suave con outfit pastel y transicion rapida.",
    colors: "linear-gradient(160deg, #06131a, #65e4ff 46%, #77f4c7)",
  },
  {
    id: "random-play-ba",
    user: "Random Play BA",
    challenge: "Cover random play dance",
    song: "K-pop mix · LATAM",
    description: "Reto para grupos grandes en eventos y juntadas.",
    colors: "linear-gradient(160deg, #ffb703, #ff2d55 48%, #111827)",
  },
  {
    id: "kpop-chile",
    user: "Hallyu Chile",
    challenge: "Challenge K-pop Chile",
    song: "LATAM fandom · stage",
    description: "Drop local para mostrar pasos, light sticks y comunidad.",
    colors: "linear-gradient(160deg, #fbbcdb, #65e4ff 52%, #ffb86b)",
  },
].map((drop, index) => ({
  ...drop,
  userId: normalizeProfileKey(getDemoUser(drop.user).username || drop.user),
  username: getDemoUser(drop.user).username || normalizeProfileKey(drop.user),
  groupId: ["bp", "bts", "newjeans", "", ""][index] || "",
  artistId: ["", "bts-jungkook", "", "", ""][index] || "",
  avatarUrl: getDemoUser(drop.user).avatarUrl,
  imageUrl: getDemoDropMedia(index),
  coverUrl: getDemoDropMedia(index),
  mediaUrl: getDemoDropMedia(index),
  thumbnail: getDemoDropMedia(index),
  mediaType: "image",
  createdAt: new Date(Date.now() - index * 38 * 60 * 1000).toISOString(),
  likes: ["82K", "64K", "48K", "33K", "21K"][index] || "12K",
  comments: ["1.2K", "840", "520", "311", "204"][index] || "98",
  hashtags: ["#Drops", "#KpopLatam", index === 0 ? "#BLACKPINK" : index === 1 ? "#BTS" : index === 2 ? "#NewJeans" : "#Dance"],
}));

const trendVideos = DEMO_DROPS;

const dropVisualFilters = [
  { id: "kpop-stage", name: "K-pop Stage", creator: "HallyuHub", category: "Stage", status: "approved", uses: "18.4K", detail: "Luces de escenario, foco suave y marco premium." },
  { id: "neon-rush", name: "Neon Rush", creator: "HallyuHub", category: "Neón", status: "approved", uses: "14.2K", detail: "Brillos magenta/cyan y contraste de videoclip." },
  { id: "lightstick-glow", name: "Lightstick Glow", creator: "HallyuHub", category: "Glow", status: "approved", uses: "11.8K", detail: "Aura de lightstick, partículas suaves y fandom glow." },
  { id: "vhs-idol", name: "VHS Idol", creator: "HallyuHub", category: "Retro", status: "approved", uses: "9.7K", detail: "Scanlines, tono video casero y estilo vertical retro." },
  { id: "pastel-comeback", name: "Pastel Comeback", creator: "HallyuHub", category: "Pastel", status: "approved", uses: "12.9K", detail: "Rosa suave, bloom cute y comeback luminoso." },
  { id: "dark-concept", name: "Dark Concept", creator: "HallyuHub", category: "Concept", status: "approved", uses: "8.1K", detail: "Sombras profundas, violeta oscuro y brillo elegante." },
  { id: "cyber-seoul", name: "Cyber Seoul", creator: "Mika.army", category: "Comunidad", status: "pending", uses: "0", detail: "Propuesta futurista pendiente de revisión." },
  { id: "cute-bubble", name: "Cute Bubble", creator: "Vale.multi", category: "Comunidad", status: "approved", uses: "3.2K", detail: "Burbujas pastel, brillo soft y energía cute." },
  { id: "concert-lights", name: "Concert Lights", creator: "Agus.random", category: "Comunidad", status: "rejected", uses: "0", detail: "Rechazado en demo por exceso de flashes." },
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
      { name: "RM", realName: "Kim Nam-joon", birth: "1994-09-12", role: "Lider · rap", country: "Corea del Sur", nationality: "Coreana" },
      { name: "Jin", realName: "Kim Seok-jin", birth: "1992-12-04", role: "Vocal", country: "Corea del Sur", nationality: "Coreana" },
      { name: "SUGA", realName: "Min Yoon-gi", birth: "1993-03-09", role: "Rap · productor", country: "Corea del Sur", nationality: "Coreana" },
      { name: "j-hope", realName: "Jung Ho-seok", birth: "1994-02-18", role: "Dance · rap", country: "Corea del Sur", nationality: "Coreana" },
      { name: "Jimin", realName: "Park Ji-min", birth: "1995-10-13", role: "Vocal · dance", country: "Corea del Sur", nationality: "Coreana" },
      { name: "V", realName: "Kim Tae-hyung", birth: "1995-12-30", role: "Vocal", country: "Corea del Sur", nationality: "Coreana" },
      { name: "Jung Kook", realName: "Jeon Jung-kook", birth: "1997-09-01", role: "Vocal · dance · maknae", country: "Corea del Sur", nationality: "Coreana" },
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

kpopGroups.push(
  {
    id: "enhypen",
    name: "ENHYPEN",
    type: "group",
    fandom: "ENGENE",
    company: "BELIFT LAB",
    debut: "2020",
    country: "Corea del Sur",
    status: "Activo",
    style: "Pop oscuro, narrativa vampirica, performance pulida y energia juvenil.",
    bio: "ENHYPEN nacio desde un proyecto de supervivencia y construyo una identidad marcada por conceptos dramaticos, baile preciso y una comunidad global muy conectada. Su perfil en Hallyu Hub sirve para seguir comebacks, stages, perfiles individuales y contenido ENGENE con datos preparados para actualizarse desde fuentes oficiales.",
    latest: "Noticias de comebacks, giras, contenido Weverse y clips de performance.",
    colors: "linear-gradient(135deg, #111827, #a855f7 46%, #65e4ff)",
    officialLinks: [
      ["Sitio oficial", "https://beliftlab.com/artist/profile/ENHYPEN"],
      ["YouTube", "https://www.youtube.com/@ENHYPENOFFICIAL"],
      ["Weverse", "https://weverse.io/enhypen"],
      ["Instagram", "https://www.instagram.com/enhypen/"],
    ],
    artists: [
      { name: "Jungwon", realName: "Yang Jung-won", birth: "2004-02-09", role: "Lider · vocal · dance", country: "Corea del Sur", nationality: "Coreana" },
      { name: "Jay", realName: "Park Jong-seong", birth: "2002-04-20", role: "Rap · vocal · dance", country: "Corea / EE.UU.", nationality: "Coreana-estadounidense" },
      { name: "Jake", realName: "Sim Jae-yun", birth: "2002-11-15", role: "Vocal · dance", country: "Australia / Corea", nationality: "Coreana-australiana" },
      { name: "Sunghoon", realName: "Park Sung-hoon", birth: "2002-12-08", role: "Vocal · dance", country: "Corea del Sur", nationality: "Coreana" },
      { name: "Sunoo", realName: "Kim Sun-oo", birth: "2003-06-24", role: "Vocal", country: "Corea del Sur", nationality: "Coreana" },
      { name: "Ni-ki", realName: "Nishimura Riki", birth: "2005-12-09", role: "Dance · maknae", country: "Japon", nationality: "Japonesa" },
    ],
  },
  {
    id: "cortis",
    name: "CORTIS",
    type: "group",
    fandom: "COER",
    company: "BIGHIT MUSIC",
    debut: "2025",
    country: "Corea del Sur",
    status: "Activo",
    style: "Young creator crew, pop/hip-hop global, energia joven y participacion creativa.",
    bio: "CORTIS es un grupo de BIGHIT MUSIC con una identidad de creadores jovenes. En Hallyu Hub se organiza como ficha ampliable para seguir integrantes, clips, noticias y contenido oficial sin copiar material de comunidades externas.",
    latest: "Seguimiento de debut, clips oficiales, noticias de BIGHIT y actividad fandom.",
    colors: "linear-gradient(135deg, #101827, #77f4c7 44%, #fbbcdb)",
    officialLinks: [
      ["Sitio oficial", "https://ibighit.com/cor/eng/profile/"],
      ["Japan official", "https://cortis-official.jp/profile"],
      ["YouTube", "https://www.youtube.com/@cortis_bighit"],
      ["Instagram", "https://www.instagram.com/cortis_bighit_official/"],
      ["Weverse", "https://weverse.io/cortis"],
    ],
    artists: [
      { name: "Martin", birth: "2008-03-20", role: "Lider · creador · performance", country: "Corea / Canada", nationality: "Coreana-canadiense" },
      { name: "James", birth: "2005-10-14", role: "Performance · creativo", country: "Internacional" },
      { name: "Juhoon", birth: "2008-01-03", role: "Vocal · performance", country: "Corea del Sur", nationality: "Coreana" },
      { name: "Seonghyeon", birth: "2009-01-13", role: "Vocal · performance", country: "Corea del Sur", nationality: "Coreana" },
      { name: "Keonho", birth: "2009-02-14", role: "Vocal · maknae", country: "Corea del Sur", nationality: "Coreana" },
    ],
  },
  {
    id: "lesserafim",
    name: "LE SSERAFIM",
    type: "group",
    fandom: "FEARNOT",
    company: "SOURCE MUSIC",
    debut: "2022",
    country: "Corea del Sur",
    status: "Activo",
    style: "Pop elegante, performance fuerte, confianza escenica y conceptos de crecimiento.",
    bio: "LE SSERAFIM construye una identidad basada en seguridad, energia de escenario y mensajes de avance personal. En Hallyu Hub su ficha ayuda a seguir eras, integrantes, clips, photocards y noticias FEARNOT.",
    latest: "Comebacks, stages, fancams y actividad global FEARNOT.",
    colors: "linear-gradient(135deg, #f8fafc, #ff8ac8 48%, #111827)",
    officialLinks: [["Sitio oficial", "https://www.le-sserafim.com/"], ["YouTube", "https://www.youtube.com/@LESSERAFIM_official"], ["Instagram", "https://www.instagram.com/le_sserafim/"], ["Weverse", "https://weverse.io/lesserafim"]],
    artists: [
      { name: "Sakura", role: "Vocal · performance", country: "Japon" },
      { name: "Kim Chaewon", role: "Lider · vocal", country: "Corea del Sur" },
      { name: "Huh Yunjin", role: "Vocal", country: "Corea / EE.UU." },
      { name: "Kazuha", role: "Dance · vocal", country: "Japon" },
      { name: "Hong Eunchae", role: "Vocal · dance · maknae", country: "Corea del Sur" },
    ],
  },
  {
    id: "nct",
    name: "NCT",
    type: "group",
    fandom: "NCTzen",
    company: "SM Entertainment",
    debut: "2016",
    country: "Corea del Sur",
    status: "Activo",
    style: "Sistema de unidades, pop experimental, hip-hop, performance y conceptos urbanos.",
    bio: "NCT funciona como un universo de unidades con sonidos variados y muchos perfiles para explorar. La ficha prioriza busqueda por integrantes, unidades, lanzamientos y contenido relacionado para NCTzen.",
    latest: "Noticias de unidades, comebacks, conciertos y actividades individuales.",
    colors: "linear-gradient(135deg, #77f4c7, #22c55e 48%, #0f172a)",
    officialLinks: [["Sitio oficial", "https://www.smtown.com/"], ["YouTube", "https://www.youtube.com/@NCTsmtown"], ["Instagram", "https://www.instagram.com/nct/"], ["Weverse", "https://weverse.io/nct127"]],
    artists: [
      { name: "Taeyong", role: "Lider · rap · dance", country: "Corea del Sur" },
      { name: "Johnny", role: "Rap · vocal", country: "Estados Unidos / Corea" },
      { name: "Yuta", role: "Vocal · dance", country: "Japon" },
      { name: "Kun", role: "Lider WayV · vocal", country: "China" },
      { name: "Doyoung", role: "Vocal", country: "Corea del Sur" },
      { name: "Ten", role: "Dance · vocal", country: "Tailandia" },
      { name: "Jaehyun", role: "Vocal · rap", country: "Corea del Sur" },
      { name: "Jungwoo", role: "Vocal · dance", country: "Corea del Sur" },
      { name: "Mark", role: "Rap · dance", country: "Canada / Corea" },
      { name: "Haechan", role: "Vocal · dance", country: "Corea del Sur" },
      { name: "Jeno", role: "Rap · dance", country: "Corea del Sur" },
      { name: "Jaemin", role: "Rap · dance", country: "Corea del Sur" },
      { name: "Chenle", role: "Vocal", country: "China" },
      { name: "Jisung", role: "Dance · vocal", country: "Corea del Sur" },
    ],
  },
  {
    id: "riize",
    name: "RIIZE",
    type: "group",
    fandom: "BRIIZE",
    company: "SM Entertainment",
    debut: "2023",
    country: "Corea del Sur",
    status: "Activo",
    style: "Emotional pop, performance fresca, estilo juvenil y sonido brillante.",
    bio: "RIIZE propone una imagen cercana y moderna, con canciones pensadas para momentos faciles de compartir. Su ficha organiza integrantes, clips, noticias y publicaciones de BRIIZE.",
    latest: "Clips virales, comebacks y actividad BRIIZE.",
    colors: "linear-gradient(135deg, #ffb703, #ff8ac8 50%, #65e4ff)",
    officialLinks: [["Sitio oficial", "https://www.smtown.com/"], ["YouTube", "https://www.youtube.com/@RIIZE_official"], ["Instagram", "https://www.instagram.com/riize_official/"], ["Weverse", "https://weverse.io/riize"]],
    artists: [
      { name: "Shotaro", role: "Dance · performance", country: "Japon" },
      { name: "Eunseok", role: "Vocal", country: "Corea del Sur" },
      { name: "Sungchan", role: "Rap · performance", country: "Corea del Sur" },
      { name: "Wonbin", role: "Vocal · dance", country: "Corea del Sur" },
      { name: "Sohee", role: "Vocal", country: "Corea del Sur" },
      { name: "Anton", role: "Vocal · maknae", country: "Estados Unidos / Corea" },
    ],
  },
  {
    id: "babymonster",
    name: "BABYMONSTER",
    type: "group",
    fandom: "MONSTIEZ",
    company: "YG Entertainment",
    debut: "2024",
    country: "Corea del Sur",
    status: "Activo",
    style: "Rap, vocal potente, performance YG y energia rookie global.",
    bio: "BABYMONSTER combina voces fuertes, rap y una imagen de alto impacto. Su perfil esta pensado para seguir stages, challenges, fancams y contenido de cada integrante.",
    latest: "Fancams, lanzamientos, videos oficiales y actividad MONSTIEZ.",
    colors: "linear-gradient(135deg, #111827, #ff2d55 52%, #fbbcdb)",
    officialLinks: [["Sitio oficial", "https://yg-babymonster.com/"], ["YouTube", "https://www.youtube.com/@BABYMONSTER"], ["Instagram", "https://www.instagram.com/babymonster_ygofficial/"], ["Weverse", "https://weverse.io/babymonster"]],
    artists: [
      { name: "Ruka", role: "Rap · dance", country: "Japon" },
      { name: "Pharita", role: "Vocal", country: "Tailandia" },
      { name: "Asa", role: "Rap · dance", country: "Japon" },
      { name: "Ahyeon", role: "Vocal · rap", country: "Corea del Sur" },
      { name: "Rami", role: "Vocal", country: "Corea del Sur" },
      { name: "Rora", role: "Vocal", country: "Corea del Sur" },
      { name: "Chiquita", role: "Dance · vocal · maknae", country: "Tailandia" },
    ],
  },
  {
    id: "itzy",
    name: "ITZY",
    type: "group",
    fandom: "MIDZY",
    company: "JYP Entertainment",
    debut: "2019",
    country: "Corea del Sur",
    status: "Activo",
    style: "Teen crush, dance, confianza, pop energetico y visual moderno.",
    bio: "ITZY se apoya en mensajes de seguridad personal, coreografias marcadas y un estilo pop directo. Su espacio reune contenido MIDZY, stages, outfits y noticias.",
    latest: "Comebacks, tours, dance practices y publicaciones MIDZY.",
    colors: "linear-gradient(135deg, #65e4ff, #a855f7 48%, #ff2d55)",
    officialLinks: [["Sitio oficial", "https://itzy.jype.com/"], ["YouTube", "https://www.youtube.com/@ITZY"], ["Instagram", "https://www.instagram.com/itzy.all.in.us/"]],
    artists: [
      { name: "Yeji", role: "Lider · dance · vocal", country: "Corea del Sur" },
      { name: "Lia", role: "Vocal", country: "Corea del Sur" },
      { name: "Ryujin", role: "Rap · dance", country: "Corea del Sur" },
      { name: "Chaeryeong", role: "Dance · vocal", country: "Corea del Sur" },
      { name: "Yuna", role: "Vocal · dance · maknae", country: "Corea del Sur" },
    ],
  },
  {
    id: "gidle",
    name: "(G)I-DLE",
    type: "group",
    fandom: "NEVERLAND",
    company: "Cube Entertainment",
    debut: "2018",
    country: "Corea del Sur",
    status: "Activo",
    style: "Conceptos fuertes, produccion creativa, pop alternativo y visual teatral.",
    bio: "(G)I-DLE destaca por conceptos definidos, participacion creativa y canciones con identidad propia. Hallyu Hub lo organiza para seguir eras, integrantes y publicaciones NEVERLAND.",
    latest: "Noticias de comebacks, proyectos individuales y contenido NEVERLAND.",
    colors: "linear-gradient(135deg, #7c3aed, #ff8ac8 50%, #111827)",
    officialLinks: [["Sitio oficial", "https://www.cubeent.co.kr/"], ["YouTube", "https://www.youtube.com/@official_g_i_dle"], ["Instagram", "https://www.instagram.com/official_g_i_dle/"], ["Weverse", "https://weverse.io/gidle"]],
    artists: [
      { name: "Miyeon", role: "Vocal", country: "Corea del Sur" },
      { name: "Minnie", role: "Vocal", country: "Tailandia" },
      { name: "Soyeon", role: "Lider · rap · productora", country: "Corea del Sur" },
      { name: "Yuqi", role: "Vocal · dance", country: "China" },
      { name: "Shuhua", role: "Vocal · visual · maknae", country: "Taiwan" },
    ],
  },
  {
    id: "zerobaseone",
    name: "ZEROBASEONE",
    type: "group",
    fandom: "ZEROSE",
    company: "WAKEONE",
    debut: "2023",
    country: "Corea del Sur",
    status: "Activo",
    style: "Pop brillante, performance de supervivencia, energia global y fandom muy activo.",
    bio: "ZEROBASEONE reune integrantes conocidos por su paso por un programa de competencia y una base ZEROSE muy participativa. La ficha ordena perfiles, noticias y contenido viral del grupo.",
    latest: "Comebacks, eventos, clips ZEROSE y actividad de integrantes.",
    colors: "linear-gradient(135deg, #fff1f9, #65e4ff 50%, #a855f7)",
    officialLinks: [["Sitio oficial", "https://wake-one.com/"], ["YouTube", "https://www.youtube.com/@ZB1_official"], ["Instagram", "https://www.instagram.com/zb1official/"], ["Weverse", "https://weverse.io/zerobaseone"]],
    artists: [
      { name: "Sung Hanbin", role: "Lider · dance · vocal", country: "Corea del Sur" },
      { name: "Kim Jiwoong", role: "Vocal · visual", country: "Corea del Sur" },
      { name: "Zhang Hao", role: "Vocal", country: "China" },
      { name: "Seok Matthew", role: "Vocal · dance", country: "Canada / Corea" },
      { name: "Kim Taerae", role: "Vocal", country: "Corea del Sur" },
      { name: "Ricky", role: "Vocal · visual", country: "China" },
      { name: "Kim Gyuvin", role: "Dance · vocal", country: "Corea del Sur" },
      { name: "Park Gunwook", role: "Rap · dance", country: "Corea del Sur" },
      { name: "Han Yujin", role: "Dance · maknae", country: "Corea del Sur" },
    ],
  },
  {
    id: "nmixx",
    name: "NMIXX",
    type: "group",
    fandom: "NSWER",
    company: "JYP Entertainment",
    debut: "2022",
    country: "Corea del Sur",
    status: "Activo",
    style: "Mixx pop, voces potentes, cambios de ritmo y performance tecnica.",
    bio: "NMIXX se caracteriza por voces fuertes y canciones que mezclan estilos. Su perfil permite seguir etapas, lives, dance practices y contenido de NSWER.",
    latest: "Stages vocales, comeback news y publicaciones NSWER.",
    colors: "linear-gradient(135deg, #22d3ee, #d946ef 52%, #0f172a)",
    officialLinks: [["Sitio oficial", "https://nmixx.jype.com/"], ["YouTube", "https://www.youtube.com/@NMIXXOfficial"], ["Instagram", "https://www.instagram.com/nmixx_official/"]],
    artists: [
      { name: "Lily", role: "Vocal", country: "Australia / Corea" },
      { name: "Haewon", role: "Lider · vocal", country: "Corea del Sur" },
      { name: "Sullyoon", role: "Vocal · visual", country: "Corea del Sur" },
      { name: "Bae", role: "Vocal · dance", country: "Corea del Sur" },
      { name: "Jiwoo", role: "Rap · dance · vocal", country: "Corea del Sur" },
      { name: "Kyujin", role: "Dance · vocal · maknae", country: "Corea del Sur" },
    ],
  },
  {
    id: "treasure",
    name: "TREASURE",
    type: "group",
    fandom: "Treasure Maker",
    company: "YG Entertainment",
    debut: "2020",
    country: "Corea del Sur",
    status: "Activo",
    style: "Pop energetico, rap YG, performance y variedad juvenil.",
    bio: "TREASURE combina performance, rap y una dinamica grupal amplia. Su pagina esta pensada para seguir integrantes, conciertos, lanzamientos y contenido Treasure Maker.",
    latest: "Giras, comebacks, lives y publicaciones Treasure Maker.",
    colors: "linear-gradient(135deg, #2563eb, #65e4ff 48%, #111827)",
    officialLinks: [["Sitio oficial", "https://yg-treasure.com/"], ["YouTube", "https://www.youtube.com/@TREASURE"], ["Instagram", "https://www.instagram.com/yg_treasure_official/"], ["Weverse", "https://weverse.io/treasure"]],
    artists: [
      { name: "Choi Hyunsuk", role: "Lider · rap", country: "Corea del Sur" },
      { name: "Jihoon", role: "Lider · vocal · dance", country: "Corea del Sur" },
      { name: "Yoshi", role: "Rap", country: "Japon" },
      { name: "Junkyu", role: "Vocal", country: "Corea del Sur" },
      { name: "Yoon Jaehyuk", role: "Vocal · dance", country: "Corea del Sur" },
      { name: "Asahi", role: "Vocal", country: "Japon" },
      { name: "Doyoung", role: "Dance · vocal", country: "Corea del Sur" },
      { name: "Haruto", role: "Rap", country: "Japon" },
      { name: "Park Jeongwoo", role: "Vocal", country: "Corea del Sur" },
      { name: "So Junghwan", role: "Dance · vocal · maknae", country: "Corea del Sur" },
    ],
  },
  {
    id: "boynextdoor",
    name: "BOYNEXTDOOR",
    type: "group",
    fandom: "ONEDOOR",
    company: "KOZ Entertainment",
    debut: "2023",
    country: "Corea del Sur",
    status: "Activo",
    style: "Pop cercano, historias cotidianas, performance fresca y energia teen.",
    bio: "BOYNEXTDOOR trabaja una identidad amigable y expresiva, con canciones que se sienten como escenas de juventud. Su ficha ayuda a seguir clips, retos y contenido ONEDOOR.",
    latest: "Challenges, comebacks, lives y actividad ONEDOOR.",
    colors: "linear-gradient(135deg, #fbbcdb, #77f4c7 52%, #111827)",
    officialLinks: [["Sitio oficial", "https://kozofficial.com/artist/profile/BOYNEXTDOOR"], ["YouTube", "https://www.youtube.com/@BOYNEXTDOOR_official"], ["Instagram", "https://www.instagram.com/boynextdoor_official/"], ["Weverse", "https://weverse.io/boynextdoor"]],
    artists: [
      { name: "Sungho", role: "Vocal", country: "Corea del Sur" },
      { name: "Riwoo", role: "Dance · vocal", country: "Corea del Sur" },
      { name: "Jaehyun", role: "Lider · rap · vocal", country: "Corea del Sur" },
      { name: "Taesan", role: "Vocal · rap", country: "Corea del Sur" },
      { name: "Leehan", role: "Vocal", country: "Corea del Sur" },
      { name: "Woonhak", role: "Vocal · maknae", country: "Corea del Sur" },
    ],
  },
  {
    id: "tws",
    name: "TWS",
    type: "group",
    fandom: "42",
    company: "PLEDIS Entertainment",
    debut: "2024",
    country: "Corea del Sur",
    status: "Activo",
    style: "Boyhood pop, sonidos brillantes, coreografias limpias y energia escolar.",
    bio: "TWS presenta una estetica clara, fresca y juvenil. En Hallyu Hub se organiza como pagina para descubrir integrantes, videos cortos, noticias y publicaciones de 42.",
    latest: "Clips, stages, comebacks y actividad fandom 42.",
    colors: "linear-gradient(135deg, #65e4ff, #fff1f9 52%, #77f4c7)",
    officialLinks: [["Sitio oficial", "https://www.pledis.co.kr/"], ["YouTube", "https://www.youtube.com/@TWS_PLEDIS"], ["Instagram", "https://www.instagram.com/tws_pledis/"], ["Weverse", "https://weverse.io/tws"]],
    artists: [
      { name: "Shinyu", role: "Lider · rap", country: "Corea del Sur" },
      { name: "Dohoon", role: "Vocal · dance", country: "Corea del Sur" },
      { name: "Youngjae", role: "Vocal", country: "Corea del Sur" },
      { name: "Hanjin", role: "Vocal", country: "China" },
      { name: "Jihoon", role: "Dance · vocal", country: "Corea del Sur" },
      { name: "Kyungmin", role: "Vocal · maknae", country: "Corea del Sur" },
    ],
  },
);

const groupOfficialLinks = {
  skz: [["Sitio oficial", "https://straykids.jype.com/"], ["YouTube", "https://www.youtube.com/@StrayKids"], ["Instagram", "https://www.instagram.com/realstraykids/"], ["Weverse", "https://weverse.io/straykids"]],
  bts: [["Sitio oficial", "https://ibighit.com/bts/"], ["YouTube", "https://www.youtube.com/@BTS"], ["Instagram", "https://www.instagram.com/bts.bighitofficial/"], ["Weverse", "https://weverse.io/bts"]],
  bp: [["Sitio oficial", "https://www.blackpinkofficial.com/"], ["YouTube", "https://www.youtube.com/@BLACKPINK"], ["Instagram", "https://www.instagram.com/blackpinkofficial/"], ["Weverse", "https://weverse.io/blackpink"]],
  nj: [["YouTube", "https://www.youtube.com/@NewJeans_official"], ["Instagram", "https://www.instagram.com/newjeans_official/"], ["Weverse", "https://weverse.io/newjeansofficial"]],
  svt: [["Sitio oficial", "https://www.pledis.co.kr/"], ["YouTube", "https://www.youtube.com/@pledis17"], ["Instagram", "https://www.instagram.com/saythename_17/"], ["Weverse", "https://weverse.io/seventeen"]],
  txt: [["Sitio oficial", "https://ibighit.com/txt/"], ["YouTube", "https://www.youtube.com/@TXT_bighit"], ["Instagram", "https://www.instagram.com/txt_bighit/"], ["Weverse", "https://weverse.io/txt"]],
  ive: [["Sitio oficial", "https://www.starship-ent.com/"], ["YouTube", "https://www.youtube.com/@IVEstarship"], ["Instagram", "https://www.instagram.com/ivestarship/"]],
  ateez: [["Sitio oficial", "https://ateez.kqent.com/"], ["YouTube", "https://www.youtube.com/@ATEEZofficial"], ["Instagram", "https://www.instagram.com/ateez_official_/"]],
  twice: [["Sitio oficial", "https://twice.jype.com/"], ["YouTube", "https://www.youtube.com/@TWICE"], ["Instagram", "https://www.instagram.com/twicetagram/"]],
  aespa: [["Sitio oficial", "https://www.smtown.com/"], ["YouTube", "https://www.youtube.com/@aespa"], ["Instagram", "https://www.instagram.com/aespa_official/"], ["Weverse", "https://weverse.io/aespa"]],
};

const groupVisualAssets = {
  bts: {
    imageUrl: "https://upload.wikimedia.org/wikipedia/commons/7/74/BTS_at_%22Map_of_the_Soul_-_Persona%22_global_press_conference%2C_17_April_2019_01.jpg",
    coverUrl: "https://upload.wikimedia.org/wikipedia/commons/7/74/BTS_at_%22Map_of_the_Soul_-_Persona%22_global_press_conference%2C_17_April_2019_01.jpg",
    sourceCredit: "TV Ten / Wikimedia Commons · CC BY 3.0",
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:BTS_at_%22Map_of_the_Soul_-_Persona%22_global_press_conference,_17_April_2019_01.jpg',
    license: "CC BY 3.0",
    author: "TV Ten",
    attributionText: 'TV Ten, "BTS at Map of the Soul: Persona global press conference", CC BY 3.0, via Wikimedia Commons',
  },
};

const artistVisualAssets = {
  "bts-jungkook": {
    imageUrl: "https://upload.wikimedia.org/wikipedia/commons/9/9f/Jeon_Jungkook_at_the_White_House%2C_31_May_2022.jpg",
    coverUrl: "https://upload.wikimedia.org/wikipedia/commons/9/9f/Jeon_Jungkook_at_the_White_House%2C_31_May_2022.jpg",
    sourceCredit: "The White House / Wikimedia Commons · Public domain",
    sourceUrl: "https://commons.wikimedia.org/wiki/File:Jeon_Jungkook_at_the_White_House,_31_May_2022.jpg",
    license: "Public domain",
    author: "The White House",
    attributionText: "The White House, Jeon Jungkook at the White House, public domain, via Wikimedia Commons",
  },
};

const officialVideoEmbeds = [
  {
    title: "Dynamite · Official MV",
    artist: "BTS",
    group: "BTS",
    groupId: "bts",
    artistId: "bts-jungkook",
    youtubeId: "gdZLi9oWNZg",
    thumbnail: "https://img.youtube.com/vi/gdZLi9oWNZg/hqdefault.jpg",
    source: "YouTube oficial de BTS",
    audioTitle: "Audio oficial externo",
    previewUrl: "",
  },
  {
    title: "Butter · Official MV",
    artist: "BTS",
    group: "BTS",
    groupId: "bts",
    artistId: "bts-jungkook",
    youtubeId: "WMweEpGlu_U",
    thumbnail: "https://img.youtube.com/vi/WMweEpGlu_U/hqdefault.jpg",
    source: "YouTube oficial de BTS",
    audioTitle: "Audio oficial externo",
    previewUrl: "",
  },
  {
    title: "DDU-DU DDU-DU · Official MV",
    artist: "BLACKPINK",
    group: "BLACKPINK",
    groupId: "bp",
    artistId: "bp-lisa",
    youtubeId: "IHNzOHi8sJs",
    thumbnail: "https://img.youtube.com/vi/IHNzOHi8sJs/hqdefault.jpg",
    source: "YouTube oficial de BLACKPINK",
    audioTitle: "Audio oficial externo",
    previewUrl: "",
  },
  {
    title: "Given-Taken · Official MV",
    artist: "ENHYPEN",
    group: "ENHYPEN",
    groupId: "enhypen",
    artistId: "enhypen-jungwon",
    youtubeId: "nQ6wLuYvGd4",
    thumbnail: "https://img.youtube.com/vi/nQ6wLuYvGd4/hqdefault.jpg",
    source: "YouTube oficial de ENHYPEN",
    audioTitle: "Audio oficial externo",
    previewUrl: "",
  },
];

const localVisuals = {
  groupCover: "assets/visuals/hallyu-group-cover.svg",
  idolCard: "assets/visuals/hallyu-idol-card.svg",
};

const placeholderCredit = {
  sourceCredit: "Placeholder premium HallyuHub · temporal",
  sourceUrl: "",
  license: "Asset propio demo",
  author: "HallyuHub",
  attributionText: "Imagen temporal creada para HallyuHub. Reemplazar por foto autorizada cuando esté disponible.",
};

function enrichGroupCatalog() {
  kpopGroups.forEach((group) => {
    const visual = groupVisualAssets[group.id] || {};
    group.type ||= "group";
    group.country ||= "Corea del Sur";
    group.status ||= "Activo";
    group.officialLinks ||= groupOfficialLinks[group.id] || [["Buscar noticias", `https://news.google.com/search?q=${encodeURIComponent(group.name + " K-pop")}`]];
    group.imageUrl ||= visual.imageUrl || localVisuals.idolCard;
    group.coverUrl ||= visual.coverUrl || localVisuals.groupCover;
    group.sourceCredit ||= visual.sourceCredit || placeholderCredit.sourceCredit;
    group.sourceUrl ||= visual.sourceUrl || "";
    group.license ||= visual.license || placeholderCredit.license;
    group.author ||= visual.author || placeholderCredit.author;
    group.attributionText ||= visual.attributionText || placeholderCredit.attributionText;
    group.instagramUrl ||= getOfficialLink(group, "Instagram");
    group.youtubeUrl ||= getOfficialLink(group, "YouTube");
    group.weverseUrl ||= getOfficialLink(group, "Weverse");
    group.newsTags ||= [group.name, group.fandom].filter(Boolean);
    group.artists = (group.artists || []).map((artist, index) => ({
      ...artist,
      id: `${group.id}-${normalizeProfileKey(artist.name || index)}`,
      groupId: group.id,
    })).map((artist, index) => {
      const artistVisual = artistVisualAssets[artist.id] || {};
      return {
        bio: `${artist.name} forma parte de ${group.name}. En Hallyu Hub su perfil reune rol, actividad fandom, publicaciones relacionadas y enlaces del grupo para descubrir contenido sin copiar biografias externas.`,
        socials: group.officialLinks,
        imageUrl: artistVisual.imageUrl || artist.imageUrl || localVisuals.idolCard,
        coverUrl: artistVisual.coverUrl || artist.coverUrl || artist.imageUrl || localVisuals.groupCover,
        sourceCredit: artistVisual.sourceCredit || artist.sourceCredit || placeholderCredit.sourceCredit,
        sourceUrl: artistVisual.sourceUrl || artist.sourceUrl || "",
        license: artistVisual.license || artist.license || placeholderCredit.license,
        author: artistVisual.author || artist.author || placeholderCredit.author,
        attributionText: artistVisual.attributionText || artist.attributionText || placeholderCredit.attributionText,
        instagramUrl: artist.instagramUrl || group.instagramUrl,
        youtubeUrl: artist.youtubeUrl || group.youtubeUrl,
        weverseUrl: artist.weverseUrl || group.weverseUrl,
        ...artist,
      };
    });
  });
}

function getOfficialLink(entity, label) {
  const match = (entity.officialLinks || []).find(([name]) => normalizeProfileKey(name) === normalizeProfileKey(label));
  return match?.[1] || "";
}

enrichGroupCatalog();

const fancamVideos = [
  { id: "fc-jungkook-seven", groupId: "bts", artistId: "bts-jungkook", artist: "Jung Kook", group: "BTS", era: "Seven era", show: "Music show focus", date: "2024 · demo", views: "2.8M", likes: "481K", sort: "trending", description: "Focus vertical con energia de stage, pensado para seguir movimientos y expresiones.", mediaUrl: getDemoDropMedia(1), colors: "linear-gradient(160deg, #0d0718, #8b5cf6 52%, #d9b4ff)" },
  { id: "fc-jungwon-bite", groupId: "enhypen", artistId: "enhypen-jungwon", artist: "Jungwon", group: "ENHYPEN", era: "Dark Blood", show: "Comeback stage", date: "2024 · demo", views: "1.6M", likes: "302K", sort: "trending", description: "Fancam centrada en lineas limpias, mirada a camara y performance intensa.", mediaUrl: getDemoDropMedia(2), colors: "linear-gradient(160deg, #111827, #a855f7 48%, #65e4ff)" },
  { id: "fc-lisa-pink", groupId: "bp", artistId: "bp-lisa", artist: "Lisa", group: "BLACKPINK", era: "Pink stage", show: "Concert focus", date: "2023 · demo", views: "3.4M", likes: "620K", sort: "trending", description: "Dance focus con luces rosas, energia de concierto y cortes verticales.", mediaUrl: getDemoDropMedia(3), colors: "linear-gradient(160deg, #09060a, #ff3ea5 52%, #ff8ac8)" },
  { id: "fc-wonyoung-ive", groupId: "ive", artistId: "ive-wonyoung", artist: "Wonyoung", group: "IVE", era: "I AM", show: "Music show", date: "2024 · demo", views: "1.9M", likes: "388K", sort: "recent", description: "Visual focus elegante con close-ups suaves y concepto premium.", mediaUrl: getDemoDropMedia(4), colors: "linear-gradient(160deg, #fff1f9, #ff8ac8 48%, #8b5cf6)" },
  { id: "fc-yeonjun-txt", groupId: "txt", artistId: "txt-yeonjun", artist: "Yeonjun", group: "TXT", era: "Sugar Rush", show: "Stage cam", date: "2024 · demo", views: "1.2M", likes: "244K", sort: "recent", description: "Performance cam con transiciones rapidas y presencia escenica.", mediaUrl: getDemoDropMedia(5), colors: "linear-gradient(160deg, #65e4ff, #77f4c7 52%, #0f172a)" },
  { id: "fc-karina-aespa", groupId: "aespa", artistId: "aespa-karina", artist: "Karina", group: "aespa", era: "Cyber Seoul", show: "Stage focus", date: "2024 · demo", views: "2.1M", likes: "410K", sort: "trending", description: "Fancam futurista con glow azul, movimientos precisos y concepto cyber.", mediaUrl: getDemoDropMedia(6), colors: "linear-gradient(160deg, #06131a, #65e4ff 46%, #d946ef)" },
  { id: "fc-hoshi-svt", groupId: "svt", artistId: "svt-hoshi", artist: "Hoshi", group: "SEVENTEEN", era: "Performance unit", show: "Concert focus", date: "2023 · demo", views: "980K", likes: "190K", sort: "recent", description: "Focus de performance con energia CARAT y coreografia sincronizada.", mediaUrl: getDemoDropMedia(7), colors: "linear-gradient(160deg, #f7cadf, #9ad7ff 50%, #07101f)" },
  { id: "fc-san-ateez", groupId: "ateez", artistId: "ateez-san", artist: "San", group: "ATEEZ", era: "Bouncy", show: "Festival focus", date: "2024 · demo", views: "1.4M", likes: "276K", sort: "trending", description: "Stage cam poderosa, expresiones intensas y luces de festival.", mediaUrl: getDemoDropMedia(8), colors: "linear-gradient(160deg, #ffb703, #ff2d55 48%, #111827)" },
];

fancamVideos.forEach((fancam, index) => {
  const mediaUrl = getDemoDropMedia(index + 1);
  fancam.userId = fancam.userId || `fan-${normalizeProfileKey(fancam.artist)}`;
  fancam.user = fancam.user || ["Renata Vega", "Mateo Song", "Emi Sol", "Isa DIVE", "Ara Chen", "Dani Lee", "Noa Rivera", "Thiago Baek"][index] || "Hallyu fan";
  fancam.username = fancam.username || normalizeProfileKey(fancam.user);
  fancam.createdAt = fancam.createdAt || new Date(Date.now() - index * 52 * 60 * 1000).toISOString();
  fancam.comments = fancam.comments || ["2.1K", "1K", "1.7K", "840", "620", "1.1K", "420", "730"][index] || "120";
  fancam.hashtags = fancam.hashtags || [`#${fancam.group}`, `#${fancam.artist.replace(/\s+/g, "")}`, "#Fancam"];
  fancam.thumbnail = fancam.thumbnail || mediaUrl;
  fancam.imageUrl = mediaUrl;
  fancam.coverUrl = mediaUrl;
  fancam.mediaUrl = mediaUrl;
  fancam.mediaType = "image";
});

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
    mood: "Cyber, futurista y listo para Drops verticales.",
    rarity: "Rare",
    minLevel: 9,
    reward: "Participar en Drops",
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
  ["Participar en Drops", "+40 estrellas", "Challenges y dance covers"],
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

hydrateDemoSocialData();

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
  ["trends", "Drops"],
  ["outfits", "Outfit"],
  ["photocards", "Photocards"],
  ["saved", "Guardados"],
  ["archive", "Archivo"],
  ["favorites", "Favoritos"],
];

const fandomBadges = ["Army 💜", "Blink 🖤💖", "Once 🍭", "Stay ⭐", "Tokki 🐰"];

const reportReasons = ["Copyright", "Spam", "Acoso", "Contenido ofensivo", "Contenido sexual", "Grabación no permitida", "Fake", "Otro"];

const legalAudioSources = [
  { audioTitle: "Drop dance · demo loop", artist: "HallyuHub", source: "Audio propio demo", previewUrl: "" },
  { audioTitle: "Idol sparkle · safe preview", artist: "HallyuHub", source: "Preview corto libre", previewUrl: "" },
  { audioTitle: "Fan upload audio", artist: "Usuario", source: "Audio subido por usuario", previewUrl: "" },
];

const publishTypes = [
  ["posts", "Publicación"],
  ["trends", "Drop"],
  ["fancams", "Fancam"],
  ["stories", "Story"],
  ["outfits", "Outfit"],
  ["photocards", "Photocard"],
];

const publishFilters = [
  ["original", "Original"],
  ["neon-idol", "Neon Idol"],
  ["seoul-night", "Seoul Night"],
  ["lightstick-glow", "Lightstick Glow"],
  ["pastel-comeback", "Pastel Comeback"],
  ["fancam-vhs", "Fancam VHS"],
  ["dark-concept", "Dark Concept"],
  ["concert-lights", "Concert Lights"],
  ["soft-kpop", "Soft K-pop"],
];

const storyMusicLibrary = [
  { level: 1, category: "Viral", name: "Basic beat · safe loop", detail: "Sonido corto libre para historias nuevas", tone: 523 },
  { level: 1, category: "Cute", name: "Idol sparkle · demo", detail: "Preview original HallyuHub", tone: 659 },
  { level: 3, category: "Dance", name: "Comeback pulse · safe preview", detail: "Desbloqueo por estrellas nivel 3", tone: 784 },
  { level: 5, category: "Dance", name: "Drop dance · demo loop", detail: "Sonido para challenges cortos", tone: 880 },
  { level: 5, category: "Dark", name: "Dark stage · synth hit", detail: "Preview oscuro para concepts intensos", tone: 392 },
  { level: 3, category: "Chill", name: "Seoul chill · soft loop", detail: "Preview suave para historias tranquilas", tone: 440 },
  { level: 10, category: "Viral", name: "Premium stage · event sound", detail: "Sonido especial para eventos premium", tone: 988 },
];

const storyBackgrounds = ["Neon pastel", "Idol stage", "Seoul night", "Lightstick glow", "Photocard wall", "Cute comeback"];
const storyMusicCategories = ["Viral", "Cute", "Dark", "Dance", "Chill"];
const storyStickerGroups = {
  Cute: ["🎀", "✨", "🫰", "🌸", "🧸", "🍭"],
  Idol: ["🎤", "👑", "📸", "🎬", "⭐", "💫"],
  Neon: ["🪩", "⚡", "💿", "💎", "🌙", "🔥"],
  Hearts: ["💜", "🩷", "💖", "💕", "🫶", "🖤"],
  Fans: ["📣", "🎫", "🛍️", "📷", "💌", "🧡"],
  Lightsticks: ["🔮", "💡", "🪄", "🌟", "💫", "✨"],
  "Korean aesthetic": ["🌙", "☁️", "🍡", "🌸", "🧋", "🎐"],
  Funny: ["😂", "🤭", "😎", "🤯", "🥹", "🙌"],
  Music: ["🎵", "🎶", "🎧", "💿", "🎹", "🥁"],
};
const storyStickerPalette = Object.values(storyStickerGroups).flat();
const storyFonts = ["Inter", "Poppins", "Arial", "Georgia"];
const storyTextColors = ["#ffffff", "#fbbcdb", "#65e4ff", "#77f4c7", "#ffb86b", "#a855f7"];
const storyTextStyles = ["bold", "glow", "neon", "soft pastel", "dark aesthetic"];

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
    state.storyComposerOpen = false;
    state.storyEditorOpen = false;
    clearStoryAutoplay();
  }
  if (nextView !== "trends") {
    state.dropSearchOpen = false;
    state.dropCreatorOpen = false;
  }
  if (nextView !== "fancams") {
    state.fancamCreatorOpen = false;
  }
  if (nextView !== "search") state.selectedHashtag = null;
  if (!state.isAuthenticated && nextView !== "auth") {
    state.view = "auth";
    renderAndScrollTop();
    return;
  }
  state.view = nextView;
  document.querySelectorAll(".nav-item").forEach((button) => {
    button.classList.toggle("active", button.dataset.view === nextView);
  });
  const appScreen = document.querySelector(".app-screen");
  document.body?.classList.toggle("story-open", state.activeStory !== null);
  document.body?.classList.toggle("share-open", Boolean(state.sharePostTarget));
  appScreen.classList.toggle("profile-mode", nextView === "profile");
  appScreen.classList.toggle("auth-mode", nextView === "auth");
  appScreen.classList.toggle("home-mode", nextView === "home");
  appScreen.classList.toggle("story-mode", state.activeStory !== null);
  appScreen.classList.toggle("comments-open-mode", Object.values(state.openComments).some(Boolean) || Object.values(state.dropCommentsOpen).some(Boolean) || Object.values(state.fancamCommentsOpen).some(Boolean));
  appScreen.classList.toggle("light-mode", state.user?.mode === "light");
  appScreen.style.setProperty("--user-accent", state.user?.accent || "#fbbcdb");
  appScreen.dataset.ambience = state.ambience;
  document.getElementById("screen-title").textContent = titleByView[nextView];
  renderAndScrollTop();
  if (nextView === "news") loadKpopNews(false);
}

function getScrollTargets() {
  return [
    window,
    document.documentElement,
    document.body,
    document.getElementById("view"),
    ...document.querySelectorAll(".view"),
    document.querySelector(".app-screen"),
    document.querySelector(".main-content"),
    document.querySelector(".screen-container"),
    document.querySelector(".mobile-shell"),
    document.querySelector(".phone-shell"),
    document.querySelector(".phone-frame"),
  ].filter(Boolean);
}

function applyScrollTop(behavior = "smooth") {
  getScrollTargets().forEach((target) => {
    if (target === window) {
      target.scrollTo({ top: 0, left: 0, behavior });
    } else if (typeof target.scrollTo === "function") {
      target.scrollTo({ top: 0, left: 0, behavior });
    } else {
      target.scrollTop = 0;
      target.scrollLeft = 0;
    }
  });
}

function scrollToTop() {
  applyScrollTop("smooth");
  requestAnimationFrame(() => applyScrollTop("auto"));
  requestAnimationFrame(() => requestAnimationFrame(() => applyScrollTop("auto")));
  setTimeout(() => applyScrollTop("auto"), 80);
}

const scrollActiveViewToTop = scrollToTop;

function renderAndScrollTop() {
  render();
  scrollToTop();
}

function isEditableField(element) {
  return Boolean(element?.matches?.("input, textarea, select"));
}

function lockViewportScale() {
  const content = "width=device-width, initial-scale=1, maximum-scale=1, viewport-fit=cover";
  let viewport = document.querySelector('meta[name="viewport"]');
  if (!viewport) {
    viewport = document.createElement("meta");
    viewport.name = "viewport";
    document.head.appendChild(viewport);
  }
  viewport.setAttribute("content", content);
}

function resetMobileInputZoom() {
  setTimeout(() => {
    window.scrollTo(0, window.scrollY);
    if (document.body) document.body.style.zoom = "1";
    applyScrollTop("auto");
  }, 100);
}

function setupMobileInputZoomGuard() {
  lockViewportScale();
  if (document.body?.dataset.inputZoomGuard === "true") return;
  document.body.dataset.inputZoomGuard = "true";
  document.addEventListener("focusin", (event) => {
    if (isEditableField(event.target)) document.body.classList.add("typing-field-active");
  });
  document.addEventListener("focusout", () => {
    if (isEditableField(document.activeElement)) return;
    document.body.classList.remove("typing-field-active");
    resetMobileInputZoom();
  });
  window.visualViewport?.addEventListener("resize", () => {
    if (document.body.classList.contains("typing-field-active") || isEditableField(document.activeElement)) return;
    setTimeout(() => applyScrollTop("auto"), 80);
  });
}

function render() {
  const view = document.getElementById("view");
  const appScreen = document.querySelector(".app-screen");
  syncStoryFullscreenState();
  appScreen.dataset.ambience = state.ambience;
  appScreen.classList.toggle("auth-mode", state.view === "auth");
  appScreen.classList.toggle("home-mode", state.view === "home");
  appScreen.classList.toggle("story-mode", state.activeStory !== null);
  appScreen.classList.toggle("light-mode", state.user?.mode === "light");
  appScreen.style.setProperty("--user-accent", state.user?.accent || "#fbbcdb");
  document.querySelector("[data-toggle-app-sound]")?.classList.toggle("active", state.soundEnabled);
  document.querySelector("[data-toggle-app-sound]")?.setAttribute("aria-label", state.soundEnabled ? "Sonidos activados" : "Sonidos desactivados");
  document.querySelector(".bottom-nav").classList.toggle("hidden", !state.isAuthenticated || state.view === "publish" || state.storyEditorOpen || state.activeStory !== null || state.dropSearchOpen || state.dropCreatorOpen || state.fancamCreatorOpen || state.videoProfileOverlay || state.videoFullscreen);
  document.querySelector(".topbar").classList.toggle("hidden", !state.isAuthenticated || state.view === "profile" || state.view === "publish" || state.storyEditorOpen || state.activeStory !== null);
  if (!state.isAuthenticated) {
    view.innerHTML = renderAuth();
    mountGlobalStoryViewer();
    mountGlobalStoryEditor();
    bindDynamicActions();
    return;
  }
  if (state.user && state.user.onboarded === false) {
    document.querySelector(".bottom-nav").classList.add("hidden");
    document.querySelector(".topbar").classList.add("hidden");
    view.innerHTML = renderOnboarding();
    mountGlobalStoryViewer();
    mountGlobalStoryEditor();
    bindDynamicActions();
    return;
  }
  const templates = {
    home: renderHome,
    search: renderSearch,
    trends: renderTrends,
    fancams: renderFancams,
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
  view.innerHTML = templates[state.view]() + renderPermissionPrompt() + (state.reportTarget ? renderReportSheet() : "") + renderMediaEmbedModal();
  mountGlobalStoryViewer();
  mountGlobalStoryEditor();
  bindDynamicActions();
  scheduleStoryAutoplay();
}

function syncStoryFullscreenState() {
  document.body?.classList.toggle("story-open", state.activeStory !== null);
  document.body?.classList.toggle("story-create-open", state.storyEditorOpen);
}

function mountGlobalStoryViewer() {
  document.getElementById("global-story-viewer")?.remove();
  if (state.activeStory === null) return;
  document.body.insertAdjacentHTML("beforeend", `<div id="global-story-viewer">${renderStoryViewer()}</div>`);
}

function mountGlobalStoryEditor() {
  document.getElementById("global-story-editor")?.remove();
  if (!state.storyEditorOpen) return;
  document.body.insertAdjacentHTML("beforeend", `<div id="global-story-editor">${renderStoryEditor()}</div>`);
}

function getStoryKey(index) {
  if (index === -1) {
    const ownStory = getActiveOwnStory();
    const stamp = ownStory?.id || ownStory?.createdAt || ownStory?.mediaUrl || ownStory?.time || "own";
    return `own-story-${normalizeProfileKey(stamp)}`;
  }
  const story = followingStories[index];
  return story ? story.id || `story-${index}-${normalizeProfileKey(story.user)}-${normalizeProfileKey(story.time)}` : "";
}

function isStoryViewed(index) {
  const key = getStoryKey(index);
  return Boolean(key && state.viewedStories[key]);
}

function markStoryViewed(index) {
  if (index === null || index === undefined) return;
  const key = getStoryKey(index);
  if (!key || state.viewedStories[key]) return;
  state.viewedStories = { ...state.viewedStories, [key]: true };
  storage.set("hallyuHubViewedStories", state.viewedStories);
}

function getFirstUnviewedStoryIndex(startIndex = 0) {
  if (!followingStories.length) return null;
  for (let offset = 0; offset < followingStories.length; offset += 1) {
    const index = (Math.max(0, startIndex) + offset) % followingStories.length;
    if (!isStoryViewed(index)) return index;
  }
  return null;
}

function getFirstUnviewedOwnStoryIndex() {
  const stories = getOwnStorySequence();
  if (!stories.length) return 0;
  const previousOwnIndex = state.activeOwnStoryIndex;
  for (let index = 0; index < stories.length; index += 1) {
    state.activeOwnStoryIndex = index;
    if (!isStoryViewed(-1)) {
      state.activeOwnStoryIndex = previousOwnIndex;
      return index;
    }
  }
  state.activeOwnStoryIndex = previousOwnIndex;
  return Math.max(0, stories.length - 1);
}

function getStoryOpenIndex(requestedIndex = 0) {
  if (!isStoryViewed(requestedIndex)) return requestedIndex;
  const nextUnviewed = getFirstUnviewedStoryIndex(requestedIndex);
  return nextUnviewed === null ? requestedIndex : nextUnviewed;
}

function getOrderedStoryIndexes() {
  const indexes = followingStories.map((_, index) => index);
  return [
    ...indexes.filter((index) => !isStoryViewed(index)),
    ...indexes.filter((index) => isStoryViewed(index)),
  ];
}

function areAllOwnStoriesViewed() {
  const stories = getOwnStorySequence();
  if (!stories.length) return false;
  const previousOwnIndex = state.activeOwnStoryIndex;
  const allViewed = stories.every((_, index) => {
    state.activeOwnStoryIndex = index;
    return isStoryViewed(-1);
  });
  state.activeOwnStoryIndex = previousOwnIndex;
  return allViewed;
}

function getStoryGroupInfo(index = state.activeStory) {
  const active = followingStories[index];
  if (!active) return { group: [], groupIndex: -1, userKey: "" };
  const userKey = normalizeProfileKey(active.user);
  const group = followingStories
    .map((story, sourceIndex) => ({ story, sourceIndex }))
    .filter((item) => normalizeProfileKey(item.story.user) === userKey);
  return {
    group,
    groupIndex: group.findIndex((item) => item.sourceIndex === index),
    userKey,
  };
}

function getStoryProfileOrder() {
  const seen = new Set();
  return followingStories.reduce((profiles, story, sourceIndex) => {
    const userKey = normalizeProfileKey(story.user);
    if (seen.has(userKey)) return profiles;
    seen.add(userKey);
    profiles.push({ userKey, firstIndex: sourceIndex });
    return profiles;
  }, []);
}

function getAdjacentStoryProfileIndex(direction = 1) {
  const active = followingStories[state.activeStory];
  if (!active) return null;
  const order = getStoryProfileOrder();
  const userKey = normalizeProfileKey(active.user);
  const profileIndex = order.findIndex((profile) => profile.userKey === userKey);
  const nextProfile = order[profileIndex + direction];
  return nextProfile ? nextProfile.firstIndex : null;
}

function jumpStoryProfile(direction = 1) {
  if (state.activeStory === null || state.activeStory === -1) return;
  if (direction > 0) markStoryViewed(state.activeStory);
  const nextIndex = getAdjacentStoryProfileIndex(direction);
  state.storyDirection = direction;
  state.storyPaused = false;
  state.storyComposerOpen = false;
  state.ownStoryStatsOpen = false;
  state.storyMusicInfoOpen = false;
  if (nextIndex === null) {
    closeStoryViewer();
    return;
  }
  state.activeStory = nextIndex;
  render();
}

function advanceStory(direction = 1, options = {}) {
  if (state.activeStory === null) return;
  if (options.completed || direction > 0) markStoryViewed(state.activeStory);
  state.storyDirection = direction;
  state.storyPaused = false;
  state.storyMusicInfoOpen = false;
  if (state.activeStory === -1) {
    const ownStories = getOwnStorySequence();
    const nextOwnIndex = state.activeOwnStoryIndex + direction;
    if (nextOwnIndex >= 0 && nextOwnIndex < ownStories.length) {
      state.activeOwnStoryIndex = nextOwnIndex;
      state.storyComposerOpen = false;
      state.ownStoryStatsOpen = false;
      render();
      return;
    }
    closeStoryViewer();
    return;
  }
  const { group, groupIndex } = getStoryGroupInfo(state.activeStory);
  const sameProfileItem = group[groupIndex + direction];
  if (!sameProfileItem) {
    if (direction > 0) jumpStoryProfile(1);
    else scheduleStoryAutoplay();
    return;
  }
  state.activeStory = sameProfileItem.sourceIndex;
  state.storyComposerOpen = false;
  state.ownStoryStatsOpen = false;
  render();
}

function setStoryPaused(paused) {
  if (state.activeStory === null) return;
  state.storyPaused = paused;
  if (paused) {
    clearStoryAutoplay();
  } else {
    scheduleStoryAutoplay();
  }
  document.getElementById("global-story-viewer")?.classList.toggle("story-paused", paused);
  document.querySelector(".story-viewer")?.classList.toggle("story-paused", paused);
  const media = document.querySelector(".story-full-media");
  if (media?.tagName === "VIDEO") {
    if (paused) {
      media.pause();
    } else {
      media.play?.().catch(() => {});
    }
  }
}

function isStoryInteractiveTarget(target) {
  return Boolean(
    target?.closest?.(
      "[data-story-star], [data-own-story-stats], [data-story-music-info], [data-story-audio-action], [data-story-message-open], [data-story-message-close], [data-story-send], [data-story-phrase], [data-story-message-input], .story-audio-sheet, .story-composer-sheet, .story-interactions, .story-close",
    ),
  );
}

function bindStoryTapZone(element) {
  let holdStart = 0;
  let handledPointer = false;
  let activePointerId = null;
  let startX = 0;
  let startY = 0;
  const pause = (event) => {
    if (isStoryInteractiveTarget(event.target)) return;
    event.preventDefault?.();
    activePointerId = event.pointerId ?? "touch";
    startX = event.clientX || 0;
    startY = event.clientY || 0;
    holdStart = Date.now();
    handledPointer = true;
    setStoryPaused(true);
  };
  const resume = (event) => {
    if (!handledPointer || isStoryInteractiveTarget(event.target)) return;
    event.preventDefault?.();
    if (activePointerId !== null && event.pointerId !== undefined && event.pointerId !== activePointerId) return;
    const heldLongEnough = Date.now() - holdStart > 250;
    const deltaX = (event.clientX || startX) - startX;
    const deltaY = (event.clientY || startY) - startY;
    const isHorizontalSwipe = Math.abs(deltaX) > 48 && Math.abs(deltaX) > Math.abs(deltaY) * 1.25;
    const direction = Number(element.dataset.storyNav || 0);
    setStoryPaused(false);
    if (!heldLongEnough) {
      if (isHorizontalSwipe && state.activeStory === -1) {
        closeStoryViewer();
      } else if (isHorizontalSwipe && state.activeStory !== -1) {
        jumpStoryProfile(deltaX < 0 ? 1 : -1);
      } else if (direction) {
        advanceStory(direction, { completed: direction > 0, closeAtEnd: false });
      }
    }
    element.dataset.suppressStoryNav = "true";
    setTimeout(() => delete element.dataset.suppressStoryNav, 120);
    handledPointer = false;
    activePointerId = null;
  };
  const cancel = (event) => {
    if (!handledPointer) return;
    event.preventDefault?.();
    setStoryPaused(false);
    handledPointer = false;
    activePointerId = null;
  };
  element.addEventListener("pointerdown", (event) => {
    pause(event);
  });
  element.addEventListener("pointerup", (event) => {
    resume(event);
  });
  element.addEventListener("pointercancel", cancel);
  element.addEventListener("pointerleave", (event) => {
    if (event.buttons) cancel(event);
  });
}

function toggleStoryStar(button) {
  const index = Number(button.dataset.storyStar);
  state.likedStories[index] = !state.likedStories[index];
  const active = Boolean(state.likedStories[index]);
  button.classList.toggle("active", active);
  button.classList.add("popped");
  const story = getActiveStory();
  const count = Number(story?.stars || 0) + (active ? 1 : 0);
  const label = button.closest(".story-like-line")?.querySelector("strong");
  if (label) label.textContent = `${count} estrellas`;
  playAppSound("like");
  setTimeout(() => button.classList.remove("popped"), 260);
}

function focusStoryMessageInput() {
  setTimeout(() => {
    const input = document.getElementById("story-message-input");
    input?.focus({ preventScroll: true });
  }, 60);
}

function openStoryComposer() {
  state.storyComposerOpen = true;
  state.storyPaused = true;
  clearStoryAutoplay();
  render();
  focusStoryMessageInput();
}

function handleMediaUpload(file, type = "media") {
  if (!file) return null;
  const mediaType = file.type?.startsWith("video") ? "video" : "image";
  const mediaUrl = URL.createObjectURL(file);
  return {
    mediaUrl,
    mediaType,
    mediaName: file.name || `${type}.${mediaType === "video" ? "mp4" : "jpg"}`,
    file,
  };
}

function readImageFileAsDataUrl(file) {
  if (!file || !file.type?.startsWith("image")) return Promise.resolve("");
  return new Promise((resolve) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result || "");
    reader.onerror = () => resolve("");
    reader.readAsDataURL(file);
  });
}

function isCurrentUserReference(item, user = state.user) {
  if (!item || !user) return false;
  const keys = [item.userId, item.username, item.user, item.name].filter(Boolean).map(normalizeProfileKey);
  const userKeys = [user.id, user.username, user.name].filter(Boolean).map(normalizeProfileKey);
  return keys.some((key) => userKeys.includes(key));
}

function syncCommentAvatarReferences(comments = [], user = state.user) {
  comments.forEach((comment) => {
    if (isCurrentUserReference(comment, user)) {
      comment.user = user.name;
      comment.username = user.username;
      comment.avatarUrl = user.avatarUrl;
      comment.avatar = user.avatar;
    }
    syncCommentAvatarReferences(comment.replies || [], user);
  });
}

function syncCurrentUserVisualReferences(user = state.user) {
  if (!user?.avatarUrl) return;
  state.session = state.session ? { ...state.session, user } : state.session;
  if (state.viewedProfile && isCurrentUserReference(state.viewedProfile, user)) {
    state.viewedProfile = { ...state.viewedProfile, ...user, avatarUrl: user.avatarUrl };
  }
  userPosts.forEach((post) => {
    if (isCurrentUserReference(post, user)) {
      post.user = user.name;
      post.username = user.username;
      post.userId = user.id;
      post.avatarUrl = user.avatarUrl;
      post.avatar = user.avatar;
    }
    syncCommentAvatarReferences(post.commentList || [], user);
  });
  trendVideos.forEach((drop) => {
    if (isCurrentUserReference(drop, user)) {
      drop.user = user.name;
      drop.username = user.username;
      drop.userId = user.id;
      drop.avatarUrl = user.avatarUrl;
    }
  });
  fancamVideos.forEach((fancam) => {
    if (isCurrentUserReference(fancam, user)) {
      fancam.user = user.name;
      fancam.username = user.username;
      fancam.userId = user.id;
      fancam.avatarUrl = user.avatarUrl;
    }
  });
  if (state.ownStory) {
    state.ownStory = { ...state.ownStory, user: user.name, avatar: user.avatar, avatarUrl: user.avatarUrl };
    storage.set("hallyuHubOwnStory", state.ownStory);
  }
  if (Array.isArray(state.ownStories) && state.ownStories.length) {
    state.ownStories = state.ownStories.map((story) => ({ ...story, user: user.name, avatar: user.avatar, avatarUrl: user.avatarUrl }));
    storage.set("hallyuHubOwnStories", state.ownStories);
  }
  storage.set("hallyuHubUserPosts", userPosts.filter((post) => String(post.id || "").startsWith("local-")));
  storage.set("hallyuHubUserDrops", trendVideos.filter((dropItem) => String(dropItem.id || "").startsWith("local-trends")));
  storage.set("hallyuHubUserFancams", fancamVideos.filter((item) => String(item.id || "").startsWith("local-fancams")));
}

function closeStoryViewer() {
  state.activeStory = null;
  state.storyComposerOpen = false;
  state.ownStoryStatsOpen = false;
  state.storyMusicInfoOpen = false;
  state.storyPaused = false;
  clearStoryAutoplay();
  render();
}

function clearStoryAutoplay() {
  if (storyAutoTimer) {
    clearTimeout(storyAutoTimer);
    storyAutoTimer = null;
  }
}

function scheduleStoryAutoplay() {
  clearStoryAutoplay();
  if (state.view !== "home" || state.activeStory === null || state.storyPaused) return;
  storyAutoTimer = setTimeout(() => {
    advanceStory(1, { completed: true });
  }, 4200);
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

  document.querySelectorAll("[data-toggle-app-sound]").forEach((button) => {
    button.addEventListener("click", () => {
      state.soundEnabled = !state.soundEnabled;
      storage.set("hallyuHubSoundEnabled", state.soundEnabled);
      playAppSound(state.soundEnabled ? "message" : "save");
      showToast(state.soundEnabled ? "Sonidos activados" : "Sonidos silenciados");
      render();
    });
  });

  document.querySelectorAll("[data-create-post]").forEach((button) => {
    button.addEventListener("click", createPost);
  });

  document.querySelectorAll("[data-publish-type]").forEach((button) => {
    button.addEventListener("click", () => {
      state.publishDraft.type = button.dataset.publishType;
      state.publishDraft.result = null;
      render();
    });
  });

  document.querySelectorAll("[data-publish-draft]").forEach((field) => {
    field.addEventListener("input", () => {
      const key = field.dataset.publishDraft;
      if (field.type === "checkbox") {
        state.publishDraft[key] = field.checked;
      } else {
        state.publishDraft[key] = field.value;
      }
    });
    field.addEventListener("change", () => {
      const key = field.dataset.publishDraft;
      state.publishDraft[key] = field.type === "checkbox" ? field.checked : field.value;
    });
  });

  document.querySelectorAll("[data-publish-file-trigger]").forEach((button) => {
    button.addEventListener("click", () => requestMediaAccessBeforeFile("publish-media-input", { source: "gallery", camera: false, mic: false }));
  });

  document.querySelectorAll("[data-publish-change-file]").forEach((button) => {
    button.addEventListener("click", () => requestMediaAccessBeforeFile("publish-media-input", { source: "gallery", camera: false, mic: false }));
  });

  document.querySelectorAll("[data-publish-remove-media]").forEach((button) => {
    button.addEventListener("click", () => {
      state.publishDraft.mediaUrl = "";
      state.publishDraft.mediaType = "";
      state.publishDraft.mediaName = "";
      render();
    });
  });

  document.querySelectorAll("#publish-media-input").forEach((input) => {
    input.addEventListener("change", () => {
      const file = input.files?.[0];
      if (!file) return;
      const media = handleMediaUpload(file, "publish");
      if (!media) return;
      state.publishDraft.mediaUrl = media.mediaUrl;
      state.publishDraft.mediaType = media.mediaType;
      state.publishDraft.mediaName = media.mediaName;
      state.publishDraft.result = null;
      render();
    });
  });

  document.querySelectorAll("[data-permission-allow]").forEach((button) => {
    button.addEventListener("click", () => continuePermissionRequest());
  });

  document.querySelectorAll("[data-permission-deny]").forEach((button) => {
    button.addEventListener("click", () => {
      rememberPermissionInfo(false);
      state.permissionPrompt = null;
      showToast("Podés seguir usando HallyuHub sin activar permisos ahora.");
      render();
    });
  });

  document.querySelectorAll("[data-publish-filter]").forEach((button) => {
    button.addEventListener("click", () => {
      state.publishDraft.filter = button.dataset.publishFilter;
      render();
    });
  });

  document.querySelectorAll("[data-publish-cancel]").forEach((button) => {
    button.addEventListener("click", () => {
      resetPublishDraft();
      setView("profile");
    });
  });

  document.querySelectorAll("[data-view-created]").forEach((button) => {
    button.addEventListener("click", () => openPublishedContent(button.dataset.viewCreated));
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
      const filter = button.dataset.homeFilter;
      if (filter.startsWith("#")) {
        openHashtagExplore(filter);
      } else {
        state.homeFilter = filter;
        renderAndScrollTop();
      }
    });
  });

  document.querySelectorAll("[data-toggle-post-more]").forEach((button) => {
    button.addEventListener("click", () => {
      const id = button.dataset.togglePostMore;
      state.expandedPosts[id] = !state.expandedPosts[id];
      render();
    });
  });

  document.querySelectorAll("[data-post-menu]").forEach((button) => {
    button.addEventListener("click", () => {
      const id = button.dataset.postMenu;
      state.openPostMenu = state.openPostMenu === id ? null : id;
      state.reportTarget = null;
      render();
    });
  });

  document.querySelectorAll("[data-report-post]").forEach((button) => {
    button.addEventListener("click", () => {
      state.reportTarget = `post:${button.dataset.reportPost}`;
      state.openPostMenu = null;
      render();
    });
  });

  document.querySelectorAll("[data-report-content]").forEach((button) => {
    button.addEventListener("click", () => {
      state.reportTarget = button.dataset.reportContent;
      state.openPostMenu = null;
      render();
    });
  });

  document.querySelectorAll("[data-report-reason]").forEach((button) => {
    button.addEventListener("click", () => savePostReport(button.dataset.reportReason));
  });

  document.querySelectorAll("[data-report-close]").forEach((button) => {
    button.addEventListener("click", () => {
      state.reportTarget = null;
      render();
    });
  });

  document.querySelectorAll("[data-open-artist-video]").forEach((button) => {
    button.addEventListener("click", () => {
      const video = officialVideoEmbeds.find((item) => item.youtubeId === button.dataset.openArtistVideo);
      if (!video) return;
      state.mediaEmbed = video;
      render();
    });
  });

  document.querySelectorAll("[data-close-media-embed]").forEach((button) => {
    button.addEventListener("click", () => {
      state.mediaEmbed = null;
      render();
    });
  });

  document.querySelectorAll("[data-admin-action]").forEach((button) => {
    button.addEventListener("click", () => {
      const [action, reportId] = button.dataset.adminAction.split(":");
      const exists = state.socialReports.some((report) => report.id === reportId);
      state.socialReports = exists
        ? state.socialReports.map((report) => (report.id === reportId ? { ...report, status: action } : report))
        : [{ id: reportId, targetType: "demo", targetId: reportId, user: "Reporte demo", reason: "Moderación demo", status: action, createdAt: new Date().toISOString() }, ...state.socialReports];
      storage.set("hallyuHubReports", state.socialReports);
      showToast(`Moderación demo: ${action}`);
      render();
    });
  });

  document.querySelectorAll("[data-hide-post]").forEach((button) => {
    button.addEventListener("click", () => hidePost(button.dataset.hidePost));
  });

  document.querySelectorAll("[data-unfollow-feed-user]").forEach((button) => {
    button.addEventListener("click", () => unfollowFeedUser(button.dataset.unfollowFeedUser));
  });

  document.querySelectorAll("[data-follow-feed-user]").forEach((button) => {
    button.addEventListener("click", () => followFeedUser(button.dataset.followFeedUser));
  });

  document.querySelectorAll("[data-edit-post]").forEach((button) => {
    button.addEventListener("click", () => {
      state.expandedPosts[button.dataset.editPost] = true;
      state.openPostMenu = null;
      showToast("Edicion de publicacion en modo demo");
      render();
    });
  });

  document.querySelectorAll("[data-delete-post]").forEach((button) => {
    button.addEventListener("click", () => hidePost(button.dataset.deletePost, "Publicacion eliminada en modo demo"));
  });

  document.querySelectorAll("[data-hashtag-sort]").forEach((button) => {
    button.addEventListener("click", () => {
      state.hashtagSort = button.dataset.hashtagSort;
      render();
    });
  });

  document.querySelectorAll("[data-toggle-comments]").forEach((button) => {
    button.addEventListener("click", () => {
      const id = button.dataset.toggleComments;
      state.openComments[id] = !state.openComments[id];
      render();
    });
  });

  document.querySelectorAll("[data-comment-draft]").forEach((input) => {
    input.addEventListener("input", () => {
      state.commentDrafts[input.dataset.commentDraft] = input.value;
    });
    input.addEventListener("keydown", (event) => {
      if (event.key === "Enter") {
        event.preventDefault();
        sendInlineComment(input.dataset.commentDraft);
      }
    });
  });

  document.querySelectorAll("[data-send-comment]").forEach((button) => {
    button.addEventListener("click", () => sendInlineComment(button.dataset.sendComment));
  });

  document.querySelectorAll("[data-comment-emoji]").forEach((button) => {
    button.addEventListener("click", () => {
      const [postId, emoji] = button.dataset.commentEmoji.split("|");
      state.commentDrafts[postId] = `${state.commentDrafts[postId] || ""}${emoji}`;
      render();
    });
  });

  document.querySelectorAll("[data-reply-comment]").forEach((button) => {
    button.addEventListener("click", () => {
      const [postId, commentId, username] = button.dataset.replyComment.split(":");
      state.replyTo[postId] = commentId;
      state.commentDrafts[postId] = `@${username} `;
      render();
    });
  });

  document.querySelectorAll("[data-like-comment]").forEach((button) => {
    button.addEventListener("click", () => likeComment(button.dataset.likeComment));
  });

  document.querySelectorAll("[data-cancel-reply]").forEach((button) => {
    button.addEventListener("click", () => {
      const postId = button.dataset.cancelReply;
      state.replyTo[postId] = null;
      state.commentDrafts[postId] = "";
      render();
    });
  });

  document.querySelectorAll("[data-save-post]").forEach((button) => {
    button.addEventListener("click", () => {
      const id = button.dataset.savePost;
      const baseId = getBasePostId(id);
      state.savedPosts[baseId] = !state.savedPosts[baseId];
      storage.set("hallyuHubSavedPosts", state.savedPosts);
      showToast(state.savedPosts[baseId] ? "Publicacion guardada" : "Publicacion quitada de guardados");
      if (state.savedPosts[baseId]) playAppSound("save");
      render();
    });
  });

  document.querySelectorAll("[data-share-post]").forEach((button) => {
    button.addEventListener("click", () => {
      const id = button.dataset.sharePost;
      state.sharePostTarget = state.sharePostTarget === id ? null : id;
      state.sharedPosts[id] = true;
      storage.set("hallyuHubSharedPosts", state.sharedPosts);
      render();
    });
  });

  document.querySelectorAll("[data-close-post-share]").forEach((button) => {
    button.addEventListener("click", () => {
      state.sharePostTarget = null;
      render();
    });
  });

  document.querySelectorAll("[data-share-sheet]").forEach((sheet) => {
    let startY = 0;
    let currentY = 0;
    sheet.addEventListener("pointerdown", (event) => {
      startY = event.clientY;
      currentY = event.clientY;
      sheet.dataset.dragging = "true";
    });
    sheet.addEventListener("pointermove", (event) => {
      if (sheet.dataset.dragging !== "true") return;
      currentY = event.clientY;
      const distance = Math.max(0, currentY - startY);
      sheet.style.transform = `translateY(${Math.min(distance, 120)}px)`;
    });
    sheet.addEventListener("pointerup", () => {
      const shouldClose = currentY - startY > 64;
      sheet.dataset.dragging = "false";
      sheet.style.transform = "";
      if (shouldClose) {
        state.sharePostTarget = null;
        render();
      }
    });
  });

  document.querySelectorAll("[data-open-feed-profile]").forEach((button) => {
    button.addEventListener("click", () => openFeedProfile(button.dataset.openFeedProfile));
  });

  document.querySelectorAll("[data-story-index]").forEach((button) => {
    button.addEventListener("click", () => {
      state.activeStory = getStoryOpenIndex(Number(button.dataset.storyIndex));
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
        state.activeOwnStoryIndex = getFirstUnviewedOwnStoryIndex();
        state.storyDirection = 1;
        state.storyPaused = false;
      } else {
        state.storyEditorOpen = true;
      }
      state.storyComposerOpen = false;
      state.ownStoryStatsOpen = false;
      state.storyMusicInfoOpen = false;
      state.storyPaused = false;
      render();
    });
  });

  document.querySelectorAll("[data-create-own-story]").forEach((button) => {
    button.addEventListener("click", () => publishStoryFromEditor(button.dataset.createOwnStory));
  });

  document.querySelectorAll("[data-story-editor-open]").forEach((button) => {
    button.addEventListener("touchstart", (event) => event.stopPropagation(), { passive: true });
    button.addEventListener("pointerdown", (event) => event.stopPropagation());
    button.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
      state.activeStory = null;
      state.storyEditorOpen = true;
      state.storyToolPanel = null;
      state.storyComposerOpen = false;
      state.ownStoryStatsOpen = false;
      state.storyMusicInfoOpen = false;
      clearStoryAutoplay();
      render();
    });
  });

  document.querySelectorAll("[data-story-editor-close]").forEach((button) => {
    button.addEventListener("click", () => {
      state.storyEditorOpen = false;
      state.storyToolPanel = null;
      render();
    });
  });

  document.querySelectorAll("[data-story-tool]").forEach((button) => {
    button.addEventListener("click", () => {
      const tool = button.dataset.storyTool;
      state.storyToolPanel = state.storyToolPanel === tool ? null : tool;
      render();
    });
  });

  document.querySelectorAll("[data-story-tool-close]").forEach((button) => {
    button.addEventListener("click", () => {
      state.storyToolPanel = null;
      render();
    });
  });

  document.querySelectorAll("[data-story-draft]").forEach((input) => {
    input.addEventListener("input", () => {
      state.storyDraft[input.dataset.storyDraft] = input.value;
      syncStoryDraftElement(input.dataset.storyDraft, input.value);
    });
  });

  document.querySelectorAll("[data-story-bg]").forEach((button) => {
    button.addEventListener("click", () => {
      state.storyDraft.background = button.dataset.storyBg;
      render();
    });
  });

  document.querySelectorAll("[data-story-sticker]").forEach((button) => {
    button.addEventListener("click", () => {
      state.storyDraft.sticker = button.dataset.storySticker;
      addStoryElement(button.dataset.storySticker);
      state.storyToolPanel = null;
      render();
    });
  });

  document.querySelectorAll("[data-story-sticker-category]").forEach((button) => {
    button.addEventListener("click", () => {
      state.storyDraft.stickerCategory = button.dataset.storyStickerCategory;
      render();
    });
  });

  document.querySelectorAll("[data-protected-file]").forEach((button) => {
    button.addEventListener("click", () => {
      requestMediaAccessBeforeFile(button.dataset.protectedFile, {
        source: button.dataset.permissionSource || "gallery",
        camera: button.dataset.permissionCamera === "true",
        mic: button.dataset.permissionMic === "true",
      });
    });
  });

  document.querySelectorAll("[data-story-custom-sticker]").forEach((input) => {
    input.addEventListener("change", () => {
      const file = input.files?.[0];
      if (!file) return;
      const reader = new FileReader();
      reader.onload = () => {
        addStoryElement(file.name.replace(/\.[^.]+$/, "") || "Sticker", { imageUrl: reader.result || "", type: "custom-sticker" });
        state.storyToolPanel = null;
        render();
      };
      reader.readAsDataURL(file);
    });
  });

  document.querySelectorAll("[data-video-editor-file]").forEach((input) => {
    input.addEventListener("change", () => {
      const file = input.files?.[0];
      if (!file) return;
      if (!file.type.startsWith("video")) {
        showToast("Elegí un video para publicar");
        return;
      }
      const maxSize = 18 * 1024 * 1024;
      if (file.size > maxSize) {
        state.videoEditorDraft.error = "El video es muy pesado para esta demo. Probá con uno más corto.";
        state.videoEditorDraft.loading = false;
        state.videoEditorDraft.mediaUrl = "";
        showToast("Video demasiado pesado para cargar en mobile");
        render();
        return;
      }
      state.videoEditorDraft.loading = true;
      state.videoEditorDraft.error = "";
      render();
      try {
        const media = handleMediaUpload(file, state.videoEditorDraft.kind);
        state.videoEditorDraft.mediaUrl = media.mediaUrl;
        state.videoEditorDraft.mediaType = "video";
        state.videoEditorDraft.mediaName = media.mediaName;
        state.videoEditorDraft.start = "0";
        state.videoEditorDraft.end = state.videoEditorDraft.kind === "fancams" ? "180" : "60";
        state.videoEditorDraft.duration = state.videoEditorDraft.kind === "fancams" ? "180" : "60";
        state.videoEditorDraft.loading = false;
        state.videoEditorDraft.error = "";
        state.videoEditorDraft.result = null;
        render();
      } catch {
        state.videoEditorDraft.loading = false;
        state.videoEditorDraft.error = "No pudimos cargar el video. Probá con otro archivo.";
        showToast("No pudimos cargar el video");
        render();
      }
    });
  });

  document.querySelectorAll("[data-video-editor-cover]").forEach((input) => {
    input.addEventListener("change", () => {
      const file = input.files?.[0];
      if (!file) return;
      const reader = new FileReader();
      reader.onload = () => {
        state.videoEditorDraft.coverUrl = reader.result || "";
        state.videoEditorDraft.coverName = file.name;
        render();
      };
      reader.readAsDataURL(file);
    });
  });

  document.querySelectorAll("[data-story-layer]").forEach((button) => {
    button.addEventListener("pointerdown", (event) => startStoryElementDrag(event, button.dataset.storyLayer));
    button.addEventListener("click", () => {
      state.storyDraft.selectedElementId = button.dataset.storyLayer;
      state.storyToolPanel = "adjust";
      render();
    });
  });

  document.querySelectorAll("[data-story-music]").forEach((button) => {
    button.addEventListener("click", () => {
      state.storyDraft.music = button.dataset.storyMusic;
      playStoryMusicPreview(button.dataset.storyMusic);
      state.storyToolPanel = null;
      render();
    });
  });

  document.querySelectorAll("[data-story-music-preview]").forEach((button) => {
    button.addEventListener("click", () => playStoryMusicPreview(button.dataset.storyMusicPreview));
  });

  document.querySelectorAll("[data-story-music-category]").forEach((button) => {
    button.addEventListener("click", () => {
      state.storyDraft.musicCategory = button.dataset.storyMusicCategory;
      render();
    });
  });

  document.querySelectorAll("[data-story-control]").forEach((input) => {
    input.addEventListener("input", () => {
      updateSelectedStoryElement(input.dataset.storyControl, Number(input.value));
      render();
    });
  });

  document.querySelectorAll("[data-story-font]").forEach((button) => {
    button.addEventListener("click", () => {
      state.storyDraft.font = button.dataset.storyFont;
      updateSelectedTextElement("font", button.dataset.storyFont);
      render();
    });
  });

  document.querySelectorAll("[data-story-text-color]").forEach((button) => {
    button.addEventListener("click", () => {
      state.storyDraft.textColor = button.dataset.storyTextColor;
      updateSelectedTextElement("color", button.dataset.storyTextColor);
      render();
    });
  });

  document.querySelectorAll("[data-story-text-style]").forEach((button) => {
    button.addEventListener("click", () => {
      state.storyDraft.textStyle = button.dataset.storyTextStyle;
      updateSelectedTextElement("textStyle", button.dataset.storyTextStyle);
      render();
    });
  });

  document.querySelectorAll("[data-drop-filter]").forEach((button) => {
    button.addEventListener("click", () => {
      state.dropFeedFilter = button.dataset.dropFilter;
      showToast(`Drops: ${button.textContent.trim()}`);
      render();
    });
  });

  document.querySelectorAll("[data-create-drop]").forEach((button) => {
    button.addEventListener("click", () => {
      resetVideoEditorDraft("trends");
      state.dropCreatorOpen = true;
      state.dropSearchOpen = false;
      render();
    });
  });

  document.querySelectorAll("[data-create-fancam]").forEach((button) => {
    button.addEventListener("click", () => {
      resetVideoEditorDraft("fancams");
      state.fancamCreatorOpen = true;
      state.fancamFilterOpen = false;
      render();
    });
  });

  document.querySelectorAll("[data-search-drops]").forEach((button) => {
    button.addEventListener("click", () => {
      state.dropSearchOpen = true;
      state.dropCreatorOpen = false;
      render();
    });
  });

  document.querySelectorAll("[data-close-drop-search]").forEach((button) => {
    button.addEventListener("click", () => {
      state.dropSearchOpen = false;
      render();
    });
  });

  document.querySelectorAll("[data-drop-search-input]").forEach((input) => {
    input.addEventListener("input", () => {
      state.dropSearchQuery = input.value;
      render();
      setTimeout(() => {
        const nextInput = document.querySelector("[data-drop-search-input]");
        if (!nextInput) return;
        nextInput.focus();
        nextInput.setSelectionRange(state.dropSearchQuery.length, state.dropSearchQuery.length);
      }, 0);
    });
  });

  document.querySelectorAll("[data-drop-result]").forEach((button) => {
    button.addEventListener("click", () => {
      state.dropSearchSelection = button.dataset.dropResult;
      state.dropSearchQuery = button.dataset.dropResult;
      state.dropSearchOpen = false;
      showToast(`Drops relacionados: ${button.dataset.dropResult}`);
      render();
    });
  });

  document.querySelectorAll("[data-clear-drop-search]").forEach((button) => {
    button.addEventListener("click", () => {
      state.dropSearchQuery = "";
      state.dropSearchSelection = "";
      render();
    });
  });

  document.querySelectorAll("[data-close-drop-creator]").forEach((button) => {
    button.addEventListener("click", () => {
      state.dropCreatorOpen = false;
      resetVideoEditorDraft("trends");
      render();
    });
  });

  document.querySelectorAll("[data-close-video-editor]").forEach((button) => {
    button.addEventListener("click", () => {
      const kind = state.videoEditorDraft.kind;
      state.dropCreatorOpen = false;
      state.fancamCreatorOpen = false;
      resetVideoEditorDraft(kind);
      render();
    });
  });

  document.querySelectorAll("[data-video-editor-field]").forEach((field) => {
    field.addEventListener("input", () => {
      state.videoEditorDraft[field.dataset.videoEditorField] = field.type === "checkbox" ? field.checked : field.value;
    });
    field.addEventListener("change", () => {
      state.videoEditorDraft[field.dataset.videoEditorField] = field.type === "checkbox" ? field.checked : field.value;
      render();
    });
  });

  document.querySelectorAll("[data-video-editor-filter]").forEach((button) => {
    button.addEventListener("click", () => {
      state.videoEditorDraft.filter = button.dataset.videoEditorFilter;
      render();
    });
  });

  document.querySelectorAll("[data-video-editor-sticker]").forEach((button) => {
    button.addEventListener("click", () => {
      state.videoEditorDraft.sticker = button.dataset.videoEditorSticker;
      render();
    });
  });

  document.querySelectorAll("[data-video-editor-remove-media]").forEach((button) => {
    button.addEventListener("click", () => {
      state.videoEditorDraft.mediaUrl = "";
      state.videoEditorDraft.mediaType = "";
      state.videoEditorDraft.mediaName = "";
      state.videoEditorDraft.result = null;
      render();
    });
  });

  document.querySelectorAll("[data-video-editor-toggle]").forEach((button) => {
    button.addEventListener("click", () => {
      const key = button.dataset.videoEditorToggle;
      state.videoEditorDraft[key] = !state.videoEditorDraft[key];
      render();
    });
  });

  document.querySelectorAll("[data-video-editor-publish]").forEach((button) => {
    button.addEventListener("click", () => publishVideoEditorContent());
  });

  document.querySelectorAll("[data-video-editor-preview]").forEach((video) => {
    video.addEventListener("loadedmetadata", () => syncVideoEditorDuration(video));
    video.addEventListener("timeupdate", () => stopVideoAtTrimEnd(video));
  });

  document.querySelectorAll("[data-video-trim-handle]").forEach((handle) => {
    handle.addEventListener("pointerdown", (event) => startVideoTrimDrag(event, handle.dataset.videoTrimHandle));
  });

  document.querySelectorAll("[data-video-trim-range]").forEach((range) => {
    range.addEventListener("pointerdown", (event) => startVideoTrimDrag(event, "range"));
  });

  document.querySelectorAll("[data-video-trim-track]").forEach((track) => {
    track.addEventListener("pointerdown", (event) => {
      if (event.target.closest("[data-video-trim-range]") || event.target.closest("[data-video-trim-handle]")) return;
      moveNearestTrimHandle(event, track);
    });
  });

  document.querySelectorAll("[data-video-preview-range]").forEach((button) => {
    button.addEventListener("click", playSelectedVideoRange);
  });

  document.querySelectorAll("[data-drop-effect]").forEach((button) => {
    button.addEventListener("click", () => {
      state.dropEffect = button.dataset.dropEffect;
      render();
    });
  });

  document.querySelectorAll("[data-drop-action]").forEach((button) => {
    button.addEventListener("click", () => {
      const [action, id] = button.dataset.dropAction.split(":");
      handleDropAction(action, id);
      render();
    });
  });

  document.querySelectorAll("[data-drop-toggle]").forEach((button) => {
    button.addEventListener("click", () => {
      const id = button.dataset.dropToggle;
      state.dropPaused[id] = !state.dropPaused[id];
      state.dropFeedback[id] = state.dropPaused[id] ? "play" : "pause";
      render();
      setTimeout(() => {
        if (state.dropFeedback[id]) {
          delete state.dropFeedback[id];
          render();
        }
      }, 520);
    });
  });

  document.querySelectorAll("[data-drop-share-copy]").forEach((button) => {
    button.addEventListener("click", () => {
      showToast("Enlace del Drop copiado en modo demo");
      state.dropShareOpen[button.dataset.dropShareCopy] = false;
      render();
    });
  });

  document.querySelectorAll("[data-drop-comment-send]").forEach((button) => {
    button.addEventListener("click", () => {
      sendVideoComment("drop", button.dataset.dropCommentSend);
    });
  });

  document.querySelectorAll("[data-toggle-drop-text]").forEach((button) => {
    button.addEventListener("click", () => {
      const id = button.dataset.toggleDropText;
      state.expandedPosts[`drop-${id}`] = !state.expandedPosts[`drop-${id}`];
      render();
    });
  });

  document.querySelectorAll("[data-open-video-profile]").forEach((button) => {
    button.addEventListener("click", () => {
      state.videoProfileOverlay = button.dataset.openVideoProfile;
      render();
    });
  });

  document.querySelectorAll("[data-close-video-profile]").forEach((button) => {
    button.addEventListener("click", () => {
      state.videoProfileOverlay = null;
      render();
    });
  });

  document.querySelectorAll("[data-open-video-fullscreen]").forEach((button) => {
    button.addEventListener("click", () => {
      state.videoFullscreen = button.dataset.openVideoFullscreen;
      render();
    });
  });

  document.querySelectorAll("[data-close-video-fullscreen]").forEach((button) => {
    button.addEventListener("click", () => {
      state.videoFullscreen = null;
      render();
    });
  });

  document.querySelectorAll("[data-toggle-video-sound]").forEach((button) => {
    button.addEventListener("click", () => {
      state.videoMuted = !state.videoMuted;
      storage.set("hallyuHubVideoMuted", state.videoMuted);
      showToast(state.videoMuted ? "Audio silenciado" : "Audio activado");
      render();
    });
  });

  document.querySelectorAll("[data-fancam-search-input]").forEach((input) => {
    input.addEventListener("input", () => {
      state.fancamSearchQuery = input.value;
      render();
      setTimeout(() => {
        const nextInput = document.querySelector("[data-fancam-search-input]");
        if (!nextInput) return;
        nextInput.focus();
        nextInput.setSelectionRange(state.fancamSearchQuery.length, state.fancamSearchQuery.length);
      }, 0);
    });
  });

  document.querySelectorAll("[data-toggle-fancam-filter]").forEach((button) => {
    button.addEventListener("click", () => {
      state.fancamFilterOpen = !state.fancamFilterOpen;
      render();
    });
  });

  document.querySelectorAll("[data-toggle-fancam-text]").forEach((button) => {
    button.addEventListener("click", () => {
      const id = button.dataset.toggleFancamText;
      state.expandedPosts[`fancam-${id}`] = !state.expandedPosts[`fancam-${id}`];
      render();
    });
  });

  document.querySelectorAll("[data-clear-fancam-search]").forEach((button) => {
    button.addEventListener("click", () => {
      state.fancamSearchQuery = "";
      state.fancamGroupFilter = "all";
      state.fancamArtistFilter = "all";
      state.fancamSort = "recommended";
      render();
    });
  });

  document.querySelectorAll("[data-fancam-group]").forEach((button) => {
    button.addEventListener("click", () => {
      state.fancamGroupFilter = button.dataset.fancamGroup;
      state.fancamArtistFilter = "all";
      render();
    });
  });

  document.querySelectorAll("[data-fancam-artist]").forEach((button) => {
    button.addEventListener("click", () => {
      state.fancamArtistFilter = button.dataset.fancamArtist;
      render();
    });
  });

  document.querySelectorAll("[data-fancam-sort]").forEach((button) => {
    button.addEventListener("click", () => {
      state.fancamSort = button.dataset.fancamSort;
      render();
    });
  });

  document.querySelectorAll("[data-fancam-action]").forEach((button) => {
    button.addEventListener("click", () => {
      const [action, id] = button.dataset.fancamAction.split(":");
      handleFancamAction(action, id);
      render();
    });
  });

  document.querySelectorAll("[data-fancam-toggle]").forEach((button) => {
    button.addEventListener("click", () => {
      const id = button.dataset.fancamToggle;
      state.fancamPaused[id] = !state.fancamPaused[id];
      state.fancamFeedback[id] = true;
      render();
      setTimeout(() => {
        delete state.fancamFeedback[id];
        render();
      }, 520);
    });
  });

  document.querySelectorAll("[data-fancam-comment-send]").forEach((button) => {
    button.addEventListener("click", () => {
      sendVideoComment("fancam", button.dataset.fancamCommentSend);
    });
  });

  document.querySelectorAll("[data-video-comment-draft]").forEach((input) => {
    input.addEventListener("input", () => {
      state.videoCommentDrafts[input.dataset.videoCommentDraft] = input.value;
    });
    input.addEventListener("keydown", (event) => {
      if (event.key === "Enter") {
        event.preventDefault();
        const [type, id] = input.dataset.videoCommentDraft.split(":");
        sendVideoComment(type, id);
      }
    });
  });

  document.querySelectorAll("[data-video-comment-reply]").forEach((button) => {
    button.addEventListener("click", () => {
      const [key, commentId, username] = button.dataset.videoCommentReply.split("|");
      if (!commentId) {
        state.videoCommentReplyTo[key] = null;
        state.videoCommentDrafts[key] = "";
        render();
        return;
      }
      state.videoCommentReplyTo[key] = commentId;
      state.videoCommentDrafts[key] = `@${username} `;
      render();
    });
  });

  document.querySelectorAll("[data-video-comment-like]").forEach((button) => {
    button.addEventListener("click", () => {
      likeVideoComment(button.dataset.videoCommentLike);
    });
  });

  document.querySelectorAll("[data-open-fancam-artist]").forEach((button) => {
    button.addEventListener("click", () => {
      const fancam = fancamVideos.find((item) => item.artistId === button.dataset.openFancamArtist);
      state.videoProfileOverlay = `fancam:${fancam?.id || button.dataset.openFancamArtist}`;
      render();
    });
  });

  document.querySelectorAll("[data-open-artist-fancams]").forEach((button) => {
    button.addEventListener("click", () => {
      const artistId = button.dataset.openArtistFancams;
      const fancam = fancamVideos.find((item) => item.artistId === artistId);
      state.fancamGroupFilter = fancam?.groupId || "all";
      state.fancamArtistFilter = artistId;
      state.fancamSort = "all";
      setView("fancams");
    });
  });

  document.querySelectorAll("[data-demo-action]").forEach((button) => {
    button.addEventListener("click", () => showToast(button.dataset.demoAction));
  });

  document.querySelectorAll("[data-story-delete-element]").forEach((button) => {
    button.addEventListener("click", () => {
      const id = state.storyDraft.selectedElementId;
      state.storyDraft.elements = (state.storyDraft.elements || []).filter((element) => element.id !== id);
      state.storyDraft.selectedElementId = state.storyDraft.elements[0]?.id || "";
      render();
    });
  });

  document.querySelectorAll("[data-story-media]").forEach((input) => {
    input.addEventListener("change", () => {
      const file = input.files?.[0];
      state.storyDraft.type = input.dataset.storyMedia;
      state.storyDraft.mediaName = file?.name || "";
      state.storyDraft.text = state.storyDraft.text || "";
      state.storyDraft.mediaType = file?.type?.startsWith("video") ? "video" : file ? "image" : "";
      resetStoryMediaTransform();
      if (!file) {
        render();
        return;
      }
      const media = handleMediaUpload(file, "story");
      if (!media) return;
      state.storyDraft.mediaUrl = media.mediaUrl;
      state.storyDraft.mediaType = media.mediaType;
      state.storyDraft.mediaName = media.mediaName;
      render();
    });
  });

  document.querySelectorAll("[data-story-media-transform]").forEach((element) => {
    element.addEventListener("touchstart", startStoryMediaTouchTransform, { passive: false });
    element.addEventListener("pointerdown", startStoryMediaTransform);
  });

  document.querySelectorAll("[data-story-close]").forEach((button) => {
    button.addEventListener("click", () => {
      markStoryViewed(state.activeStory);
      state.activeStory = null;
      state.storyComposerOpen = false;
      state.ownStoryStatsOpen = false;
      state.storyMusicInfoOpen = false;
      state.storyPaused = false;
      clearStoryAutoplay();
      render();
    });
  });

  document.querySelectorAll("[data-story-nav]").forEach((button) => {
    button.addEventListener("click", (event) => {
      event.preventDefault();
      if (button.dataset.suppressStoryNav === "true") {
        delete button.dataset.suppressStoryNav;
        return;
      }
      const direction = Number(button.dataset.storyNav);
      advanceStory(direction, { completed: direction > 0, closeAtEnd: false });
    });
  });

  document.querySelectorAll("[data-story-nav]").forEach(bindStoryTapZone);

  document.querySelectorAll("[data-own-story-stats]").forEach((button) => {
    button.addEventListener("click", () => {
      state.ownStoryStatsOpen = !state.ownStoryStatsOpen;
      state.storyMusicInfoOpen = false;
      render();
    });
  });

  document.querySelectorAll("[data-story-music-info]").forEach((button) => {
    button.addEventListener("touchstart", (event) => event.stopPropagation(), { passive: true });
    button.addEventListener("pointerdown", (event) => event.stopPropagation());
    button.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
      state.storyMusicInfoOpen = !state.storyMusicInfoOpen;
      state.ownStoryStatsOpen = false;
      render();
    });
  });

  document.querySelectorAll("[data-story-audio-action]").forEach((button) => {
    button.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
      const action = button.dataset.storyAudioAction;
      const story = getActiveStory();
      if (action === "use") {
        state.storyDraft.music = story?.music || state.storyDraft.music;
        state.storyDraft.musicCategory = story?.musicCategory || state.storyDraft.musicCategory;
        state.storyMusicInfoOpen = false;
        showToast("Audio agregado a tu editor");
      } else {
        state.storyMusicInfoOpen = false;
        state.view = "trends";
        showToast("Mostrando contenido con este audio");
        scrollToTop();
      }
      render();
    });
  });

  document.querySelectorAll("[data-story-star]").forEach((button) => {
    button.addEventListener("touchstart", (event) => event.stopPropagation(), { passive: true });
    button.addEventListener("pointerdown", (event) => event.stopPropagation());
    button.addEventListener("touchend", (event) => {
      event.preventDefault();
      event.stopPropagation();
      button.dataset.touchHandled = "true";
      toggleStoryStar(button);
      setTimeout(() => delete button.dataset.touchHandled, 80);
    });
    button.addEventListener("click", (event) => {
      event.stopPropagation();
      if (button.dataset.touchHandled === "true") return;
      toggleStoryStar(button);
    });
  });

  document.querySelectorAll("[data-story-message-open]").forEach((button) => {
    button.addEventListener("touchstart", (event) => event.stopPropagation(), { passive: true });
    button.addEventListener("pointerdown", (event) => event.stopPropagation());
    button.addEventListener("touchend", (event) => {
      event.preventDefault();
      event.stopPropagation();
      button.dataset.touchHandled = "true";
      openStoryComposer();
      setTimeout(() => delete button.dataset.touchHandled, 80);
    });
    button.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
      if (button.dataset.touchHandled === "true") return;
      openStoryComposer();
    });
  });

  document.querySelectorAll("[data-story-message-close]").forEach((button) => {
    button.addEventListener("touchstart", (event) => event.stopPropagation(), { passive: true });
    button.addEventListener("pointerdown", (event) => event.stopPropagation());
    button.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
      state.storyComposerOpen = false;
      state.storyPaused = false;
      render();
    });
  });

  document.querySelectorAll("[data-story-message-input]").forEach((input) => {
    input.addEventListener("focus", () => setStoryPaused(true));
    input.addEventListener("touchstart", (event) => event.stopPropagation(), { passive: true });
    input.addEventListener("touchend", (event) => event.stopPropagation(), { passive: true });
    input.addEventListener("pointerdown", (event) => event.stopPropagation());
  });

  document.querySelectorAll("[data-story-phrase]").forEach((button) => {
    button.addEventListener("touchstart", (event) => event.stopPropagation(), { passive: true });
    button.addEventListener("pointerdown", (event) => event.stopPropagation());
    button.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
      sendStoryMessage(button.dataset.storyPhrase);
    });
  });

  document.querySelectorAll("[data-story-send]").forEach((button) => {
    button.addEventListener("touchstart", (event) => event.stopPropagation(), { passive: true });
    button.addEventListener("pointerdown", (event) => event.stopPropagation());
    button.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
      const input = document.getElementById("story-message-input");
      sendStoryMessage(input?.value.trim() || "Saranghae 💜");
    });
  });

  document.querySelectorAll("[data-like-post]").forEach((button) => {
    button.addEventListener("click", () => toggleLike(button.dataset.likePost));
  });

  document.querySelectorAll("[data-comment-post]").forEach((button) => {
    button.addEventListener("click", () => {
      const id = button.dataset.commentPost;
      state.openComments[id] = !state.openComments[id];
      render();
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
      state.profileAvatarPreviewUrl = "";
      state.profileEditorOpen = true;
      render();
    });
  });

  document.querySelectorAll("[data-profile-edit-close]").forEach((button) => {
    button.addEventListener("click", () => {
      state.profileAvatarPreviewUrl = "";
      state.profileEditorOpen = false;
      render();
    });
  });

  document.querySelectorAll("[data-save-profile-edit]").forEach((button) => {
    button.addEventListener("click", saveProfileEdit);
  });

  document.querySelectorAll("#profile-edit-avatar-file").forEach((input) => {
    input.addEventListener("change", async () => {
      const file = input.files?.[0];
      if (!file) return;
      const previewUrl = await readImageFileAsDataUrl(file);
      if (!previewUrl) {
        showToast("No pudimos leer la foto de perfil");
        return;
      }
      state.profileAvatarPreviewUrl = previewUrl;
      render();
    });
  });

  document.querySelectorAll("#settings-avatar-file").forEach((input) => {
    input.addEventListener("change", async () => {
      const file = input.files?.[0];
      if (!file) return;
      const previewUrl = await readImageFileAsDataUrl(file);
      if (!previewUrl) {
        showToast("No pudimos leer la foto de perfil");
        return;
      }
      state.settingsAvatarPreviewUrl = previewUrl;
      render();
    });
  });

  document.querySelectorAll("[data-open-profile]").forEach((button) => {
    button.addEventListener("click", () => {
      const profile = state.liveProfiles.find((item) => item.id === button.dataset.openProfile);
      const demoProfile = demoUsers.find((item) => item.id === button.dataset.openProfile);
      if (!profile && !demoProfile) return;
      state.profileEditorOpen = false;
      state.viewedProfile = demoProfile ? getDemoProfilePayload(demoProfile) : {
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
      renderAndScrollTop();
    });
  });

  document.querySelectorAll("[data-story-reshare]").forEach((button) => {
    button.addEventListener("click", () => {
      showToast("Recuerdos disponible próximamente");
    });
  });

  document.querySelectorAll("[data-toggle-premium]").forEach((button) => {
    button.addEventListener("click", () => {
      state.user = {
        ...state.user,
        premium: !state.user.premium,
        themePremium: !state.user.premium,
      };
      state.user = userService.saveCurrentUser(state.user);
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
      state.selectedArtist = null;
      renderAndScrollTop();
    });
  });

  document.querySelectorAll("[data-group-search]").forEach((input) => {
    input.addEventListener("input", () => {
      state.groupSearch = input.value;
      const firstMatch = getFilteredGroups()[0];
      if (firstMatch) state.selectedGroup = firstMatch.id;
      state.selectedArtist = null;
      render();
      setTimeout(() => {
        const nextInput = document.querySelector("[data-group-search]");
        if (!nextInput) return;
        nextInput.focus();
        nextInput.setSelectionRange(state.groupSearch.length, state.groupSearch.length);
      }, 0);
    });
  });

  document.querySelectorAll("[data-group-filter]").forEach((button) => {
    button.addEventListener("click", () => {
      state.groupFilter = button.dataset.groupFilter;
      const firstMatch = getFilteredGroups()[0];
      if (firstMatch) state.selectedGroup = firstMatch.id;
      state.selectedArtist = null;
      renderAndScrollTop();
    });
  });

  document.querySelectorAll("[data-fan-content-filter]").forEach((button) => {
    button.addEventListener("click", () => {
      state.fanContentFilter = button.dataset.fanContentFilter;
      render();
    });
  });

  document.querySelectorAll("[data-hide-fan-content]").forEach((button) => {
    button.addEventListener("click", () => {
      state.hiddenFanContent[button.dataset.hideFanContent] = true;
      storage.set("hallyuHubHiddenFanContent", state.hiddenFanContent);
      showToast("Contenido fan ocultado");
      render();
    });
  });

  document.querySelectorAll("[data-block-fan-user]").forEach((button) => {
    button.addEventListener("click", () => {
      const username = button.dataset.blockFanUser;
      state.mutedUsers[normalizeProfileKey(username)] = true;
      storage.set("hallyuHubMutedUsers", state.mutedUsers);
      showToast(`Usuario bloqueado: ${username}`);
      render();
    });
  });

  document.querySelectorAll("[data-artist-profile]").forEach((button) => {
    button.addEventListener("click", () => {
      openArtistProfile(button.dataset.artistProfile);
    });
  });

  document.querySelectorAll("[data-close-artist]").forEach((button) => {
    button.addEventListener("click", () => {
      state.selectedArtist = null;
      renderAndScrollTop();
    });
  });

  document.querySelectorAll("[data-go-view]").forEach((button) => {
    button.addEventListener("click", () => setView(button.dataset.goView));
  });

  bindFallbackButtonActions();
}

function bindFallbackButtonActions() {
  document.querySelectorAll("button").forEach((button) => {
    if (button.dataset.fallbackReady === "true" || button.disabled) return;
    const hasDataAction = Object.keys(button.dataset || {}).some((key) => key !== "fallbackReady");
    const hasNativeAction = button.type === "submit" || button.closest("a[href]");
    if (hasDataAction || hasNativeAction) return;
    button.dataset.fallbackReady = "true";
    button.addEventListener("click", () => showToast("Estamos preparando esta función"));
  });
}

function openArtistProfile(artistId) {
  const group = kpopGroups.find((item) => (item.artists || []).some((artist) => artist.id === artistId));
  if (group) state.selectedGroup = group.id;
  state.selectedArtist = artistId;
  renderAndScrollTop();
}

function setupSwipeNavigation() {
  const view = document.getElementById("view");
  if (!view || view.dataset.swipeReady === "true") return;
  view.dataset.swipeReady = "true";
  view.addEventListener("touchstart", (event) => {
    if (isSwipeNavigationBlocked(event.target)) return;
    const touch = event.touches?.[0];
    if (!touch) return;
    swipeStart = { x: touch.clientX, y: touch.clientY, time: Date.now() };
  }, { passive: true });
  view.addEventListener("touchend", (event) => {
    if (!swipeStart || isSwipeNavigationBlocked(event.target)) {
      swipeStart = null;
      return;
    }
    const touch = event.changedTouches?.[0];
    if (!touch) return;
    const deltaX = touch.clientX - swipeStart.x;
    const deltaY = touch.clientY - swipeStart.y;
    const fastEnough = Date.now() - swipeStart.time < 720;
    swipeStart = null;
    if (!fastEnough || Math.abs(deltaX) < 72 || Math.abs(deltaX) < Math.abs(deltaY) * 1.35) return;
    const currentIndex = swipeNavigationViews.indexOf(state.view);
    if (currentIndex < 0) return;
    const nextIndex = deltaX < 0 ? currentIndex + 1 : currentIndex - 1;
    if (nextIndex < 0 || nextIndex >= swipeNavigationViews.length) return;
    swipeSuppressClickUntil = Date.now() + 420;
    setView(swipeNavigationViews[nextIndex]);
  }, { passive: true });
  view.addEventListener("click", (event) => {
    if (Date.now() < swipeSuppressClickUntil) {
      event.preventDefault();
      event.stopPropagation();
    }
  }, true);
}

function isSwipeNavigationBlocked(target) {
  if (!state.isAuthenticated) return true;
  if (!swipeNavigationViews.includes(state.view)) return true;
  if (state.activeStory !== null || state.storyEditorOpen || state.dropSearchOpen || state.dropCreatorOpen || state.fancamCreatorOpen || state.videoProfileOverlay || state.videoFullscreen || state.mediaEmbed || state.reportTarget || state.settingsPanel || state.profileEditorOpen) return true;
  const element = target?.closest?.("input, textarea, select, iframe, .stories-row, .group-story-row, .artist-media-row, .artist-fancam-row, .fancam-filter-row, .drop-result-list, .video-comment-list, .comments-list");
  return Boolean(element);
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
  const localSession = authService.getSession();
  const savedUser = localSession?.user || userService.getCurrentUser() || defaultUser;
  state.user = {
    ...defaultUser,
    ...(savedUser || {}),
    avatarUrl: savedUser?.avatarUrl || defaultUser.avatarUrl || getDemoUserImage(0),
    imageUrl: savedUser?.imageUrl || defaultUser.imageUrl || getDemoUserImage(0),
    coverUrl: savedUser?.coverUrl || defaultUser.coverUrl || getDemoPostImage(0),
    mediaUrl: savedUser?.mediaUrl || defaultUser.mediaUrl || getDemoStoryImage(0),
  };
  const savedLocalPosts = storage.get("hallyuHubUserPosts", []);
  if (Array.isArray(savedLocalPosts) && savedLocalPosts.length) {
    userPosts.unshift(...savedLocalPosts.filter((post) => !userPosts.some((item) => item.id === post.id)));
  }
  normalizePostTimestamps(userPosts);
  sortPostsByRecentInPlace(userPosts);
  const savedLocalDrops = storage.get("hallyuHubUserDrops", []);
  if (Array.isArray(savedLocalDrops) && savedLocalDrops.length) {
    trendVideos.unshift(...savedLocalDrops.filter((drop) => !trendVideos.some((item, index) => getDropId(item, index) === drop.id || item.id === drop.id)));
  }
  const savedLocalFancams = storage.get("hallyuHubUserFancams", []);
  if (Array.isArray(savedLocalFancams) && savedLocalFancams.length) {
    fancamVideos.unshift(...savedLocalFancams.filter((fancam) => !fancamVideos.some((item) => item.id === fancam.id)));
  }
  normalizeDropAndFancamMetadata();
  const savedNews = storage.get("hallyuHubNewsCache", null);
  state.newsItems = savedNews?.items?.length ? mergeNewsStatuses(savedNews.items, news) : news;
  state.newsLastUpdated = savedNews?.updatedAt || null;
  state.ownStories = storage.get("hallyuHubOwnStories", []);
  state.ownStory = state.ownStories[0] || storage.get("hallyuHubOwnStory", null);
  state.storyArchive = storage.get("hallyuHubStoryArchive", state.ownStories || []);
  state.storyInbox = storage.get("hallyuHubStoryInbox", []);
  state.viewedStories = storage.get("hallyuHubViewedStories", {});
  state.soundEnabled = storage.get("hallyuHubSoundEnabled", true);
  state.hiddenPosts = storage.get("hallyuHubHiddenPosts", {});
  state.hiddenFanContent = storage.get("hallyuHubHiddenFanContent", {});
  state.mutedUsers = storage.get("hallyuHubMutedUsers", {});
  state.socialReports = storage.get("hallyuHubReports", []);
  state.likedPosts = storage.get("hallyuHubLikedPosts", {});
  state.savedPosts = storage.get("hallyuHubSavedPosts", {});
  state.sharedPosts = storage.get("hallyuHubSharedPosts", {});
  state.videoMuted = storage.get("hallyuHubVideoMuted", true);
  state.isAuthenticated = Boolean(localSession);
  state.session = localSession ? { user: localSession.user, created_at: localSession.sessionCreatedAt } : null;
  state.selectedAvatar = state.user.avatar || "berry";
  state.selectedProfileBg = state.user.profileBg || "army";
  state.ambience = state.user.ambience || "hallyu";
  syncCurrentUserVisualReferences(state.user);
  state.view = state.isAuthenticated ? "home" : "auth";
  render();
}

async function submitAuth(mode) {
  const email = document.getElementById("auth-email")?.value.trim() || defaultUser.email;
  const password = document.getElementById("auth-password")?.value || defaultUser.password;
  const confirmPassword = document.getElementById("auth-password-confirm")?.value || "";
  const acceptedTerms = document.getElementById("auth-terms")?.checked ?? mode !== "register";
  const name = document.getElementById("auth-name")?.value.trim() || defaultUser.name;
  const username = document.getElementById("auth-username")?.value.trim() || defaultUser.username;
  const avatar = document.querySelector("[data-auth-avatar].active")?.dataset.authAvatar || state.selectedAvatar;

  if (mode === "register" && !confirmPassword) {
    alert("Confirma tu contraseña para crear la cuenta.");
    return;
  }
  if (mode === "register" && confirmPassword !== password) {
    alert("Las contraseñas no coinciden.");
    return;
  }
  if (mode === "register" && !acceptedTerms) {
    alert("Para crear cuenta debes aceptar términos y política de privacidad.");
    return;
  }

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

  try {
    const localSession =
      mode === "register"
        ? authService.register({
            email,
            password,
            name,
            username,
            avatar,
            avatarUrl: state.user?.avatarUrl || defaultUser.avatarUrl || getDemoUserImage(0),
            bio: state.user?.bio || defaultUser.bio,
            country: state.user?.country || defaultUser.country,
            fandom: state.user?.fandom || defaultUser.fandom,
            favoriteGroup: state.user?.favoriteGroup || defaultUser.favoriteGroup,
          })
        : authService.login(email, password);
    state.user = localSession.user;
    state.session = { user: localSession.user, created_at: localSession.sessionCreatedAt };
    state.selectedAvatar = state.user.avatar || avatar;
    state.ambience = state.user.ambience;
    state.isAuthenticated = true;
  } catch (error) {
    alert(error.message || "No pudimos iniciar sesión.");
    return;
  }
  setView("home");
}

async function saveSettings() {
  const wantsNotifications = Boolean(document.getElementById("settings-notifications")?.checked);
  if (wantsNotifications) {
    const allowed = await requestNotificationPermissionWhenNeeded();
    if (!allowed) {
      showToast("No pudimos activar notificaciones. Revisá los permisos del navegador o del dispositivo.");
    }
  }
  const selectedAvatar = document.querySelector("[data-avatar].active")?.dataset.avatar || state.selectedAvatar;
  const selectedAmbience = document.querySelector("[data-ambience].active")?.dataset.ambience || state.ambience;
  const selectedProfileBg = document.querySelector("[data-profile-bg].active")?.dataset.profileBg || state.selectedProfileBg || state.user.profileBg;
  const avatarFile = document.getElementById("settings-avatar-file")?.files?.[0];
  const uploadedAvatarUrl =
    state.backendMode === "supabase" && avatarFile
      ? await uploadMedia(avatarFile, supabaseBuckets.avatars)
      : avatarFile
      ? state.settingsAvatarPreviewUrl || (await readImageFileAsDataUrl(avatarFile))
      : state.user.avatarUrl;
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
    notifications: wantsNotifications,
    privateProfile: Boolean(document.getElementById("settings-privacy")?.checked),
  };
  state.selectedAvatar = state.user.avatar;
  state.selectedProfileBg = state.user.profileBg;
  state.ambience = state.user.ambience;
  if (state.backendMode === "supabase" && state.session?.user) {
    await upsertProfile(state.session.user, state.user);
  }
  state.user = userService.saveCurrentUser(state.user);
  syncCurrentUserVisualReferences(state.user);
  state.settingsAvatarPreviewUrl = "";
  renderAndScrollTop();
}

async function saveProfileEdit() {
  const selectedAvatar = document.querySelector("[data-avatar].active")?.dataset.avatar || state.selectedAvatar || state.user.avatar;
  const selectedProfileBg = document.querySelector("[data-profile-bg].active")?.dataset.profileBg || state.selectedProfileBg || state.user.profileBg;
  const avatarFile = document.getElementById("profile-edit-avatar-file")?.files?.[0];
  const uploadedAvatarUrl =
    state.backendMode === "supabase" && avatarFile
      ? await uploadMedia(avatarFile, supabaseBuckets.avatars)
      : avatarFile
      ? state.profileAvatarPreviewUrl || (await readImageFileAsDataUrl(avatarFile))
      : state.user.avatarUrl;

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
  state.user = userService.saveCurrentUser(state.user);
  syncCurrentUserVisualReferences(state.user);
  state.profileAvatarPreviewUrl = "";
  renderAndScrollTop();
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
  state.user = userService.saveCurrentUser(state.user);
  syncCurrentUserVisualReferences(state.user);
  setView("profile");
  scrollToTop();
}

async function logout() {
  if (state.backendMode === "supabase") {
    await state.supabase.auth.signOut();
  }
  authService.logout();
  state.isAuthenticated = false;
  state.session = null;
  state.viewedProfile = null;
  state.profileEditorOpen = false;
  state.view = "auth";
  state.authMode = "start";
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
  syncPublishDraftFromDom();
  const draft = state.publishDraft;
  const caption = draft.caption.trim();
  const file = document.getElementById("publish-media-input")?.files?.[0];
  const category = draft.type || "posts";
  const optionalFields = {
    location: draft.location.trim(),
    taggedPeople: draft.taggedPeople.trim(),
    taggedPlace: draft.taggedPlace.trim(),
    taggedGroup: draft.taggedGroup.trim(),
    taggedArtist: draft.taggedArtist.trim(),
    taggedShow: draft.taggedShow.trim(),
    city: draft.city.trim(),
    eventDate: draft.eventDate.trim(),
  };
  const hashtags = (draft.hashtags || "")
    .split(/[,\s]+/)
    .map((tag) => tag.trim())
    .filter(Boolean)
    .map((tag) => (tag.startsWith("#") ? tag : `#${tag}`));
  const mediaUrl = draft.mediaUrl || getDemoPostImage(userPosts.length + 2);
  const mediaType = draft.mediaType || "image";
  if (!draft.rightsConfirmed) {
    showToast("Confirmá que tenés permiso para subir este contenido");
    return;
  }
  if (state.backendMode !== "supabase") {
    const created = createLocalPublishedContent({
      category,
      caption,
      hashtags,
      optionalFields,
      mediaUrl,
      mediaType,
      filter: draft.filter,
      audio: draft.audio,
      privacy: draft.privacy,
      allowComments: draft.allowComments,
      rightsConfirmed: draft.rightsConfirmed,
    });
    sortPostsByRecentInPlace(userPosts);
    state.publishDraft.result = created;
    showToast("Publicado correctamente");
    playAppSound("publish");
    renderAndScrollTop();
    return;
  }
  const uploadedMediaUrl = file ? await uploadMedia(file, supabaseBuckets.posts) : mediaUrl;
  const uploadedMediaType = file?.type?.startsWith("video") ? "video" : file ? "image" : mediaType;
  const { error } = await state.supabase.from("posts").insert({
    user_id: state.session.user.id,
    caption,
    media_url: uploadedMediaUrl,
    media_type: uploadedMediaType,
    category: getPostCategoryLabel(category),
  });
  if (error) {
    alert(error.message);
    return;
  }
  await loadPosts();
  state.publishDraft.result = {
    id: `supabase-${Date.now()}`,
    type: category,
    label: getPostCategoryLabel(category),
    mediaUrl: uploadedMediaUrl,
    mediaType: uploadedMediaType,
    filter: draft.filter,
  };
  renderAndScrollTop();
}

function syncPublishDraftFromDom() {
  document.querySelectorAll("[data-publish-draft]").forEach((field) => {
    const key = field.dataset.publishDraft;
    state.publishDraft[key] = field.type === "checkbox" ? field.checked : field.value;
  });
}

function resetVideoEditorDraft(kind = "trends") {
  state.videoEditorDraft = {
    kind,
    mediaUrl: "",
    mediaType: "",
    mediaName: "",
    coverUrl: "",
    coverName: "",
    description: "",
    hashtags: "",
    music: kind === "fancams" ? "Stage audio · safe preview" : "Drop dance · demo loop",
    group: "",
    artist: "",
    show: "",
    city: "",
    eventDate: "",
    location: "",
    start: "0",
    end: kind === "fancams" ? "180" : "60",
    duration: kind === "fancams" ? "180" : "60",
    muted: false,
    soundOn: true,
    overlayText: "",
    sticker: "✨",
    filter: "original",
    privacy: "Seguidores",
    allowComments: true,
    rightsConfirmed: false,
    vertical: true,
    loading: false,
    error: "",
    result: null,
  };
}

function syncVideoEditorDraftFromDom() {
  document.querySelectorAll("[data-video-editor-field]").forEach((field) => {
    state.videoEditorDraft[field.dataset.videoEditorField] = field.type === "checkbox" ? field.checked : field.value;
  });
}

function getVideoEditorMaxDuration(kind) {
  if (kind === "fancams") return 180;
  if (kind === "stories") return 15;
  return 60;
}

function getVideoTrimMetrics(kind = state.videoEditorDraft.kind, draft = state.videoEditorDraft) {
  const recommendedMax = getVideoEditorMaxDuration(kind);
  const duration = Math.max(1, Number(draft.duration || 0) || recommendedMax, Number(draft.end || 0) || recommendedMax);
  let start = Math.max(0, Math.min(duration - 0.5, Number(draft.start || 0)));
  let end = Math.max(start + 0.5, Math.min(duration, Number(draft.end || recommendedMax)));
  if (end > duration) end = duration;
  if (start >= end) start = Math.max(0, end - 0.5);
  return { start, end, duration, selected: Math.max(0, end - start), recommendedMax };
}

function formatTrimTime(value) {
  const total = Math.max(0, Number(value || 0));
  const minutes = Math.floor(total / 60);
  const seconds = Math.floor(total % 60);
  const tenths = Math.round((total - Math.floor(total)) * 10);
  return total < 10 && tenths ? `${seconds}.${tenths}s` : `${minutes}:${String(seconds).padStart(2, "0")}`;
}

function updateVideoTrimValues(start, end, options = {}) {
  const metrics = getVideoTrimMetrics();
  const nextStart = Math.max(0, Math.min(metrics.duration - 0.5, Number(start)));
  const nextEnd = Math.max(nextStart + 0.5, Math.min(metrics.duration, Number(end)));
  state.videoEditorDraft.start = String(Math.round(nextStart * 10) / 10);
  state.videoEditorDraft.end = String(Math.round(nextEnd * 10) / 10);
  updateVideoTrimDom();
  if (options.preview !== false) setVideoPreviewTime(nextStart);
}

function updateVideoTrimDom() {
  const { start, end, duration, selected } = getVideoTrimMetrics();
  const left = (start / duration) * 100;
  const width = (selected / duration) * 100;
  document.querySelectorAll("[data-video-trim-selection]").forEach((element) => {
    element.style.left = `${left}%`;
    element.style.width = `${width}%`;
  });
  document.querySelectorAll("[data-video-trim-start]").forEach((element) => {
    element.textContent = formatTrimTime(start);
  });
  document.querySelectorAll("[data-video-trim-end]").forEach((element) => {
    element.textContent = formatTrimTime(end);
  });
  document.querySelectorAll("[data-video-trim-duration]").forEach((element) => {
    element.textContent = `${formatTrimTime(selected)} seleccionados`;
  });
}

function setVideoPreviewTime(time) {
  const video = document.querySelector("[data-video-editor-preview]");
  if (!video || !Number.isFinite(Number(time))) return;
  const safeTime = Math.max(0, Math.min(Number(time), video.duration || Number(time)));
  try {
    video.currentTime = safeTime;
  } catch {
    // Some mobile browsers delay seeking until metadata is ready.
  }
}

function syncVideoEditorDuration(video) {
  const duration = Math.ceil(Number(video.duration || 0));
  if (!duration) return;
  const current = Number(state.videoEditorDraft.duration || 0);
  if (Math.abs(current - duration) < 1) return;
  const max = getVideoEditorMaxDuration(state.videoEditorDraft.kind);
  state.videoEditorDraft.duration = String(duration);
  state.videoEditorDraft.start = "0";
  state.videoEditorDraft.end = String(Math.min(duration, max));
  render();
}

function stopVideoAtTrimEnd(video) {
  if (video.dataset.playingRange !== "true") return;
  const { end } = getVideoTrimMetrics();
  if (video.currentTime >= end) {
    video.pause();
    video.dataset.playingRange = "false";
    setVideoPreviewTime(Number(state.videoEditorDraft.start || 0));
  }
}

function playSelectedVideoRange() {
  const video = document.querySelector("[data-video-editor-preview]");
  if (!video) {
    showToast("Subí un video para previsualizar el recorte");
    return;
  }
  const { start } = getVideoTrimMetrics();
  video.dataset.playingRange = "true";
  setVideoPreviewTime(start);
  video.play().catch(() => showToast("Tocá el video para reproducir la vista previa"));
}

function startVideoTrimDrag(event, mode) {
  const track = event.currentTarget.closest("[data-video-trim-track]");
  if (!track) return;
  event.preventDefault();
  event.stopPropagation();
  const rect = track.getBoundingClientRect();
  const initial = getVideoTrimMetrics();
  const drag = {
    mode,
    startX: event.clientX,
    width: Math.max(1, rect.width),
    initialStart: initial.start,
    initialEnd: initial.end,
    duration: initial.duration,
  };
  const onMove = (moveEvent) => updateVideoTrimFromPointer(moveEvent, drag);
  const onUp = () => {
    window.removeEventListener("pointermove", onMove);
    window.removeEventListener("pointerup", onUp);
    render();
  };
  window.addEventListener("pointermove", onMove);
  window.addEventListener("pointerup", onUp, { once: true });
}

function updateVideoTrimFromPointer(event, drag) {
  const delta = ((event.clientX - drag.startX) / drag.width) * drag.duration;
  let start = drag.initialStart;
  let end = drag.initialEnd;
  if (drag.mode === "start") {
    start = Math.min(Math.max(0, drag.initialStart + delta), drag.initialEnd - 0.5);
  } else if (drag.mode === "end") {
    end = Math.max(Math.min(drag.duration, drag.initialEnd + delta), drag.initialStart + 0.5);
  } else {
    const length = drag.initialEnd - drag.initialStart;
    start = Math.min(Math.max(0, drag.initialStart + delta), drag.duration - length);
    end = start + length;
  }
  updateVideoTrimValues(start, end);
}

function moveNearestTrimHandle(event, track) {
  const rect = track.getBoundingClientRect();
  const metrics = getVideoTrimMetrics();
  const position = ((event.clientX - rect.left) / Math.max(1, rect.width)) * metrics.duration;
  const moveStart = Math.abs(position - metrics.start) <= Math.abs(position - metrics.end);
  updateVideoTrimValues(moveStart ? position : metrics.start, moveStart ? metrics.end : position);
  render();
}

function getVideoEditorHashtags() {
  return String(state.videoEditorDraft.hashtags || "")
    .split(/[,\s]+/)
    .map((tag) => tag.trim())
    .filter(Boolean)
    .map((tag) => (tag.startsWith("#") ? tag : `#${tag}`));
}

function isVideoEditorLong(kind, draftOrEnd) {
  const selected = typeof draftOrEnd === "object"
    ? getVideoTrimMetrics(kind, draftOrEnd).selected
    : Number(draftOrEnd || 0);
  if (!selected) return false;
  return selected > getVideoEditorMaxDuration(kind);
}

function publishVideoEditorContent() {
  syncVideoEditorDraftFromDom();
  const draft = state.videoEditorDraft;
  if (draft.loading) {
    showToast("Esperá a que termine de cargar el video");
    return;
  }
  if (!draft.mediaUrl) {
    showToast("Subí un video antes de publicar");
    return;
  }
  if (!draft.rightsConfirmed) {
    showToast("Confirmá que este contenido fue creado por vos o tenés permiso");
    return;
  }
  if (isVideoEditorLong(draft.kind, draft)) {
    showToast("Tu video es muy largo, recortalo antes de publicar");
    return;
  }
  const optionalFields = {
    location: "",
    taggedGroup: draft.group || "",
    taggedArtist: draft.artist || "",
    taggedShow: draft.show || "",
    city: draft.city || "",
    eventDate: draft.eventDate || "",
    trimStart: draft.start || "0",
    trimEnd: draft.end || "",
    trimDuration: String(getVideoTrimMetrics(draft.kind, draft).selected),
    coverUrl: draft.coverUrl || "",
    taggedPeople: draft.artist ? `@${draft.artist.replace(/^@/, "")}` : "",
    taggedPlace: draft.show || draft.location || "",
  };
  const created = createLocalPublishedContent({
    category: draft.kind,
    caption: draft.description.trim(),
    hashtags: getVideoEditorHashtags(),
    optionalFields,
    mediaUrl: draft.mediaUrl,
    mediaType: "video",
    filter: draft.filter,
    audio: draft.music,
    privacy: draft.privacy,
    allowComments: draft.allowComments,
    rightsConfirmed: draft.rightsConfirmed,
  });
  state.videoEditorDraft.result = created;
  state.dropCreatorOpen = false;
  state.fancamCreatorOpen = false;
  showToast("Publicado correctamente");
  playAppSound("publish");
  renderAndScrollTop();
}

function createLocalPublishedContent({ category, caption, hashtags, optionalFields, mediaUrl, mediaType, filter, audio, privacy, allowComments, rightsConfirmed }) {
  const id = `local-${category}-${Date.now()}`;
  const label = getPostCategoryLabel(category);
  const tagText = [
    caption,
    ...(hashtags || []),
    optionalFields?.taggedGroup,
    optionalFields?.taggedArtist,
    optionalFields?.taggedPeople,
    optionalFields?.taggedShow,
    optionalFields?.taggedPlace,
    optionalFields?.location,
  ].join(" ");
  const taggedGroupMatch = findCatalogGroupFromText(tagText);
  const taggedArtistMatch = findCatalogArtistFromText(tagText);
  const linkedGroup = taggedGroupMatch || taggedArtistMatch?.group || null;
  const linkedArtist = taggedArtistMatch?.artist || null;
  const userId = state.user?.id || normalizeProfileKey(state.user?.username || state.user?.name || "current-user");
  const username = state.user?.username || "hallyufan";
  const base = {
    id,
    userId,
    createdAt: new Date().toISOString(),
    user: state.user.name,
    username,
    avatarUrl: state.user.avatarUrl || getDemoUserImage(0),
    group: label,
    groupId: linkedGroup?.id || "",
    artistId: linkedArtist?.id || "",
    category,
    time: "Ahora",
    badge: state.user.fandom || "Army 💜",
    online: true,
    caption: caption || `Nuevo ${label} en HallyuHub.`,
    likes: "0",
    comments: allowComments ? "0" : "Cerrado",
    commentList: [],
    hashtags: hashtags.length ? hashtags : ["#HallyuHub", "#KpopLatam"],
    shares: "0",
    saves: "0",
    mediaUrl,
    thumbnail: optionalFields?.coverUrl || mediaUrl,
    imageUrl: mediaUrl,
    coverUrl: optionalFields?.coverUrl || mediaUrl,
    mediaType,
    filter,
    audio,
    privacy,
    allowComments,
    rightsConfirmed: Boolean(rightsConfirmed),
    moderationStatus: rightsConfirmed ? "publicado" : "pendiente revisión",
    fanContentStatus: rightsConfirmed ? "publicado" : "pendiente revisión",
    ...optionalFields,
  };
  if (category === "stories") {
    const story = {
      id,
      createdAt: base.createdAt,
      user: state.user.name,
      avatarUrl: state.user.avatarUrl || getDemoUserImage(0),
      label: "story",
      time: "Ahora",
      music: audio || "HallyuHub · safe loop",
      title: "Tu historia",
      detail: caption || "Nueva historia publicada.",
      stars: 0,
      views: 1,
      colors: art[0],
      imageUrl: mediaUrl,
      coverUrl: mediaUrl,
      mediaUrl,
      mediaType,
      elements: [],
      filter,
    };
    state.ownStories = [story, ...(state.ownStories || [])].slice(0, 20);
    state.ownStory = story;
    storage.set("hallyuHubOwnStories", state.ownStories);
    storage.set("hallyuHubOwnStory", state.ownStory);
    const storyKey = getStoryKey(-1);
    if (storyKey) {
      state.viewedStories = { ...state.viewedStories };
      delete state.viewedStories[storyKey];
      storage.set("hallyuHubViewedStories", state.viewedStories);
    }
    return { id, type: category, label: "Story", mediaUrl, mediaType, filter };
  }
  if (category === "trends") {
    const drop = {
      id,
      userId,
      createdAt: base.createdAt,
      user: state.user.name,
      username,
      avatarUrl: state.user.avatarUrl || getDemoUserImage(0),
      groupId: linkedGroup?.id || normalizeProfileKey(optionalFields.taggedGroup || ""),
      artistId: linkedArtist?.id || normalizeProfileKey(optionalFields.taggedArtist || optionalFields.taggedPeople || ""),
      group: linkedGroup?.name || optionalFields.taggedGroup || state.user.favoriteGroup || "HallyuHub",
      artist: linkedArtist?.name || optionalFields.taggedArtist || optionalFields.taggedPeople?.replace("@", "") || "",
      challenge: caption ? caption.slice(0, 44) : "Nuevo Drop HallyuHub",
      song: audio || "HallyuHub · safe loop",
      description: caption || "Drop nuevo creado en modo demo.",
      colors: art[1],
      imageUrl: mediaUrl,
      coverUrl: optionalFields?.coverUrl || mediaUrl,
      mediaUrl,
      thumbnail: optionalFields?.coverUrl || mediaUrl,
      mediaType,
      filter,
      hashtags: base.hashtags,
      audio,
      comments: allowComments ? "0" : "Cerrados",
      rightsConfirmed: base.rightsConfirmed,
      moderationStatus: base.moderationStatus,
      taggedGroup: base.taggedGroup,
      taggedArtist: base.taggedArtist,
      taggedShow: base.taggedShow,
      city: base.city,
      eventDate: base.eventDate,
      location: base.location,
      trimStart: base.trimStart,
      trimEnd: base.trimEnd,
      trimDuration: base.trimDuration,
    };
    trendVideos.unshift(drop);
    userPosts.unshift({ ...base, type: "trending" });
    sortPostsByRecentInPlace(userPosts);
    storage.set("hallyuHubUserPosts", userPosts.filter((post) => String(post.id || "").startsWith("local-")));
    storage.set("hallyuHubUserDrops", trendVideos.filter((dropItem) => String(dropItem.id || "").startsWith("local-trends")));
    return { id, type: category, label: "Drop", mediaUrl, mediaType, filter };
  }
  if (category === "fancams") {
    const fancam = {
      id,
      userId,
      createdAt: base.createdAt,
      groupId: linkedGroup?.id || normalizeProfileKey(optionalFields.taggedGroup || state.user.favoriteGroup || "hallyu"),
      artistId: linkedArtist?.id || normalizeProfileKey(optionalFields.taggedArtist || optionalFields.taggedPeople || `local-artist-${Date.now()}`),
      artist: linkedArtist?.name || optionalFields.taggedArtist || optionalFields.taggedPeople.replace("@", "") || state.user.name,
      group: linkedGroup?.name || optionalFields.taggedGroup || state.user.favoriteGroup || "HallyuHub",
      user: state.user.name,
      username,
      avatarUrl: state.user.avatarUrl || getDemoUserImage(0),
      era: "Demo upload",
      show: optionalFields.taggedPlace || "Fan focus",
      date: "Ahora",
      views: "0",
      likes: "0",
      sort: "recent",
      description: caption || "Fancam nueva creada en modo demo.",
      imageUrl: mediaUrl,
      coverUrl: optionalFields?.coverUrl || mediaUrl,
      mediaUrl,
      thumbnail: optionalFields?.coverUrl || mediaUrl,
      mediaType,
      colors: art[3],
      filter,
      hashtags: base.hashtags,
      audio,
      comments: allowComments ? "0" : "Cerrados",
      rightsConfirmed: base.rightsConfirmed,
      moderationStatus: base.moderationStatus,
      taggedGroup: base.taggedGroup,
      taggedArtist: base.taggedArtist,
      taggedShow: base.taggedShow,
      city: base.city,
      eventDate: base.eventDate,
      location: base.location,
      trimStart: base.trimStart,
      trimEnd: base.trimEnd,
      trimDuration: base.trimDuration,
    };
    fancamVideos.unshift(fancam);
    userPosts.unshift({ ...base, type: "popular" });
    sortPostsByRecentInPlace(userPosts);
    storage.set("hallyuHubUserPosts", userPosts.filter((post) => String(post.id || "").startsWith("local-")));
    storage.set("hallyuHubUserFancams", fancamVideos.filter((item) => String(item.id || "").startsWith("local-fancams")));
    return { id, type: category, label: "Fancam", mediaUrl, mediaType, filter };
  }
  userPosts.unshift(base);
  sortPostsByRecentInPlace(userPosts);
  storage.set("hallyuHubUserPosts", userPosts.filter((post) => String(post.id || "").startsWith("local-")));
  return { id, type: category, label, mediaUrl, mediaType, filter };
}

function findCatalogGroupFromText(text) {
  const source = String(text || "").replace(/@/g, " ");
  const normalized = normalizeProfileKey(source);
  if (!normalized) return null;
  return (
    kpopGroups.find((group) => {
      const fields = [group.id, group.name, group.fandom, group.company, ...(group.aliases || [])].filter(Boolean);
      return fields.some((field) => matchesCatalogField(source, normalized, field));
    }) || null
  );
}

function findCatalogArtistFromText(text) {
  const source = String(text || "").replace(/@/g, " ");
  const normalized = normalizeProfileKey(source);
  if (!normalized) return null;
  for (const group of kpopGroups) {
    const artists = [...(group.artists || [])].sort((a, b) => normalizeProfileKey(b.name).length - normalizeProfileKey(a.name).length);
    for (const artist of artists) {
      const names = [artist.name, artist.realName, artist.id].filter(Boolean);
      if (names.some((name) => matchesCatalogField(source, normalized, name))) {
        return { group, artist };
      }
    }
  }
  return null;
}

function matchesCatalogField(sourceText, normalizedText, fieldValue, options = {}) {
  const field = normalizeProfileKey(fieldValue);
  if (!field) return false;
  if (field.length <= 3 && !options.allowShortContains) {
    const escaped = String(fieldValue).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    return new RegExp(`(^|[^a-z0-9])${escaped}($|[^a-z0-9])`, "i").test(String(sourceText || ""));
  }
  return normalizedText.includes(field) || field.includes(normalizedText);
}

function normalizeDropAndFancamMetadata() {
  trendVideos.forEach((drop, index) => {
    const tagText = [drop.challenge, drop.description, drop.song, drop.group, drop.groupId, drop.artist, drop.artistId, drop.taggedGroup, drop.taggedArtist, ...(drop.hashtags || [])].join(" ");
    const group = drop.groupId ? kpopGroups.find((item) => item.id === drop.groupId) : findCatalogGroupFromText(tagText);
    const artistMatch = drop.artistId ? findArtistById(drop.artistId) : findCatalogArtistFromText(tagText);
    drop.userId = drop.userId || normalizeProfileKey(drop.username || drop.user || `drop-user-${index}`);
    drop.username = drop.username || normalizeProfileKey(drop.user || `drop-user-${index}`);
    drop.groupId = drop.groupId || group?.id || artistMatch?.group?.id || "";
    drop.artistId = drop.artistId || artistMatch?.artist?.id || "";
    drop.group = drop.group || group?.name || artistMatch?.group?.name || "";
    drop.artist = drop.artist || artistMatch?.artist?.name || "";
    drop.createdAt = drop.createdAt || new Date(Date.now() - index * 38 * 60 * 1000).toISOString();
    drop.likes = drop.likes || "0";
    drop.comments = drop.comments || "0";
    drop.hashtags = drop.hashtags || ["#Drops", "#HallyuHub"];
    drop.thumbnail = drop.thumbnail || drop.coverUrl || drop.imageUrl || drop.mediaUrl || getDemoDropMedia(index);
    drop.mediaUrl = drop.mediaUrl || drop.imageUrl || drop.thumbnail;
    drop.coverUrl = drop.coverUrl || drop.thumbnail;
    drop.imageUrl = drop.imageUrl || drop.thumbnail;
  });
  fancamVideos.forEach((fancam, index) => {
    const tagText = [fancam.artist, fancam.artistId, fancam.group, fancam.groupId, fancam.show, fancam.era, ...(fancam.hashtags || [])].join(" ");
    const artistMatch = fancam.artistId ? findArtistById(fancam.artistId) : findCatalogArtistFromText(tagText);
    const group = fancam.groupId ? kpopGroups.find((item) => item.id === fancam.groupId) : artistMatch?.group || findCatalogGroupFromText(tagText);
    fancam.userId = fancam.userId || normalizeProfileKey(fancam.username || fancam.user || `fancam-user-${index}`);
    fancam.username = fancam.username || normalizeProfileKey(fancam.user || `fancam-user-${index}`);
    fancam.groupId = fancam.groupId || group?.id || artistMatch?.group?.id || "";
    fancam.artistId = fancam.artistId || artistMatch?.artist?.id || "";
    fancam.group = fancam.group || group?.name || artistMatch?.group?.name || "";
    fancam.artist = fancam.artist || artistMatch?.artist?.name || "Fancam";
    fancam.createdAt = fancam.createdAt || new Date(Date.now() - index * 52 * 60 * 1000).toISOString();
    fancam.likes = fancam.likes || "0";
    fancam.comments = fancam.comments || "0";
    fancam.hashtags = fancam.hashtags || [`#${fancam.group || "Kpop"}`, "#Fancam"];
    fancam.thumbnail = fancam.thumbnail || fancam.coverUrl || fancam.imageUrl || fancam.mediaUrl || getDemoDropMedia(index + 1);
    fancam.mediaUrl = fancam.mediaUrl || fancam.imageUrl || fancam.thumbnail;
    fancam.coverUrl = fancam.coverUrl || fancam.thumbnail;
    fancam.imageUrl = fancam.imageUrl || fancam.thumbnail;
  });
}

function findArtistById(artistId) {
  const normalized = normalizeProfileKey(artistId);
  for (const group of kpopGroups) {
    const artist = (group.artists || []).find((item) => normalizeProfileKey(item.id) === normalized);
    if (artist) return { group, artist };
  }
  return null;
}

function resetPublishDraft() {
  state.publishDraft = {
    type: "posts",
    mediaUrl: "",
    mediaType: "",
    mediaName: "",
    caption: "",
    hashtags: "",
    taggedPeople: "",
    taggedGroup: "",
    taggedArtist: "",
    taggedShow: "",
    city: "",
    eventDate: "",
    location: "",
    taggedPlace: "",
    audio: "",
    privacy: "Seguidores",
    allowComments: true,
    rightsConfirmed: false,
    filter: "original",
    result: null,
  };
}

function openPublishedContent(type) {
  const result = state.publishDraft.result;
  if (type === "trends") {
    resetPublishDraft();
    setView("trends");
    return;
  }
  if (type === "fancams") {
    resetPublishDraft();
    setView("fancams");
    return;
  }
  if (type === "stories") {
    resetPublishDraft();
    setView("home");
    state.activeStory = -1;
    renderAndScrollTop();
    return;
  }
  if (["outfits", "photocards", "favorites", "posts"].includes(type)) {
    const nextTab = type === "posts" ? "posts" : type;
    resetPublishDraft();
    state.profileTab = nextTab;
    setView("profile");
    return;
  }
  if (result) {
    resetPublishDraft();
    setView("profile");
  }
}

async function createLegacySupabasePost() {
  const caption = document.getElementById("post-caption")?.value.trim() || "";
  const file = document.getElementById("post-media")?.files?.[0];
  const category = document.getElementById("post-category")?.value || "posts";
  const optionalFields = {
    location: document.getElementById("post-location")?.value.trim() || "",
    taggedPeople: document.getElementById("post-tagged-people")?.value.trim() || "",
    taggedPlace: document.getElementById("post-tagged-place")?.value.trim() || "",
  };
  const hashtags = (document.getElementById("post-hashtags")?.value || "")
    .split(/[,\s]+/)
    .map((tag) => tag.trim())
    .filter(Boolean)
    .map((tag) => (tag.startsWith("#") ? tag : `#${tag}`));
  if (state.backendMode !== "supabase") {
    userPosts.unshift({
      id: `local-${Date.now()}`,
      user: state.user.name,
      group: getPostCategoryLabel(category),
      category,
      time: "Ahora",
      badge: state.user.fandom || "Army 💜",
      online: true,
      caption: caption || "Publicacion nueva en modo demo.",
      likes: "0",
      comments: "0",
      commentList: [],
      hashtags: hashtags.length ? hashtags : ["#HallyuHub", "#KpopLatam"],
      ...optionalFields,
    });
    storage.set("hallyuHubUserPosts", userPosts.filter((post) => String(post.id || "").startsWith("local-")));
    setView("profile");
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
  setView("profile");
}

function getPostCategoryLabel(category) {
  const labels = {
    posts: "Publicacion",
    trends: "Drop",
    fancams: "Fancam",
    outfits: "Outfit",
    photocards: "Photocard",
    saved: "Guardado",
    favorites: "Favorito",
    stories: "Historia",
  };
  return labels[category] || "Publicacion";
}

function findPostById(postId) {
  const id = String(postId);
  return userPosts.find((item) => item.id === id) || userPosts.find((item) => item.id === id.replace(/-\d+$/, ""));
}

function getBasePostId(postId) {
  return String(postId || "").replace(/-\d+$/, "");
}

function isOwnPost(post) {
  const owner = normalizeProfileKey(post.user);
  return owner === normalizeProfileKey(state.user?.name) || owner === normalizeProfileKey(state.user?.username);
}

function isPostHidden(post) {
  return Boolean(state.hiddenPosts[getBasePostId(post.id)] || state.hiddenPosts[post.id]);
}

function isUserMuted(post) {
  return Boolean(state.mutedUsers[normalizeProfileKey(post.user)]);
}

function showToast(message) {
  state.toast = message;
  setTimeout(() => {
    if (state.toast === message) {
      state.toast = null;
      render();
    }
  }, 2200);
}

function playAppSound(type = "tap") {
  if (!state.soundEnabled) return;
  const AudioEngine = window.AudioContext || window.webkitAudioContext;
  if (!AudioEngine) return;
  try {
    const audio = new AudioEngine();
    const gain = audio.createGain();
    const oscillator = audio.createOscillator();
    const tones = {
      publish: [659, 880],
      message: [740, 988],
      like: [880, 1175],
      save: [523, 659],
      comment: [587, 784],
      tap: [440, 554],
    };
    const [first, second] = tones[type] || tones.tap;
    oscillator.type = type === "message" ? "triangle" : "sine";
    oscillator.frequency.setValueAtTime(first, audio.currentTime);
    oscillator.frequency.exponentialRampToValueAtTime(second, audio.currentTime + 0.08);
    gain.gain.setValueAtTime(0.0001, audio.currentTime);
    gain.gain.exponentialRampToValueAtTime(type === "publish" ? 0.055 : 0.035, audio.currentTime + 0.015);
    gain.gain.exponentialRampToValueAtTime(0.0001, audio.currentTime + 0.18);
    oscillator.connect(gain);
    gain.connect(audio.destination);
    oscillator.start();
    oscillator.stop(audio.currentTime + 0.2);
  } catch {
    // El navegador puede bloquear audio hasta la primera interacción.
  }
}

function shouldShowPermissionInfo() {
  const lastPrompt = storage.get("hallyuHubLastPermissionPromptDate", null);
  const accepted = storage.get("hallyuHubPermissionsAcceptedInfo", false);
  if (!lastPrompt) return true;
  const elapsed = Date.now() - Date.parse(lastPrompt);
  return !accepted || !Number.isFinite(elapsed) || elapsed > PERMISSION_PROMPT_INTERVAL_MS;
}

function rememberPermissionInfo(accepted) {
  storage.set("hallyuHubLastPermissionPromptDate", new Date().toISOString());
  storage.set("hallyuHubPermissionsAcceptedInfo", Boolean(accepted));
}

async function requestMediaAccessBeforeFile(inputId, options = {}) {
  const payload = { inputId, ...options };
  if (shouldShowPermissionInfo()) {
    state.permissionPrompt = payload;
    render();
    return;
  }
  await openProtectedFileInput(payload);
}

async function continuePermissionRequest() {
  const payload = state.permissionPrompt;
  if (!payload) return;
  rememberPermissionInfo(true);
  state.permissionPrompt = null;
  render();
  await openProtectedFileInput(payload);
}

async function openProtectedFileInput(payload) {
  const granted = await requestRealDevicePermission(payload);
  if (!granted) {
    showToast("No pudimos acceder. Revisá los permisos del navegador o del dispositivo.");
    return;
  }
  document.getElementById(payload.inputId)?.click();
}

async function requestRealDevicePermission({ camera = false, mic = false } = {}) {
  if (!camera && !mic) return true;
  if (!navigator.mediaDevices?.getUserMedia) return true;
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ video: Boolean(camera), audio: Boolean(mic) });
    stream.getTracks().forEach((track) => track.stop());
    return true;
  } catch {
    return false;
  }
}

async function requestNotificationPermissionWhenNeeded() {
  if (!("Notification" in window)) return true;
  if (Notification.permission === "granted") return true;
  if (Notification.permission === "denied") return false;
  try {
    const result = await Notification.requestPermission();
    return result === "granted";
  } catch {
    return false;
  }
}

function savePostReport(key) {
  const separator = key.lastIndexOf("|");
  const target = separator >= 0 ? key.slice(0, separator) : key;
  const reason = separator >= 0 ? key.slice(separator + 1) : "Otro";
  const parsed = parseReportTarget(target);
  const post = parsed.type === "post" ? findPostById(parsed.id) : null;
  state.socialReports = [
    {
      id: `report-${Date.now()}`,
      target,
      targetType: parsed.type,
      targetId: parsed.id,
      postId: parsed.type === "post" ? getBasePostId(parsed.id) : "",
      user: post?.user || parsed.label || "Usuario",
      reason,
      status: "pendiente",
      createdAt: new Date().toISOString(),
    },
    ...state.socialReports,
  ];
  storage.set("hallyuHubReports", state.socialReports);
  state.reportTarget = null;
  showToast("Reporte enviado para revision");
  render();
}

function parseReportTarget(target) {
  const [type, ...rest] = String(target || "").split(":");
  if (rest.length) return { type, id: rest.join(":"), label: rest.join(":") };
  return { type: "post", id: target, label: target };
}

function hidePost(postId, message = "Publicacion ocultada") {
  state.hiddenPosts[getBasePostId(postId)] = true;
  state.openPostMenu = null;
  storage.set("hallyuHubHiddenPosts", state.hiddenPosts);
  showToast(message);
  render();
}

function unfollowFeedUser(userName) {
  const key = normalizeProfileKey(userName);
  state.mutedUsers[key] = true;
  state.followedProfiles[key] = false;
  state.openPostMenu = null;
  storage.set("hallyuHubMutedUsers", state.mutedUsers);
  showToast(`Dejaste de seguir a ${userName}`);
  render();
}

function followFeedUser(userName) {
  const key = normalizeProfileKey(userName);
  state.mutedUsers[key] = false;
  state.followedProfiles[key] = true;
  state.openPostMenu = null;
  storage.set("hallyuHubMutedUsers", state.mutedUsers);
  showToast(`Ahora seguís a ${userName}`);
  render();
}

function normalizePostTimestamps(posts) {
  const now = Date.now();
  posts.forEach((post, index) => {
    if (!post.createdAt) {
      const localStamp = String(post.id || "").match(/local-[a-z]+-(\d+)/)?.[1] || String(post.id || "").match(/local-(\d+)/)?.[1];
      post.createdAt = localStamp ? new Date(Number(localStamp)).toISOString() : new Date(now - index * 7 * 60 * 1000).toISOString();
    }
  });
}

function sortPostsByRecentInPlace(posts) {
  posts.sort((a, b) => getPostTimeValue(b) - getPostTimeValue(a));
}

function sortPostsByRecent(posts) {
  normalizePostTimestamps(posts);
  return [...posts].sort((a, b) => getPostTimeValue(b) - getPostTimeValue(a));
}

function getPostTimeValue(post) {
  const value = Date.parse(post.createdAt || "");
  return Number.isFinite(value) ? value : 0;
}

function getPostDisplayTime(post) {
  if (!post.createdAt) return post.time || "Ahora";
  return formatRelativeTime(post.createdAt);
}

function formatRelativeTime(dateValue) {
  const diffMs = Math.max(0, Date.now() - getPostTimeValue({ createdAt: dateValue }));
  const minutes = Math.floor(diffMs / 60000);
  if (minutes < 1) return "ahora";
  if (minutes < 60) return `${minutes} min`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours} h`;
  const days = Math.floor(hours / 24);
  if (days < 7) return `${days} d`;
  return new Date(dateValue).toLocaleDateString("es", { day: "2-digit", month: "short" });
}

function openHashtagExplore(tag) {
  state.selectedHashtag = tag;
  state.hashtagSort = "recent";
  state.homeFilter = "all";
  setView("search");
}

async function toggleLike(postId) {
  if (state.backendMode !== "supabase" || !state.session?.user) {
    const post = findPostById(postId);
    const baseId = getBasePostId(postId);
    state.likedPosts[baseId] = !state.likedPosts[baseId];
    storage.set("hallyuHubLikedPosts", state.likedPosts);
    if (post) post.likes = state.likedPosts[baseId] ? bumpEngagement(post.likes) : reduceEngagement(post.likes);
    if (state.likedPosts[baseId]) playAppSound("like");
    render();
    return;
  }
  await state.supabase.from("likes").upsert({ post_id: postId, user_id: state.session.user.id });
}

async function addComment(postId, body) {
  if (state.backendMode !== "supabase" || !state.session?.user) {
    const post = findPostById(postId);
    if (post) {
      post.comments = bumpEngagement(post.comments);
      post.commentList = [
        ...(post.commentList || []),
        {
          id: `comment-${Date.now()}`,
          user: state.user?.name || "Hallyu fan",
          username: state.user?.username || "hallyufan",
          avatar: state.user?.avatar || "berry",
          avatarUrl: state.user?.avatarUrl || getDemoUserImage(0),
          time: "Ahora",
          body,
          likes: 0,
          replies: [],
        },
      ];
    }
    render();
    return;
  }
  await state.supabase.from("comments").insert({ post_id: postId, user_id: state.session.user.id, body });
}

function sendInlineComment(postId) {
  const body = (state.commentDrafts[postId] || "").trim();
  if (!body) return;
  const post = findPostById(postId);
  if (!post) return;
  const replyTarget = state.replyTo[postId];
  const comment = {
    id: `comment-${Date.now()}`,
    user: state.user?.name || "Hallyu fan",
    username: state.user?.username || "hallyufan",
    avatar: state.user?.avatar || "berry",
    avatarUrl: state.user?.avatarUrl || getDemoUserImage(0),
    time: "Ahora",
    body,
    likes: 0,
    replies: [],
  };
  if (replyTarget) {
    post.commentList = (post.commentList || []).map((item) =>
      item.id === replyTarget ? { ...item, replies: [...(item.replies || []), comment] } : item,
    );
    state.replyTo[postId] = null;
  } else {
    post.commentList = [...(post.commentList || []), comment];
  }
  post.comments = bumpEngagement(post.comments);
  state.commentDrafts[postId] = "";
  state.openComments[postId] = true;
  persistLocalPosts();
  playAppSound("comment");
  render();
}

function likeComment(key) {
  const [postId, commentId] = key.split(":");
  const post = findPostById(postId);
  if (!post) return;
  state.likedComments[key] = !state.likedComments[key];
  const delta = state.likedComments[key] ? 1 : -1;
  post.commentList = (post.commentList || []).map((comment) => updateCommentLike(comment, commentId, delta));
  if (state.likedComments[key]) playAppSound("like");
  persistLocalPosts();
  render();
}

function getVideoCommentStore(type) {
  return type === "fancam" ? state.fancamVideoComments : state.dropVideoComments;
}

function getDefaultVideoComments(type, id) {
  const key = `${type}:${id}`;
  const store = getVideoCommentStore(type);
  if (!store[id]) {
    store[id] = [
      { id: `${type}-${id}-demo-1`, user: "Luna Hallyu", username: "luna.hallyu", avatar: "berry", avatarUrl: getDemoUserImage(0), time: "2m", body: "Ese momento quedó increíble para verlo en loop.", likes: 24, replies: [] },
      { id: `${type}-${id}-demo-2`, user: "Cami.STAY", username: "cami.stay", avatar: "star", avatarUrl: getDemoUserImage(2), time: "8m", body: "Necesito tutorial y audio guardado ✨", likes: 17, replies: [] },
    ];
  }
  return store[id];
}

function sendVideoComment(type, id) {
  const key = `${type}:${id}`;
  const body = (state.videoCommentDrafts[key] || "").trim();
  if (!body) return;
  const store = getVideoCommentStore(type);
  const comments = getDefaultVideoComments(type, id);
  const replyTarget = state.videoCommentReplyTo[key];
  const comment = {
    id: `video-comment-${Date.now()}`,
    user: state.user?.name || "Hallyu fan",
    username: state.user?.username || "hallyufan",
    avatar: state.user?.avatar || "berry",
    avatarUrl: state.user?.avatarUrl || getDemoUserImage(0),
    time: "Ahora",
    body,
    likes: 0,
    replies: [],
  };
  store[id] = replyTarget
    ? comments.map((item) => (item.id === replyTarget ? { ...item, replies: [...(item.replies || []), comment] } : item))
    : [...comments, comment];
  if (!replyTarget) bumpVideoCommentCount(type, id);
  state.videoCommentDrafts[key] = "";
  state.videoCommentReplyTo[key] = null;
  playAppSound("comment");
  showToast("Comentario enviado");
  render();
}

function bumpVideoCommentCount(type, id) {
  if (type === "drop") {
    const entry = trendVideos.map((item, index) => [item, getDropId(item, index)]).find(([, itemId]) => itemId === id);
    if (entry?.[0]) entry[0].comments = bumpEngagement(entry[0].comments || "0");
    return;
  }
  const fancam = fancamVideos.find((item) => item.id === id);
  if (fancam) fancam.comments = bumpEngagement(fancam.comments || "0");
}

function likeVideoComment(key) {
  const [type, id, commentId] = key.split(":");
  const store = getVideoCommentStore(type);
  const comments = getDefaultVideoComments(type, id);
  state.videoCommentLikes[key] = !state.videoCommentLikes[key];
  const delta = state.videoCommentLikes[key] ? 1 : -1;
  store[id] = comments.map((comment) => updateCommentLike(comment, commentId, delta));
  if (state.videoCommentLikes[key]) playAppSound("like");
  render();
}

function persistLocalPosts() {
  storage.set("hallyuHubUserPosts", userPosts.filter((post) => String(post.id || "").startsWith("local-")));
}

function updateCommentLike(comment, commentId, delta) {
  if (comment.id === commentId) {
    return { ...comment, likes: Math.max(0, Number(comment.likes || 0) + delta) };
  }
  return {
    ...comment,
    replies: (comment.replies || []).map((reply) => updateCommentLike(reply, commentId, delta)),
  };
}

function bumpEngagement(value) {
  const text = String(value || "0");
  const number = Number.parseFloat(text.replace(/[^0-9.]/g, "")) || 0;
  if (text.toLowerCase().includes("k")) return `${(number + 0.1).toFixed(1)}K`;
  return String(Math.round(number + 1));
}

function reduceEngagement(value) {
  const text = String(value || "0");
  const number = Number.parseFloat(text.replace(/[^0-9.]/g, "")) || 0;
  if (text.toLowerCase().includes("k")) return `${Math.max(0, number - 0.1).toFixed(1)}K`;
  return String(Math.max(0, Math.round(number - 1)));
}

function normalizeProfileKey(value) {
  return String(value || "")
    .replace(/^@/, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "");
}

function findCommentProfile(name) {
  const key = normalizeProfileKey(name);
  for (const post of userPosts) {
    for (const comment of post.commentList || []) {
      const allComments = [comment, ...(comment.replies || [])];
      const found = allComments.find((item) => normalizeProfileKey(item.username || item.user) === key || normalizeProfileKey(item.user) === key);
      if (found) return { ...found, sourcePost: post };
    }
  }
  return null;
}

function openFeedProfile(name) {
  const key = normalizeProfileKey(name);
  const post = userPosts.find((item) => normalizeProfileKey(item.user) === key || normalizeProfileKey(item.username) === key);
  const commentProfile = post ? null : findCommentProfile(name);
  const demoProfile = getDemoUser(name);
  if (!post && !commentProfile && !demoProfile) return;
  const source = post || commentProfile?.sourcePost || {};
  const profileName = post?.user || commentProfile?.user || demoProfile.name;
  if (profileName === state.user?.name || normalizeProfileKey(profileName) === normalizeProfileKey(state.user?.username)) {
    state.viewedProfile = null;
  } else if (demoProfile) {
    state.viewedProfile = getDemoProfilePayload(demoProfile);
  } else {
    state.viewedProfile = {
      id: normalizeProfileKey(profileName),
      name: profileName,
      username: normalizeProfileKey(commentProfile?.username || profileName),
      avatar: post?.avatar || commentProfile?.avatar || "star",
      avatarUrl: post?.avatarUrl || commentProfile?.avatarUrl,
      bio: post?.caption || `Fan activo de ${source.group || "K-pop"} en HallyuHub.`,
      country: source.location || "Latam",
      fandom: source.badge || "Army 💜",
      bias: "Bias secreto",
      favoriteGroup: source.group || "K-pop",
      phrase: "Compartiendo momentos fandom en HallyuHub.",
      followers: "2.8K",
      following: "210",
      posts: "32",
      starsReceived: source.likes || "1.2K",
      profileBg: source.type === "trending" ? "stage" : "pastel",
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
  const safeUrl = imageUrl || getDemoUserImage(getStableAssetIndex(`${className}-${avatarId || "demo"}`, DEMO_USER_IMAGES.length));
  const fallbackUrl = getDemoUserImage(getStableAssetIndex(`${safeUrl}-fallback`, DEMO_USER_IMAGES.length));
  return `<img class="avatar-photo ${className}" src="${escapeAttr(safeUrl)}" alt="Avatar de usuario" loading="lazy" onerror="this.onerror=null;this.src='${escapeAttr(fallbackUrl)}';" />`;
}

function getDemoAssetPath(folder, prefix, index, count) {
  const safeIndex = ((Number(index) || 0) % count + count) % count;
  return `./assets/${folder}/${prefix}-${String(safeIndex + 1).padStart(2, "0")}.jpg`;
}

function getStableAssetIndex(seed, count) {
  const value = String(seed || "hallyu");
  let hash = 0;
  for (let index = 0; index < value.length; index += 1) {
    hash = (hash * 31 + value.charCodeAt(index)) % 100000;
  }
  return hash % count;
}

function getDemoUserImage(index) {
  return DEMO_USER_IMAGES[((Number(index) || 0) % DEMO_USER_IMAGES.length + DEMO_USER_IMAGES.length) % DEMO_USER_IMAGES.length];
}

function getDemoPostImage(index) {
  return DEMO_POST_IMAGES[((Number(index) || 0) % DEMO_POST_IMAGES.length + DEMO_POST_IMAGES.length) % DEMO_POST_IMAGES.length];
}

function getDemoStoryImage(index) {
  return DEMO_STORY_IMAGES[((Number(index) || 0) % DEMO_STORY_IMAGES.length + DEMO_STORY_IMAGES.length) % DEMO_STORY_IMAGES.length];
}

function getDemoDropMedia(index) {
  return DEMO_DROP_MEDIA[((Number(index) || 0) % DEMO_DROP_MEDIA.length + DEMO_DROP_MEDIA.length) % DEMO_DROP_MEDIA.length];
}

function getDemoUser(identifier) {
  if (typeof identifier === "number") return demoUsers[identifier % demoUsers.length];
  const key = normalizeProfileKey(identifier);
  return demoUsers.find((user) => [user.id, user.name, user.username].some((value) => normalizeProfileKey(value) === key || normalizeProfileKey(value).includes(key))) || demoUsers[0];
}

function getDemoProfilePayload(user) {
  return {
    id: user.id,
    name: user.name,
    username: user.username,
    avatar: "berry",
    avatarUrl: user.avatarUrl,
    bio: user.bio,
    country: `${user.city}, ${user.country}`,
    fandom: user.fandom,
    bias: "Bias secreto",
    favoriteGroup: user.favoriteGroup,
    phrase: user.bio,
    followers: user.followers,
    following: user.following,
    posts: user.posts,
    starsReceived: user.starsReceived,
    level: user.level,
    profileBg: user.profileBg,
  };
}

function hydrateDemoSocialData() {
    const postUsers = ["Luna Rivas", "Camila Seo", "Valentina Park", "Agus Han", "Dani Lee", "Sofi Moon"];
  const postTopics = [
    ["Comeback night", ["#comeback", "#STAYLatam"], "Santiago, Chile", "✦"],
    ["Trade seguro", ["#photocard", "#tradeSeguro"], "Palermo, Buenos Aires", "♡"],
    ["K-pop 101", ["#Kpop101", "#bias"], "Lima, Perú", "♪"],
    ["Random dance", ["#DanceChallenge", "#RandomPlay", "#BLACKPINK"], "Buenos Aires", "★"],
    ["Evento fandom", ["#EventoKpop", "#Santiago", "#FandomSeguro"], "Santiago, Chile", "◇"],
    ["Outfit pastel", ["#KpopOutfit", "#Y2K", "#PastelNeon"], "Santiago, Chile", "✦"],
  ];
  userPosts.forEach((post, index) => {
    const user = getDemoUser(postUsers[index] || index);
    const [title, hashtags, location, motif] = postTopics[index] || postTopics[0];
    const mediaImage = post.imageUrl || post.mediaUrl || getDemoPostImage(index);
    post.user = user.name;
    post.username = user.username;
    post.avatarUrl = user.avatarUrl;
    post.badge = user.fandom;
    post.location ||= location;
    post.hashtags = hashtags || post.hashtags;
    post.imageUrl = mediaImage;
    post.mediaUrl = mediaImage;
    post.mediaType ||= "image";
    post.caption = post.caption || user.bio;
    hydrateDemoComments(post.commentList || [], index + 1);
  });
  if (!userPosts.some((post) => post.id === "demo-extra-1")) {
    [
      ["demo-extra-1", "Renata Vega", "IVE fancam board", "Reacción al stage de IVE: luces frías, look elegante y cámara vertical perfecta para Drop.", ["#IVE", "#fancam", "#DIVE"], "Fancam", "📸"],
      ["demo-extra-2", "Julieta Min", "Carpeta de photocards", "Actualicé la carpeta con sleeves holográficos y separadores por era. Quedó demasiado cute.", ["#photocard", "#collector", "#tradeSeguro"], "Photocard", "💿"],
      ["demo-extra-3", "Emi Sol", "Outfit BLACKPINK", "Probando un outfit black-pink para el próximo random dance. Brillo suave, botas y lazo.", ["#BLACKPINK", "#KpopOutfit", "#Blink"], "Outfit", "🎀"],
      ["demo-extra-4", "Ara Chen", "Cyber Seoul edit", "Hice un edit estilo aespa con neón azul, tipografía futurista y glow de escenario.", ["#aespa", "#CyberSeoul", "#MY"], "Fanart", "✦"],
      ["demo-extra-5", "Mateo Song", "Lightstick night", "Probé batería, funda y modo concierto del lightstick antes del evento ENGENE.", ["#ENHYPEN", "#lightstick", "#ENGENE"], "Evento fandom", "★"],
      ["demo-extra-6", "Bruno Park", "Unboxing de álbum", "Llegó el álbum y el photobook se ve increíble. Dejo mini review para quienes están dudando.", ["#album", "#unboxing", "#KpopLatam"], "Compra álbum", "♪"],
    ].forEach(([id, userName, title, caption, hashtags, group, motif], index) => {
      const user = getDemoUser(userName);
      const mediaImage = getDemoPostImage(index + 6);
      userPosts.push({
        id,
        user: user.name,
        username: user.username,
        avatarUrl: user.avatarUrl,
        group,
        category: group === "Outfit" ? "outfits" : group === "Photocard" ? "photocards" : "posts",
        type: index % 2 ? "popular" : "event",
        time: `hace ${index + 2} h`,
        badge: user.fandom,
        online: index % 2 === 0,
        hashtags,
        caption,
        likes: `${(1.1 + index * 0.6).toFixed(1)}K`,
        comments: String(42 + index * 19),
        commentList: [
          { id: `${id}-c1`, user: getDemoUser(index + 3).name, username: getDemoUser(index + 3).username, avatarUrl: getDemoUser(index + 3).avatarUrl, time: "18m", body: "Se ve muy real, guardado para inspirarme ✨", likes: 12 + index, replies: [] },
        ],
        imageUrl: mediaImage,
        mediaUrl: mediaImage,
        mediaType: "image",
        location: `${user.city}, ${user.country}`,
        shares: String(30 + index * 14),
        saves: String(96 + index * 33),
      });
    });
  }
  followingStories.forEach((story, index) => {
    const user = getDemoUser(index + 2);
    story.user = user.name;
    story.avatarUrl = user.avatarUrl;
    story.imageUrl = story.imageUrl || getDemoStoryImage(index);
    story.mediaUrl = story.mediaUrl || story.imageUrl;
    story.mediaType ||= "image";
  });
  privateRequests.forEach((request, index) => {
    const user = getDemoUser(index + 8);
    request.name = user.name;
    request.avatarUrl = user.avatarUrl;
  });
  conversations.forEach((chat, index) => {
    const user = getDemoUser(index + 10);
    chat.name = user.name;
    chat.avatarUrl = user.avatarUrl;
  });
}

function hydrateDemoComments(comments, offset = 0) {
  comments.forEach((comment, index) => {
    const user = getDemoUser(offset + index);
    comment.user = user.name;
    comment.username = user.username;
    comment.avatarUrl = user.avatarUrl;
    hydrateDemoComments(comment.replies || [], offset + index + 3);
  });
}

function renderAuth() {
  const isRegister = state.authMode === "register";
  const isLogin = state.authMode === "login";
  return `
    <section class="auth-screen">
      <div class="auth-glow auth-glow-one"></div>
      <div class="auth-glow auth-glow-two"></div>
      <div class="auth-brand">
        <span class="auth-logo app-logo" aria-hidden="true"><span class="hallyu-mark"></span></span>
        <p class="eyebrow">HallyuHub</p>
        <h1>Tu universo K-pop latino</h1>
        <p class="muted">Comunidad, Drops, Fancams y fandoms latinos en una app social premium.</p>
      </div>
      ${
        !isLogin && !isRegister
          ? `<div class="auth-card auth-choice-card">
              <button class="primary-button auth-main-action" data-auth-mode="login">Iniciar sesión</button>
              <button class="ghost-button auth-secondary-action" data-auth-mode="register">Crear cuenta</button>
            </div>`
          : `<div class="auth-card">
              <button class="auth-back-button" data-auth-mode="start" aria-label="Volver">←</button>
              <div class="auth-card-head">
                <span>${isRegister ? "Nueva cuenta" : "Bienvenido/a"}</span>
                <h2>${isRegister ? "Crear cuenta" : "Iniciar sesión"}</h2>
              </div>
              <div class="form-stack auth-form-stack">
                ${
                  isRegister
                    ? `<label>Nombre<input id="auth-name" value="${state.user?.name || ""}" placeholder="Luna Hallyu" /></label>
                       <label>Usuario<input id="auth-username" value="${state.user?.username || ""}" placeholder="lunahallyu" /></label>`
                    : ""
                }
                <label>Email o usuario<input id="auth-email" type="text" value="${state.user?.email || ""}" placeholder="fan@hallyuhub.app" /></label>
                <label>Contraseña<input id="auth-password" type="password" value="${state.user?.password || ""}" placeholder="••••••••" /></label>
                ${
                  isRegister
                    ? `<label>Confirmar contraseña<input id="auth-password-confirm" type="password" placeholder="••••••••" /></label>
                       <label class="auth-terms-row"><input id="auth-terms" type="checkbox" /> Acepto términos y política de privacidad</label>`
                    : ""
                }
              </div>
              <button class="primary-button auth-submit" data-auth-submit="${isRegister ? "register" : "login"}">${isRegister ? "Crear cuenta" : "Entrar"}</button>
              ${
                isLogin
                  ? `<button class="auth-link-button" data-demo-action="Recuperación de contraseña disponible próximamente">Olvidé mi contraseña</button>
                     <div class="auth-divider"><span>o continuar con</span></div>
                     <div class="auth-social-grid">
                       <button data-demo-action="Login con Google disponible próximamente">Google</button>
                       <button data-demo-action="Login con Apple disponible próximamente">Apple</button>
                     </div>
                     <button class="auth-face-button" data-demo-action="Disponible próximamente">Face ID / reconocimiento facial</button>`
                  : `<p class="auth-after-copy">Después podrás elegir avatar/foto, fandom, grupos favoritos, país y bio.</p>`
              }
            </div>`
      }
    </section>
  `;
}

function getStoryDraftElements() {
  if (!Array.isArray(state.storyDraft.elements) || !state.storyDraft.elements.length) {
    state.storyDraft.elements = [{ id: "sticker-1", type: "sticker", content: state.storyDraft.sticker || "✨", x: 72, y: 18, size: 38, rotation: 0 }];
    state.storyDraft.selectedElementId = state.storyDraft.elements[0].id;
  }
  return state.storyDraft.elements;
}

function addStoryElement(content, options = {}) {
  const id = `layer-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
  state.storyDraft.elements = [
    ...getStoryDraftElements(),
    {
      id,
      type: options.type || "sticker",
      content,
      x: 36 + Math.round(Math.random() * 28),
      y: 28 + Math.round(Math.random() * 28),
      size: options.size || 34,
      rotation: 0,
      color: options.color || state.storyDraft.textColor,
      font: options.font || state.storyDraft.font,
      textStyle: options.textStyle || state.storyDraft.textStyle,
      imageUrl: options.imageUrl || "",
      animated: Boolean(options.animated),
    },
  ];
  state.storyDraft.selectedElementId = id;
}

function syncStoryDraftElement(field, value) {
  if (field !== "text" && field !== "mention") return;
  const id = field === "text" ? "text-layer" : "mention-layer";
  const clean = String(value || "").trim();
  state.storyDraft.elements = getStoryDraftElements().filter((element) => element.id !== id || clean);
  if (!clean) return;
  const existing = state.storyDraft.elements.find((element) => element.id === id);
  const nextElement = {
    id,
    type: "text",
    content: field === "mention" && !clean.startsWith("@") ? `@${clean}` : clean,
    x: field === "text" ? 50 : 50,
    y: field === "text" ? 62 : 72,
    size: field === "text" ? 24 : 16,
    rotation: 0,
    color: state.storyDraft.textColor,
    font: state.storyDraft.font,
    textStyle: state.storyDraft.textStyle,
  };
  state.storyDraft.elements = existing
    ? state.storyDraft.elements.map((element) => (element.id === id ? { ...element, content: nextElement.content } : element))
    : [...state.storyDraft.elements, nextElement];
  state.storyDraft.selectedElementId = id;
}

function getSelectedStoryElement() {
  return getStoryDraftElements().find((element) => element.id === state.storyDraft.selectedElementId) || getStoryDraftElements()[0];
}

function updateSelectedStoryElement(key, value) {
  const selectedId = state.storyDraft.selectedElementId;
  state.storyDraft.elements = getStoryDraftElements().map((element) =>
    element.id === selectedId ? { ...element, [key]: value } : element,
  );
}

function updateSelectedTextElement(key, value) {
  const selectedId = state.storyDraft.selectedElementId;
  state.storyDraft.elements = getStoryDraftElements().map((element) =>
    element.id === selectedId || element.type === "text" ? { ...element, [key]: value } : element,
  );
}

function startStoryElementDrag(event, elementId) {
  event.preventDefault();
  state.storyDraft.selectedElementId = elementId;
  const preview = event.currentTarget.closest(".story-editor-preview");
  const target = event.currentTarget;
  if (!preview) return;
  const moveLayer = (moveEvent) => {
    const rect = preview.getBoundingClientRect();
    const x = Math.max(4, Math.min(92, ((moveEvent.clientX - rect.left) / rect.width) * 100));
    const y = Math.max(4, Math.min(88, ((moveEvent.clientY - rect.top) / rect.height) * 100));
    state.storyDraft.elements = getStoryDraftElements().map((element) => (element.id === elementId ? { ...element, x, y } : element));
    target.style.left = `${x}%`;
    target.style.top = `${y}%`;
  };
  const stopDrag = () => {
    document.removeEventListener("pointermove", moveLayer);
    document.removeEventListener("pointerup", stopDrag);
    render();
  };
  document.addEventListener("pointermove", moveLayer);
  document.addEventListener("pointerup", stopDrag);
}

function getStoryMediaTransform(source = state.storyDraft) {
  return {
    scale: Math.max(0.55, Math.min(3, Number(source?.mediaScale || 1))),
    x: Math.max(-120, Math.min(120, Number(source?.mediaX || 0))),
    y: Math.max(-120, Math.min(120, Number(source?.mediaY || 0))),
    rotation: Math.max(-35, Math.min(35, Number(source?.mediaRotation || 0))),
  };
}

function getStoryMediaStyle(source = state.storyDraft) {
  const transform = getStoryMediaTransform(source);
  return `--media-scale:${transform.scale};--media-x:${transform.x}px;--media-y:${transform.y}px;--media-rotation:${transform.rotation}deg;`;
}

function resetStoryMediaTransform() {
  state.storyDraft.mediaScale = 1;
  state.storyDraft.mediaX = 0;
  state.storyDraft.mediaY = 0;
  state.storyDraft.mediaRotation = 0;
}

function startStoryMediaTransform(event) {
  if (!state.storyDraft.mediaUrl) return;
  if (event.pointerType === "touch") return;
  event.preventDefault();
  event.stopPropagation();
  const target = event.currentTarget;
  target.setPointerCapture?.(event.pointerId);
  const pointers = new Map([[event.pointerId, { x: event.clientX, y: event.clientY }]]);
  const initial = {
    ...getStoryMediaTransform(),
    pointerX: event.clientX,
    pointerY: event.clientY,
    distance: 0,
  };
  const updatePreview = () => {
    target.style.setProperty("--media-scale", state.storyDraft.mediaScale);
    target.style.setProperty("--media-x", `${state.storyDraft.mediaX}px`);
    target.style.setProperty("--media-y", `${state.storyDraft.mediaY}px`);
    target.style.setProperty("--media-rotation", `${state.storyDraft.mediaRotation || 0}deg`);
  };
  const pointerDistance = () => {
    const values = [...pointers.values()];
    if (values.length < 2) return 0;
    return Math.hypot(values[0].x - values[1].x, values[0].y - values[1].y);
  };
  const moveMedia = (moveEvent) => {
    if (!pointers.has(moveEvent.pointerId)) return;
    moveEvent.preventDefault();
    moveEvent.stopPropagation();
    pointers.set(moveEvent.pointerId, { x: moveEvent.clientX, y: moveEvent.clientY });
    if (pointers.size > 1) {
      const distance = pointerDistance();
      const baseDistance = initial.distance || distance || 1;
      if (!initial.distance) initial.distance = distance;
      state.storyDraft.mediaScale = Math.max(0.55, Math.min(3, Math.round(initial.scale * (distance / baseDistance) * 100) / 100));
    } else {
      const current = pointers.get(moveEvent.pointerId);
      state.storyDraft.mediaX = Math.max(-120, Math.min(120, Math.round(initial.x + current.x - initial.pointerX)));
      state.storyDraft.mediaY = Math.max(-120, Math.min(120, Math.round(initial.y + current.y - initial.pointerY)));
    }
    updatePreview();
  };
  const stopMedia = (upEvent) => {
    upEvent.preventDefault?.();
    upEvent.stopPropagation?.();
    pointers.delete(upEvent.pointerId);
    if (pointers.size === 0) {
      document.removeEventListener("pointermove", moveMedia);
      document.removeEventListener("pointerup", stopMedia);
      document.removeEventListener("pointercancel", stopMedia);
      render();
    }
  };
  document.addEventListener("pointermove", moveMedia);
  document.addEventListener("pointerup", stopMedia);
  document.addEventListener("pointercancel", stopMedia);
}

function startStoryMediaTouchTransform(event) {
  if (!state.storyDraft.mediaUrl || !event.touches?.length) return;
  event.preventDefault();
  event.stopPropagation();
  const target = event.currentTarget;
  const startTouches = [...event.touches].map((touch) => ({ x: touch.clientX, y: touch.clientY }));
  const initial = getStoryMediaTransform();
  const initialDistance = startTouches.length > 1 ? Math.hypot(startTouches[0].x - startTouches[1].x, startTouches[0].y - startTouches[1].y) : 0;
  const updatePreview = () => {
    target.style.setProperty("--media-scale", state.storyDraft.mediaScale);
    target.style.setProperty("--media-x", `${state.storyDraft.mediaX}px`);
    target.style.setProperty("--media-y", `${state.storyDraft.mediaY}px`);
    target.style.setProperty("--media-rotation", `${state.storyDraft.mediaRotation || 0}deg`);
  };
  const move = (moveEvent) => {
    moveEvent.preventDefault();
    moveEvent.stopPropagation();
    const touches = [...moveEvent.touches].map((touch) => ({ x: touch.clientX, y: touch.clientY }));
    if (touches.length > 1 && initialDistance) {
      const distance = Math.hypot(touches[0].x - touches[1].x, touches[0].y - touches[1].y);
      state.storyDraft.mediaScale = Math.max(0.55, Math.min(3, Math.round(initial.scale * (distance / initialDistance) * 100) / 100));
    } else if (touches.length === 1 && startTouches[0]) {
      state.storyDraft.mediaX = Math.max(-120, Math.min(120, Math.round(initial.x + touches[0].x - startTouches[0].x)));
      state.storyDraft.mediaY = Math.max(-120, Math.min(120, Math.round(initial.y + touches[0].y - startTouches[0].y)));
    }
    updatePreview();
  };
  const end = (endEvent) => {
    endEvent?.preventDefault?.();
    endEvent?.stopPropagation?.();
    target.removeEventListener("touchmove", move);
    target.removeEventListener("touchend", end);
    target.removeEventListener("touchcancel", end);
    render();
  };
  target.addEventListener("touchmove", move, { passive: false });
  target.addEventListener("touchend", end, { passive: false });
  target.addEventListener("touchcancel", end, { passive: false });
}

function playStoryMusicPreview(name) {
  const track = storyMusicLibrary.find((item) => item.name === name);
  const AudioEngine = window.AudioContext || window.webkitAudioContext;
  if (!track || !AudioEngine) return;
  const audio = new AudioEngine();
  const oscillator = audio.createOscillator();
  const gain = audio.createGain();
  oscillator.type = "sine";
  oscillator.frequency.value = track.tone || 523;
  gain.gain.setValueAtTime(0.0001, audio.currentTime);
  gain.gain.exponentialRampToValueAtTime(0.08, audio.currentTime + 0.03);
  gain.gain.exponentialRampToValueAtTime(0.0001, audio.currentTime + 0.65);
  oscillator.connect(gain);
  gain.connect(audio.destination);
  oscillator.start();
  oscillator.stop(audio.currentTime + 0.68);
}

function createOwnStory(style = "Neon pastel") {
  const draft = state.storyDraft || {};
  const elements = getStoryDraftElements();
  const storyId = `own-${Date.now()}`;
  const story = {
    id: storyId,
    createdAt: new Date().toISOString(),
    user: state.user?.name || "Mi historia",
    avatar: state.user?.avatar || "berry",
    label: "mi historia",
    time: "Ahora",
    music: draft.music || "HallyuHub · fan upload",
    title: "",
    detail: draft.location || "",
    stars: 0,
    views: 37,
    colors: getStoryBackground(style),
    style,
    mediaName: draft.mediaName || "",
    mediaUrl: draft.mediaUrl || "",
    mediaType: draft.mediaType || "",
    thumbnail: draft.mediaUrl || "",
    text: draft.text || "",
    stickers: elements,
    mediaScale: getStoryMediaTransform(draft).scale,
    mediaX: getStoryMediaTransform(draft).x,
    mediaY: getStoryMediaTransform(draft).y,
    mediaRotation: getStoryMediaTransform(draft).rotation,
    type: draft.type || "text",
    musicCategory: draft.musicCategory || "Viral",
    elements,
  };
  state.ownStories = [story, ...(state.ownStories || [])].slice(0, 20);
  state.ownStory = story;
  state.activeOwnStoryIndex = 0;
  state.storyArchive = [
    {
      id: story.id,
      userId: state.user?.id || "local-user",
      mediaUrl: story.mediaUrl,
      mediaType: story.mediaType || "text",
      createdAt: story.createdAt,
      thumbnail: story.thumbnail || story.mediaUrl || "",
      text: story.text || "",
      stickers: story.stickers || [],
      music: story.music,
      scale: story.mediaScale,
      positionX: story.mediaX,
      positionY: story.mediaY,
      rotation: story.mediaRotation,
    },
    ...(state.storyArchive || []),
  ].slice(0, 60);
  storage.set("hallyuHubOwnStories", state.ownStories);
  storage.set("hallyuHubOwnStory", state.ownStory);
  storage.set("hallyuHubStoryArchive", state.storyArchive);
  const storyKey = getStoryKey(-1);
  if (storyKey) {
    state.viewedStories = { ...state.viewedStories };
    delete state.viewedStories[storyKey];
    storage.set("hallyuHubViewedStories", state.viewedStories);
  }
  state.storyEditorOpen = false;
  state.activeStory = -1;
  state.storyDirection = 1;
}

function publishStoryFromEditor(style = state.storyDraft?.background || "Neon pastel") {
  createOwnStory(style);
  showToast("Historia publicada");
  playAppSound("publish");
  render();
}

function getStoryBackground(style) {
  const backgrounds = {
    "Neon pastel": "linear-gradient(160deg, #fbbcdb, #65e4ff 50%, #a855f7)",
    "Idol stage": "linear-gradient(160deg, #101827, #d946ef 48%, #65e4ff)",
    "Seoul night": "linear-gradient(160deg, #040711, #263d72 50%, #fbbcdb)",
    "Lightstick glow": "linear-gradient(160deg, #fff1f9, #a855f7 45%, #12051e)",
    "Photocard wall": "linear-gradient(160deg, #ffb86b, #fbbcdb 46%, #77f4c7)",
    "Cute comeback": "linear-gradient(160deg, #fbbcdb, #fff1f9 48%, #65e4ff)",
  };
  return backgrounds[style] || backgrounds["Neon pastel"];
}

function sendStoryMessage(message) {
  if (!message) return;
  const story = getActiveStory();
  const ownerKey = normalizeProfileKey(story?.user || "historia");
  const currentUser = state.user || defaultUser;
  const item = {
    id: `story-msg-${Date.now()}`,
    ownerId: ownerKey,
    fromId: currentUser.id,
    from: currentUser.name,
    fromUsername: currentUser.username,
    fromAvatarUrl: currentUser.avatarUrl,
    to: story?.user || "Historia",
    storyId: story?.id || getStoryKey(state.activeStory),
    message,
    time: "Ahora",
    status: "Enviado",
  };
  state.storyInbox = [item, ...state.storyInbox].slice(0, 12);
  storage.set("hallyuHubStoryInbox", state.storyInbox);
  state.storyComposerOpen = false;
  state.storyPaused = false;
  showToast("Mensaje enviado");
  playAppSound("message");
  render();
}

function getActiveStory() {
  if (state.activeStory === -1) return getActiveOwnStory();
  return followingStories[state.activeStory];
}

function getOwnStorySequence() {
  return Array.isArray(state.ownStories) && state.ownStories.length
    ? state.ownStories
    : state.ownStory
      ? [state.ownStory]
      : [];
}

function getActiveOwnStory() {
  const stories = getOwnStorySequence();
  return stories[Math.max(0, Math.min(stories.length - 1, state.activeOwnStoryIndex || 0))] || state.ownStory;
}

function getStoryViewerSequence() {
  if (state.activeStory === -1) {
    return { stories: getOwnStorySequence(), index: Math.max(0, state.activeOwnStoryIndex || 0), isOwn: true };
  }
  const active = followingStories[state.activeStory];
  if (!active) return { stories: [], index: 0, isOwn: false };
  const userKey = normalizeProfileKey(active.user);
  const group = followingStories
    .map((story, index) => ({ ...story, sourceIndex: index }))
    .filter((story) => normalizeProfileKey(story.user) === userKey);
  const groupIndex = Math.max(0, group.findIndex((story) => story.sourceIndex === state.activeStory));
  return { stories: group.length ? group : [active], index: groupIndex, isOwn: false };
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
          createdAt: post.created_at || new Date().toISOString(),
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
  const orderedStoryIndexes = getOrderedStoryIndexes();
  return `
    ${renderHomeHighlights()}
    <div class="stories-row" aria-label="Historias de personas que sigo">
      <div class="story-item own-story-item">
        <button type="button" class="story-own-main" data-own-story aria-label="${state.ownStory ? "Ver mi historia" : "Crear historia"}">
          <span class="story-ring own-ring ${state.ownStory ? "has-story" : "empty-story"} ${state.ownStory && areAllOwnStoriesViewed() ? "viewed" : ""}">
            ${state.ownStory ? renderAvatarElement("story-avatar", state.user?.avatar || "berry", state.user?.avatarUrl || getDemoUserImage(0)) : `<span class="story-plus">+</span>`}
          </span>
        </button>
        ${state.ownStory ? `<button type="button" class="story-add-badge" data-story-editor-open aria-label="Agregar nueva historia">+</button>` : ""}
        <strong>${state.ownStory ? "Tu historia" : "Crear"}</strong>
        <small>${state.ownStory ? `${state.ownStory.stars}★ · ${state.ownStory.views} vistas` : "Subir"}</small>
      </div>
      ${orderedStoryIndexes
        .map(
          (index) => {
            const story = followingStories[index];
            return `
          <button class="story-item" data-story-index="${index}">
            <span class="story-ring ${isStoryViewed(index) ? "viewed" : "unviewed"}">
              ${renderAvatarElement("story-avatar", story.avatar, story.avatarUrl)}
            </span>
            <strong>${story.user}</strong>
          </button>`;
          },
        )
        .join("")}
    </div>
    <section class="home-banner-shell" aria-label="Banners destacados">
      <div class="home-banner-track">
        ${[...homeBanners, ...homeBanners]
          .map(
            (banner, index) => `
            <button type="button" class="home-banner" style="--art:${banner.colors}" ${getBannerActionAttrs(banner)}>
              <span>${banner.meta}</span>
              <strong>${banner.title}</strong>
            </button>`,
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
        .map((post, index) => renderSocialPost(post, index, { compactHome: true }))
        .join("")}
      <div class="feed-loader">
        <span></span><span></span><span></span>
        <strong>Cargando más momentos fandom...</strong>
      </div>
    </div>
    ${state.toast ? `<div class="app-toast">${state.toast}</div>` : ""}
  `;
}

function filterHomeFeed(posts) {
  const filter = state.homeFilter || "all";
  const visiblePosts = posts.filter((post) => !isPostHidden(post) && !isUserMuted(post));
  if (filter === "all") return sortPostsByRecent(visiblePosts);
  if (filter === "viral" || filter === "trends") return sortPostsByRecent(visiblePosts.filter((post) => post.type === "trending" || post.category === "trends"));
  if (filter === "outfits") return sortPostsByRecent(visiblePosts.filter((post) => post.category === "outfits" || post.type === "outfit"));
  if (filter === "challenges") return sortPostsByRecent(visiblePosts.filter((post) => post.category === "trends" || (post.hashtags || []).some((tag) => tag.toLowerCase().includes("challenge"))));
  if (filter === "events") return sortPostsByRecent(visiblePosts.filter((post) => post.type === "event" || (post.hashtags || []).some((tag) => tag.toLowerCase().includes("evento"))));
  if (filter.startsWith("#")) return sortPostsByRecent(visiblePosts.filter((post) => (post.hashtags || []).some((tag) => tag.toLowerCase() === filter.toLowerCase())));
  return sortPostsByRecent(visiblePosts);
}

function getHomeFilterLabel(filter) {
  const labels = {
    all: "Feed vivo",
    viral: "Lo más viral",
    trends: "Drops populares",
    outfits: "Outfits K-pop",
    challenges: "Challenges",
    events: "Eventos destacados",
  };
  return labels[filter] || `Hashtag ${filter}`;
}

function buildHomeFeed(posts) {
  const cycles = ["Ahora", "Hace 4 min", "Hace 12 min", "Hace 25 min"];
  const sortedPosts = sortPostsByRecent(posts);
  return Array.from({ length: 3 }, (_, round) =>
    sortedPosts.map((post, index) => ({
      ...post,
      id: `${post.id || "post"}-${round}`,
      time: round === 0 ? getPostDisplayTime(post) : cycles[(index + round) % cycles.length],
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
  const cleanHighlights = homeHighlightStories.filter((item) => !["Drops", "Challenges"].includes(item.label));
  return `
    <section class="home-highlights" aria-label="Categorias rapidas del inicio">
      ${cleanHighlights
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

function renderStoryViewer() {
  if (state.activeStory === null) return "";
  const story = getActiveStory();
  if (!story) return "";
  const isOwnStory = state.activeStory === -1;
  const liked = state.likedStories[state.activeStory];
  const sequence = getStoryViewerSequence();
  const progressTotal = Math.max(1, sequence.stories.length);
  const progressIndex = Math.max(0, Math.min(progressTotal - 1, sequence.index));
  return `
    <section class="story-viewer story-slide-${state.storyDirection > 0 ? "next" : "prev"} ${state.storyPaused ? "story-paused" : ""} ${isOwnStory ? "own-story-viewer" : ""}" style="--story-art:${story.colors}" aria-label="Historia abierta">
      <div class="story-progress">${Array.from({ length: progressTotal }, (_, index) => `<span class="${index < progressIndex ? "seen" : ""} ${index === progressIndex ? "active" : ""}"></span>`).join("")}</div>
      <button class="story-close" data-story-close aria-label="Cerrar historia">X</button>
      <div class="story-hold-layer" data-story-hold aria-hidden="true"></div>
      <button class="story-tap-zone left" data-story-nav="-1" aria-label="Historia anterior"></button>
      <button class="story-tap-zone right" data-story-nav="1" aria-label="Historia siguiente"></button>
      <article class="story-full-card" style="--art:${story.colors}">
        <div class="story-full-head">
          <span class="story-ring small-ring">${renderAvatarElement("story-avatar small", story.avatar, story.avatarUrl)}</span>
          <div><h3>${story.user}</h3><p>${story.label} · ${story.time}</p></div>
        </div>
        <button type="button" class="story-music-pill" data-story-music-info aria-label="Ver audio de la historia"><span>♪</span>${story.music}</button>
        ${!isOwnStory && story.musicCategory ? `<div class="story-music-sticker">♪ ${story.musicCategory}</div>` : ""}
        ${state.storyMusicInfoOpen ? renderStoryAudioSheet(story) : ""}
        <div class="live-fandom-pill"><span></span>Live fandom activo</div>
        ${renderStoryMedia(story)}
        ${renderStoryLayers(story.elements || [])}
        ${
          story.title || story.detail
            ? `<div class="story-full-copy">
                ${story.title ? `<h2>${escapeHtml(story.title)}</h2>` : ""}
                ${story.detail ? `<p>${escapeHtml(story.detail)}</p>` : ""}
              </div>`
            : "<span></span>"
        }
        ${
          isOwnStory
            ? `<div class="story-interactions own-story-actions">
                <button class="own-story-stats-trigger ${state.ownStoryStatsOpen ? "active" : ""}" data-own-story-stats aria-label="Ver vistas y reacciones">Vistas y reacciones</button>
                <strong>${story.views || 0} vistas · ${story.stars || 0} estrellas</strong>
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

function renderStoryMedia(story) {
  const mediaUrl = story.mediaUrl || story.imageUrl || getDemoStoryImage(getStableAssetIndex(story.user, DEMO_STORY_IMAGES.length));
  const fallbackUrl = getDemoStoryImage(getStableAssetIndex(`${story.user}-fallback`, DEMO_STORY_IMAGES.length));
  const hasCustomTransform = story.mediaScale || story.mediaX || story.mediaY || story.mediaRotation;
  const mediaMarkup = story.mediaType === "video"
    ? `<video class="story-full-media" src="${escapeAttr(mediaUrl)}" autoplay muted loop playsinline preload="metadata"></video>`
    : `<img class="story-full-media" src="${escapeAttr(mediaUrl)}" alt="Historia subida por ${escapeAttr(story.user)}" loading="lazy" draggable="false" onerror="this.onerror=null;this.src='${escapeAttr(fallbackUrl)}';" />`;
  return hasCustomTransform
    ? `<div class="story-full-media-frame" style="${getStoryMediaStyle(story)}">${mediaMarkup}</div>`
    : mediaMarkup;
}

function renderStoryLayers(elements) {
  if (!elements.length) return "";
  return `<div class="story-layer-stage">${elements.map((element) => renderStoryLayer(element, false)).join("")}</div>`;
}

function renderStoryLayer(element, editable = false) {
  const Tag = editable ? "button" : "span";
  const data = editable ? `type="button" data-story-layer="${element.id}"` : "";
  const typeClass = element.type === "text" ? `text-layer ${element.textStyle || "glow"}` : element.type === "custom-sticker" ? "custom-sticker-layer" : "";
  const animated = element.animated || ["🪩", "✨", "💫", "🔥", "⭐", "💜"].includes(element.content) ? "animated-sticker" : "";
  const content = element.imageUrl
    ? `<img src="${escapeAttr(element.imageUrl)}" alt="${escapeAttr(element.content)}" />`
    : escapeHtml(element.content);
  return `<${Tag} class="story-layer ${typeClass} ${animated} ${editable && state.storyDraft.selectedElementId === element.id ? "selected" : ""}" ${data} style="left:${element.x}%; top:${element.y}%; font-size:${element.size}px; color:${element.color || "#fff"}; font-family:${escapeAttr(element.font || "Inter")}, system-ui, sans-serif; transform:translate(-50%, -50%) rotate(${element.rotation || 0}deg);">${content}</${Tag}>`;
}

function renderSocialPost(post, index, options = {}) {
  const expanded = Boolean(options.expanded || state.expandedPosts[post.id]);
  const isFeatured = !options.compactHome && (options.featured || post.type === "trending" || post.type === "event");
  const postMediaUrl = post.mediaUrl || post.imageUrl || getDemoPostImage(index);
  const postFallbackUrl = getDemoPostImage(index + 4);
  const caption = post.caption || "";
  const hasLongCaption = caption.length > 112;
  const hasExtraMeta = Boolean(post.location || post.date || post.hour || post.taggedPeople || post.taggedPlace || (post.hashtags || []).length > 2);
  const canExpand = hasLongCaption || hasExtraMeta;
  const baseId = getBasePostId(post.id);
  const liked = Boolean(state.likedPosts[baseId]);
  const shared = Boolean(state.sharedPosts[post.id] || state.sharePostTarget === post.id);
  const saved = Boolean(state.savedPosts[baseId]);
  return `
    <article class="post-card ${options.compact ? "profile-feed-post" : ""} ${isFeatured ? "featured-post" : ""} ${expanded ? "expanded-post" : ""}">
      <div class="post-head modern-post-head">
        <button class="post-profile-button" data-open-feed-profile="${post.user}">
          ${renderAvatarElement("mini post-author-avatar", post.avatar || "berry", post.avatarUrl)}
        </button>
        <button class="post-author-copy" data-open-feed-profile="${post.user}">
          <div class="post-user-line">
            <span class="online-dot ${post.online ? "active" : ""}"></span>
            <h3>${post.user}</h3>
          </div>
          <p class="muted">${getPostDisplayTime(post)}</p>
        </button>
        <div class="post-menu-wrap">
          <button class="post-menu-button" data-post-menu="${post.id}" aria-label="Mas opciones">•••</button>
          ${state.openPostMenu === post.id ? renderPostMenu(post) : ""}
        </div>
      </div>
      <div class="post-body-card filter-${post.filter || "original"}">
        <button class="post-open-button" data-toggle-post-more="${post.id}" aria-label="${expanded ? "Contraer publicacion" : "Expandir publicacion"}">
        ${
          postMediaUrl
              ? post.mediaType === "video"
              ? `<video class="post-media real-media" src="${postMediaUrl}" controls playsinline muted preload="metadata"></video>`
              : `<img class="post-media real-media" src="${escapeAttr(postMediaUrl)}" alt="Publicacion de ${escapeAttr(post.user)}" loading="lazy" onerror="this.onerror=null;this.src='${escapeAttr(postFallbackUrl)}';" />`
            : `<img class="post-media real-media" src="${escapeAttr(postFallbackUrl)}" alt="Publicacion de ${escapeAttr(post.user)}" loading="lazy" />`
        }
        </button>
        <p class="post-caption ${expanded ? "expanded" : ""}">${escapeHtml(caption)}</p>
        ${expanded ? renderPostOptionalMeta(post) : ""}
        ${expanded ? `<div class="post-hashtags">${(post.hashtags || ["#KpopLatam", "#HallyuHub"]).map((tag) => `<button type="button" data-home-filter="${tag}">${tag}</button>`).join("")}</div>` : ""}
        ${canExpand ? `<button class="post-more-button" data-toggle-post-more="${post.id}">${expanded ? "Ver menos" : "Ver más"}</button>` : ""}
        <div class="post-actions premium-actions">
          <button class="post-action-star ${liked ? "active" : ""}" ${post.id ? `data-like-post="${post.id}"` : ""}><span>★</span><strong>${post.likes || "0"}</strong></button>
          <button class="post-action-comment" ${post.id ? `data-comment-post="${post.id}"` : ""}><span></span><strong>${post.comments || "0"}</strong></button>
          <button class="post-action-share ${shared ? "active" : ""}" data-share-post="${post.id}"><span></span><strong>${post.shares || index + 24}</strong></button>
          <button class="post-action-save ${saved ? "active" : ""}" data-save-post="${post.id}"><span></span><strong>${post.saves || index + 12}</strong></button>
        </div>
        ${state.sharePostTarget === post.id ? renderPostShareSheet(post) : ""}
        ${state.openComments[post.id] ? renderCommentsPanel(post) : ""}
      </div>
    </article>`;
}

function renderPostMenu(post) {
  const key = normalizeProfileKey(post.user);
  const isFollowing = Boolean(state.followedProfiles[key]) && !state.mutedUsers[key];
  return isOwnPost(post)
    ? `<div class="post-menu-popover">
        <button type="button" data-edit-post="${post.id}">Editar publicacion</button>
        <button type="button" data-delete-post="${post.id}">Eliminar publicacion</button>
      </div>`
    : `<div class="post-menu-popover">
        <button type="button" data-report-post="${post.id}">Reportar publicacion</button>
        <button type="button" data-hide-post="${post.id}">Ocultar publicacion</button>
        ${
          isFollowing
            ? `<button type="button" data-unfollow-feed-user="${escapeAttr(post.user)}">Dejar de seguir usuario</button>`
            : `<button type="button" data-follow-feed-user="${escapeAttr(post.user)}">Seguir usuario</button>`
        }
      </div>`;
}

function renderPostShareSheet(post) {
  return `
    <section class="post-share-backdrop" aria-label="Compartir publicacion">
      <button class="post-share-dismiss" type="button" data-close-post-share aria-label="Cerrar compartir"></button>
      <div class="post-share-sheet" role="dialog" aria-label="Opciones para compartir" data-share-sheet>
        <div class="sheet-handle"></div>
        <div class="composer-head">
          <strong>Compartir publicación</strong>
          <button type="button" data-close-post-share aria-label="Cerrar">X</button>
        </div>
        <div class="share-option-grid">
          <button type="button" data-demo-action="Compartido en historia demo"><span class="nav-icon plus-icon"></span><strong>Compartir en historia</strong></button>
          <button type="button" data-demo-action="Enviado por chat demo"><span class="nav-icon chat-icon"></span><strong>Enviar por chat</strong></button>
          <button type="button" data-demo-action="Enlace copiado de ${escapeAttr(post.user)}"><span class="share-dot"></span><strong>Copiar enlace</strong></button>
        </div>
      </div>
    </section>
  `;
}

function renderReportSheet() {
  const parsed = parseReportTarget(state.reportTarget);
  const post = parsed.type === "post" ? findPostById(parsed.id) : null;
  const targetLabel = post ? `Publicacion de ${post.user}` : getReportTargetLabel(parsed);
  return `
    <section class="report-sheet" aria-label="Reportar publicacion">
      <div class="sheet-handle"></div>
      <div class="composer-head">
        <strong>${parsed.type === "copyright" ? "Reportar copyright" : "Reportar contenido"}</strong>
        <button type="button" data-report-close aria-label="Cerrar">X</button>
      </div>
      <p>${parsed.type === "copyright" ? "Si sos dueño del contenido y creés que se publicó sin autorización, podés reportarlo." : "Elegí un motivo. Queda guardado como pendiente para revisión del administrador."}</p>
      <div class="report-reason-list">
        ${reportReasons.map((reason) => `<button type="button" data-report-reason="${state.reportTarget}|${reason}">${reason}</button>`).join("")}
      </div>
      <button class="ghost-button danger-button" type="button" data-report-reason="copyright:${parsed.id}|Copyright">Reportar copyright</button>
      <small>${targetLabel}</small>
    </section>
  `;
}

function getReportTargetLabel(parsed) {
  const labels = {
    post: "Publicación seleccionada",
    comment: "Comentario seleccionado",
    drop: "Drop seleccionado",
    fancam: "Fancam seleccionada",
    profile: "Perfil seleccionado",
    artist: "Artista seleccionado",
    group: "Grupo seleccionado",
    copyright: "Contenido con posible infracción",
  };
  return labels[parsed.type] || "Contenido seleccionado";
}

function renderCommentsPanel(post) {
  const comments = post.commentList || [];
  const replyTarget = state.replyTo[post.id];
  const replyUser = replyTarget ? findCommentInPost(post, replyTarget)?.username : null;
  const replyLabel = replyUser ? `Respondiendo a @${replyUser}` : "Comparte tu opinión...";
  const emojis = ["💜", "✨", "🔥", "🫰", "🎤", "📸"];
  return `
    <section class="comments-panel" aria-label="Comentarios de ${escapeAttr(post.user)}">
      <div class="comments-list">
        ${
          comments.length
            ? comments.map((comment) => renderCommentItem(post.id, comment)).join("")
            : `<p class="comments-empty">Se la primera persona en comentar.</p>`
        }
      </div>
      ${
        replyTarget
          ? `<div class="reply-context">Respondiendo a @${escapeHtml(replyUser || "fan")} <button type="button" data-cancel-reply="${post.id}">Cancelar</button></div>`
          : ""
      }
      <div class="comment-composer">
        ${renderAvatarElement("mini comment-input-avatar", state.user?.avatar || "berry", state.user?.avatarUrl)}
        <input type="text" data-comment-draft="${post.id}" value="${escapeAttr(state.commentDrafts[post.id] || "")}" placeholder="${escapeAttr(replyLabel)}" />
        <button class="comment-send-button" type="button" data-send-comment="${post.id}">Enviar</button>
        <div class="comment-emoji-row">
          ${emojis.map((emoji) => `<button type="button" data-comment-emoji="${post.id}|${emoji}" aria-label="Agregar ${emoji}">${emoji}</button>`).join("")}
        </div>
      </div>
    </section>
  `;
}

function renderCommentItem(postId, comment, isReply = false) {
  const key = `${postId}:${comment.id}`;
  const liked = Boolean(state.likedComments[key]);
  return `
    <div class="comment-item ${isReply ? "comment-reply" : ""}">
      ${renderAvatarElement("mini comment-avatar", comment.avatar || "berry", comment.avatarUrl)}
      <div class="comment-main">
        <div class="comment-meta">
          <button type="button" data-open-feed-profile="${escapeAttr(comment.username || comment.user)}">${escapeHtml(comment.user || "Hallyu fan")}</button>
          <span>${escapeHtml(comment.time || "Ahora")}</span>
        </div>
        <p class="comment-text">${renderMentionedText(comment.body || "")}</p>
        <div class="comment-tools">
          <button type="button" data-reply-comment="${postId}:${comment.id}:${escapeAttr(comment.username || normalizeProfileKey(comment.user))}">Responder</button>
          <button type="button" data-report-content="comment:${postId}:${comment.id}">Reportar</button>
          <button class="comment-like ${liked ? "active" : ""}" type="button" data-like-comment="${key}" aria-label="Dar estrella al comentario">
            <span>★</span>
            <strong>${Number(comment.likes || 0)}</strong>
          </button>
        </div>
        ${(comment.replies || []).length ? `<div class="comment-replies">${(comment.replies || []).map((reply) => renderCommentItem(postId, reply, true)).join("")}</div>` : ""}
      </div>
    </div>
  `;
}

function findCommentInPost(post, commentId) {
  for (const comment of post.commentList || []) {
    if (comment.id === commentId) return comment;
    const reply = (comment.replies || []).find((item) => item.id === commentId);
    if (reply) return reply;
  }
  return null;
}

function renderMentionedText(text) {
  return escapeHtml(text).replace(/@([a-zA-Z0-9_.]+)/g, (_, username) => {
    const clean = username.replace(/\./g, "");
    return `<button class="mention-link" type="button" data-open-feed-profile="${escapeAttr(clean)}">@${escapeHtml(username)}</button>`;
  });
}

function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function escapeAttr(value) {
  return escapeHtml(value).replace(/`/g, "&#096;");
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
  const starViewers = storyViewers.filter((viewer) => String(viewer.action || "").toLowerCase().includes("estrella"));
  return `
    <div class="own-story-stats">
      <div class="own-stat-grid">
        <div><strong>${story.views || 0}</strong><span>vistas</span></div>
        <div><strong>${story.stars || starViewers.length}</strong><span>estrellas</span></div>
        <div><strong>${storyViewers.length}</strong><span>fans</span></div>
      </div>
      <div class="viewer-section-label">Vieron tu historia</div>
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
      <div class="viewer-section-label">Dieron estrella</div>
      <div class="viewer-list compact-viewer-list">
        ${starViewers
          .map(
            (viewer) => `
            <div class="viewer-row">
              <span class="viewer-avatar"></span>
              <div><strong>${viewer.name}</strong><small>reaccionó con estrella</small></div>
              <span class="fandom-badge">★</span>
            </div>`,
          )
          .join("")}
      </div>
    </div>
  `;
}

function renderStoryAudioSheet(story) {
  const track = storyMusicLibrary.find((item) => item.name === story.music);
  const title = story.music || "Audio HallyuHub";
  const category = story.musicCategory || track?.category || "Demo";
  const artist = track?.detail || "Audio demo de HallyuHub";
  return `
    <div class="story-audio-sheet">
      <div class="sheet-handle"></div>
      <div>
        <span class="tag">${escapeHtml(category)}</span>
        <h3>${escapeHtml(title)}</h3>
        <p>${escapeHtml(artist)}</p>
        <small>Audio demo de HallyuHub</small>
      </div>
      <div class="story-audio-actions">
        <button type="button" data-story-audio-action="use">Usar este audio</button>
        <button type="button" data-story-audio-action="more">Ver más con este audio</button>
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
        <input id="story-message-input" data-story-message-input placeholder="Escribir texto K-pop..." />
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

function renderStoryEditor() {
  const draft = state.storyDraft;
  const userLevel = Number(state.user?.level || 1);
  const elements = getStoryDraftElements();
  const selected = getSelectedStoryElement();
  const visibleTracks = storyMusicLibrary.filter((track) => track.category === (draft.musicCategory || "Viral"));
  return `
    <section class="story-editor-overlay" aria-label="Crear historia">
      <div class="story-editor-card fullscreen-editor">
        <div class="story-editor-topbar story-create-header">
          <button type="button" data-story-editor-close aria-label="Cerrar editor">X</button>
          <strong>Historia</strong>
          <span></span>
        </div>
        <div class="story-create-body">
          <div class="story-editor-preview story-create-canvas" style="--art:${getStoryBackground(draft.background)}">
            ${
              draft.mediaUrl
                ? `<div class="story-editor-media-frame" data-story-media-transform style="${getStoryMediaStyle(draft)}">
                    ${
                      draft.mediaType === "video"
                        ? `<video class="story-editor-media" src="${draft.mediaUrl}" autoplay muted loop playsinline preload="metadata"></video>`
                        : `<img class="story-editor-media" src="${draft.mediaUrl}" alt="Vista previa de historia" draggable="false" />`
                    }
                  </div>`
                : ""
            }
            <div class="story-layer-stage editable-stage">${elements.map((element) => renderStoryLayer(element, true)).join("")}</div>
            ${draft.location ? `<small>${escapeHtml(draft.location)}</small>` : ""}
            <div class="story-music-pill story-music-edit"><span>♪</span>${escapeHtml(draft.music)}</div>
            ${draft.mediaName ? `<em>${escapeHtml(draft.mediaName)}</em>` : ""}
          </div>
          <div class="story-tool-rail" aria-label="Herramientas de historia">
            <button type="button" data-story-tool="text" aria-label="Texto"><span>T</span></button>
            <button type="button" data-story-tool="stickers" aria-label="Stickers"><span>✦</span></button>
            <button type="button" data-story-tool="music" aria-label="Musica"><span>♪</span></button>
            <button type="button" data-story-tool="background" aria-label="Fondo"><span>◎</span></button>
            <button type="button" data-story-tool="mention" aria-label="Menciones y ubicacion"><span>@</span></button>
            <button type="button" data-story-tool="gallery" aria-label="Foto o video"><span>▣</span></button>
          </div>
          ${state.storyToolPanel === "adjust" && selected ? renderStoryAdjustPanel(selected) : ""}
          ${state.storyToolPanel ? renderStoryToolPanel(draft, userLevel, visibleTracks) : ""}
        </div>
        <div class="story-create-bottom">
          <button type="button" data-create-own-story="${escapeAttr(draft.background)}">Publicar</button>
        </div>
      </div>
    </section>
  `;
}

function renderStoryToolPanel(draft, userLevel, visibleTracks) {
  const tool = state.storyToolPanel;
  if (tool === "adjust") return "";
  const header = {
    text: "Texto",
    stickers: "Stickers",
    music: "Música",
    background: "Fondo",
    mention: "Menciones y ubicación",
    gallery: "Galería",
  }[tool];
  const body = {
    text: `<div class="story-editor-fields compact-fields"><input data-story-draft="text" value="${escapeAttr(draft.text)}" placeholder="Texto de la historia" /></div>
      <div class="story-chip-row font-row">${storyFonts.map((font) => `<button class="${draft.font === font ? "active" : ""}" data-story-font="${font}">${font}</button>`).join("")}</div>
      <div class="story-chip-row color-row">${storyTextColors.map((color) => `<button class="${draft.textColor === color ? "active" : ""}" style="--swatch:${color}" data-story-text-color="${color}" aria-label="Color ${color}"></button>`).join("")}</div>
      <div class="story-chip-row">${storyTextStyles.map((style) => `<button class="${draft.textStyle === style ? "active" : ""}" data-story-text-style="${style}">${style}</button>`).join("")}</div>`,
    stickers: `<div class="story-chip-row sticker-category-row">${Object.keys(storyStickerGroups).map((category) => `<button class="${draft.stickerCategory === category ? "active" : ""}" data-story-sticker-category="${category}">${category}</button>`).join("")}</div>
      <div class="story-chip-row sticker-palette-row">${(storyStickerGroups[draft.stickerCategory] || storyStickerPalette).map((item) => `<button class="${draft.sticker === item ? "active" : ""}" data-story-sticker="${item}">${item}</button>`).join("")}</div>
      <input id="story-custom-sticker-input" class="hidden-file-input" type="file" accept="image/png,image/gif,image/webp" data-story-custom-sticker />
      <button type="button" class="custom-sticker-upload" data-protected-file="story-custom-sticker-input" data-permission-source="gallery">Sticker propio</button>`,
    music: `<div class="story-chip-row music-category-row">
        ${storyMusicCategories.map((category) => `<button class="${draft.musicCategory === category ? "active" : ""}" data-story-music-category="${category}">${category}</button>`).join("")}
      </div>
      <div class="music-unlock-list compact-music-list">
        ${visibleTracks
          .map((track) => {
            const locked = userLevel < track.level;
            return `<button type="button" class="${draft.music === track.name ? "active" : ""} ${locked ? "locked" : ""}" ${locked ? "" : `data-story-music="${escapeAttr(track.name)}"`}>
              <span>${track.name}</span>
              <small>${locked ? `Nivel ${track.level}` : track.detail}</small>
              ${locked ? "" : `<em data-story-music-preview="${escapeAttr(track.name)}">Preview</em>`}
            </button>`;
          })
          .join("")}
      </div>
      <p class="legal-note">Previews demo seguros, sin canciones completas con copyright.</p>`,
    background: `<div class="story-chip-row">${storyBackgrounds.map((item) => `<button class="${draft.background === item ? "active" : ""}" data-story-bg="${item}">${item}</button>`).join("")}</div>`,
    mention: `<div class="story-editor-fields compact-fields">
        <input data-story-draft="mention" value="${escapeAttr(draft.mention)}" placeholder="Mencionar @usuario" />
        <input data-story-draft="location" value="${escapeAttr(draft.location)}" placeholder="Ubicación opcional" />
      </div>
      <div class="story-chip-row color-row">${storyTextColors.map((color) => `<button class="${draft.textColor === color ? "active" : ""}" style="--swatch:${color}" data-story-text-color="${color}" aria-label="Color ${color}"></button>`).join("")}</div>`,
    gallery: `<div class="story-upload-grid compact-upload">
        <input id="story-media-foto" class="hidden-file-input" type="file" accept="image/*" data-story-media="foto" />
        <input id="story-media-video" class="hidden-file-input" type="file" accept="video/*" data-story-media="video" />
        <input id="story-media-camara" class="hidden-file-input" type="file" accept="image/*,video/*" capture="environment" data-story-media="camara" />
        <button type="button" data-protected-file="story-media-foto" data-permission-source="gallery">Foto</button>
        <button type="button" data-protected-file="story-media-video" data-permission-source="gallery">Video</button>
        <button type="button" data-protected-file="story-media-camara" data-permission-source="camera" data-permission-camera="true" data-permission-mic="true">Cámara</button>
      </div>`,
  }[tool];
  return `
    <div class="story-floating-panel">
      <div class="story-panel-head"><strong>${header}</strong><button type="button" data-story-tool-close>Listo</button></div>
      ${body}
    </div>
  `;
}

function renderStoryAdjustPanel(selected) {
  return `
    <div class="story-layer-controls floating-adjust">
      <div><strong>Sticker</strong><span>${selected.content}</span></div>
      <label>Tamaño <input type="range" min="20" max="86" value="${selected.size || 34}" data-story-control="size" /></label>
      <label>Rotar <input type="range" min="-35" max="35" value="${selected.rotation || 0}" data-story-control="rotation" /></label>
      <button type="button" data-story-delete-element>Eliminar</button>
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
          ["trending", "En alza"],
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
          <span class="tag">${item.trending ? "En alza" : "Reciente"}</span>
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
  if (state.newsFilter.topic === "trending") return "K-pop en alza";
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
  const users = state.backendMode === "supabase" && state.liveProfiles.length ? state.liveProfiles : demoUsers.slice(0, 8);
  const hashtagPosts = state.selectedHashtag ? getHashtagPosts(state.selectedHashtag) : [];
  return `
    <div class="search-box">
      <span class="nav-icon search-icon"></span>
      <input placeholder="Buscar idols, grupos, usuarios, hashtags o tendencias" />
    </div>
    ${
      state.selectedHashtag
        ? `<section class="hashtag-explore">
            <div class="hashtag-title">
              <button class="back-button" data-go-view="home">Volver</button>
              <div><h2>${escapeHtml(state.selectedHashtag)}</h2><p>Publicaciones relacionadas</p></div>
            </div>
            <div class="hashtag-sort-tabs">
              ${[
                ["recent", "Recientes"],
                ["popular", "Populares"],
                ["trending", "Tendencias"],
              ]
                .map(([key, label]) => `<button class="${state.hashtagSort === key ? "active" : ""}" data-hashtag-sort="${key}">${label}</button>`)
                .join("")}
            </div>
            <div class="social-feed hashtag-feed">
              ${hashtagPosts.length ? hashtagPosts.map((post, index) => renderSocialPost(post, index, { compact: true })).join("") : `<p class="empty-copy">Todavia no hay publicaciones con este hashtag.</p>`}
            </div>
          </section>`
        : ""
    }
    <div class="quick-link-grid">
      <button data-go-view="groups"><span class="nav-icon music-icon"></span><strong>Grupos</strong><small>Biografias e idols</small></button>
      <button data-go-view="news"><span class="nav-icon heart-icon"></span><strong>Noticias</strong><small>Actualidad K-pop</small></button>
      <button data-go-view="market"><span class="nav-icon bag-icon"></span><strong>Shop</strong><small>Merch y fotocards</small></button>
      <button data-go-view="community"><span class="nav-icon chat-icon"></span><strong>Comunidad</strong><small>Chats por zona</small></button>
      <button data-go-view="rookie"><span class="nav-icon spark-icon"></span><strong>K-pop 101</strong><small>Para fans nuevos</small></button>
      <button data-go-view="trends"><span class="nav-icon play-icon"></span><strong>Drops</strong><small>Clips y challenges</small></button>
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
        ? `<div class="section-heading"><h2>Usuarios sugeridos</h2><span>${state.backendMode === "supabase" ? "Supabase" : "Demo"}</span></div>
          <div class="user-result-list">
            ${users
              .map(
                (profile) => `
                <article class="user-result-card">
                  ${renderAvatarElement("mini", profile.avatar || "berry", profile.avatar_url || profile.avatarUrl)}
                  <button class="profile-result-main" data-open-profile="${profile.id}">
                    <div><h3>${profile.name}</h3><p class="muted">@${profile.username} · ${profile.city || profile.country || "Latam"}</p></div>
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

function getHashtagPosts(tag) {
  const normalized = tag.toLowerCase();
  const posts = userPosts.filter((post) => !isPostHidden(post) && !isUserMuted(post) && (post.hashtags || []).some((item) => item.toLowerCase() === normalized));
  if (state.hashtagSort === "popular") return [...posts].sort((a, b) => getEngagementNumber(b.likes) - getEngagementNumber(a.likes));
  if (state.hashtagSort === "trending") return [...posts].sort((a, b) => Number(b.type === "trending") - Number(a.type === "trending") || getEngagementNumber(b.comments) - getEngagementNumber(a.comments));
  return posts;
}

function getEngagementNumber(value) {
  const text = String(value || "0").toLowerCase();
  const number = Number.parseFloat(text.replace(/[^0-9.]/g, "")) || 0;
  return text.includes("k") ? number * 1000 : number;
}

function getDropId(trend, fallback = 0) {
  return trend.id || normalizeProfileKey(`${trend.challenge}-${trend.user}`) || `drop-${fallback}`;
}

function getActiveDropFilter() {
  return dropVisualFilters.find((filter) => filter.id === state.dropEffect) || dropVisualFilters[0];
}

function handleDropAction(action, id) {
  const closePanels = () => {
    state.dropCommentsOpen[id] = false;
    state.dropShareOpen[id] = false;
    state.dropMusicOpen[id] = false;
  };
  if (action === "follow") {
    state.dropFollowed[id] = !state.dropFollowed[id];
    showToast(state.dropFollowed[id] ? "Creador seguido" : "Dejaste de seguir al creador");
    return;
  }
  if (action === "like") {
    state.dropLiked[id] = !state.dropLiked[id];
    state.dropFeedback[id] = "star";
    showToast(state.dropLiked[id] ? "Drop marcado con estrella" : "Estrella quitada");
    if (state.dropLiked[id]) playAppSound("like");
    setTimeout(() => {
      if (state.dropFeedback[id] === "star") {
        delete state.dropFeedback[id];
        render();
      }
    }, 520);
    return;
  }
  if (action === "save") {
    state.dropSaved[id] = !state.dropSaved[id];
    showToast(state.dropSaved[id] ? "Drop guardado" : "Drop quitado de guardados");
    if (state.dropSaved[id]) playAppSound("save");
    return;
  }
  if (action === "comment") {
    state.dropCommentsOpen[id] = !state.dropCommentsOpen[id];
    state.dropShareOpen[id] = false;
    state.dropMusicOpen[id] = false;
    return;
  }
  if (action === "share") {
    state.dropShareOpen[id] = !state.dropShareOpen[id];
    state.dropCommentsOpen[id] = false;
    state.dropMusicOpen[id] = false;
    return;
  }
  if (action === "music") {
    state.dropMusicOpen[id] = !state.dropMusicOpen[id];
    state.dropCommentsOpen[id] = false;
    state.dropShareOpen[id] = false;
    return;
  }
  closePanels();
}

function renderTrends() {
  const drops = getFilteredDrops();
  const dropFilters = [
    ["popular", "Populares"],
    ["recent", "Recientes"],
    ["followed", "Seguidos"],
    ["challenge", "Challenges"],
    ["dance", "Dance"],
    ["outfit", "Outfit"],
    ["edits", "Edits"],
  ];
  return `
    <div class="drop-tools-row">
      <div class="trend-tabs premium-drop-tabs">
        ${dropFilters.map(([id, label]) => `<button class="${(state.dropFeedFilter === id || (state.dropFeedFilter === "viral" && id === "popular")) ? "active" : ""}" data-drop-filter="${id}">${label}</button>`).join("")}
      </div>
      <div class="drop-tool-actions">
        <button class="drop-icon-button" data-search-drops aria-label="Buscar Drops"><span class="nav-icon search-icon"></span></button>
        <button class="drop-create-mini" data-create-drop aria-label="Crear Drop"><span>+</span><small>Drop</small></button>
      </div>
    </div>
    ${state.dropSearchSelection ? `<div class="drop-search-chip"><span>Resultados para ${state.dropSearchSelection}</span><button data-clear-drop-search>Limpiar</button></div>` : ""}
    <section class="trends-feed" aria-label="Drops estilo reels">
      ${drops
        .map(
          (trend, index) => renderDropCard(trend, index),
        )
        .join("")}
    </section>
    ${state.dropSearchOpen ? renderDropSearchOverlay() : ""}
    ${state.dropCreatorOpen ? renderDropCreator() : ""}
    ${renderOpenDropCommentsSheet()}
    ${state.videoProfileOverlay?.startsWith("drop:") ? renderVideoProfileOverlay() : ""}
    ${state.videoFullscreen?.startsWith("drop:") ? renderVideoFullscreenOverlay() : ""}
  `;
}

function renderDropCard(trend, index) {
  const id = getDropId(trend, index);
  const demoUser = getDemoUser(trend.user);
  const mediaUrl = trend.mediaUrl || trend.imageUrl || getDemoDropMedia(index);
  const fallbackUrl = getDemoDropMedia(index + 3);
  const liked = Boolean(state.dropLiked[id]);
  const followed = Boolean(state.dropFollowed[id]);
  const saved = Boolean(state.dropSaved[id]);
  const expanded = Boolean(state.expandedPosts[`drop-${id}`]);
  const longDescription = trend.description.length > 68;
  const feedback = state.dropFeedback[id];
  return `
          <article class="trend-card premium-drop-card effect-${state.dropEffect} filter-${trend.filter || "original"} ${state.dropPaused[id] ? "paused" : ""}" style="--art:${trend.colors}">
            ${
              trend.mediaType === "video"
                ? `<video class="drop-video-media" src="${escapeAttr(mediaUrl)}" playsinline loop ${state.videoMuted ? "muted" : ""} ${state.dropPaused[id] ? "" : "autoplay"}></video>`
                : `<img class="drop-video-media" src="${escapeAttr(mediaUrl)}" alt="${escapeAttr(trend.challenge)}" loading="lazy" onerror="this.onerror=null;this.src='${escapeAttr(fallbackUrl)}';" />`
            }
            <button class="drop-play-toggle" data-drop-toggle="${id}" aria-label="${state.dropPaused[id] ? "Reproducir Drop" : "Pausar Drop"}"></button>
            ${feedback ? `<div class="drop-center-feedback ${feedback === "star" ? "starburst" : ""}">${feedback === "star" ? "★" : state.dropPaused[id] ? "▶" : "Ⅱ"}</div>` : ""}
            <div class="video-quick-controls">
              <button class="video-sound-button ${state.videoMuted ? "muted" : ""}" data-toggle-video-sound aria-label="${state.videoMuted ? "Activar audio" : "Silenciar"}">${state.videoMuted ? "♪" : "♪"}</button>
              <button class="video-fullscreen-button" data-open-video-fullscreen="drop:${id}" aria-label="Ver en pantalla completa"></button>
            </div>
            <div class="trend-overlay">
              <div class="trend-copy">
                <div class="drop-info-card">
                  <div class="drop-author-row">
                    ${renderAvatarElement("mini drop-avatar", demoUser.avatar || "berry", demoUser.avatarUrl)}
                    <div>
                      <button type="button" data-open-video-profile="drop:${id}">${escapeHtml(trend.user)}</button>
                      <span>♪ ${escapeHtml(trend.song)}</span>
                    </div>
                    <button class="drop-follow-inline ${followed ? "active" : ""}" data-drop-action="follow:${id}" aria-label="${followed ? "Siguiendo" : "Seguir"}">${followed ? "Siguiendo" : "Seguir"}</button>
                  </div>
                  <p class="drop-description ${expanded ? "expanded" : ""}">${escapeHtml(trend.description)}</p>
                  ${longDescription ? `<button class="drop-more-link" data-toggle-drop-text="${id}">${expanded ? "Ver menos" : "Ver más"}</button>` : ""}
                </div>
              </div>
              <div class="trend-actions">
                <button class="${liked ? "active liked" : ""}" data-drop-action="like:${id}" aria-label="Estrella"><span class="drop-action-symbol star">★</span><small>${liked ? "Listo" : "Like"}</small></button>
                <button class="${state.dropCommentsOpen[id] ? "active" : ""}" data-drop-action="comment:${id}" aria-label="Comentar"><span class="nav-icon chat-icon"></span><small>${trend.comments || "0"}</small></button>
                <button class="${state.dropShareOpen[id] ? "active" : ""}" data-drop-action="share:${id}" aria-label="Compartir"><span class="share-dot"></span><small>Compartir</small></button>
                <button class="${saved ? "active saved" : ""}" data-drop-action="save:${id}" aria-label="Guardar"><span class="save-mark"></span><small>${saved ? "Guardado" : "Guardar"}</small></button>
                <button class="${state.dropMusicOpen[id] ? "active" : ""}" data-drop-action="music:${id}" aria-label="Música"><span class="drop-action-symbol">♪</span><small>Música</small></button>
                <button data-report-content="drop:${id}" aria-label="Reportar Drop"><span class="drop-action-symbol">!</span><small>Reportar</small></button>
              </div>
              ${renderDropPanel(trend, id)}
            </div>
          </article>
  `;
}

function renderDropPanel(trend, id) {
  if (state.dropCommentsOpen[id]) {
    return "";
  }
  if (state.dropShareOpen[id]) {
    return `
      <div class="drop-mini-panel">
        <strong>Compartir</strong>
        <button data-drop-share-copy="${id}">Copiar enlace demo</button>
        <button data-demo-action="Compartido en mensajes demo">Enviar por mensaje</button>
      </div>`;
  }
  if (state.dropMusicOpen[id]) {
    return `
      <div class="drop-mini-panel">
        <strong>Audio usado</strong>
        <p>${escapeHtml(trend.song)}</p>
        <button data-demo-action="Audio agregado a favoritos">Guardar audio</button>
      </div>`;
  }
  return "";
}

function renderOpenDropCommentsSheet() {
  const entry = trendVideos
    .map((trend, index) => [trend, getDropId(trend, index)])
    .find(([, id]) => state.dropCommentsOpen[id]);
  if (!entry) return "";
  const [trend, id] = entry;
  return renderVideoCommentsSheet({
    id,
    title: trend.challenge,
    subtitle: `Drop de ${trend.user}`,
    type: "drop",
    sendAttr: `data-drop-comment-send="${id}"`,
  });
}

function renderOpenFancamCommentsSheet() {
  const fancam = fancamVideos.find((item) => state.fancamCommentsOpen[item.id]);
  if (!fancam) return "";
  return renderVideoCommentsSheet({
    id: fancam.id,
    title: `${fancam.artist} fancam`,
    subtitle: `${fancam.group} · ${fancam.show}`,
    type: "fancam",
    sendAttr: `data-fancam-comment-send="${fancam.id}"`,
  });
}

function renderVideoCommentsSheet({ id, title, subtitle, type, sendAttr }) {
  const key = `${type}:${id}`;
  const comments = getDefaultVideoComments(type, id);
  const replyTarget = state.videoCommentReplyTo[key];
  const replyUser = replyTarget ? findCommentInList(comments, replyTarget)?.username : null;
  return `
    <section class="video-comments-sheet" aria-label="Comentarios de ${escapeAttr(title)}">
      <div class="sheet-handle"></div>
      <div class="composer-head">
        <div><strong>Comentarios</strong><small>${escapeHtml(subtitle)}</small></div>
        <button type="button" ${type === "drop" ? `data-drop-action="comment:${id}"` : `data-fancam-action="comment:${id}"`} aria-label="Cerrar comentarios">X</button>
      </div>
      <div class="video-comment-list">
        ${comments.map((comment) => renderVideoCommentItem(type, id, comment)).join("")}
      </div>
      ${
        replyTarget
          ? `<div class="reply-context">Respondiendo a @${escapeHtml(replyUser || "fan")} <button type="button" data-video-comment-reply="${key}||">Cancelar</button></div>`
          : ""
      }
      <div class="comment-composer video-comment-composer">
        ${renderAvatarElement("mini comment-input-avatar", state.user?.avatar || "berry", state.user?.avatarUrl)}
        <input data-video-comment-draft="${key}" value="${escapeAttr(state.videoCommentDrafts[key] || "")}" placeholder="${replyUser ? `Respondiendo a @${escapeAttr(replyUser)}` : "Comentar..."}" aria-label="Escribir comentario" />
        <button class="comment-send-button" type="button" ${sendAttr}>Enviar</button>
      </div>
    </section>
  `;
}

function renderVideoCommentItem(type, id, comment, isReply = false) {
  const sheetKey = `${type}:${id}`;
  const likeKey = `${type}:${id}:${comment.id}`;
  const liked = Boolean(state.videoCommentLikes[likeKey]);
  return `
    <div class="comment-item ${isReply ? "comment-reply" : ""}">
      ${renderAvatarElement("mini comment-avatar", comment.avatar || "berry", comment.avatarUrl)}
      <div class="comment-main">
        <div class="comment-meta">
          <button type="button" data-open-feed-profile="${escapeAttr(comment.username || comment.user)}">${escapeHtml(comment.user || "Hallyu fan")}</button>
          <span>${escapeHtml(comment.time || "Ahora")}</span>
        </div>
        <p class="comment-text">${renderMentionedText(comment.body || "")}</p>
        <div class="comment-tools">
          <button type="button" data-video-comment-reply="${sheetKey}|${comment.id}|${escapeAttr(comment.username || normalizeProfileKey(comment.user))}">Responder</button>
          <button type="button" data-report-content="comment:${sheetKey}:${comment.id}">Reportar</button>
          <button class="comment-like ${liked ? "active" : ""}" type="button" data-video-comment-like="${likeKey}" aria-label="Dar estrella al comentario">
            <span>★</span>
            <strong>${Number(comment.likes || 0)}</strong>
          </button>
        </div>
        ${(comment.replies || []).length ? `<div class="comment-replies">${(comment.replies || []).map((reply) => renderVideoCommentItem(type, id, reply, true)).join("")}</div>` : ""}
      </div>
    </div>
  `;
}

function findCommentInList(comments, commentId) {
  for (const comment of comments || []) {
    if (comment.id === commentId) return comment;
    const reply = findCommentInList(comment.replies || [], commentId);
    if (reply) return reply;
  }
  return null;
}

function getFilteredDrops() {
  const query = normalizeProfileKey(state.dropSearchSelection || "");
  const searchTerms = getDropRelatedTerms(state.dropSearchSelection || "");
  const base = sortDropsForFeed(trendVideos);
  const byFilter = base.filter((trend) => dropMatchesFeedFilter(trend, state.dropFeedFilter));
  const safeFiltered = byFilter.length ? byFilter : base;
  if (!query) return safeFiltered;
  const matchesQuery = (trend) => {
    const haystack = getDropSearchText(trend);
    return searchTerms.some((term) => haystack.includes(term));
  };
  const matched = safeFiltered.filter(matchesQuery);
  if (matched.length) return matched;
  const fallback = base.filter(matchesQuery);
  return fallback.length ? fallback : safeFiltered;
}

function dropMatchesFeedFilter(trend, filterValue) {
  const filter = filterValue === "viral" ? "popular" : filterValue || "popular";
  const haystack = getDropSearchText(trend);
  if (filter === "popular") return true;
  if (filter === "recent") return true;
  if (filter === "followed") {
    const favorite = normalizeProfileKey(state.user?.favoriteGroup || "");
    return Boolean(state.dropFollowed[getDropId(trend)]) || (favorite && haystack.includes(favorite));
  }
  if (filter === "challenge") return /(challenge|reto|viral|paso)/.test(haystack);
  if (filter === "dance") return /(dance|baile|cover|randomplay|coreografia|paso)/.test(haystack);
  if (filter === "outfit") return /(outfit|look|fashion|ropa|style|kstyle)/.test(haystack);
  if (filter === "edits") return /(edit|clip|fancam|transition|transicion)/.test(haystack);
  return true;
}

function sortDropsForFeed(items) {
  const filter = state.dropFeedFilter === "viral" ? "popular" : state.dropFeedFilter;
  const favorite = normalizeProfileKey(state.user?.favoriteGroup || "");
  return [...items].sort((a, b) => {
    if (filter === "recent") return getPostTimeValue(b) - getPostTimeValue(a);
    const score = (item) =>
      getEngagementNumber(item.likes) +
      getEngagementNumber(item.comments) * 2 +
      Number(Boolean(state.dropFollowed[getDropId(item)])) * 8000 +
      Number(favorite && getDropSearchText(item).includes(favorite)) * 5000;
    return score(b) - score(a) || getPostTimeValue(b) - getPostTimeValue(a);
  });
}

function getDropSearchText(trend) {
  return normalizeProfileKey([
    trend.user,
    trend.username,
    trend.challenge,
    trend.song,
    trend.description,
    trend.group,
    trend.groupId,
    trend.artist,
    trend.artistId,
    trend.taggedGroup,
    trend.taggedArtist,
    trend.taggedShow,
    trend.city,
    trend.location,
    ...(trend.hashtags || []),
  ].join(" "));
}

function getDropRelatedTerms(selection) {
  const terms = new Set([normalizeProfileKey(selection)]);
  const groupMatch = kpopGroups.find((group) => {
    const groupFields = [group.name, group.fandom, group.company].map(normalizeProfileKey);
    const artistFields = group.artists.flatMap((artist) => [artist.name, artist.realName]).map(normalizeProfileKey);
    return [...groupFields, ...artistFields].some((field) => field && (field.includes(normalizeProfileKey(selection)) || normalizeProfileKey(selection).includes(field)));
  });
  if (groupMatch) {
    terms.add(normalizeProfileKey(groupMatch.name));
    terms.add(normalizeProfileKey(groupMatch.fandom));
    groupMatch.artists.forEach((artist) => terms.add(normalizeProfileKey(artist.name)));
  }
  return [...terms].filter(Boolean);
}

function getDropSearchResults() {
  const query = normalizeProfileKey(state.dropSearchQuery);
  const base = [
    ...kpopGroups.map((group) => ({ type: "Grupo", label: group.name, detail: group.fandom })),
    ...kpopGroups.flatMap((group) => group.artists.map((artist) => ({ type: "Idol", label: artist.name, detail: group.name }))),
    ...trendVideos.map((trend) => ({ type: "Drop", label: trend.challenge, detail: trend.song })),
    ...trendVideos.map((trend) => ({ type: "Canción", label: trend.song, detail: trend.challenge })),
    ...trendVideos.map((trend) => ({ type: "Usuario", label: trend.user, detail: "Creador Drop" })),
    ...["#BTS", "#BLACKPINK", "#DanceChallenge", "#KpopChile", "#Drops", "#RandomPlayDance", "#FanEdit"].map((tag) => ({ type: "Hashtag", label: tag, detail: "Explorar Drops" })),
  ];
  const unique = [];
  const seen = new Set();
  base.forEach((item) => {
    const key = normalizeProfileKey(`${item.type}-${item.label}`);
    if (seen.has(key)) return;
    seen.add(key);
    if (!query || normalizeProfileKey([item.type, item.label, item.detail].join(" ")).includes(query)) unique.push(item);
  });
  return unique.slice(0, 10);
}

function renderDropSearchOverlay() {
  const results = getDropSearchResults();
  return `
    <section class="drop-search-overlay">
      <div class="drop-search-panel">
        <div class="drop-search-head">
          <button data-close-drop-search aria-label="Cerrar busqueda">Cerrar</button>
          <strong>Buscar Drops</strong>
          <span></span>
        </div>
        <div class="drop-search-input">
          <span class="nav-icon search-icon"></span>
          <input data-drop-search-input value="${escapeAttr(state.dropSearchQuery)}" placeholder="Grupo, idol, canción, hashtag..." />
        </div>
        <div class="drop-result-list">
          ${results
            .map(
              (item) => `
              <button data-drop-result="${escapeAttr(item.label)}">
                <span>${item.type}</span>
                <strong>${item.label}</strong>
                <small>${item.detail}</small>
              </button>`,
            )
            .join("")}
        </div>
      </div>
    </section>
  `;
}

function renderDropCreator() {
  return renderVideoUploadEditor("trends");
}

function renderFancamCreator() {
  return renderVideoUploadEditor("fancams");
}

function renderVideoUploadEditor(kind) {
  const draft = state.videoEditorDraft.kind === kind ? state.videoEditorDraft : { ...state.videoEditorDraft, kind };
  const isFancam = kind === "fancams";
  const title = isFancam ? "Crear Fancam" : "Crear Drop";
  const accepted = "video/*";
  const fileInputId = isFancam ? "fancam-video-input" : "drop-video-input";
  const coverInputId = isFancam ? "fancam-cover-input" : "drop-cover-input";
  const maxLabel = isFancam ? "hasta 3 min" : "15-60 seg recomendado";
  const longVideo = isVideoEditorLong(kind, draft);
  const activeFilter = publishFilters.find(([id]) => id === draft.filter) || publishFilters[0];
  const filterClass = `filter-${draft.filter || "original"}`;
  return `
    <section class="video-editor-overlay" aria-label="${escapeAttr(title)}">
      <div class="video-editor-shell">
        <header class="video-editor-topbar">
          <button type="button" data-close-video-editor>Cerrar</button>
          <div>
            <strong>${title}</strong>
            <span>${maxLabel} · formato vertical 9:16</span>
          </div>
          <button class="video-editor-publish" type="button" data-video-editor-publish>Publicar</button>
        </header>

        <div class="video-editor-body">
          <section class="video-editor-preview-card ${filterClass}">
            ${
              draft.loading
                ? `<div class="video-upload-stage video-loading-state"><span class="video-upload-plus">...</span><strong>Cargando video</strong><small>Preparando preview para mobile</small></div>`
                : draft.mediaUrl
                ? `<video class="video-editor-preview" data-video-editor-preview src="${escapeAttr(draft.mediaUrl)}" controls playsinline muted preload="metadata"></video>`
                : `<button class="video-upload-stage" type="button" data-protected-file="${fileInputId}" data-permission-source="gallery" data-permission-mic="true">
                    <span class="video-upload-plus">+</span>
                    <strong>Subir video</strong>
                    <small>Galería, cámara o grabación</small>
                  </button>`
            }
            ${draft.error ? `<p class="video-upload-error">${escapeHtml(draft.error)}</p>` : ""}
            ${draft.overlayText ? `<div class="video-editor-overlay-text">${escapeHtml(draft.overlayText)}</div>` : ""}
            ${draft.sticker ? `<div class="video-editor-sticker">${escapeHtml(draft.sticker)}</div>` : ""}
            <div class="video-editor-media-actions">
              <input id="${fileInputId}" class="hidden-file-input" type="file" accept="${accepted}" data-video-editor-file />
              <button type="button" data-protected-file="${fileInputId}" data-permission-source="gallery" data-permission-mic="true">${draft.mediaUrl ? "Cambiar" : "Subir"}</button>
              ${draft.mediaUrl ? `<button type="button" data-video-editor-remove-media>Eliminar</button>` : ""}
            </div>
          </section>

          ${renderVideoTrimControl(kind, draft, longVideo)}

          <section class="video-editor-tools">
            <div class="video-editor-chip-row">
              <button type="button" data-demo-action="Cámara preparada en modo demo">Cámara</button>
              <button type="button" data-demo-action="Grabación lista en modo demo">Grabar</button>
              <button class="${draft.muted ? "active" : ""}" type="button" data-video-editor-toggle="muted">Audio original ${draft.muted ? "OFF" : "ON"}</button>
              <button class="${draft.soundOn ? "active" : ""}" type="button" data-video-editor-toggle="soundOn">Sonido ${draft.soundOn ? "ON" : "OFF"}</button>
            </div>

            <div class="video-editor-fields">
              <label>Descripción<textarea data-video-editor-field="description" placeholder="${isFancam ? "Describe la fancam..." : "Describe tu Drop..."}">${escapeHtml(draft.description)}</textarea></label>
              <label>Hashtags<input data-video-editor-field="hashtags" value="${escapeAttr(draft.hashtags)}" placeholder="#HallyuHub #KpopLatam" /></label>
              <label>Música/audio<input data-video-editor-field="music" value="${escapeAttr(draft.music)}" placeholder="Elegí o escribí audio seguro" /></label>
              <div class="video-editor-grid-fields">
                <label>Grupo<input data-video-editor-field="group" value="${escapeAttr(draft.group)}" placeholder="BTS, ENHYPEN..." /></label>
                <label>Artista<input data-video-editor-field="artist" value="${escapeAttr(draft.artist)}" placeholder="Jung Kook, Jungwon..." /></label>
                <label>Show/evento<input data-video-editor-field="show" value="${escapeAttr(draft.show)}" placeholder="Music show, concierto..." /></label>
                <label>Ciudad<input data-video-editor-field="city" value="${escapeAttr(draft.city)}" placeholder="Buenos Aires, Santiago..." /></label>
                <label>Fecha<input data-video-editor-field="eventDate" value="${escapeAttr(draft.eventDate)}" placeholder="2026-05-21" /></label>
                <label>Ubicación opcional<input data-video-editor-field="location" value="${escapeAttr(draft.location)}" placeholder="Estadio, teatro, fan meeting..." /></label>
              </div>
              <label>Texto sobre video<input data-video-editor-field="overlayText" value="${escapeAttr(draft.overlayText)}" placeholder="Texto corto opcional" /></label>
              <div class="video-editor-toggle-row">
                <label><input type="checkbox" data-video-editor-field="allowComments" ${draft.allowComments ? "checked" : ""} /> Permitir comentarios</label>
                <label><input type="checkbox" data-video-editor-field="vertical" ${draft.vertical ? "checked" : ""} /> Ajustar 9:16</label>
                <label><input type="checkbox" data-video-editor-field="rightsConfirmed" ${draft.rightsConfirmed ? "checked" : ""} /> Confirmo que este contenido fue grabado o creado por mí, o que tengo permiso para subirlo.</label>
              </div>
            </div>

            <div class="video-editor-section">
              <div class="section-heading small"><h2>Filtros</h2><span>${escapeHtml(activeFilter[1])}</span></div>
              <div class="video-editor-filter-row">
                ${publishFilters.map(([id, label]) => `<button class="${draft.filter === id ? "active" : ""}" type="button" data-video-editor-filter="${id}">${label}</button>`).join("")}
              </div>
            </div>

            <div class="video-editor-section">
              <div class="section-heading small"><h2>Efectos K-pop</h2><span>Comunidad moderada</span></div>
              <div class="video-editor-filter-row">
                ${dropVisualFilters
                  .filter((filter) => filter.status === "approved")
                  .map((filter) => `<button class="${state.dropEffect === filter.id ? "active" : ""}" type="button" data-drop-effect="${filter.id}">${escapeHtml(filter.name)}</button>`)
                  .join("")}
              </div>
            </div>

            <div class="video-editor-section">
              <div class="section-heading small"><h2>Stickers</h2><span>K-pop aesthetic</span></div>
              <div class="video-editor-sticker-row">
                ${["✨", "💜", "🫰", "🎤", "📸", "🪩", "🎀", "💿"].map((sticker) => `<button class="${draft.sticker === sticker ? "active" : ""}" type="button" data-video-editor-sticker="${sticker}">${sticker}</button>`).join("")}
              </div>
            </div>

            <div class="video-editor-section">
              <div class="section-heading small"><h2>Portada</h2><span>Opcional</span></div>
              <input id="${coverInputId}" class="hidden-file-input" type="file" accept="image/*" data-video-editor-cover />
              <button class="video-cover-button" type="button" data-protected-file="${coverInputId}" data-permission-source="gallery">${draft.coverName ? `Cambiar portada · ${escapeHtml(draft.coverName)}` : "Elegir portada/thumbnail"}</button>
              ${draft.coverUrl ? `<img class="video-cover-preview" src="${escapeAttr(draft.coverUrl)}" alt="Portada elegida" />` : ""}
            </div>
            <p class="legal-note">Al publicar confirmás que tenés permiso para subir este contenido. No uses videos oficiales completos ni música protegida sin autorización.</p>
          </section>
        </div>
      </div>
    </section>
  `;
}

function renderVideoTrimControl(kind, draft, longVideo) {
  const { start, end, duration, selected, recommendedMax } = getVideoTrimMetrics(kind, draft);
  const left = (start / duration) * 100;
  const width = (selected / duration) * 100;
  const helper = longVideo
    ? "Recortá tu video para que cargue mejor."
    : kind === "fancams"
      ? "Arrastrá el rango. Fancams permite hasta 3 minutos."
      : "Arrastrá el rango. Drops funciona mejor entre 15 y 60 segundos.";
  const ticks = Array.from({ length: 12 }, (_, index) => `<span style="--tick:${index}"></span>`).join("");
  return `
    <section class="video-editor-trim visual-trim ${longVideo ? "warning" : ""}" aria-label="Recortar video">
      <div class="trim-head">
        <div>
          <strong>Recorte</strong>
          <small data-video-trim-duration>${formatTrimTime(selected)} seleccionados</small>
        </div>
        <button type="button" data-video-preview-range>Previsualizar</button>
      </div>
      <div class="trim-timeline" data-video-trim-track>
        <div class="trim-ticks">${ticks}</div>
        <div class="trim-selection" data-video-trim-selection data-video-trim-range style="left:${left}%;width:${width}%">
          <button type="button" class="trim-handle start" data-video-trim-handle="start" aria-label="Mover inicio del recorte"></button>
          <button type="button" class="trim-handle end" data-video-trim-handle="end" aria-label="Mover final del recorte"></button>
        </div>
      </div>
      <div class="trim-time-row">
        <span>Inicio <strong data-video-trim-start>${formatTrimTime(start)}</strong></span>
        <span>Final <strong data-video-trim-end>${formatTrimTime(end)}</strong></span>
        <span>Máx. <strong>${formatTrimTime(recommendedMax)}</strong></span>
      </div>
      <p>${helper}</p>
    </section>
  `;
}

function renderDropFilterButton(filter) {
  return `
    <button class="${state.dropEffect === filter.id ? "active" : ""}" data-drop-effect="${filter.id}">
      <span class="filter-mini-preview effect-${filter.id}"></span>
      <strong>${escapeHtml(filter.name)}</strong>
      <small>${escapeHtml(filter.category)}</small>
    </button>
  `;
}

function renderDropCommunityFilter(filter) {
  const approved = filter.status === "approved";
  const statusLabel = {
    approved: "Aprobado",
    pending: "Pendiente",
    rejected: "Rechazado",
  }[filter.status] || filter.status;
  return `
    <article class="drop-community-filter ${filter.status}">
      <span class="filter-mini-preview effect-${filter.id}"></span>
      <div>
        <strong>${escapeHtml(filter.name)}</strong>
        <small>${escapeHtml(filter.creator)} · ${escapeHtml(filter.category)} · ${escapeHtml(filter.uses)} usos</small>
        <em>${escapeHtml(statusLabel)}</em>
      </div>
      <button ${approved ? `data-drop-effect="${filter.id}"` : "disabled"}>${approved ? "Usar filtro" : statusLabel}</button>
    </article>
  `;
}

function getFancamArtistOptions() {
  return fancamVideos
    .filter((fancam) => state.fancamGroupFilter === "all" || fancam.groupId === state.fancamGroupFilter)
    .map((fancam) => [fancam.artistId, fancam.artist]);
}

function getFilteredFancams(artistId = null) {
  const targetArtist = artistId || state.fancamArtistFilter;
  const query = normalizeProfileKey(state.fancamSearchQuery);
  const filtered = fancamVideos.filter((fancam) => {
    const groupOk = state.fancamGroupFilter === "all" || fancam.groupId === state.fancamGroupFilter || artistId;
    const artistOk = !targetArtist || targetArtist === "all" || fancam.artistId === targetArtist;
    const sortOk = artistId || fancamMatchesSort(fancam, state.fancamSort);
    const queryOk = !query || getFancamSearchText(fancam).includes(query);
    return groupOk && artistOk && sortOk && queryOk;
  });
  const hasActiveFilter = query || artistId || state.fancamGroupFilter !== "all" || (targetArtist && targetArtist !== "all") || state.fancamSort !== "recommended";
  const base = filtered.length || hasActiveFilter ? filtered : fancamVideos;
  const sorted = sortFancamsForFeed(base.length ? base : fancamVideos);
  return sorted;
}

function fancamMatchesSort(fancam, sortValue) {
  const sort = sortValue || "recommended";
  const text = getFancamSearchText(fancam);
  if (sort === "recommended" || sort === "all") return true;
  if (sort === "recent") return fancam.sort === "recent" || getPostTimeValue(fancam) > Date.now() - 7 * 24 * 60 * 60 * 1000;
  if (sort === "trending" || sort === "popular") return fancam.sort === "trending" || getEngagementNumber(fancam.likes) > 250000 || getEngagementNumber(fancam.views) > 1500000;
  if (sort === "followed") return Boolean(state.followedArtists[fancam.artistId]);
  if (sort === "show") return /(show|stage|concert|concierto|festival|focus|musicshow|fanmeeting)/.test(text);
  return true;
}

function getFancamSearchText(fancam) {
  const group = kpopGroups.find((item) => item.id === fancam.groupId);
  return normalizeProfileKey([
    fancam.artist,
    fancam.user,
    fancam.username,
    fancam.group,
    fancam.groupId,
    fancam.artistId,
    fancam.show,
    fancam.era,
    fancam.date,
    fancam.description,
    ...(fancam.hashtags || []),
    fancam.sort === "recent" ? "recientes reciente nuevo" : "popular populares trending virales",
    group?.fandom,
    group?.company,
  ].join(" "));
}

function sortFancamsForFeed(items) {
  const favorite = normalizeProfileKey(state.user?.favoriteGroup || "");
  return [...items].sort((a, b) => {
    if (state.fancamSort === "recent") return Number(b.sort === "recent") - Number(a.sort === "recent");
    if (state.fancamSort === "trending" || state.fancamSort === "popular") return getEngagementNumber(b.likes) - getEngagementNumber(a.likes) || getEngagementNumber(b.views) - getEngagementNumber(a.views);
    const score = (item) =>
      Number(Boolean(state.followedArtists[item.artistId])) * 8 +
      Number(normalizeProfileKey(item.group).includes(favorite) || favorite.includes(normalizeProfileKey(item.group))) * 5 +
      Number(item.sort === "trending") * 3 +
      (getEngagementNumber(item.views) % 7);
    return score(b) - score(a);
  });
}

function renderFancams() {
  const fancams = getFilteredFancams();
  const groupOptions = [["all", "Todos"], ...kpopGroups.filter((group) => fancamVideos.some((fancam) => fancam.groupId === group.id)).map((group) => [group.id, group.name])];
  const artistOptions = [["all", "Integrantes"], ...getFancamArtistOptions()];
  return `
    <section class="fancam-control-bar" aria-label="Buscar y filtrar Fancams">
      <div class="fancam-search-input">
        <span class="nav-icon search-icon"></span>
        <input data-fancam-search-input value="${escapeAttr(state.fancamSearchQuery)}" placeholder="Grupo, artista, show, era..." />
      </div>
      <button class="${state.fancamFilterOpen ? "active" : ""}" data-toggle-fancam-filter>Filtros</button>
      <button class="fancam-create-mini" data-create-fancam aria-label="Crear Fancam"><span>+</span><small>Fancam</small></button>
    </section>
    ${
      state.fancamFilterOpen
        ? `<section class="fancam-filter-panel">
            <div class="fancam-filter-row">
              ${groupOptions.map(([id, label]) => `<button class="${state.fancamGroupFilter === id ? "active" : ""}" data-fancam-group="${id}">${label}</button>`).join("")}
            </div>
            <div class="fancam-filter-row compact">
              ${artistOptions.slice(0, 10).map(([id, label]) => `<button class="${state.fancamArtistFilter === id ? "active" : ""}" data-fancam-artist="${id}">${label}</button>`).join("")}
            </div>
            <div class="fancam-filter-row compact">
              ${[
                ["recommended", "Para ti"],
                ["popular", "Populares"],
                ["recent", "Recientes"],
                ["followed", "Seguidas"],
                ["show", "Shows"],
                ["all", "Todas"],
              ].map(([id, label]) => `<button class="${state.fancamSort === id ? "active" : ""}" data-fancam-sort="${id}">${label}</button>`).join("")}
            </div>
          </section>`
        : ""
    }
    ${state.fancamSearchQuery || state.fancamGroupFilter !== "all" || state.fancamArtistFilter !== "all" || state.fancamSort !== "recommended" ? `<div class="fancam-search-chip"><span>${fancams.length} fancams encontradas</span><button data-clear-fancam-search>Limpiar</button></div>` : `<p class="fancam-feed-note">Fancams de artistas que seguís, favoritos y recomendaciones para descubrir.</p>`}
    <section class="fancam-feed" aria-label="Feed vertical de fancams">
      ${fancams.length ? fancams.map((fancam, index) => renderFancamCard(fancam, index, { fullscreen: true })).join("") : `<article class="settings-demo-box">No hay fancams con estos filtros.</article>`}
    </section>
    ${renderOpenFancamCommentsSheet()}
    ${state.fancamCreatorOpen ? renderFancamCreator() : ""}
    ${state.videoProfileOverlay?.startsWith("fancam:") ? renderVideoProfileOverlay() : ""}
    ${state.videoFullscreen?.startsWith("fancam:") ? renderVideoFullscreenOverlay() : ""}
  `;
}

function renderFancamCard(fancam, index = 0, options = {}) {
  const liked = Boolean(state.likedFancams[fancam.id]);
  const saved = Boolean(state.savedFancams[fancam.id]);
  const followed = Boolean(state.followedArtists[fancam.artistId]);
  const commentsOpen = Boolean(state.fancamCommentsOpen[fancam.id]);
  const paused = Boolean(state.fancamPaused[fancam.id]);
  const expanded = Boolean(state.expandedPosts[`fancam-${fancam.id}`]);
  const longDescription = fancam.description.length > 76;
  const mediaUrl = fancam.mediaUrl || fancam.imageUrl || getDemoDropMedia(index + 2);
  const fallbackUrl = getDemoDropMedia(index + 5);
  const artistAvatar = getDemoUserImage(getStableAssetIndex(fancam.artist, DEMO_USER_IMAGES.length));
  return `
    <article class="fancam-card filter-${fancam.filter || "original"} ${options.compact ? "compact" : ""} ${paused ? "paused" : ""}" style="--art:${fancam.colors}">
      <button class="fancam-play-area" data-fancam-toggle="${fancam.id}" aria-label="${paused ? "Reproducir fancam" : "Pausar fancam"}"></button>
      ${state.fancamFeedback[fancam.id] ? `<div class="drop-center-feedback">${paused ? "▶" : "Ⅱ"}</div>` : ""}
      ${
        fancam.mediaType === "video"
          ? `<video class="fancam-media" src="${escapeAttr(mediaUrl)}" playsinline loop ${state.videoMuted ? "muted" : ""} ${paused ? "" : "autoplay"}></video>`
          : `<img class="fancam-media" src="${escapeAttr(mediaUrl)}" alt="Fancam de ${escapeAttr(fancam.artist)}" loading="lazy" onerror="this.onerror=null;this.src='${escapeAttr(fallbackUrl)}';" />`
      }
      <div class="video-quick-controls">
        <button class="video-sound-button ${state.videoMuted ? "muted" : ""}" data-toggle-video-sound aria-label="${state.videoMuted ? "Activar audio" : "Silenciar"}">♪</button>
        <button class="video-fullscreen-button" data-open-video-fullscreen="fancam:${fancam.id}" aria-label="Ver en pantalla completa"></button>
      </div>
      <div class="fancam-shade"></div>
      <div class="fancam-info">
        <button class="fancam-artist-link" data-open-video-profile="fancam:${fancam.id}">
          ${renderAvatarElement("mini fancam-avatar", "berry", artistAvatar)}
          <div>
            <strong>${escapeHtml(fancam.artist)}</strong>
            <small>${escapeHtml(fancam.group)} · ${escapeHtml(fancam.show)}</small>
          </div>
        </button>
        <p class="fancam-description ${expanded ? "expanded" : ""}">${escapeHtml(fancam.description)}</p>
        ${longDescription ? `<button class="drop-more-link fancam-more-link" data-toggle-fancam-text="${fancam.id}">${expanded ? "Ver menos" : "Ver más"}</button>` : ""}
      </div>
      <div class="fancam-actions">
        <button data-fancam-action="profile:${fancam.id}" aria-label="Abrir perfil"><span>@</span><small>Perfil</small></button>
        <button class="${followed ? "active" : ""}" data-fancam-action="follow:${fancam.id}" aria-label="Seguir artista"><span>${followed ? "✓" : "+"}</span><small>Seguir</small></button>
        <button class="${liked ? "active" : ""}" data-fancam-action="like:${fancam.id}" aria-label="Like"><span>★</span><small>${fancam.likes}</small></button>
        <button class="${commentsOpen ? "active" : ""}" data-fancam-action="comment:${fancam.id}" aria-label="Comentar"><span class="nav-icon chat-icon"></span><small>${fancam.comments || "0"}</small></button>
        <button class="${state.fancamShareOpen[fancam.id] ? "active" : ""}" data-fancam-action="share:${fancam.id}" aria-label="Compartir"><span class="share-dot"></span><small>Compartir</small></button>
        <button class="${saved ? "active" : ""}" data-fancam-action="save:${fancam.id}" aria-label="Guardar"><span class="save-mark"></span><small>Guardar</small></button>
        <button class="${state.fancamMusicOpen[fancam.id] ? "active" : ""}" data-fancam-action="music:${fancam.id}" aria-label="Audio"><span>♪</span><small>Audio</small></button>
        <button data-report-content="fancam:${fancam.id}" aria-label="Reportar fancam"><span>!</span><small>Reportar</small></button>
      </div>
      ${state.fancamShareOpen[fancam.id] ? renderFancamSharePanel(fancam) : ""}
      ${state.fancamMusicOpen[fancam.id] ? renderFancamMusicPanel(fancam) : ""}
    </article>
  `;
}

function renderFancamComments(fancam) {
  return `
    <div class="fancam-comments-panel">
      <strong>Comentarios</strong>
      <p><b>@ren.fancam</b> Ese focus está perfecto para estudiar el stage.</p>
      <p><b>@mika.army</b> Guardada para ver después ✨</p>
      <div class="drop-comment-input">
        <input placeholder="Comentar fancam..." aria-label="Comentar fancam" />
        <button data-fancam-comment-send="${fancam.id}">Enviar</button>
      </div>
    </div>
  `;
}

function renderFancamSharePanel(fancam) {
  return `
    <div class="fancam-comments-panel fancam-mini-panel">
      <strong>Compartir fancam</strong>
      <button data-demo-action="Enlace de ${escapeAttr(fancam.artist)} copiado">Copiar enlace demo</button>
      <button data-demo-action="Fancam enviada por mensaje demo">Enviar por mensaje</button>
    </div>
  `;
}

function renderFancamMusicPanel(fancam) {
  return `
    <div class="fancam-comments-panel fancam-mini-panel">
      <strong>Audio / show</strong>
      <p>${escapeHtml(fancam.show)} · ${escapeHtml(fancam.era)}</p>
      <button data-demo-action="Audio guardado en favoritos">Guardar audio</button>
    </div>
  `;
}

function handleFancamAction(action, fancamId) {
  const fancam = fancamVideos.find((item) => item.id === fancamId);
  if (!fancam) return;
  state.fancamShareOpen[fancamId] = action === "share" ? !state.fancamShareOpen[fancamId] : false;
  state.fancamMusicOpen[fancamId] = action === "music" ? !state.fancamMusicOpen[fancamId] : false;
  if (action === "profile") {
    state.videoProfileOverlay = `fancam:${fancamId}`;
    return;
  }
  if (action === "follow") {
    state.followedArtists[fancam.artistId] = !state.followedArtists[fancam.artistId];
    showToast(state.followedArtists[fancam.artistId] ? `Seguís a ${fancam.artist}` : `Dejaste de seguir a ${fancam.artist}`);
    return;
  }
  if (action === "like") {
    state.likedFancams[fancamId] = !state.likedFancams[fancamId];
    showToast(state.likedFancams[fancamId] ? "Fancam marcada con estrella" : "Estrella quitada");
    if (state.likedFancams[fancamId]) playAppSound("like");
    return;
  }
  if (action === "save") {
    state.savedFancams[fancamId] = !state.savedFancams[fancamId];
    showToast(state.savedFancams[fancamId] ? "Fancam guardada" : "Fancam quitada de guardados");
    if (state.savedFancams[fancamId]) playAppSound("save");
    return;
  }
  if (action === "comment") {
    state.fancamCommentsOpen[fancamId] = !state.fancamCommentsOpen[fancamId];
    return;
  }
  if (action === "share") {
    state.fancamCommentsOpen[fancamId] = false;
    return;
  }
  if (action === "music") {
    state.fancamCommentsOpen[fancamId] = false;
  }
}

function renderVideoProfileOverlay() {
  if (!state.videoProfileOverlay) return "";
  const [type, id] = state.videoProfileOverlay.split(":");
  if (type === "drop") {
    const trend = trendVideos.find((item, index) => getDropId(item, index) === id);
    if (!trend) return "";
    const demoUser = getDemoUser(trend.user);
    const followed = Boolean(state.dropFollowed[id]);
    return `
      <section class="video-profile-overlay" aria-label="Perfil del creador del Drop">
        <button class="story-close video-profile-close" data-close-video-profile aria-label="Cerrar">X</button>
        <article class="video-profile-card" style="--art:${trend.colors}">
          <div class="video-profile-hero">
            ${renderAvatarElement("video-profile-avatar", demoUser.avatar || "berry", demoUser.avatarUrl)}
            <div>
              <span class="eyebrow">Creador Drop</span>
              <h2>${escapeHtml(trend.user)}</h2>
              <p>${escapeHtml(demoUser.city || "Latam")} · ${escapeHtml(demoUser.fandom || "Hallyu fan")}</p>
            </div>
          </div>
          <div class="video-profile-stats">
            <span><strong>${escapeHtml(demoUser.followers || "8.2K")}</strong> seguidores</span>
            <span><strong>${escapeHtml(demoUser.posts || "42")}</strong> posts</span>
            <span><strong>${escapeHtml(demoUser.starsReceived || "18K")}</strong> estrellas</span>
          </div>
          <div class="video-profile-preview">
            <strong>${escapeHtml(trend.challenge)}</strong>
            <p>${escapeHtml(trend.description)}</p>
            <small>♪ ${escapeHtml(trend.song)}</small>
          </div>
          <div class="video-profile-actions">
            <button class="primary-button" data-drop-action="follow:${id}">${followed ? "Siguiendo" : "Seguir creador"}</button>
            <button class="ghost-button" data-drop-action="music:${id}">Audio</button>
            <button class="ghost-button" data-report-content="profile:${escapeAttr(trend.user)}">Reportar perfil</button>
            <button class="ghost-button" data-close-video-profile>Volver al Drop</button>
          </div>
        </article>
      </section>
    `;
  }
  const fancam = fancamVideos.find((item) => item.id === id || item.artistId === id);
  if (!fancam) return "";
  const followed = Boolean(state.followedArtists[fancam.artistId]);
  return `
    <section class="video-profile-overlay" aria-label="Perfil del artista de la fancam">
      <button class="story-close video-profile-close" data-close-video-profile aria-label="Cerrar">X</button>
      <article class="video-profile-card fancam-profile-card" style="--art:${fancam.colors}">
        <div class="video-profile-hero">
          ${renderAvatarElement("video-profile-avatar", "berry", fancam.imageUrl || getDemoUserImage(getStableAssetIndex(fancam.artist, DEMO_USER_IMAGES.length)))}
          <div>
            <span class="eyebrow">Focus idol</span>
            <h2>${escapeHtml(fancam.artist)}</h2>
            <p>${escapeHtml(fancam.group)} · ${escapeHtml(fancam.era)}</p>
          </div>
        </div>
        <div class="video-profile-stats">
          <span><strong>${escapeHtml(fancam.views)}</strong> vistas</span>
          <span><strong>${escapeHtml(fancam.likes)}</strong> estrellas</span>
          <span><strong>${escapeHtml(fancam.show)}</strong> show</span>
        </div>
        <div class="video-profile-preview">
          ${fancam.mediaUrl ? `<img src="${escapeAttr(fancam.mediaUrl)}" alt="Preview de ${escapeAttr(fancam.artist)}" />` : ""}
          <strong>${escapeHtml(fancam.artist)} fancam</strong>
          <p>${escapeHtml(fancam.description)}</p>
        </div>
        <div class="video-profile-actions">
          <button class="primary-button" data-fancam-action="follow:${fancam.id}">${followed ? "Siguiendo" : "Seguir artista"}</button>
          <button class="ghost-button" data-fancam-action="music:${fancam.id}">Audio/show</button>
          <button class="ghost-button" data-report-content="artist:${fancam.artistId}">Reportar artista</button>
          <button class="ghost-button" data-close-video-profile>Volver a Fancams</button>
        </div>
      </article>
    </section>
  `;
}

function renderVideoFullscreenOverlay() {
  if (!state.videoFullscreen) return "";
  const [type, id] = state.videoFullscreen.split(":");
  const isDrop = type === "drop";
  const item = isDrop ? trendVideos.find((trend, index) => getDropId(trend, index) === id) : fancamVideos.find((fancam) => fancam.id === id);
  if (!item) return "";
  const title = isDrop ? item.user : item.artist;
  const audio = isDrop ? item.song : `${item.group} · ${item.show}`;
  const description = item.description;
  const mediaUrl = item.mediaUrl || item.imageUrl || getDemoDropMedia(getStableAssetIndex(id, DEMO_DROP_MEDIA.length));
  const fallbackUrl = getDemoDropMedia(getStableAssetIndex(`${id}-fallback`, DEMO_DROP_MEDIA.length));
  const media = `<img class="video-fullscreen-media" src="${escapeAttr(mediaUrl)}" alt="${escapeAttr(title)}" loading="lazy" onerror="this.onerror=null;this.src='${escapeAttr(fallbackUrl)}';" />`;
  return `
    <section class="video-fullscreen-overlay" style="--art:${item.colors}" aria-label="Video en pantalla completa">
      <button class="story-close video-profile-close" data-close-video-fullscreen aria-label="Cerrar">X</button>
      ${media}
      <div class="video-fullscreen-art"></div>
      <div class="video-fullscreen-controls">
        <button class="video-sound-button ${state.videoMuted ? "muted" : ""}" data-toggle-video-sound aria-label="${state.videoMuted ? "Activar audio" : "Silenciar"}">♪</button>
      </div>
      <div class="video-fullscreen-copy">
        <strong>${escapeHtml(title)}</strong>
        <span>♪ ${escapeHtml(audio)}</span>
        <p>${escapeHtml(description)}</p>
      </div>
    </section>
  `;
}

function renderPublish() {
  const draft = state.publishDraft;
  const selectedType = publishTypes.find(([key]) => key === draft.type) || publishTypes[0];
  const selectedFilter = publishFilters.find(([key]) => key === draft.filter) || publishFilters[0];
  if (draft.result) return renderPublishSuccess(draft.result);
  return `
    <section class="publish-studio" aria-label="Editor universal HallyuHub">
      <div class="publish-studio-top">
        <button class="publish-icon-close" data-publish-cancel aria-label="Cerrar editor">×</button>
        <div>
          <p class="eyebrow">Crear</p>
          <h2>${selectedType[1]}</h2>
        </div>
        <button class="publish-primary-mini" data-create-post>Publicar</button>
      </div>
      <input id="publish-media-input" class="publish-file-input" type="file" accept="image/*,video/*" />
      <div class="publish-preview-shell filter-${draft.filter}">
        ${
          draft.mediaUrl
            ? `<div class="publish-preview-media">
                ${
                  draft.mediaType === "video"
                    ? `<video src="${escapeAttr(draft.mediaUrl)}" controls playsinline muted preload="metadata"></video>`
                    : `<img src="${escapeAttr(draft.mediaUrl)}" alt="Preview de ${selectedType[1]}" />`
                }
                <div class="publish-preview-actions">
                  <button type="button" data-publish-change-file>Cambiar</button>
                  <button type="button" data-publish-remove-media>Eliminar</button>
                </div>
                <span class="publish-filter-badge">${selectedFilter[1]}</span>
              </div>`
            : `<button type="button" class="publish-upload-hero" data-publish-file-trigger>
                <span>+</span>
                <strong>Subir foto o video</strong>
                <small>Imagen o video para Publicación, Drop, Fancam, Story, Outfit o Photocard</small>
              </button>`
        }
      </div>
      <div class="publish-type-tabs" aria-label="Tipo de contenido">
        ${publishTypes.map(([key, label]) => `<button type="button" class="${draft.type === key ? "active" : ""}" data-publish-type="${key}">${label}</button>`).join("")}
      </div>
      <section class="publish-filter-row" aria-label="Filtros visuales">
        ${publishFilters.map(([key, label]) => `<button type="button" class="${draft.filter === key ? "active" : ""}" data-publish-filter="${key}"><span class="filter-dot filter-${key}"></span>${label}</button>`).join("")}
      </section>
      <div class="publish-fields-card">
        <div class="publish-author-row">
          ${renderAvatarElement("mini", state.user.avatar || "berry", state.user.avatarUrl || getDemoUserImage(0))}
          <div><strong>${state.user.name}</strong><span>@${state.user.username}</span></div>
        </div>
        <label class="publish-field clean">Descripción
          <textarea data-publish-draft="caption" placeholder="Contá qué estás compartiendo..." rows="3">${escapeHtml(draft.caption)}</textarea>
        </label>
        <div class="publish-field-grid">
          <label>Hashtags<input data-publish-draft="hashtags" value="${escapeAttr(draft.hashtags)}" placeholder="#KpopLatam #Comeback" /></label>
          <label>Etiquetar personas<input data-publish-draft="taggedPeople" value="${escapeAttr(draft.taggedPeople)}" placeholder="@cami @mika" /></label>
          <label>Grupo<input data-publish-draft="taggedGroup" value="${escapeAttr(draft.taggedGroup)}" placeholder="BTS, BLACKPINK, ENHYPEN" /></label>
          <label>Artista/integrante<input data-publish-draft="taggedArtist" value="${escapeAttr(draft.taggedArtist)}" placeholder="Jung Kook, Lisa, Jungwon" /></label>
          <label>Show/evento<input data-publish-draft="taggedShow" value="${escapeAttr(draft.taggedShow)}" placeholder="Music show, concierto, cupsleeve" /></label>
          <label>Ciudad<input data-publish-draft="city" value="${escapeAttr(draft.city)}" placeholder="Buenos Aires, Santiago" /></label>
          <label>Fecha<input data-publish-draft="eventDate" value="${escapeAttr(draft.eventDate)}" placeholder="2026-05-21" /></label>
          <label>Ubicación<input data-publish-draft="location" value="${escapeAttr(draft.location)}" placeholder="Buenos Aires, Argentina" /></label>
          <label>Etiquetar lugar<input data-publish-draft="taggedPlace" value="${escapeAttr(draft.taggedPlace)}" placeholder="Cupsleeve, show, café" /></label>
          <label>Música / audio<input data-publish-draft="audio" value="${escapeAttr(draft.audio)}" placeholder="K-pop safe loop, fan audio..." /></label>
          <label>Privacidad
            <select data-publish-draft="privacy">
              ${["Público", "Seguidores", "Privado"].map((item) => `<option value="${item}" ${draft.privacy === item ? "selected" : ""}>${item}</option>`).join("")}
            </select>
          </label>
        </div>
        <label class="publish-switch">
          <input type="checkbox" data-publish-draft="allowComments" ${draft.allowComments ? "checked" : ""} />
          <span></span>
          Permitir comentarios
        </label>
        <label class="publish-switch rights-confirm-switch">
          <input type="checkbox" data-publish-draft="rightsConfirmed" ${draft.rightsConfirmed ? "checked" : ""} />
          <span></span>
          Confirmo que este contenido fue grabado o creado por mí, o que tengo permiso para subirlo.
        </label>
      </div>
      <div class="publish-bottom-actions">
        <button class="ghost-button" type="button" data-publish-cancel>Cancelar</button>
        <button class="primary-button" type="button" data-create-post>Publicar</button>
      </div>
      <p class="legal-note">El usuario es responsable del contenido que sube. HallyuHub puede remover contenido reportado o que infrinja derechos.</p>
    </section>
  `;
}

function renderPublishSuccess(result) {
  return `
    <section class="publish-success-card">
      <div class="publish-success-art filter-${result.filter || "original"}">
        ${
          result.mediaType === "video"
            ? `<video src="${escapeAttr(result.mediaUrl)}" muted loop playsinline></video>`
            : `<img src="${escapeAttr(result.mediaUrl)}" alt="Contenido publicado" />`
        }
      </div>
      <div class="publish-success-copy">
        <span>Publicado correctamente</span>
        <h2>${result.label}</h2>
        <p>Tu contenido ya quedó guardado en modo demo y aparece en la sección correspondiente.</p>
      </div>
      <div class="publish-success-actions">
        <button class="primary-button" data-view-created="${result.type}">Ver publicación</button>
        <button class="ghost-button" data-publish-cancel>Volver al perfil</button>
      </div>
    </section>
  `;
}

function renderPermissionPrompt() {
  if (!state.permissionPrompt) return "";
  return `
    <section class="permission-sheet" role="dialog" aria-label="Permisos de HallyuHub">
      <div class="permission-card">
        <div class="permission-glow-icon"><span>+</span></div>
        <h2>Permisos para crear</h2>
        <p>HallyuHub necesita acceso a tu cámara, galería y micrófono para crear publicaciones, stories, drops y fancams.</p>
        <div class="permission-actions">
          <button class="primary-button" type="button" data-permission-allow>Permitir</button>
          <button class="ghost-button" type="button" data-permission-deny>Ahora no</button>
        </div>
        <small>Este aviso se recuerda por 30 días y no vuelve a aparecer cada vez que subís algo.</small>
      </div>
    </section>
  `;
}

function renderMediaEmbedModal() {
  if (!state.mediaEmbed) return "";
  const video = state.mediaEmbed;
  return `
    <section class="media-embed-modal" aria-label="Reproductor oficial">
      <button class="story-close media-embed-close" data-close-media-embed aria-label="Cerrar">X</button>
      <article class="media-embed-card">
        <div class="media-embed-frame">
          <iframe src="https://www.youtube.com/embed/${escapeAttr(video.youtubeId)}" title="${escapeAttr(video.title)}" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>
        </div>
        <div class="media-embed-copy">
          <span class="tag">Embed oficial</span>
          <h2>${escapeHtml(video.title)}</h2>
          <p>${escapeHtml(video.group)} · ${escapeHtml(video.source)}</p>
          <small>No alojamos videos oficiales protegidos: usamos reproductor embebido o links externos oficiales.</small>
        </div>
      </article>
    </section>
  `;
}

function renderNotifications() {
  const items = [
    [getDemoUser("Camila Seo"), "empezo a seguirte", "Nuevo seguidor", "Ahora"],
    [getDemoUser("Mika Torres"), "le dio like a tu publicacion", "Like recibido", "12 min"],
    [getDemoUser("Valentina Park"), "comento tu pregunta de K-pop 101", "Comentario", "1 h"],
    [getDemoUser("Nico Kim"), "guardo tu wishlist de photocards", "Actividad", "Ayer"],
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
                ([user, action, type, time], index) => `
                <article class="notification-card">
                  ${renderAvatarElement("mini", user.avatar || "berry", user.avatarUrl)}
                  <div><h3>${user.name}</h3><p class="muted">${action}</p><span class="tag">${type}</span></div>
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
      <button class="filter-chip active" data-demo-action="Eventos cerca de mi">Cerca de mi</button>
      <button class="filter-chip" data-demo-action="Filtro Conciertos aplicado">Conciertos</button>
      <button class="filter-chip" data-demo-action="Filtro Fan meetings aplicado">Fan meetings</button>
      <button class="filter-chip" data-demo-action="Filtro Random dance aplicado">Random dance</button>
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
              <div class="price-row"><strong>${product.price}</strong><button class="tiny-plus" aria-label="Agregar" data-demo-action="Producto agregado a wishlist">+</button></div>
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
            <button class="ghost-button" data-demo-action="Local guardado en carpeta">Agregar a carpeta</button>
          </article>`,
        )
        .join("")}
    </div>
  `;
}

function renderGroups() {
  const filteredGroups = getFilteredGroups();
  const artistResults = getFilteredArtists();
  const hasGroupQuery = Boolean(normalizeProfileKey(state.groupSearch));
  const activeGroup = filteredGroups.find((group) => group.id === state.selectedGroup) || (hasGroupQuery ? filteredGroups[0] : null) || kpopGroups.find((group) => group.id === state.selectedGroup) || filteredGroups[0] || kpopGroups[0];
  const selectedArtist = activeGroup.artists.find((artist) => artist.id === state.selectedArtist);
  if (selectedArtist) return renderArtistProfile(selectedArtist, activeGroup);
  const relatedNews = getRelatedNewsForGroup(activeGroup);
  const relatedPosts = userPosts.filter((post) => [post.group, post.badge, ...(post.hashtags || [])].join(" ").toLowerCase().includes(activeGroup.name.toLowerCase()) || (post.hashtags || []).some((tag) => tag.toLowerCase().includes(activeGroup.fandom.toLowerCase()))).slice(0, 3);
  const groupFilters = [
    ["all", "Todo"],
    ["group", "Grupos"],
    ["artist", "Integrantes"],
    ["fandom", "Fandom"],
    ["company", "Empresa"],
  ];
  return `
    <div class="search-box group-search-box">
      <span class="nav-icon search-icon"></span>
      <input data-group-search value="${escapeAttr(state.groupSearch)}" placeholder="Buscar grupo, integrante, fandom o empresa" />
    </div>
    <div class="group-filter-row">
      ${groupFilters.map(([key, label]) => `<button class="${state.groupFilter === key ? "active" : ""}" data-group-filter="${key}">${label}</button>`).join("")}
    </div>
    <div class="group-story-row">
      ${
        filteredGroups.length
          ? filteredGroups
              .map(
                (group) => `
          <button class="group-story ${activeGroup.id === group.id ? "active" : ""}" data-group="${group.id}">
            <span class="group-story-photo ${getVisualClass(group, "image")}" style="${getVisualStyle(group, group.colors, "image")}">${shouldShowInitials(group, "image") ? getInitials(group.name) : ""}</span>
            <strong>${group.name}</strong>
            <small>${group.fandom}</small>
          </button>`,
              )
              .join("")
          : `<article class="empty-group-result">No encontramos ese grupo todavia. Probá buscar por integrante, fandom o empresa.</article>`
      }
    </div>
    ${artistResults.length ? renderArtistSearchResults(artistResults) : ""}
    <article class="group-hero ${activeGroup.coverUrl ? "has-cover" : "is-placeholder"}" style="${getVisualStyle(activeGroup, activeGroup.colors, "cover")}">
      <span class="tag">${activeGroup.type === "soloist" ? "Solista" : "Grupo"} · ${activeGroup.status}</span>
      <h2>${activeGroup.name}</h2>
      <p>${activeGroup.style}</p>
      <small class="source-credit">${renderSourceCredit(activeGroup)}</small>
    </article>
    <div class="artist-action-row">
      <button class="primary-button follow-group-button" data-demo-action="Ahora seguís a ${activeGroup.name}">Seguir ${activeGroup.name}</button>
      <button class="ghost-button" data-report-content="group:${activeGroup.id}">Reportar grupo</button>
    </div>
    <section class="group-info-grid">
      <div class="info-tile"><span>Empresa</span><strong>${activeGroup.company}</strong></div>
      <div class="info-tile"><span>Debut</span><strong>${activeGroup.debut}</strong></div>
      <div class="info-tile"><span>Fandom</span><strong>${activeGroup.fandom}</strong></div>
      <div class="info-tile"><span>País</span><strong>${activeGroup.country}</strong></div>
    </section>
    <section class="official-links-card">
      <strong>Links oficiales</strong>
      <div>${activeGroup.officialLinks.map(([label, url]) => `<a href="${url}" target="_blank" rel="noopener noreferrer">${label}</a>`).join("")}</div>
    </section>
    ${renderImageCredits(activeGroup)}
    <div class="group-photo-strip">
      <div class="${activeGroup.coverUrl ? "has-photo" : "is-placeholder"}" style="${getVisualStyle(activeGroup, activeGroup.colors, "cover")}">Portada</div>
      <div class="${activeGroup.imageUrl ? "has-photo" : "is-placeholder"}" style="${getVisualStyle(activeGroup, activeGroup.colors, "image")}">Grupo</div>
      <div style="--art:${art[4]}">Behind</div>
    </div>
    <section class="glass-card update-card">
      <div>
        <h3 class="card-title">Noticias destacadas</h3>
        <p class="muted">${activeGroup.latest}</p>
        <div class="group-news-list">
          ${
            relatedNews.length
              ? relatedNews.map((item) => `<a href="${item.link}" target="_blank" rel="noopener noreferrer">${item.title}</a>`).join("")
              : `<button type="button" data-go-view="news">Ver noticias K-pop</button>`
          }
        </div>
      </div>
      <span class="tag">Internet ready</span>
    </section>
    <section class="glass-card biography-card">
      <h3 class="card-title">Biografia</h3>
      <p>${activeGroup.bio}</p>
    </section>
    ${renderGroupFanContent(activeGroup)}
    <div class="section-heading"><h2>Artistas</h2><span>${activeGroup.artists.length} perfiles</span></div>
    <div class="artist-list">
      ${activeGroup.artists
        .map(
          (artist, index) => `
          <article class="artist-card ${state.selectedArtist === artist.id ? "active" : ""}">
            <div class="artist-photo ${getVisualClass(artist, "image")}" style="${getVisualStyle(artist, art[index % art.length], "image")}"><span>${shouldShowInitials(artist, "image") ? getInitials(artist.name) : ""}</span></div>
            <div>
              <h3>${artist.name}</h3>
              <p class="muted">${artist.role}</p>
              <div class="meta-row"><span>${artist.country}</span><button class="tag" data-artist-profile="${artist.id}">Ver perfil</button></div>
            </div>
          </article>`,
        )
        .join("")}
    </div>
    <div class="section-heading"><h2>Publicaciones relacionadas</h2><span>${activeGroup.name}</span></div>
    <div class="social-feed compact-related-feed">
      ${relatedPosts.length ? relatedPosts.map((post, index) => renderSocialPost(post, index, { compact: true })).join("") : `<article class="settings-demo-box">Todavia no hay publicaciones relacionadas. Se pueden cargar desde Publicar usando hashtags del grupo.</article>`}
    </div>
  `;
}

function getFilteredGroups() {
  const query = normalizeProfileKey(state.groupSearch);
  const filter = state.groupFilter || "all";
  const fieldMatches = {
    group: (group) => [group.name, group.type, group.country, group.status],
    artist: (group) => (group.artists || []).flatMap((artist) => [artist.name, artist.realName, artist.role, artist.country, artist.nationality]),
    fandom: (group) => [group.fandom],
    company: (group) => [group.company],
    all: (group) => [
      group.name,
      group.type,
      group.fandom,
      group.company,
      group.country,
      group.status,
      ...(group.artists || []).flatMap((artist) => [artist.name, artist.realName, artist.role, artist.country, artist.nationality]),
    ],
  };
  if (!query) return kpopGroups.filter((group) => normalizeProfileKey((fieldMatches[filter] || fieldMatches.all)(group).join(" ")));
  return kpopGroups.filter((group) => {
    const haystack = (fieldMatches[filter] || fieldMatches.all)(group).join(" ");
    return normalizeProfileKey(haystack).includes(query);
  });
}

function getFilteredArtists() {
  const query = normalizeProfileKey(state.groupSearch);
  if (!query) return [];
  const filter = state.groupFilter || "all";
  if (!["all", "artist"].includes(filter)) return [];
  return kpopGroups
    .flatMap((group) =>
      (group.artists || []).map((artist) => ({
        artist,
        group,
        haystack: normalizeProfileKey([artist.name, artist.realName, artist.role, artist.country, artist.nationality, group.name, group.fandom, group.company].join(" ")),
      })),
    )
    .filter((item) => item.haystack.includes(query))
    .slice(0, 8);
}

function renderArtistSearchResults(results) {
  return `
    <section class="artist-search-results">
      <div class="section-heading small"><h2>Artistas encontrados</h2><span>${results.length}</span></div>
      <div class="artist-result-grid">
        ${results
          .map(
            ({ artist, group }, index) => `
            <article class="artist-result-card">
              <div class="artist-result-photo ${getVisualClass(artist, "image")}" style="${getVisualStyle(artist, group.colors || art[index % art.length], "image")}">
                <span>${shouldShowInitials(artist, "image") ? getInitials(artist.name) : ""}</span>
              </div>
              <div>
                <strong>${artist.name}</strong>
                <small>${artist.realName ? `${artist.realName} · ` : ""}${group.name}</small>
                <p>${artist.role}</p>
                <button class="tag" data-artist-profile="${artist.id}">Ver perfil</button>
              </div>
            </article>`,
          )
          .join("")}
      </div>
    </section>
  `;
}

function getRelatedNewsForGroup(group) {
  return (state.newsItems.length ? state.newsItems : news)
    .filter((item) => [item.artist, item.title, item.summary].join(" ").toLowerCase().includes(group.name.toLowerCase()))
    .slice(0, 3);
}

function getInitials(name) {
  return String(name || "HH")
    .replace(/[()]/g, "")
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0])
    .join("")
    .toUpperCase();
}

function getVisualStyle(entity, fallbackArt, variant = "image") {
  const url = variant === "cover" ? entity.coverUrl || entity.imageUrl : entity.imageUrl || entity.coverUrl;
  const artValue = fallbackArt || entity.colors || art[0];
  return `--art:${artValue};${url ? `--photo:url('${escapeAttr(url)}');--cover:url('${escapeAttr(url)}');` : ""}`;
}

function isLocalPlaceholderVisual(url) {
  return String(url || "").includes("assets/visuals/");
}

function shouldShowInitials(entity, variant = "image") {
  const url = variant === "cover" ? entity.coverUrl || entity.imageUrl : entity.imageUrl || entity.coverUrl;
  return !url || isLocalPlaceholderVisual(url);
}

function getVisualClass(entity, variant = "image") {
  const url = variant === "cover" ? entity.coverUrl || entity.imageUrl : entity.imageUrl || entity.coverUrl;
  return `${url ? "has-photo" : "is-placeholder"} ${isLocalPlaceholderVisual(url) ? "local-placeholder" : ""}`;
}

function renderSourceCredit(entity) {
  if (!entity.sourceCredit) return "Imagen pendiente";
  if (!entity.sourceUrl) return entity.sourceCredit;
  return `<a href="${entity.sourceUrl}" target="_blank" rel="noopener noreferrer">${entity.sourceCredit}</a>`;
}

function renderImageCredits(entity) {
  const creditRows = [
    ["Autor", entity.author],
    ["Licencia", entity.license],
    ["Atribucion", entity.attributionText],
  ].filter(([, value]) => value);
  return `
    <section class="image-credit-card">
      <strong>Créditos de imagen</strong>
      <div>
        ${creditRows.map(([label, value]) => `<p><span>${label}</span>${value}</p>`).join("")}
        ${
          entity.sourceUrl
            ? `<a href="${entity.sourceUrl}" target="_blank" rel="noopener noreferrer">Ver fuente</a>`
            : `<small>Placeholder temporal listo para reemplazar por foto legal autorizada.</small>`
        }
      </div>
    </section>
  `;
}

function renderArtistProfile(artist, group) {
  const artistFacts = [
    ["Nombre real", artist.realName],
    ["Grupo", group.name],
    ["Rol", artist.role],
    ["Nacimiento", artist.birth],
    ["Nacionalidad", artist.nationality || artist.country],
  ].filter(([, value]) => value);
  const artistRelatedPosts = userPosts
    .filter((post) => [post.text, post.group, post.user, ...(post.hashtags || [])].join(" ").toLowerCase().includes(artist.name.toLowerCase()) || [post.group, post.badge, ...(post.hashtags || [])].join(" ").toLowerCase().includes(group.name.toLowerCase()))
    .slice(0, 2);
  return `
    <section class="artist-profile-panel artist-profile-screen" style="${getVisualStyle(artist, group.colors, "cover")}">
      <button class="artist-back" data-close-artist aria-label="Volver a ${group.name}">← Grupo</button>
      <div class="artist-profile-cover ${artist.coverUrl ? "has-cover" : "is-placeholder"}">
        <span class="source-credit">${renderSourceCredit(artist)}</span>
      </div>
      <div class="artist-profile-head">
        <div class="artist-photo large ${getVisualClass(artist, "image")}" style="${getVisualStyle(artist, group.colors, "image")}"><span>${shouldShowInitials(artist, "image") ? getInitials(artist.name) : ""}</span></div>
        <div>
          <span class="tag">${group.name}</span>
          <h2>${artist.name}</h2>
          <p>${artist.role}</p>
        </div>
      </div>
      <div class="artist-action-row">
        <button class="primary-button follow-group-button" data-demo-action="Ahora seguís a ${artist.name}">Seguir artista</button>
        <button class="ghost-button" data-report-content="artist:${artist.id}">Reportar perfil</button>
      </div>
      <p>${artist.bio}</p>
      ${renderArtistMediaHub(artist, group)}
      ${renderArtistFanContent(artist, group)}
      <section class="group-info-grid mini-info-grid">
        ${artistFacts.map(([label, value]) => `<div class="info-tile"><span>${label}</span><strong>${value}</strong></div>`).join("")}
      </section>
      ${renderImageCredits(artist)}
      <div class="artist-related-card">
        <strong>Noticias y publicaciones relacionadas</strong>
        <div class="group-news-list">
          ${getRelatedNewsForGroup(group)
            .slice(0, 2)
            .map((item) => `<a href="${item.link}" target="_blank" rel="noopener noreferrer">${item.title}</a>`)
            .join("")}
          ${artistRelatedPosts.map((post) => `<button type="button" data-demo-action="Abriste una publicacion sobre ${artist.name}">${post.text.split(" ").slice(0, 7).join(" ")}...</button>`).join("")}
        </div>
      </div>
    </section>
  `;
}

function renderArtistMediaHub(artist, group) {
  const photos = getArtistPhotos(artist, group);
  const videos = getArtistVideos(artist, group);
  const artistFancams = getFilteredFancams(artist.id);
  const links = getArtistOfficialLinks(artist, group);
  return `
    <section class="artist-media-hub">
      <div class="section-heading small"><h2>Media oficial y fan</h2><span>Legal ready</span></div>
      <div class="artist-media-section">
        <div class="artist-media-title"><strong>Fotos</strong><small>Licenciadas, autorizadas o placeholders</small></div>
        <div class="artist-media-row">
          ${photos.map((photo) => renderArtistPhotoTile(photo)).join("")}
        </div>
      </div>
      <div class="artist-media-section">
        <div class="artist-media-title"><strong>Videos</strong><small>Embeds oficiales de YouTube</small></div>
        <div class="artist-media-row large-previews">
          ${
            videos.length
              ? videos.map((video) => renderArtistVideoTile(video)).join("")
              : `<article class="settings-demo-box">Próximamente: embeds oficiales o links externos del artista.</article>`
          }
        </div>
      </div>
      <div class="artist-media-section">
        <div class="artist-media-title"><strong>Fancams</strong><small>Contenido de usuarios moderable</small></div>
        ${
          artistFancams.length
            ? `<div class="artist-fancam-row">${artistFancams.map((fancam, index) => renderArtistFancamTile(fancam, index)).join("")}</div>`
            : `<article class="settings-demo-box">Todavia no hay fancams cargadas para ${escapeHtml(artist.name)}.</article>`
        }
      </div>
      <div class="artist-media-section">
        <div class="artist-media-title"><strong>Links oficiales</strong><small>No copiamos contenido de plataformas externas</small></div>
        <div class="artist-official-link-row">
          ${links.map(([label, url]) => `<a href="${escapeAttr(url)}" target="_blank" rel="noopener noreferrer">${escapeHtml(label)}</a>`).join("")}
        </div>
      </div>
      <p class="legal-note">Los videos oficiales se muestran mediante embeds o enlaces. Fotos y media se reemplazan progresivamente por material con licencia o autorizado.</p>
    </section>
  `;
}

function renderArtistFanContent(artist, group) {
  const content = getFanContentForEntity({ artist, group, scope: "artist" });
  return renderFanContentSection({
    title: "Contenido de fans",
    subtitle: `${artist.name} · creado por la comunidad`,
    empty: `Todavía no hay contenido fan etiquetado para ${artist.name}.`,
    content,
  });
}

function renderGroupFanContent(group) {
  const content = getFanContentForEntity({ group, scope: "group" });
  return renderFanContentSection({
    title: "Fans en shows",
    subtitle: `${group.name} · experiencias, fotos y fancams`,
    empty: `Todavía no hay experiencias fan etiquetadas para ${group.name}.`,
    content,
  });
}

function renderFanContentSection({ title, subtitle, empty, content }) {
  const filtered = filterFanContent(content);
  const fancams = filtered.filter((item) => item.type === "fancam").slice(0, 6);
  const drops = filtered.filter((item) => item.type === "drop").slice(0, 6);
  const photos = filtered.filter((item) => item.mediaType === "image" || item.type === "photo").slice(0, 8);
  const feed = filtered.slice(0, 5);
  const filters = [
    ["recent", "Recientes"],
    ["popular", "Populares"],
    ["fancams", "Fancams"],
    ["photos", "Fotos"],
    ["shows", "Shows"],
  ];
  return `
    <section class="fan-content-section">
      <div class="section-heading small"><h2>${title}</h2><span>${filtered.length}</span></div>
      <p class="muted">${subtitle}</p>
      <div class="fan-filter-row">
        ${filters.map(([key, label]) => `<button class="${state.fanContentFilter === key ? "active" : ""}" data-fan-content-filter="${key}">${label}</button>`).join("")}
      </div>
      ${
        filtered.length
          ? `
            <div class="fan-content-block">
              <div class="artist-media-title"><strong>Carrusel de fancams</strong><small>Usuarios/fans</small></div>
              <div class="fan-fancam-row">${(fancams.length ? fancams : filtered.slice(0, 4)).map(renderFanFancamTile).join("")}</div>
            </div>
            <div class="fan-content-block">
              <div class="artist-media-title"><strong>Drops relacionados</strong><small>Challenges, edits y clips fan</small></div>
              <div class="fan-fancam-row">${(drops.length ? drops : filtered.filter((item) => item.type === "video").slice(0, 4)).map(renderFanFancamTile).join("")}</div>
            </div>
            <div class="fan-content-block">
              <div class="artist-media-title"><strong>Fotos de conciertos</strong><small>Subidas por fans</small></div>
              <div class="fan-photo-grid">${(photos.length ? photos : filtered.slice(0, 6)).map(renderFanPhotoTile).join("")}</div>
            </div>
            <div class="fan-content-block">
              <div class="artist-media-title"><strong>Feed fan</strong><small>Experiencias y publicaciones</small></div>
              <div class="fan-feed-list">${feed.map(renderFanFeedCard).join("")}</div>
            </div>`
          : `<article class="settings-demo-box">${empty}</article>`
      }
      <p class="legal-note">El usuario es responsable del contenido que sube. HallyuHub podrá remover contenido reportado o que infrinja derechos.</p>
    </section>
  `;
}

function getFanContentForEntity({ artist, group, scope }) {
  const groupKey = normalizeProfileKey(group?.name);
  const groupId = normalizeProfileKey(group?.id);
  const fandomKey = normalizeProfileKey(group?.fandom);
  const artistKey = normalizeProfileKey(artist?.name);
  const artistId = normalizeProfileKey(artist?.id);
  const postItems = userPosts.map((post, index) => ({
    id: post.id || `post-${index}`,
    type: post.mediaType === "video" ? "video" : "post",
    mediaType: post.mediaType || "image",
    title: post.group || "Publicación fan",
    caption: post.caption || post.text || "Experiencia fan compartida en HallyuHub.",
    user: post.user || "Hallyu fan",
    username: post.username || normalizeProfileKey(post.user),
    mediaUrl: post.mediaUrl || post.imageUrl || getDemoPostImage(index),
    thumbnail: post.thumbnail || post.coverUrl || post.imageUrl || post.mediaUrl || getDemoPostImage(index),
    likes: post.likes || "0",
    comments: post.comments || "0",
    status: post.fanContentStatus || post.moderationStatus || "publicado",
    taggedGroup: post.taggedGroup || post.group || post.groupId || "",
    taggedArtist: post.taggedArtist || post.taggedPeople || post.artistId || "",
    taggedShow: post.taggedShow || post.taggedPlace || "",
    city: post.city || post.location || "",
    eventDate: post.eventDate || "",
    hashtags: post.hashtags || [],
    createdAt: post.createdAt || new Date().toISOString(),
  }));
  const fancamItems = fancamVideos.map((fancam, index) => ({
    id: fancam.id,
    type: "fancam",
    mediaType: fancam.mediaType || "image",
    title: `${fancam.artist} fancam`,
    caption: fancam.description,
    user: fancam.user || state.user?.name || "Fan upload",
    username: fancam.username || state.user?.username || "fan",
    mediaUrl: fancam.mediaUrl || fancam.imageUrl || getDemoDropMedia(index),
    thumbnail: fancam.thumbnail || fancam.coverUrl || fancam.imageUrl || fancam.mediaUrl || getDemoDropMedia(index),
    likes: fancam.likes || "0",
    comments: fancam.comments || "0",
    status: fancam.fanContentStatus || fancam.moderationStatus || "publicado",
    taggedGroup: fancam.taggedGroup || fancam.group || "",
    taggedArtist: fancam.taggedArtist || fancam.artist || "",
    taggedShow: fancam.taggedShow || fancam.show || "",
    city: fancam.city || fancam.location || "",
    eventDate: fancam.eventDate || fancam.date || "",
    hashtags: fancam.hashtags || [],
    createdAt: fancam.createdAt || new Date().toISOString(),
  }));
  const dropItems = trendVideos.map((drop, index) => ({
    id: drop.id || getDropId(drop, index),
    type: "drop",
    mediaType: drop.mediaType || "image",
    title: drop.challenge || "Drop fan",
    caption: drop.description || "Drop creado por la comunidad.",
    user: drop.user || "Hallyu fan",
    username: drop.username || normalizeProfileKey(drop.user),
    mediaUrl: drop.mediaUrl || drop.imageUrl || drop.thumbnail || getDemoDropMedia(index),
    thumbnail: drop.thumbnail || drop.coverUrl || drop.imageUrl || drop.mediaUrl || getDemoDropMedia(index),
    likes: drop.likes || "0",
    comments: drop.comments || "0",
    status: drop.fanContentStatus || drop.moderationStatus || "publicado",
    taggedGroup: drop.taggedGroup || drop.group || drop.groupId || "",
    taggedArtist: drop.taggedArtist || drop.artist || drop.artistId || "",
    taggedShow: drop.taggedShow || "",
    city: drop.city || drop.location || "",
    eventDate: drop.eventDate || "",
    hashtags: drop.hashtags || [],
    createdAt: drop.createdAt || new Date().toISOString(),
  }));
  return [...postItems, ...fancamItems, ...dropItems]
    .filter((item) => !state.hiddenFanContent[item.id] && !state.mutedUsers[normalizeProfileKey(item.user)])
    .filter((item) => item.status !== "oculto" && item.status !== "eliminado")
    .filter((item) => {
      const haystack = normalizeProfileKey([
        item.title,
        item.caption,
        item.taggedGroup,
        item.taggedArtist,
        item.taggedShow,
        item.city,
        ...(item.hashtags || []),
      ].join(" "));
      const groupMatch = groupKey && (haystack.includes(groupKey) || haystack.includes(groupId) || haystack.includes(fandomKey));
      const artistMatch = artistKey && (haystack.includes(artistKey) || haystack.includes(artistId));
      return scope === "artist" ? artistMatch || groupMatch : groupMatch;
    })
    .sort((a, b) => getPostTimeValue(b) - getPostTimeValue(a));
}

function filterFanContent(content) {
  const filter = state.fanContentFilter || "recent";
  if (filter === "fancams") return content.filter((item) => item.type === "fancam" || item.mediaType === "video");
  if (filter === "photos") return content.filter((item) => item.mediaType === "image");
  if (filter === "shows") return content.filter((item) => item.taggedShow || item.city || item.eventDate);
  if (filter === "popular") return [...content].sort((a, b) => getEngagementNumber(b.likes) - getEngagementNumber(a.likes));
  return content;
}

function renderFanFancamTile(item) {
  const previewUrl = item.thumbnail || item.mediaUrl;
  return `
    <article class="fan-fancam-tile">
      <img src="${escapeAttr(previewUrl)}" alt="${escapeAttr(item.title)}" loading="lazy" />
      <div>
        <strong>${escapeHtml(item.title)}</strong>
        <small>${escapeHtml(item.taggedShow || item.city || "Fan upload")} · ${escapeHtml(item.status)}</small>
      </div>
      <div class="fan-safety-actions compact">
        <button data-report-content="${item.type}:${item.id}">Reportar</button>
        <button data-report-content="copyright:${item.id}">Copyright</button>
        <button data-hide-fan-content="${item.id}">Ocultar</button>
      </div>
    </article>
  `;
}

function renderFanPhotoTile(item) {
  const previewUrl = item.thumbnail || item.mediaUrl;
  return `
    <article class="fan-photo-tile">
      <img src="${escapeAttr(previewUrl)}" alt="${escapeAttr(item.title)}" loading="lazy" />
      <span>${escapeHtml(item.status)}</span>
      <div class="fan-photo-actions">
        <button data-report-content="${item.type}:${item.id}">Reportar</button>
        <button data-report-content="copyright:${item.id}">Copyright</button>
      </div>
    </article>
  `;
}

function renderFanFeedCard(item) {
  const previewUrl = item.thumbnail || item.mediaUrl;
  return `
    <article class="fan-feed-card">
      <img src="${escapeAttr(previewUrl)}" alt="${escapeAttr(item.title)}" loading="lazy" />
      <div>
        <div class="fan-feed-head">
          <strong>${escapeHtml(item.user)}</strong>
          <span>${escapeHtml(formatRelativeTime(item.createdAt))}</span>
        </div>
        <p>${escapeHtml(item.caption)}</p>
        <div class="fan-meta-line">
          ${item.taggedGroup ? `<span>${escapeHtml(item.taggedGroup)}</span>` : ""}
          ${item.taggedArtist ? `<span>${escapeHtml(item.taggedArtist)}</span>` : ""}
          ${item.taggedShow ? `<span>${escapeHtml(item.taggedShow)}</span>` : ""}
          ${item.city ? `<span>${escapeHtml(item.city)}</span>` : ""}
        </div>
        <div class="fan-safety-actions">
          <button data-report-content="${item.type}:${item.id}">Reportar</button>
          <button data-report-content="copyright:${item.id}">Reportar copyright</button>
          <button data-hide-fan-content="${item.id}">Ocultar</button>
          <button data-block-fan-user="${escapeAttr(item.username || item.user)}">Bloquear usuario</button>
        </div>
      </div>
    </article>
  `;
}

function getArtistPhotos(artist, group) {
  return [
    {
      title: `${artist.name} perfil`,
      imageUrl: artist.imageUrl,
      sourceCredit: artist.sourceCredit,
      license: artist.license,
      sourceUrl: artist.sourceUrl,
    },
    {
      title: `${group.name} portada`,
      imageUrl: group.coverUrl || group.imageUrl,
      sourceCredit: group.sourceCredit,
      license: group.license,
      sourceUrl: group.sourceUrl,
    },
    {
      title: "Placeholder autorizado",
      imageUrl: localVisuals.idolCard,
      sourceCredit: placeholderCredit.sourceCredit,
      license: placeholderCredit.license,
      sourceUrl: "",
    },
  ];
}

function getArtistVideos(artist, group) {
  const artistKey = normalizeProfileKey(artist.name);
  return officialVideoEmbeds
    .filter((video) => video.artistId === artist.id || video.groupId === group.id || normalizeProfileKey(video.artist).includes(artistKey))
    .slice(0, 4);
}

function getArtistOfficialLinks(artist, group) {
  const base = artist.socials || group.officialLinks || [];
  const required = [
    ["YouTube oficial", artist.youtubeUrl || group.youtubeUrl],
    ["Instagram oficial", artist.instagramUrl || group.instagramUrl],
    ["TikTok oficial", artist.tiktokUrl || group.tiktokUrl],
    ["Weverse oficial", artist.weverseUrl || group.weverseUrl],
    ["Spotify oficial", artist.spotifyUrl || group.spotifyUrl],
  ].filter(([, url]) => url);
  const seen = new Set();
  return [...base, ...required].filter(([label, url]) => {
    const key = normalizeProfileKey(`${label}-${url}`);
    if (!url || seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function renderArtistPhotoTile(photo) {
  return `
    <article class="artist-photo-tile">
      <img src="${escapeAttr(photo.imageUrl || localVisuals.idolCard)}" alt="${escapeAttr(photo.title)}" loading="lazy" />
      <div>
        <strong>${escapeHtml(photo.title)}</strong>
        <small>${escapeHtml(photo.license || "Licencia pendiente")}</small>
        ${photo.sourceUrl ? `<a href="${escapeAttr(photo.sourceUrl)}" target="_blank" rel="noopener noreferrer">Crédito</a>` : `<span>${escapeHtml(photo.sourceCredit || "Placeholder")}</span>`}
      </div>
    </article>
  `;
}

function renderArtistVideoTile(video) {
  return `
    <article class="artist-video-tile">
      <button type="button" data-open-artist-video="${escapeAttr(video.youtubeId)}">
        <img src="${escapeAttr(video.thumbnail)}" alt="${escapeAttr(video.title)}" loading="lazy" />
        <span>▶</span>
      </button>
      <div>
        <strong>${escapeHtml(video.title)}</strong>
        <small>${escapeHtml(video.source)}</small>
      </div>
      <button class="tag" type="button" data-report-content="copyright:${escapeAttr(video.youtubeId)}">Reportar copyright</button>
    </article>
  `;
}

function renderArtistFancams(artist) {
  const artistFancams = getFilteredFancams(artist.id);
  return `
    <section class="artist-fancams-section">
      <div class="section-heading small"><h2>Fancams</h2><span>${artistFancams.length || "Próximamente"}</span></div>
      ${
        artistFancams.length
          ? `<div class="artist-fancam-row">${artistFancams.map((fancam, index) => renderArtistFancamTile(fancam, index)).join("")}</div>`
          : `<article class="settings-demo-box">Todavia no hay fancams cargadas para ${escapeHtml(artist.name)}.</article>`
      }
    </section>
  `;
}

function renderArtistFancamTile(fancam, index = 0) {
  return `
    <article class="artist-fancam-tile" style="--art:${fancam.colors}">
      ${fancam.mediaUrl ? `<img src="${escapeAttr(fancam.mediaUrl)}" alt="Preview fancam ${escapeAttr(fancam.artist)}" />` : ""}
      <div>
        <strong>${escapeHtml(fancam.show)}</strong>
        <small>${escapeHtml(fancam.views)} vistas · ${escapeHtml(fancam.likes)} likes</small>
        <span>${escapeHtml(fancam.date)}</span>
      </div>
      <button data-open-artist-fancams="${fancam.artistId}">Reproducir</button>
    </article>
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
              <button class="ghost-button" data-go-view="messages">Ver chat</button>
              <button class="ghost-button" data-go-view="events">Eventos</button>
              <button class="ghost-button" data-demo-action="Moderadores visibles en modo demo">Moderadores</button>
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
    <button class="primary-button" data-demo-action="Solicitud enviada para crear grupo local">Solicitar grupo de mi ciudad</button>
  `;
}

function renderMessages() {
  const storyChats = (state.storyInbox || []).map((item) => ({
    name: item.to,
    last: `${item.from || state.user?.name || "Tú"}: ${item.message}`,
    time: item.time || "Ahora",
    status: item.status || "Historia",
    avatarUrl: getDemoUser(item.to).avatarUrl,
  }));
  const allConversations = [...storyChats, ...conversations];
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
            ${renderAvatarElement("mini", "berry", request.avatarUrl)}
            <div>
              <h3>${request.name}</h3>
              <p class="muted">${request.note}</p>
              <span class="tag">${request.shared}</span>
            </div>
            <div class="request-actions">
              <button class="ghost-button" data-demo-action="Solicitud rechazada">Rechazar</button>
              <button class="ghost-button accept" data-demo-action="Solicitud aceptada">Aceptar</button>
            </div>
          </article>`,
        )
        .join("")}
    </div>
    <div class="section-heading"><h2>Chats</h2><span>Aceptados</span></div>
    <div class="chat-list">
      ${allConversations
        .map(
          (chat, index) => `
          <article class="dm-card">
            ${renderAvatarElement("mini", "berry", chat.avatarUrl)}
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
      ${renderAvatarElement("hero", activeAvatar.id, state.settingsAvatarPreviewUrl || state.user.avatarUrl || getDemoUserImage(0))}
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
        { key: "notif-trends", label: "Drops", detail: "Challenges y eventos", icon: "▶" },
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
        { key: "legal-moderation", label: "Moderación legal", detail: "Reportes y acciones admin", icon: "MD" },
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
    "legal-moderation": "Moderación legal",
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
              ${renderAvatarElement("pick", avatar.id, getDemoUserImage(getStableAssetIndex(avatar.id, DEMO_USER_IMAGES.length)))}
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
  if (panel === "delete-account") return `<p class="muted">Esta pantalla demo muestra la opcion visible para eliminar cuenta, requerida para apps con usuarios.</p><button class="ghost-button danger-button" data-demo-action="Solicitud de eliminacion enviada">Solicitar eliminacion de cuenta</button>`;
  if (panel === "report-problem") return `<div class="form-stack"><label>Describe el problema<textarea>Quiero reportar contenido o usuario...</textarea></label></div><button class="primary-button" data-demo-action="Reporte enviado">Enviar reporte demo</button>`;
  if (panel === "legal-moderation") return renderLegalModerationPanel();
  const legalText = {
    "privacy-policy": "Explicamos que HallyuHub protege datos personales, usa localStorage en modo demo y luego Supabase para sesiones reales.",
    terms: "El usuario es responsable del contenido que sube a HallyuHub. HallyuHub puede remover contenido reportado o que infrinja derechos, normas de comunidad o leyes aplicables.",
    "community-rules": "Normas: cuidar a fans menores, no doxxing, no bullying, no ventas inseguras y reportar contenido riesgoso.",
    copyright: "Si sos dueño del contenido y creés que se publicó sin autorización, podés reportarlo. HallyuHub revisará reportes de copyright y podrá ocultar, remover o restringir contenido en modo real.",
    "fan-policy": "Contenido fan permitido si respeta creditos, privacidad, derechos y normas de comunidad. No se alojan canciones completas protegidas: se usan previews seguros, audios propios, audio de usuarios o links externos.",
    "payment-methods": "Metodo de pago demo: tarjeta terminada en 4242. No se procesa dinero real.",
    "payment-history": "Historial demo: HallyuHub Plus - pendiente de activar.",
    "cancel-subscription": "Puedes cancelar la suscripcion demo en cualquier momento desde esta pantalla.",
  };
  return `<p class="muted">${legalText[panel] || "Configuracion demo lista para conectarse a funciones reales mas adelante."}</p><div class="settings-demo-box">Pantalla funcional demo sin acciones reales todavia.</div>`;
}

function renderLegalModerationPanel() {
  const reports = state.socialReports || [];
  const demoReports = reports.length
    ? reports
    : [
        { id: "demo-report-post", targetType: "post", targetId: "demo", user: "Demo user", reason: "Copyright", status: "pendiente", createdAt: new Date().toISOString() },
        { id: "demo-report-fancam", targetType: "fancam", targetId: "fc-jungkook-seven", user: "Fancam demo", reason: "Contenido ofensivo", status: "pendiente", createdAt: new Date().toISOString() },
      ];
  const counts = ["post", "fancam", "comment", "profile"].map((type) => [type, demoReports.filter((report) => report.targetType === type).length]);
  return `
    <section class="legal-moderation-panel">
      <p class="muted">Sistema demo/admin para revisar contenido reportado antes de conectar un panel real.</p>
      <div class="moderation-stats">
        ${counts.map(([type, count]) => `<span><strong>${count}</strong>${type}</span>`).join("")}
      </div>
      <div class="moderation-report-list">
        ${demoReports
          .map(
            (report) => `
            <article>
              <div>
                <span class="tag">${escapeHtml(report.targetType || "contenido")}</span>
                <strong>${escapeHtml(report.reason || "Otro")}</strong>
                <small>${escapeHtml(report.user || report.targetId || "Usuario")} · ${escapeHtml(report.status || "pendiente")}</small>
              </div>
              <div class="moderation-actions">
                <button data-admin-action="ocultar:${report.id}">Ocultar</button>
                <button data-admin-action="eliminar:${report.id}">Eliminar</button>
                <button data-admin-action="advertir:${report.id}">Advertir</button>
                <button data-admin-action="suspender:${report.id}">Suspender</button>
              </div>
            </article>`,
          )
          .join("")}
      </div>
    </section>
  `;
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
              <button class="ghost-button" data-demo-action="Solicitud enviada al mentor">Pedir consejo</button>
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
          <div class="profile-title-line"><h1>${profileUser.name}</h1><span class="verified-badge">${isPlus ? "Plus" : avatarMeta.rarity}</span></div>
          <p class="profile-handle-line">@${profileUser.username} · ${profileUser.country || "Chile 🇨🇱"}</p>
          <p class="profile-bio-line">${profileUser.bio || profileUser.phrase || "Fan K-pop en HallyuHub."}</p>
        </div>
      </div>
      <div class="premium-stats compact-profile-stats" aria-label="Estadísticas del perfil">
        <div><strong>${profileUser.posts}</strong><span>posts</span></div>
        <div><strong>${profileUser.followers}</strong><span>seguidores</span></div>
        <div><strong>${profileUser.following}</strong><span>siguiendo</span></div>
        <div><strong>${profileUser.starsReceived || "32.8K"}</strong><span>estrellas</span></div>
      </div>
      <div class="profile-fandom-strip" aria-label="Datos fandom">
        <span>${profileUser.fandom || "ARMY 💜"}</span>
        <span>Bias: ${profileUser.bias || "Jungkook"}</span>
        <span>${profileUser.favoriteGroup || "BTS"}</span>
        <span>Level ${progress.level}</span>
        <span>${isPlus ? "Plus" : avatarMeta.rarity}</span>
      </div>
      <div class="profile-progress-card compact-level-card" aria-label="Nivel fandom">
        <div>
          <span>Nivel fandom ${progress.level}</span>
          <strong>${avatarMeta.name} · ${avatarMeta.rarity}</strong>
          <small>${progress.stars.toLocaleString("es")} estrellas para desbloquear estilo</small>
        </div>
        <div class="progress-ring" style="--progress:${progress.percent}%"><span></span></div>
      </div>
      <div class="premium-profile-actions ${isOwnProfile ? "own-actions" : "other-actions"}">
        ${
          isOwnProfile
            ? `<button class="primary-button profile-create-action" data-go-view="publish" aria-label="Crear publicacion"><span class="nav-icon plus-icon"></span><span>Crear</span></button>
               <button class="ghost-button profile-edit-action" data-profile-edit-open>Editar perfil</button>`
            : `<button class="primary-button profile-main-action" data-profile-follow="${profileUser.id || profileUser.username}">${isFollowing ? "Siguiendo" : "Seguir"}</button>
               <button class="ghost-button profile-share-action" data-demo-action="Perfil listo para compartir">Compartir perfil</button>
               <button class="ghost-button profile-report-action" data-report-content="profile:${profileUser.id || profileUser.username}">Reportar</button>`
        }
      </div>
    </section>
    <section class="highlight-row profile-highlight-row">
      ${profileHighlights
        .map(
          (item, index) => `
          <button data-demo-action="Historia destacada abierta" style="--art:${art[index % art.length]}">
            <span class="highlight-orb"></span>
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
    <section class="profile-editor-card edit-profile">
      <button class="ghost-button back-button" data-profile-edit-close>Volver al perfil</button>
      <div class="profile-edit-cover" style="--profile-bg:${getProfileBackground(state.selectedProfileBg || state.user.profileBg).art}">
        ${renderAvatarElement(`profile-avatar premium-avatar edit-avatar ${getRarityClass(activeAvatar)}`, state.selectedAvatar || state.user.avatar, state.profileAvatarPreviewUrl || state.user.avatarUrl)}
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
              ${renderAvatarElement("pick", avatar.id, getDemoUserImage(getStableAssetIndex(avatar.id, DEMO_USER_IMAGES.length)))}
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
  if (tab === "archive") return renderStoryArchive(profileUser, ownUser);
  if (tab === "saved") {
    const savedFeed = userPosts.filter((post) => state.savedPosts[post.id] || state.savedPosts[getBasePostId(post.id)]);
    if (savedFeed.length) return savedFeed.map((post, index) => renderSocialPost(post, index, { compact: true })).join("");
  }
  const localPosts = ownUser ? userPosts.filter((post) => (post.category || "posts") === tab) : [];
  const posts = localPosts.length ? localPosts : getProfileDemoPosts(tab, profileUser);
  return posts.map((post, index) => renderSocialPost(post, index, { compact: true })).join("");
}

function renderStoryArchive(profileUser, ownUser) {
  const items = ownUser ? state.storyArchive || [] : [];
  if (!ownUser) return `<article class="settings-demo-box">El archivo de historias es privado.</article>`;
  if (!items.length) {
    return `<article class="settings-demo-box">Todavía no hay historias archivadas. Cuando subas una historia, aparecerá acá.</article>`;
  }
  return `
    <section class="story-archive-panel">
      <div class="section-heading small"><h2>Archivo</h2><span>${items.length} historias</span></div>
      <div class="story-archive-grid">
        ${items
          .map((item) => {
            const date = formatArchiveDate(item.createdAt);
            const thumb = item.thumbnail || item.mediaUrl || getDemoStoryImage(getStableAssetIndex(item.id, DEMO_STORY_IMAGES.length));
            return `
              <article class="story-archive-card">
                <div class="story-archive-thumb">
                  ${
                    item.mediaType === "video"
                      ? `<video src="${escapeAttr(item.mediaUrl)}" muted playsinline preload="metadata"></video>`
                      : `<img src="${escapeAttr(thumb)}" alt="Historia archivada" loading="lazy" />`
                  }
                  <span>${item.mediaType === "video" ? "Video" : "Foto"}</span>
                </div>
                <div>
                  <strong>${date}</strong>
                  <small>${escapeHtml(item.music || "HallyuHub story")}</small>
                </div>
                <button type="button" data-story-reshare="${escapeAttr(item.id)}">Compartir otra vez</button>
              </article>`;
          })
          .join("")}
      </div>
    </section>
  `;
}

function formatArchiveDate(date) {
  try {
    return new Intl.DateTimeFormat("es-AR", { day: "2-digit", month: "short", year: "numeric" }).format(new Date(date));
  } catch {
    return "Fecha pendiente";
  }
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
      { ...common, id: "profile-trend-1", category: "trends", group: "Drop", time: "hace 1 h", caption: "Paso corto para un random play dance con transicion de luz neon.", hashtags: ["#DanceChallenge", "#Drops"], taggedPeople: "@mika, @vale" },
      { ...common, id: "profile-trend-2", category: "trends", group: "Drop", time: "hace 3 h", caption: "Mini cover inspirado en stage idol, pensado para grabar vertical.", hashtags: ["#cover", "#fancam"] },
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

setupSwipeNavigation();
setupMobileInputZoomGuard();
initApp();
