class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://zhmwteyerqfyjoogbsem.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_ILe1E5WWAWwMNyJ5Ja0-sQ_ZUb70rgy',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
