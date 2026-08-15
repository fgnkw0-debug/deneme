import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/fixture.dart';
import '../../services/data_service.dart';
import '../../widgets/match_card.dart';
import 'match_detail_screen.dart';

class MatchesScreen extends StatefulWidget {
  final bool showPredictionsOnly;
  const MatchesScreen({super.key, this.showPredictionsOnly = false});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  int? _selectedLeague;
  late Future<List<FixtureModel>> _future;

  @override
  void initState() {
    super.initState();
    context.read<DataService>().loadLeagues();
    _future = context.read<DataService>().fetchTodayFixtures();
  }

  void _reload() {
    setState(() => _future = context.read<DataService>().fetchTodayFixtures(leagueId: _selectedLeague));
  }

  @override
  Widget build(BuildContext context) {
    final leagues = context.watch<DataService>().leagues;

    return Scaffold(
      appBar: AppBar(title: Text(widget.showPredictionsOnly ? 'Tahminler' : 'Maçlar')),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _leagueChip('Tümü', null),
                ...leagues.map((l) => _leagueChip(l['name'], l['id'])),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<FixtureModel>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Maç verileri şu anda güncellenemiyor. Lütfen daha sonra tekrar deneyin.',
                          style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                    ),
                  );
                }
                final fixtures = snapshot.data ?? [];
                if (fixtures.isEmpty) {
                  return const Center(child: Text('Bu filtre için maç bulunamadı.', style: TextStyle(color: Colors.white54)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: fixtures.length,
                  itemBuilder: (context, i) => MatchCard(
                    fixture: fixtures[i],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => MatchDetailScreen(fixtureId: fixtures[i].id)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _leagueChip(String label, int? id) {
    final selected = _selectedLeague == id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() => _selectedLeague = id);
          _reload();
        },
      ),
    );
  }
}
