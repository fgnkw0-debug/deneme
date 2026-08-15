class FixtureModel {
  final int id;
  final String homeTeam;
  final String awayTeam;
  final String? homeLogo;
  final String? awayLogo;
  final String leagueName;
  final DateTime matchDate;
  final String status;
  final int? homeGoals;
  final int? awayGoals;

  FixtureModel({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    this.homeLogo,
    this.awayLogo,
    required this.leagueName,
    required this.matchDate,
    required this.status,
    this.homeGoals,
    this.awayGoals,
  });

  factory FixtureModel.fromJson(Map<String, dynamic> json) => FixtureModel(
        id: json['id'],
        homeTeam: json['home_team']?['name'] ?? '—',
        awayTeam: json['away_team']?['name'] ?? '—',
        homeLogo: json['home_team']?['logo_url'],
        awayLogo: json['away_team']?['logo_url'],
        leagueName: json['league']?['name'] ?? '',
        matchDate: DateTime.parse(json['match_date']),
        status: json['status'] ?? 'scheduled',
        homeGoals: json['home_goals'],
        awayGoals: json['away_goals'],
      );
}

class PredictionModel {
  final int id;
  final String market;
  final String category;
  final String label;
  final num confidence;
  final bool dataSufficient;

  PredictionModel({
    required this.id,
    required this.market,
    required this.category,
    required this.label,
    required this.confidence,
    required this.dataSufficient,
  });

  factory PredictionModel.fromJson(Map<String, dynamic> json) => PredictionModel(
        id: json['id'],
        market: json['market'],
        category: json['category'],
        label: json['prediction_value'],
        confidence: json['confidence'] ?? 0,
        dataSufficient: json['data_sufficient'] ?? false,
      );
}
