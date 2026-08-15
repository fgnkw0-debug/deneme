import 'package:flutter_dotenv/flutter_dotenv.dart';

/// KRİTİK GÜVENLİK NOTU:
/// Burada API-Football key'i YOKTUR ve olmamalıdır. Mobil uygulama
/// sadece Supabase'in "anon" (public) key'ini kullanır - bu key
/// zaten public olacak şekilde tasarlanmıştır, gerçek yetkilendirme
/// RLS politikaları ile veritabanı tarafında yapılır.
/// API-Football key'i SADECE Supabase Edge Function ortam değişkeninde
/// tutulur (bkz supabase/functions/sync-fixtures).
class SupabaseConfig {
  static String get url => dotenv.env['SUPABASE_URL'] ?? '';
  static String get anonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
}
