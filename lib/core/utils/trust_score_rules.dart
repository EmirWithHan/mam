class TrustScoreRules {
  const TrustScoreRules._();

  static const minScore = 0;
  static const maxScore = 100;
  static const neutralScore = 50;

  static int clamp(int score) => score.clamp(minScore, maxScore).toInt();

  static int applyDelta(int score, int delta) => clamp(score + delta);

  static int deltaFor(String eventType) {
    return switch (eventType) {
      'profile_event_ready' => 2,
      'first_event_approved' => 3,
      'event_join_approved' => 1,
      'host_event_with_participant' => 2,
      'event_linked_post' => 1,
      'approved_event_left' => -2,
      'event_join_cancelled' => 0,
      'event_join_rejected' => 0,
      _ => 0,
    };
  }
}
