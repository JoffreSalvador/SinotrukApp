class Environment {
  static const String supabaseUrlKey = 'SUPABASE_URL';
  static const String supabaseAnonKeyKey = 'SUPABASE_ANON_KEY';

  static String? _url;
  static String? _anonKey;

  static void load(Map<String, String> env) {
    _url = env[supabaseUrlKey];
    _anonKey = env[supabaseAnonKeyKey];
  }

  static String get supabaseUrl {
    final value = _url;
    if (value == null || value.isEmpty) {
      throw StateError(
        'SUPABASE_URL no configurada. Copia .env.example a .env y completala.',
      );
    }
    return value;
  }

  static String get supabaseAnonKey {
    final value = _anonKey;
    if (value == null || value.isEmpty) {
      throw StateError(
        'SUPABASE_ANON_KEY no configurada. Copia .env.example a .env y completala.',
      );
    }
    return value;
  }

  static bool get isConfigured =>
      (_url?.isNotEmpty ?? false) && (_anonKey?.isNotEmpty ?? false);
}
