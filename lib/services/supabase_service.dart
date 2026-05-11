import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/env.dart';

class SupabaseService {
  const SupabaseService._();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    Env.validate();

    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
    _initialized = true;
  }

  static SupabaseClient get client => Supabase.instance.client;
}
