import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../admin/admin_dashboard_screen.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final p = auth.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: p == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  child: Icon(Icons.person, size: 36, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: 16),
                Text(p.email, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text('Üyelik: ${p.membershipType}', style: const TextStyle(color: Colors.white54), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                _infoTile('Bugünkü kullanılan tahmin', p.isAdmin ? 'Sınırsız' : '${p.usedToday} / ${p.dailyLimit}'),
                _infoTile('Kalan', p.isAdmin ? 'Sınırsız' : '${p.remaining}'),
                _infoTile('Kupon erişimi', p.canViewCoupons || p.isAdmin ? 'Var' : 'Yok'),
                const SizedBox(height: 24),
                if (p.isAdmin)
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminDashboardScreen())),
                    icon: const Icon(Icons.admin_panel_settings),
                    label: const Text('Admin Paneli'),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await auth.signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Çıkış Yap'),
                ),
              ],
            ),
    );
  }

  Widget _infoTile(String label, String value) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: const Color(0xFF171B24), borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white54)),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      );
}
