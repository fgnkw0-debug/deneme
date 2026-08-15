import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _users = [];
  final _searchCtrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? query}) async {
    setState(() => _loading = true);
    var req = _client.from('profiles').select();
    if (query != null && query.isNotEmpty) {
      req = req.ilike('email', '%$query%');
    }
    final data = await req.order('created_at', ascending: false).limit(100);
    setState(() {
      _users = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  Future<void> _updateUser(String userId, {int? dailyLimit, bool? isAdmin, bool? canViewCoupons, bool? isActive}) async {
    await _client.rpc('admin_update_user', params: {
      'p_user_id': userId,
      'p_daily_limit': dailyLimit,
      'p_is_admin': isAdmin,
      'p_can_view_coupons': canViewCoupons,
      'p_is_active': isActive,
    });
    _load(query: _searchCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kullanıcı Yönetimi')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'E-posta ile ara...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) => _load(query: v),
            ),
          ),
          if (_loading) const Expanded(child: Center(child: CircularProgressIndicator())),
          if (!_loading)
            Expanded(
              child: ListView.builder(
                itemCount: _users.length,
                itemBuilder: (context, i) {
                  final u = _users[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ExpansionTile(
                      title: Text(u['email'], style: const TextStyle(color: Colors.white)),
                      subtitle: Text('Limit: ${u['daily_limit']} · Kullanılan: ${u['used_today']}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      children: [
                        SwitchListTile(
                          title: const Text('Admin Yetkisi', style: TextStyle(color: Colors.white70)),
                          value: u['is_admin'] ?? false,
                          onChanged: (v) => _updateUser(u['id'], isAdmin: v),
                        ),
                        SwitchListTile(
                          title: const Text('Kupon Erişimi', style: TextStyle(color: Colors.white70)),
                          value: u['can_view_coupons'] ?? false,
                          onChanged: (v) => _updateUser(u['id'], canViewCoupons: v),
                        ),
                        SwitchListTile(
                          title: const Text('Aktif Hesap', style: TextStyle(color: Colors.white70)),
                          value: u['is_active'] ?? true,
                          onChanged: (v) => _updateUser(u['id'], isActive: v),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Wrap(
                            spacing: 8,
                            children: [5, 10, 20, 999].map((limit) {
                              return ActionChip(
                                label: Text(limit == 999 ? 'Sınırsız' : '$limit'),
                                onPressed: () => _updateUser(u['id'], dailyLimit: limit),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
