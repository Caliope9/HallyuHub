const hallyuHubLegalVersion = '2026-09-08-v1';

const legalOwnerName = 'HallyuHub';
const supportEmail = 'soporte@hallyuhub.net';
const minimumBetaAge = 16;
const publicAccessUrl = 'https://www.hallyuhub.net/acceso';
const publicAppUrl = 'https://www.hallyuhub.net';

const hallyuHubOperatorNotice =
    'El responsable del servicio es $legalOwnerName. Para consultas, soporte o reclamos, podés contactarnos en: $supportEmail.';
const hallyuHubBetaAgeNotice =
    'HallyuHub es para personas de $minimumBetaAge años o más. La edad se verifica mediante fecha de nacimiento: 15 o menos no puede crear una cuenta; 16 y 17 sí pueden participar con protecciones reforzadas. No habilitamos menores de 16 mediante un checkbox parental.';
const hallyuHubBetaAgeCheckboxLabel =
    'Declaro que tengo $minimumBetaAge años o más y que la fecha de nacimiento ingresada es correcta.';
const hallyuHubBetaAgeValidationMessage =
    'Para crear tu cuenta necesitás confirmar que tenés 16 años o más y completar tu fecha de nacimiento.';
const hallyuHubCopyrightNotice =
    '© 2026 HallyuHub. Todos los derechos reservados.';
const hallyuHubBrandNotice =
    'HallyuHub es una marca de la plataforma. Su uso no autorizado no está permitido.';

class LegalDocument {
  const LegalDocument({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.paragraphs,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<String> paragraphs;
}

const legalTermsDocument = LegalDocument(
  id: 'terms',
  title: 'Términos y condiciones',
  subtitle: 'Reglas base para usar HallyuHub en acceso anticipado.',
  paragraphs: [
    hallyuHubOperatorNotice,
    hallyuHubBetaAgeNotice,
    'HallyuHub es una comunidad digital para fans de K-pop y cultura fandom. Al usar la app aceptás crear una cuenta real, cuidar tus credenciales y usar las funciones sociales de forma responsable.',
    'Podés publicar posts, stories, drops, fancams, comentarios, mensajes y contenido de colección siempre que tengas derecho a compartirlo o sea contenido propio. No publiques material privado, filtrado, robado, sexualizado de menores, violento, fraudulento o que pueda poner en riesgo a otra persona.',
    'Propiedad intelectual: HallyuHub, su nombre, identidad visual, diseño, interfaz, estructura, funcionalidades, textos, elementos gráficos y código pertenecen a HallyuHub o a sus titulares correspondientes. El uso de la plataforma no transfiere derechos de propiedad intelectual a los usuarios.',
    hallyuHubBrandNotice,
    'Contenido de usuarios: los usuarios conservan los derechos sobre el contenido que suben a HallyuHub. Al publicar contenido, autorizan a HallyuHub a almacenarlo, mostrarlo, reproducirlo técnicamente y distribuirlo dentro de la plataforma para el funcionamiento normal de la app.',
    'El usuario declara que cuenta con los derechos, permisos o autorizaciones necesarias para subir el contenido que publica.',
    'No está permitido subir contenido que infrinja derechos de autor, derechos de imagen, privacidad o derechos de terceros. Si una persona o titular de derechos considera que un contenido vulnera sus derechos, podrá reportarlo desde la app o comunicarse con soporte.',
    'Los usuarios pueden reportar contenido, perfiles, mensajes o problemas técnicos desde la app. HallyuHub puede revisar reportes, ocultar o retirar contenido y limitar interacciones mediante las herramientas disponibles cuando sea necesario para la seguridad de la plataforma.',
    'Las compras, trades, ventas, eventos y meetups todavía son funciones consultivas o comunitarias. HallyuHub no procesa pagos reales durante el acceso anticipado y no garantiza acuerdos entre usuarios.',
    'Estos términos se rigen por las leyes de la República Argentina, sin perjuicio de los derechos que pudieran corresponder a los usuarios según normas aplicables de su país de residencia.',
    'Si no aceptás estos términos, no debés usar HallyuHub. Podés cerrar sesión y solicitar eliminación de cuenta desde Ajustes, en la página pública de eliminación o por contacto de soporte.',
    hallyuHubCopyrightNotice,
  ],
);

const legalPrivacyDocument = LegalDocument(
  id: 'privacy',
  title: 'Política de privacidad',
  subtitle:
      'Datos usados para operar tu cuenta y mantener seguro el acceso anticipado.',
  paragraphs: [
    hallyuHubOperatorNotice,
    'HallyuHub puede recolectar y procesar datos como email, nickname, nombre visible, país, región, ciudad opcional, fandom principal, avatar, plataforma o dispositivo, información técnica básica, contenido subido por el usuario, reportes, bugs, sugerencias y datos de uso necesarios para funcionamiento, seguridad y mejora de la app.',
    'Usamos esos datos para crear y administrar cuentas, operar la comunidad, gestionar el acceso anticipado y la lista de espera, mostrar contenido dentro de la app, moderar contenido, responder reportes, corregir errores, mejorar funciones, prevenir abuso, spam o uso indebido y cumplir obligaciones legales si corresponde.',
    'No vendemos datos personales de usuarios.',
    'El contenido que publicás puede ser visible para otros usuarios según tu configuración y el tipo de contenido. Los mensajes privados solo deben ser visibles para integrantes de la conversación, salvo controles técnicos y moderación necesaria ante reportes o abuso.',
    'La ubicación es opcional. No pedimos dirección exacta para el perfil público. Podés mostrar solo país, ciudad o ocultar la ubicación pública según la configuración disponible.',
    'Usamos Supabase como proveedor técnico para autenticación, base de datos y almacenamiento. No usamos GPS, OpenAI, publicidad ni analytics activos en esta versión.',
    'Los datos se conservan durante el tiempo necesario para prestar HallyuHub, gestionar la cuenta, prevenir abuso o fraude y cumplir obligaciones legales aplicables. Al solicitar la eliminación, se eliminan la cuenta y los datos asociados, salvo la conservación limitada que resulte necesaria por seguridad, fraude u obligación legal.',
    'Contacto y soporte: $supportEmail.',
    hallyuHubCopyrightNotice,
  ],
);

const legalCommunityGuidelinesDocument = LegalDocument(
  id: 'community',
  title: 'Normas de comunidad',
  subtitle: 'Convivencia fandom, seguridad y respeto.',
  paragraphs: [
    'HallyuHub debe ser un espacio seguro para fans de 16 años o más. No se permite acoso, amenazas, discriminación, doxxing, suplantación, estafas, spam, manipulación, sexualización de menores ni difusión de datos privados.',
    'Está prohibido publicar o solicitar contenido sexual explícito, explotación sexual, gore extremo o violencia gráfica extrema. Los casos dudosos pueden quedar ocultos y pasar a revisión humana.',
    'Las cuentas de 16–17 años son privadas por defecto y tienen mensajes, stories, descubrimiento y contacto más restrictivos. Estas protecciones no se pueden desactivar para eludir la seguridad.',
    'Respeta a otros fans, idols, artistas, crews, comunidades y organizadores. Las discusiones son válidas, pero no se toleran ataques personales, persecución, humillación o incitación al odio.',
    'Publicá fancams, edits, covers, fanart y contenido de colección con respeto por créditos, privacidad y derechos. Evitá subir canciones completas, filtraciones, material pago redistribuido o contenido de terceros sin permiso.',
    'Los usuarios pueden reportar contenido, perfiles, mensajes o problemas técnicos desde la app. Las categorías de reporte pueden incluir copyright, privacidad, imagen personal, contenido no autorizado, suplantación, acoso, spam u otro motivo relevante.',
    'Durante el acceso anticipado, los reportes de errores y problemas técnicos son especialmente importantes para seguir mejorando la app.',
    'Las medidas pueden incluir advertencias, ocultar contenido, restringir interacciones, suspensiones temporales o bans. Los reportes humanos se priorizan según riesgo y urgencia.',
    hallyuHubCopyrightNotice,
  ],
);

const legalBetaNoticeDocument = LegalDocument(
  id: 'beta_notice',
  title: 'Aviso de acceso anticipado',
  subtitle: 'HallyuHub está disponible para sus primeros usuarios.',
  paragraphs: [
    hallyuHubBetaAgeNotice,
    'HallyuHub está disponible en acceso anticipado y puede recibir mejoras durante esta etapa. Algunas funciones pueden evolucionar o tener disponibilidad limitada mientras cuidamos la estabilidad y la experiencia de la comunidad.',
    'La primera ola de acceso anticipado podrá estar limitada por cupos para cuidar la estabilidad de la app y la experiencia de la comunidad.',
    'Si encontrás errores como videos sin sonido, problemas de carga, fallas al subir contenido o funciones que no responden, reportalos desde Ajustes → Reportar problema o desde el botón “¿Algo no funciona?” cuando esté disponible.',
    'No uses el acceso anticipado para información sensible, pagos reales, acuerdos comerciales definitivos o contenido que no puedas perder. Antes de ampliar el acceso, se reforzarán moderación, soporte, backups, políticas finales y controles de tienda.',
    'Contacto y soporte: $supportEmail.',
    hallyuHubCopyrightNotice,
  ],
);

const legalContactDocument = LegalDocument(
  id: 'contact',
  title: 'Contacto legal y soporte',
  subtitle: 'Canales preparados para reportes y solicitudes.',
  paragraphs: [
    hallyuHubOperatorNotice,
    'Para reportar abuso, privacidad, copyright, seguridad, suplantación o problemas graves, usá las opciones de reporte dentro de la app cuando estén disponibles.',
    'También podés escribir a soporte para solicitudes legales, privacidad, eliminación de cuenta o reclamos de contenido.',
    'Incluí tu username, email de cuenta, enlace o captura del contenido, motivo del reporte y cualquier dato necesario para revisar el caso. No envíes contraseñas ni datos sensibles innecesarios.',
    hallyuHubCopyrightNotice,
  ],
);

const legalCopyrightDocument = LegalDocument(
  id: 'copyright',
  title: 'Copyright',
  subtitle: 'Derechos de autor, marca y reclamos.',
  paragraphs: [
    'HallyuHub es una plataforma independiente para fans de K-pop. Las imágenes de artistas y grupos utilizadas en la plataforma pertenecen a sus respectivos autores y titulares. HallyuHub utiliza únicamente imágenes cuya reutilización está permitida conforme a la licencia indicada en cada perfil. La presencia de un artista, grupo, agencia o imagen no implica afiliación, patrocinio, respaldo ni asociación oficial con HallyuHub.',
    'HallyuHub, su nombre, identidad visual, diseño, interfaz, estructura, funcionalidades, textos, elementos gráficos y código pertenecen a HallyuHub o a sus titulares correspondientes.',
    hallyuHubBrandNotice,
    'Los usuarios conservan los derechos sobre el contenido que suben, pero declaran que cuentan con los derechos, permisos o autorizaciones necesarias para publicarlo.',
    'No está permitido subir contenido que infrinja derechos de autor, derechos de imagen, privacidad o derechos de terceros.',
    'Si sos titular de un contenido y creés que se publicó sin autorización, podés reportarlo desde la app o comunicarte con soporte. HallyuHub podrá ocultar, restringir o remover contenido mientras revisa reclamos de copyright o uso no autorizado.',
    'Durante el acceso anticipado y en tiendas oficiales, las imágenes, audios, videos y marcas de terceros deben usarse solo con permiso, licencia clara, contenido subido por usuarios o excepciones legales aplicables.',
    hallyuHubCopyrightNotice,
  ],
);

const legalFanPolicyDocument = LegalDocument(
  id: 'fan_policy',
  title: 'Política de contenido fan',
  subtitle: 'UGC, fan edits, fancams y previews.',
  paragraphs: [
    'Se permite contenido fan cuando respeta créditos, privacidad y derechos. Evitá subir canciones completas, filtraciones o material no autorizado.',
    'Fancams, edits, covers y clips deben indicar fuente cuando corresponda y respetar solicitudes de eliminación de titulares o personas afectadas.',
    'HallyuHub podrá remover, limitar o bloquear contenido que infrinja derechos de terceros, normas de comunidad, privacidad, seguridad, derechos de autor o cualquier regla aplicable de la plataforma.',
    'No uses HallyuHub para vender contenido falso, entradas fraudulentas, photocards inexistentes o productos que no puedas entregar.',
    hallyuHubCopyrightNotice,
  ],
);

const legalModerationDocument = LegalDocument(
  id: 'moderation',
  title: 'Moderación legal',
  subtitle: 'Reportes, revisión y acciones administrativas.',
  paragraphs: [
    'Los reportes de seguridad, privacidad, copyright y convivencia se ordenan por riesgo, urgencia y evidencia disponible.',
    'Los reportes pueden estar relacionados con copyright, privacidad, imagen personal, contenido no autorizado, suplantación, acoso, spam u otro motivo relevante.',
    'Las acciones disponibles pueden incluir advertencia, ocultamiento, restricción de interacciones, bloqueo de contenido o escalamiento legal.',
    'Durante el acceso anticipado algunas decisiones pueden requerir revisión manual y ajustes de políticas antes del lanzamiento público.',
    hallyuHubCopyrightNotice,
  ],
);

const legalAcceptanceDocuments = [
  legalTermsDocument,
  legalPrivacyDocument,
  legalCommunityGuidelinesDocument,
  legalBetaNoticeDocument,
];
