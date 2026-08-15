import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminLeaguesScreen extends StatefulWidget {
  const AdminLeaguesScreen({super.key});

  @override
  State<AdminLeaguesScreen> createState() => _AdminLeaguesScreenState();
}

class _AdminLeaguesScreenState extends State<AdminLeaguesScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _leagues = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _client.from('leagues').select().order('name');
    setState(() {
      _leagues = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  Future<void> _toggle(int id, bool active) async {
    await _client.from('leagues').update({'active': active}).eq('id', id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lig Yönetimi')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _leagues.length,
              itemBuilder: (context, i) {
                final l = _leagues[i];
                return SwitchListTile(
                  title: Text(l['name'], style: const TextStyle(color: Colors.white)),
                  subtitle: Text(l['country'] ?? '', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  value: l['active'] ?? false,
                  onChanged: (v) => _toggle(l['id'], v),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddLeagueDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Lig Ekle'),
      ),
    );
  }

  void _showAddLeagueDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final apiIdCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Yeni Lig Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Lig Adı')),
            TextField(
              controller: apiIdCtrl,
              decoration: const InputDecoration(labelText: 'API-Football Lig ID'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          FilledButton(
            onPressed: () async {
              await _client.from('leagues').insert({
                'name': nameCtrl.text,
                'api_league_id': int.tryParse(apiIdCtrl.text) ?? 0,
                'active': true,
              });
              if (context.mounted) Navigator.pop(context);
              _load();
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }
}
