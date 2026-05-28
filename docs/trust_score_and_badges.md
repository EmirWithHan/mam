# Trust Score And Badges

## Meaning

Trust Score is a lightweight reliability signal for event behavior in Match A Man. It is not a credit score, ranking, dating score, or moderation punishment system.

## Score Bounds

- Default: 50
- Minimum: 0
- Maximum: 100
- Scores move slowly through small deltas.

## Current Score Events

Positive:

- Event-ready profile completed: +2 once
- First approved event participation: +3 once
- Approved event participation: +1 once per event
- Hosting an event with an approved participant: +2 once per event
- Event-linked post after participation/hosting: +1 once per event

Negative:

- Leaving an approved event before the event date: -2 once per event

Neutral:

- Cancelling a pending request does not currently reduce score.
- Host rejection does not reduce score.
- Reports do not automatically reduce score without moderation review.

## Postponed

- No-show penalties are postponed until check-in/business flow exists.
- Phone verification is a future prompt.
- Business accounts, sponsored events, business analytics, and business ratings are future prompts.

## Badge Catalog

- İlk Adım: profile is event-ready.
- İlk Etkinlik: first approved participation.
- Güvenilir Katılımcı: Trust Score reaches 70.
- Aktif Oyuncu: 3 approved participations.
- Organizatör: hosted event has at least one approved participant.
- Sosyal: 3 non-archived posts.
- Takım Oyuncusu and Erken Katılan are future rule-backed badges.

## Security

Users cannot directly edit `profiles.trust_score`, insert trust score logs, or grant badges to themselves. Score changes and badge awards are applied through server-side RPCs with action-specific checks and idempotent source references.
