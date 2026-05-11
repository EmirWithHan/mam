class Env {
  const Env._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static void validate() {
    if (supabaseUrl.isEmpty) {
      throw StateError('Missing SUPABASE_URL. Pass it with --dart-define.');
    }
    if (supabaseAnonKey.isEmpty) {
      throw StateError(
        'Missing SUPABASE_ANON_KEY. Pass it with --dart-define.',
      );
    }
  }
}
