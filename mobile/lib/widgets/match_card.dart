import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/fixture.dart';

class MatchCard extends StatelessWidget {
  final FixtureModel fixture;
  final VoidCallback onTap;

  const MatchCard({super.key, required this.fixture, required this.onTap});

  Color _statusColor(BuildContext context) {
    switch (fixture.status) {
      case 'live':
        return Colors.orangeAccent;
      case 'finished':
        return Colors.white38;
      case 'postponed':
        return Colors.redAccent;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String _statusLabel() {
    switch (fixture.status) {
      case 'live':
        return 'CANLI';
      case 'finished':
        return 'BİTTİ';
      case 'postponed':
        return 'ERTELENDİ';
      default:
        return DateFormat('HH:mm').format(fixture.matchDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fixture.leagueName, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text('${fixture.homeTeam} — ${fixture.awayTeam}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _statusColor(context).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  fixture.status == 'finished' && fixture.homeGoals != null
                      ? '${fixture.homeGoals} - ${fixture.awayGoals}'
                      : _statusLabel(),
                  style: TextStyle(color: _statusColor(context), fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
