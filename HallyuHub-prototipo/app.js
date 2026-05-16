const state = {
  view: "home",
  communityTab: "global",
  selectedAvatar: "berry",
  ambience: "hallyu",
  selectedGroup: "skz",
};

const titleByView = {
  home: "Tu universo K-pop latino",
  events: "Eventos fandom",
  market: "Marketplace oficial",
  news: "Noticias actuales",
  groups: "Grupos e idols",
  community: "Comunidades latinas",
  rookie: "Me quiero meter al K-pop",
  messages: "Mensajes privados",
  profile: "Perfil",
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
    group: "Stray Kids",
    title: "Nueva era visual: comeback con teaser cinematografico",
    meta: "12.8K likes · 846 comentarios",
    tag: "Trending",
  },
  {
    group: "NewJeans",
    title: "Fans latinas organizan streaming party nocturna",
    meta: "8.4K likes · LATAM",
    tag: "Fandom",
  },
  {
    group: "SEVENTEEN",
    title: "Guia rapida para votar en premios semanales",
    meta: "4.1K guardados · Tutorial",
    tag: "Guia",
  },
];

const userPosts = [
  {
    user: "Luna Hallyu",
    group: "STAY Chile",
    caption: "Mi setup para ver el comeback con amigas. Ya tengo snacks, light stick y playlist lista.",
    likes: "2.4K",
    comments: "188",
  },
  {
    user: "Cami.STAY",
    group: "Buenos Aires",
    caption: "Intercambio de photocards en Palermo. Solo trades con referencias y entrega segura.",
    likes: "918",
    comments: "64",
  },
  {
    user: "Vale Multi",
    group: "K-pop 101",
    caption: "Mini guia para elegir tu primer grupo: empieza por 3 canciones, 1 live stage y 1 entrevista.",
    likes: "4.8K",
    comments: "301",
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
    gradient: "linear-gradient(145deg, #ffd6eb, #fbbcdb 46%, #a855f7)",
  },
  {
    id: "star",
    name: "Star Seoul",
    mood: "Neon, escenico y perfecto para fans de performance.",
    gradient: "linear-gradient(145deg, #fff7b3, #65e4ff 42%, #a855f7)",
  },
  {
    id: "mochi",
    name: "Mochi Beat",
    mood: "Suave, pastel y coleccionista de photocards.",
    gradient: "linear-gradient(145deg, #fff1f9, #77f4c7 44%, #d946ef)",
  },
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

function setView(nextView) {
  state.view = nextView;
  document.querySelectorAll(".nav-item").forEach((button) => {
    button.classList.toggle("active", button.dataset.view === nextView);
  });
  const appScreen = document.querySelector(".app-screen");
  appScreen.classList.toggle("profile-mode", nextView === "profile");
  appScreen.dataset.ambience = state.ambience;
  document.getElementById("screen-title").textContent = titleByView[nextView];
  render();
}

function render() {
  const view = document.getElementById("view");
  document.querySelector(".app-screen").dataset.ambience = state.ambience;
  const templates = {
    home: renderHome,
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
}

function bindDynamicActions() {
  document.querySelectorAll("[data-community-tab]").forEach((button) => {
    button.addEventListener("click", () => {
      state.communityTab = button.dataset.communityTab;
      render();
    });
  });

  document.querySelectorAll("[data-avatar]").forEach((button) => {
    button.addEventListener("click", () => {
      state.selectedAvatar = button.dataset.avatar;
      render();
    });
  });

  document.querySelectorAll("[data-ambience]").forEach((button) => {
    button.addEventListener("click", () => {
      state.ambience = button.dataset.ambience;
      render();
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

function renderHome() {
  return `
    <article class="hero-card">
      <div class="pill">Hot comeback · LATAM</div>
      <h2>HallyuHub social</h2>
      <p>Publicaciones, fandoms, grupos favoritos y actualidad K-pop para fans latinos.</p>
    </article>
    <div class="quick-grid compact">
      <div class="quick-tile"><strong>42</strong><span>eventos activos</span></div>
      <div class="quick-tile"><strong>128K</strong><span>fans conectados</span></div>
      <div class="quick-tile"><strong>24h</strong><span>drops nuevos</span></div>
    </div>
    <button class="news-cta" data-go-view="news">
      <span>Actualidad K-pop</span>
      <strong>Entrar a noticias destacadas</strong>
    </button>
    <div class="section-heading"><h2>Publicaciones</h2><span>Siguiendo</span></div>
    <div class="social-feed">
      ${userPosts
        .map(
          (post, index) => `
          <article class="post-card">
            <div class="post-head">
              <div class="plush-avatar mini" style="--avatar:${avatars[index % avatars.length].gradient}"><span></span></div>
              <div><h3>${post.user}</h3><p class="muted">${post.group}</p></div>
            </div>
            <div class="post-media" style="--art:${art[index % art.length]}"></div>
            <p>${post.caption}</p>
            <div class="post-actions"><span>Me gusta ${post.likes}</span><span>${post.comments} comentarios</span><span>Compartir</span></div>
          </article>`,
        )
        .join("")}
    </div>
  `;
}

function renderNews() {
  return `
    <button class="ghost-button back-button" data-go-view="home">Volver al inicio</button>
    <article class="hero-card">
      <div class="pill">Actualidad</div>
      <h2>Noticias destacadas de hoy</h2>
      <p>Un espacio pensado para conectarse despues a fuentes oficiales, agencias y fanbases verificadas.</p>
    </article>
    <div class="section-heading"><h2>Trending ahora</h2><span>En vivo</span></div>
    <div class="news-list">
      ${news
        .map(
          (item, index) => `
          <article class="glass-card news-card">
            <div class="cover-art" style="--art:${art[index]}"></div>
            <div>
              <span class="tag">${item.tag}</span>
              <h3 class="card-title">${item.title}</h3>
              <div class="meta-row"><strong>${item.group}</strong><span>${item.meta}</span></div>
            </div>
          </article>`,
        )
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
  const activeAvatar = avatars.find((avatar) => avatar.id === state.selectedAvatar) || avatars[0];
  const activeAmbience = ambiences.find((ambience) => ambience.id === state.ambience) || ambiences[0];
  return `
    <section class="profile-cover">
      <div class="plush-avatar hero" style="--avatar:${activeAvatar.gradient}">
        <span></span>
      </div>
      <div>
        <p class="eyebrow">Perfil de fan</p>
        <h1>Luna Hallyu</h1>
        <p class="muted">STAY · ARMY · Santiago, Chile</p>
      </div>
    </section>
    <div class="stats-row">
      <div class="stat"><strong>286</strong><span>photocards</span></div>
      <div class="stat"><strong>8.7K</strong><span>seguidores</span></div>
      <div class="stat"><strong>12K</strong><span>puntos fan</span></div>
    </div>
    <div class="profile-actions">
      <button class="primary-button">Seguir</button>
      <button class="ghost-button">Siguiendo</button>
    </div>
    <section class="profile-panel">
      <div class="section-heading"><h2>Ajustes de perfil</h2><span>Desbloqueos</span></div>
      <div class="unlock-note">Mientras mas seguidores tenga el usuario, mas avatares y ambientes especiales puede desbloquear.</div>
      <div class="section-heading small"><h2>Ambiente de app</h2><span>${activeAmbience.group}</span></div>
      <p class="muted">${activeAmbience.detail}</p>
      <div class="ambience-grid">
        ${ambiences
          .map(
            (ambience) => `
            <button class="ambience-choice ${state.ambience === ambience.id ? "active" : ""}" data-ambience="${ambience.id}">
              <span class="ambience-preview ${ambience.id}"></span>
              <strong>${ambience.name}</strong>
              <small>${ambience.group}</small>
            </button>`,
          )
          .join("")}
      </div>
      <div class="section-heading small"><h2>Mi avatar</h2><span>${activeAvatar.name}</span></div>
      <p class="muted">${activeAvatar.mood}</p>
      <div class="avatar-picker">
        ${avatars
          .map(
            (avatar) => `
            <button class="avatar-choice ${state.selectedAvatar === avatar.id ? "active" : ""}" data-avatar="${avatar.id}" aria-label="Elegir ${avatar.name}">
              <div class="plush-avatar pick" style="--avatar:${avatar.gradient}">
                <span></span>
              </div>
              <strong>${avatar.name}</strong>
            </button>`,
          )
          .join("")}
      </div>
    </section>
    <section class="profile-panel">
      <div class="section-heading"><h2>Mis carpetas</h2><span>Privacidad</span></div>
      <div class="folder-grid">
        ${profileFolders
          .map(
            (folder) => `
            <article class="folder-card">
              <div class="folder-tab"></div>
              <strong>${folder.title}</strong>
              <span>${folder.count} items</span>
              <p>${folder.detail}</p>
            </article>`,
          )
          .join("")}
      </div>
    </section>
    <section class="profile-panel">
      <div class="section-heading"><h2>Mis grupos top</h2><span>Editar</span></div>
      <div class="bias-row">
        <div class="bias-card"><strong>SKZ</strong><span class="muted">Bias: Felix</span></div>
        <div class="bias-card"><strong>BTS</strong><span class="muted">Bias: Jimin</span></div>
        <div class="bias-card"><strong>IVE</strong><span class="muted">Bias: Rei</span></div>
      </div>
    </section>
    <section class="profile-panel">
      <div class="section-heading"><h2>Fotos</h2><span>Visible para seguidores</span></div>
      <div class="profile-photo-grid">
        ${profilePhotos
          .map(
            (photo, index) => `<div class="profile-photo" style="--art:${art[index % art.length]}">${photo}</div>`,
          )
          .join("")}
      </div>
    </section>
  `;
}

document.querySelectorAll(".nav-item").forEach((button) => {
  button.addEventListener("click", () => setView(button.dataset.view));
});

render();
