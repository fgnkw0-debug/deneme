import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/data_service.dart';

class CouponsScreen extends StatefulWidget {
  const CouponsScreen({super.key});

  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<DataService>().fetchPublishedCoupons();
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthService>().profile;
    final hasAccess = profile?.canViewCoupons == true || profile?.isAdmin == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Günün Kuponları')),
      body: !hasAccess
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Bu bölüm sadece yetkilendirilmiş kullanıcılar tarafından görüntülenebilir.',
                  style: TextStyle(color: Colors.white54),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final coupons = snapshot.data ?? [];
                if (coupons.isEmpty) {
                  return const Center(child: Text('Şu anda yayınlanmış kupon yok.', style: TextStyle(color: Colors.white54)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: coupons.length,
                  itemBuilder: (context, i) {
                    final c = coupons[i];
                    final items = List<Map<String, dynamic>>.from(c['coupon_items'] ?? []);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c['title'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            if (c['description'] != null) ...[
                              const SizedBox(height: 4),
                              Text(c['description'], style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            ],
                            const Divider(height: 20),
                            ...items.map((item) {
                              final fx = item['fixtures'];
                              final pred = item['predictions'];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${fx?['home_team']?['name'] ?? ''} - ${fx?['away_team']?['name'] ?? ''}',
                                        style: const TextStyle(color: Colors.white70),
                                      ),
                                    ),
                                    Text(pred?['prediction_value'] ?? '', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
