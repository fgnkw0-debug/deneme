import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/data_service.dart';

class _ChatMessage {
  final String text;
  final bool isUser;
  final Map<String, dynamic>? data;
  _ChatMessage(this.text, this.isUser, {this.data});
}

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _controller = TextEditingController();
  final List<_ChatMessage> _messages = [
    _ChatMessage('Merhaba! Bir maç adı yaz (ör. "Galatasaray Fenerbahçe") veya '
        '"hakem kim?", "korner ortalamaları nasıl?" gibi sorular sorabilirsin.', false),
  ];
  bool _loading = false;

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(text, true));
      _loading = true;
      _controller.clear();
    });

    final response = await context.read<DataService>().queryChatbot(text);

    setState(() {
      _messages.add(_ChatMessage(response.text, false, data: response.data));
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Maç Asistanı')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final m = _messages[i];
                return Align(
                  alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: m.isUser ? Theme.of(context).colorScheme.primary.withOpacity(0.25) : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.text, style: const TextStyle(color: Colors.white)),
                        if (m.data != null) _buildDataSummary(m.data!),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Bir maç veya soru yaz...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.send), onPressed: _send),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSummary(Map<String, dynamic> data) {
    final stats = (data['fixture_stats'] as List?)?.isNotEmpty == true ? data['fixture_stats'][0] : null;
    final referee = data['referees'];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (referee != null) Text('Hakem: ${referee['name']}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          if (stats != null && stats['corners_home'] != null)
            Text('Korner: ${stats['corners_home']} - ${stats['corners_away']}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          if (stats != null && stats['yellow_home'] != null)
            Text('Sarı Kart: ${stats['yellow_home']} - ${stats['yellow_away']}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          if (stats == null) const Text('Detaylı istatistik henüz mevcut değil.', style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }
}
