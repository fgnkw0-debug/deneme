import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminCouponsScreen extends StatefulWidget {
  const AdminCouponsScreen({super.key});

  @override
  State<AdminCouponsScreen> createState() => _AdminCouponsScreenState();
}

class _AdminCouponsScreenState extends State<AdminCouponsScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _coupons = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _client.from('coupons').select().order('created_at', ascending: false);
    setState(() {
      _coupons = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  Future<void> _togglePublish(int id, bool published) async {
    await _client.from('coupons').update({'published': published}).eq('id', id);
    _load();
  }

  Future<void> _createCoupon() async {
    final titleCtrl = TextEditingController();
    String type = 'single';
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Yeni Kupon Oluştur'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Kupon Başlığı')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: type,
                items: const [
                  DropdownMenuItem(value: 'single', child: Text('Tekli Kupon')),
                  DropdownMenuItem(value: 'triple', child: Text('3 Maçlık Kupon')),
                  DropdownMenuItem(value: 'quintuple', child: Text('5 Maçlık Kupon')),
                ],
                onChanged: (v) => setLocalState(() => type = v ?? 'single'),
                decoration: const InputDecoration(labelText: 'Kupon Tipi'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Kupon oluşturulduktan sonra maç/tahmin eklemek için '
                'Supabase Studio üzerinden coupon_items tablosuna kayıt ekleyebilir, '
                'ya da bu ekranı V2\'de maç seçici ile genişletebilirsiniz.',
                style: TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
            FilledButton(
              onPressed: () async {
                await _client.from('coupons').insert({
                  'title': titleCtrl.text,
                  'coupon_type': type,
                  'published': false,
                });
                if (context.mounted) Navigator.pop(context);
                _load();
              },
              child: const Text('Oluştur'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kupon Yönetimi')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _coupons.length,
              itemBuilder: (context, i) {
                final c = _coupons[i];
                return SwitchListTile(
                  title: Text(c['title'] ?? '', style: const TextStyle(color: Colors.white)),
                  subtitle: Text(c['coupon_type'], style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  value: c['published'] ?? false,
                  activeColor: Colors.greenAccent,
                  onChanged: (v) => _togglePublish(c['id'], v),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCoupon,
        icon: const Icon(Icons.add),
        label: const Text('Yeni Kupon'),
      ),
    );
  }
}
