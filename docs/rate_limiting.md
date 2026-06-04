# Rate Limiting

## Current Foundation

Flutter clients cannot enforce true IP-based rate limits reliably. Client-side
checks can be bypassed, and mobile network IPs are often shared, unstable, or
hidden behind carrier NAT.

The current implementation adds DB/RPC based per-user limits:

- `rate_limit_events` stores action attempts by authenticated user.
- `check_and_record_rate_limit(...)` counts recent attempts and records the
  allowed action.
- The Flutter service layer calls the RPC before sensitive user actions.
- Rate-limit errors map to: `Çok fazla işlem yaptın. Biraz sonra tekrar dene.`

This is per-user abuse protection, not true IP protection.

## Covered Actions

- Create post
- Create event
- Submit business application
- Approve/reject business application
- Follow/unfollow and private follow request
- Event join request
- Event approve/reject
- Comments
- Reports
- Business review submit
- Business check-in/no-show marking

## Future IP-Based Protection

True IP-based limiting should be enforced upstream from the Flutter app with one
of these server-side options:

- Supabase Edge Function in front of sensitive RPCs
- Cloudflare/WAF rules
- Server-side request proxy
- Redis/Upstash style counters for short windows

Target future rule:

- Same IP sending more than 5 sensitive requests per second should be blocked
  upstream before the request reaches Supabase business logic.

This IP-based rule is documented for later and is not implemented yet.
