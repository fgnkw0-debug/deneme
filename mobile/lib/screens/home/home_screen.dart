import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/fixture.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../widgets/match_card.dart';
import '../chatbot/chatbot_screen.dart';
import '../matches/match_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<FixtureModel>> _fixturesFuture;

  @override
  void initState() {
    super.initState();
    _fixturesFuture = context.read<DataService>().fetchTodayFixtures();
    context.read<AuthService>().loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthService>().profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maç Tahmin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy_outlined),
            tooltip: 'Maç Asistanı',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatbotScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _fixturesFuture = context.read<DataService>().fetchTodayFixtures());
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _dailyLimitCard(profile),
            const SizedBox(height: 20),
            const Text('BUGÜNÜN MAÇLARI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 12),
            FutureBuilder<List<FixtureModel>>(
              future: _fixturesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return _errorBox('Maç verileri şu anda güncellenemiyor. Lütfen daha sonra tekrar deneyin.');
                }
                final fixtures = snapshot.data ?? [];
                if (fixtures.isEmpty) {
                  return _errorBox('Bugün için planlanmış maç bulunamadı.');
                }
                return Column(
                  children: fixtures
                      .map((f) => MatchCard(
                            fixture: f,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => MatchDetailScreen(fixtureId: f.id)),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _dailyLimitCard(dynamic profile) {
    final remaining = profile?.remaining ?? 5;
    final isAdmin = profile?.isAdmin ?? false;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.bolt, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isAdmin ? 'Sınırsız tahmin erişimi (Admin)' : 'Kalan günlük tahmin hakkın: $remaining / ${profile?.dailyLimit ?? 5}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBox(String msg) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12)),
        child: Text(msg, style: const TextStyle(color: Colors.white70)),
      );
}
