import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/fixture.dart';
import '../../services/data_service.dart';
import '../../widgets/confidence_bar.dart';

class MatchDetailScreen extends StatefulWidget {
  final int fixtureId;
  const MatchDetailScreen({super.key, required this.fixtureId});

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  Map<String, dynamic>? _detail;
  PredictionFetchResult? _predictionResult;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await context.read<DataService>().fetchFixtureDetail(widget.fixtureId);
      setState(() => _detail = detail);
    } catch (_) {
      setState(() => _error = 'Maç verileri şu anda güncellenemiyor. Lütfen daha sonra tekrar deneyin.');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadPredictions() async {
    setState(() => _loading = true);
    final result = await context.read<DataService>().fetchPredictionsForFixture(widget.fixtureId);
    setState(() {
      _predictionResult = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _detail == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text(_error!, style: const TextStyle(color: Colors.white70))));
    }
    final d = _detail!;
    final stats = (d['fixture_stats'] as List?)?.isNotEmpty == true ? d['fixture_stats'][0] : null;
    final referee = d['referees'];

    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${d['home_team']['name']} - ${d['away_team']['name']}'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Genel'),
              Tab(text: 'Form'),
              Tab(text: 'Gol'),
              Tab(text: 'Korner'),
              Tab(text: 'Kart'),
              Tab(text: 'Hakem'),
              Tab(text: 'Tahmin'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _generalTab(d),
            _notAvailableTab('Form istatistikleri için lig senkronizasyonunun tamamlanması gerekiyor.'),
            _goalTab(d),
            _cornerTab(stats),
            _cardTab(stats),
            _refereeTab(referee),
            _predictionTab(),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(List<Widget> children) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white54)),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _notAvailableTab(String msg) =>
      Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(msg, style: const TextStyle(color: Colors.white54), textAlign: TextAlign.center)));

  Widget _generalTab(Map<String, dynamic> d) => ListView(children: [
        _sectionCard([
          _row('Lig', d['league']?['name'] ?? '—'),
          _row('Tarih', DateFormat('dd.MM.yyyy').format(DateTime.parse(d['match_date']))),
          _row('Saat', DateFormat('HH:mm').format(DateTime.parse(d['match_date']))),
          _row('Stat', d['venue'] ?? 'Bilgi yok'),
          _row('Durum', d['status']),
        ]),
      ]);

  Widget _goalTab(Map<String, dynamic> d) => ListView(children: [
        _sectionCard([
          if (d['home_goals'] != null) _row('Skor', '${d['home_goals']} - ${d['away_goals']}'),
          if (d['home_goals'] == null) const Text('Maç henüz oynanmadı, gol verisi yok.', style: TextStyle(color: Colors.white54)),
        ]),
      ]);

  Widget _cornerTab(Map<String, dynamic>? stats) {
    if (stats == null || (stats['corners_home'] == null && stats['corners_away'] == null)) {
      return _notAvailableTab('Bu maç için yeterli korner verisi bulunamadı.');
    }
    return ListView(children: [
      _sectionCard([
        _row('Ev Sahibi Korner', '${stats['corners_home'] ?? '—'}'),
        _row('Deplasman Korner', '${stats['corners_away'] ?? '—'}'),
      ]),
    ]);
  }

  Widget _cardTab(Map<String, dynamic>? stats) {
    if (stats == null || (stats['yellow_home'] == null && stats['yellow_away'] == null)) {
      return _notAvailableTab('Bu veri mevcut değil.');
    }
    return ListView(children: [
      _sectionCard([
        _row('Ev Sahibi Sarı Kart', '${stats['yellow_home'] ?? '—'}'),
        _row('Deplasman Sarı Kart', '${stats['yellow_away'] ?? '—'}'),
        _row('Ev Sahibi Kırmızı Kart', '${stats['red_home'] ?? '—'}'),
        _row('Deplasman Kırmızı Kart', '${stats['red_away'] ?? '—'}'),
      ]),
    ]);
  }

  Widget _refereeTab(Map<String, dynamic>? referee) {
    if (referee == null) return _notAvailableTab('Bu maç için hakem verisi mevcut değil.');
    return ListView(children: [
      _sectionCard([
        _row('Hakem', referee['name'] ?? '—'),
        _row('Yönettiği Maç', '${referee['matches_officiated'] ?? '—'}'),
        _row('Maç Başı Sarı Kart', '${referee['avg_yellow_cards'] ?? 'Yeterli veri yok'}'),
        _row('Maç Başı Kırmızı Kart', '${referee['avg_red_cards'] ?? 'Yeterli veri yok'}'),
        _row('Maç Başı Penaltı', '${referee['avg_penalties'] ?? 'Yeterli veri yok'}'),
      ]),
    ]);
  }

  Widget _predictionTab() {
    if (_predictionResult == null) {
      return Center(
        child: FilledButton.icon(
          onPressed: _loadPredictions,
          icon: const Icon(Icons.query_stats),
          label: const Text('Tahminleri Göster'),
        ),
      );
    }
    if (!_predictionResult!.allowed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_predictionResult!.message ?? '', style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
        ),
      );
    }
    if (_predictionResult!.predictions.isEmpty) {
      return _notAvailableTab('Yeterli veri olmadığı için tahmin oluşturulamadı.');
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Bu tahminler geçmiş ve güncel istatistiklerden oluşturulmuş matematiksel değerlendirmelerdir. '
            'Kesin sonuç veya kazanç garantisi değildir.',
            style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ),
        ..._predictionResult!.predictions.map((p) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  ConfidenceBar(confidence: p.confidence, dataSufficient: p.dataSufficient),
                ],
              ),
            )),
      ],
    );
  }
}
