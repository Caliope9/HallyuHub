class ShareLinks {
  const ShareLinks._();

  static String profile(String username) {
    return '${_baseUrl()}/#/perfil/${username.replaceFirst('@', '')}';
  }

  static String publication(String id) {
    return '${_baseUrl()}/#/publicaciones/$id';
  }

  static String story(String id) {
    return '${_baseUrl()}/#/historias/$id';
  }

  static String _baseUrl() {
    const configured = String.fromEnvironment('PUBLIC_APP_URL');
    if (configured.isNotEmpty) {
      return configured.replaceFirst(RegExp(r'/$'), '');
    }

    final current = Uri.base;
    if (current.scheme == 'http' || current.scheme == 'https') {
      return current
          .replace(path: '', query: null, fragment: null)
          .toString()
          .replaceFirst(RegExp(r'/$'), '');
    }
    return 'https://www.hallyuhub.net';
  }
}
