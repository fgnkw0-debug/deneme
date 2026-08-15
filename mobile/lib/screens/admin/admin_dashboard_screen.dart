import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_users_screen.dart';
import 'admin_leagues_screen.dart';
import 'admin_coupons_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await Supabase.instance.client.rpc('admin_dashboard_stats');
      setState(() {
        _stats = Map<String, dynamic>.from(result);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Paneli')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    _statCard('Toplam Kullanıcı', '${_stats?['total_users'] ?? '-'}'),
                    _statCard('Aktif Kullanıcı', '${_stats?['active_users'] ?? '-'}'),
                    _statCard('Bugün Aktif', '${_stats?['today_active_users'] ?? '-'}'),
                    _statCard('Bugün Kullanılan Tahmin', '${_stats?['today_predictions_used'] ?? '-'}'),
                    _statCard('Bugünkü Maç Sayısı', '${_stats?['today_fixtures'] ?? '-'}'),
                    _statCard('Yayınlı Kupon', '${_stats?['published_coupons'] ?? '-'}'),
                  ],
                ),
                const SizedBox(height: 24),
                _menuTile(context, 'Kullanıcı Yönetimi', Icons.people, const AdminUsersScreen()),
                _menuTile(context, 'Lig Yönetimi', Icons.emoji_events, const AdminLeaguesScreen()),
                _menuTile(context, 'Kupon Yönetimi', Icons.confirmation_num, const AdminCouponsScreen()),
              ],
            ),
    );
  }

  Widget _statCard(String label, String value) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFF171B24), borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      );

  Widget _menuTile(BuildContext context, String label, IconData icon, Widget screen) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(label, style: const TextStyle(color: Colors.white)),
          trailing: const Icon(Icons.chevron_right, color: Colors.white38),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)),
        ),
      );
}
