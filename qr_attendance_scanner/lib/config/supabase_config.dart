import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supabase configuration
///
/// Loads Supabase credentials from the .env file.
/// Make sure to call dotenv.load() before accessing these values.
class SupabaseConfig {
  /// Supabase project URL loaded from .env file
  static String get supabaseUrl {
    final url = dotenv.env['SUPABASE_URL'];
    if (url == null || url.isEmpty) {
      throw Exception(
        'SUPABASE_URL is not set in .env file. '
        'Please ensure .env file exists and contains SUPABASE_URL.',
      );
    }
    return url;
  }

  /// Supabase anon/public key loaded from .env file
  static String get supabaseAnonKey {
    final key = dotenv.env['SUPABASE_ANON_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception(
        'SUPABASE_ANON_KEY is not set in .env file. '
        'Please ensure .env file exists and contains SUPABASE_ANON_KEY.',
      );
    }
    return key;
  }
}
