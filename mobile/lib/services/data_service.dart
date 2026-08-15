import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/fixture.dart';

class DataService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  List<Map<String, dynamic>> leagues = [];

  Future<void> loadLeagues() async {
    final data = await _client.from('leagues').select().eq('active', true).order('name');
    leagues = List<Map<String, dynamic>>.from(data);
    notifyListeners();
  }

  /// Bugünün maçlarını (opsiyonel lig filtresiyle) getirir.
  Future<List<FixtureModel>> fetchTodayFixtures({int? leagueId}) async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).toIso8601String();
    final end = DateTime(today.year, today.month, today.day, 23, 59, 59).toIso8601String();

    var query = _client
        .from('fixtures')
        .select('id, match_date, status, home_goals, away_goals, '
            'home_team:home_team_id(name, logo_url), '
            'away_team:away_team_id(name, logo_url), '
            'league:league_id(name)')
        .gte('match_date', start)
        .lte('match_date', end);

    if (leagueId != null) {
      query = query.eq('league_id', leagueId);
    }

    final data = await query.order('match_date');
    return (data as List).map((e) => FixtureModel.fromJson(e)).toList();
  }

  /// Bir maçın tahminlerini getirir. ÖNCE use_prediction RPC'si çağrılarak
  /// günlük hak kontrolü backend'de yapılır; hak yoksa boş liste + mesaj döner.
  Future<PredictionFetchResult> fetchPredictionsForFixture(int fixtureId) async {
    final rpcResult = await _client.rpc('use_prediction', params: {'p_fixture_id': fixtureId});
    final allowed = rpcResult['allowed'] == true;

    if (!allowed) {
      return PredictionFetchResult(
        allowed: false,
        message: rpcResult['message'] ?? 'Bugünkü ücretsiz tahmin hakkınız doldu.',
        predictions: [],
        remaining: 0,
      );
    }

    final data = await _client.from('predictions').select().eq('fixture_id', fixtureId);
    final predictions = (data as List).map((e) => PredictionModel.fromJson(e)).toList();

    return PredictionFetchResult(
      allowed: true,
      message: null,
      predictions: predictions,
      remaining: rpcResult['remaining'],
    );
  }

  Future<List<Map<String, dynamic>>> fetchPublishedCoupons() async {
    final data = await _client
        .from('coupons')
        .select('*, coupon_items(*, fixtures(*, home_team:home_team_id(name), away_team:away_team_id(name)), predictions(*))')
        .eq('published', true)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>?> fetchFixtureDetail(int fixtureId) async {
    final data = await _client
        .from('fixtures')
        .select('*, home_team:home_team_id(*), away_team:away_team_id(*), '
            'referees:referee_id(*), fixture_stats(*), league:league_id(*)')
        .eq('id', fixtureId)
        .maybeSingle();
    return data;
  }

  /// Basit anahtar-kelime tabanlı chatbot sorgu motoru. Sadece DB'deki
  /// gerçek verileri döner - hiçbir zaman veri uydurmaz.
  Future<ChatbotResponse> queryChatbot(String message) async {
    final normalized = message.trim();

    // "Takım1 Takım2" formatında maç arama
    final teamMatches = await _client
        .from('teams')
        .select('id, name')
        .ilike('name', '%${normalized.split(' ').first}%')
        .limit(5);

    if (teamMatches.isEmpty) {
      return ChatbotResponse(
        text: 'Bu isimle bir takım bulamadım. Örnek: "Galatasaray Fenerbahçe"',
        data: null,
      );
    }

    // Basitleştirilmiş: ilk bulunan takımın yaklaşan maçını getir
    final teamId = teamMatches.first['id'];
    final fixture = await _client
        .from('fixtures')
        .select('id, match_date, status, '
            'home_team:home_team_id(name), away_team:away_team_id(name), '
            'referees:referee_id(name, avg_yellow_cards), fixture_stats(*)')
        .or('home_team_id.eq.$teamId,away_team_id.eq.$teamId')
        .gte('match_date', DateTime.now().subtract(const Duration(days: 1)).toIso8601String())
        .order('match_date')
        .limit(1)
        .maybeSingle();

    if (fixture == null) {
      return ChatbotResponse(text: 'Bu takım için yaklaşan bir maç bulunamadı.', data: null);
    }

    return ChatbotResponse(
      text: '${fixture['home_team']['name']} - ${fixture['away_team']['name']} maçını buldum. '
          'Detaylar aşağıda.',
      data: fixture,
    );
  }
}

class PredictionFetchResult {
  final bool allowed;
  final String? message;
  final List<PredictionModel> predictions;
  final dynamic remaining;

  PredictionFetchResult({
    required this.allowed,
    required this.message,
    required this.predictions,
    required this.remaining,
  });
}

class ChatbotResponse {
  final String text;
  final Map<String, dynamic>? data;
  ChatbotResponse({required this.text, required this.data});
}
