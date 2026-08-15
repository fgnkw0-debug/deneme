import 'package:flutter/material.dart';

class ConfidenceBar extends StatelessWidget {
  final num confidence; // 0-100
  final bool dataSufficient;

  const ConfidenceBar({super.key, required this.confidence, required this.dataSufficient});

  Color _color() {
    if (!dataSufficient) return Colors.white24;
    if (confidence >= 70) return const Color(0xFF22C55E);
    if (confidence >= 50) return const Color(0xFFF59E0B);
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (confidence / 100).clamp(0, 1).toDouble(),
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(_color()),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          dataSufficient ? 'Veri Güveni: %$confidence' : 'Veri yetersiz',
          style: TextStyle(color: _color(), fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
