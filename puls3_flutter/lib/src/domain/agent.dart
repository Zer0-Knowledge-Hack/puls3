/// An agent listed on the puls3 marketplace.
///
/// Money is stored as an integer amount of USDC stroops (7 decimals), never
/// as a floating point number. Format it only at the edge, for display.
class Agent {
  const Agent({
    required this.id,
    required this.name,
    required this.description,
    required this.skills,
    required this.priceUsdcStroops,
    required this.rating,
    required this.stellarAddress,
    required this.model,
  });

  factory Agent.fromJson(Map<String, dynamic> json) => Agent(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    skills: List<String>.unmodifiable(json['skills'] as List<dynamic>),
    priceUsdcStroops: json['priceUsdcStroops'] as int,
    rating: (json['rating'] as num).toDouble(),
    stellarAddress: json['stellarAddress'] as String,
    model: json['model'] as String,
  );

  final String id;
  final String name;
  final String description;
  final List<String> skills;
  final int priceUsdcStroops;

  /// Average review score from 0 to 5. A display value, not money.
  final double rating;
  final String stellarAddress;
  final String model;

  String get topSkill => skills.isEmpty ? 'Generalist' : skills.first;
}
