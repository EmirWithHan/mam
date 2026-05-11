class TrustScoreLog {
  const TrustScoreLog({
    required this.id,
    required this.userId,
    this.actorId,
    required this.delta,
    required this.previousScore,
    required this.newScore,
    required this.reason,
    this.sourceType,
    this.sourceId,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String? actorId;
  final int delta;
  final int previousScore;
  final int newScore;
  final String reason;
  final String? sourceType;
  final String? sourceId;
  final DateTime createdAt;

  bool get isPositive => delta > 0;
  bool get isNegative => delta < 0;

  String get formattedDelta {
    if (delta > 0) return '+$delta';
    return delta.toString();
  }

  factory TrustScoreLog.fromJson(Map<String, dynamic> json) {
    return TrustScoreLog(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      actorId: json['actor_id'] as String?,
      delta: (json['delta'] as num).toInt(),
      previousScore: (json['previous_score'] as num).toInt(),
      newScore: (json['new_score'] as num).toInt(),
      reason: json['reason'] as String,
      sourceType: json['source_type'] as String?,
      sourceId: json['source_id'] as String?,
      createdAt: DateTime.parse(json['created_at'].toString()),
    );
  }
}

String trustScoreLabel(int score) {
  if (score <= 39) return 'Low trust';
  if (score <= 59) return 'New user';
  if (score <= 79) return 'Reliable participant';
  return 'Highly trusted';
}
