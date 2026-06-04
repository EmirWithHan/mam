# Supabase Cost Guardrails

## Pagination Rules

- Feed loads 20 posts per page.
- Events load 20 events per page.
- Notifications load 30 notifications per page.
- Comments load 20 comments per page.
- Followers and following load 30 profiles per page.
- Admin business applications load 20 applications per page.
- Public and profile gallery reads load 24 images per page.

Use `Daha fazla yukle` / `Daha fazla yükle` for manual pagination when a screen
does not already have infinite scroll.

## Query Limit Rules

- List screens must use a fixed `limit` or `.range(...)`.
- RPCs that back list screens should accept `p_limit` and `p_offset`.
- Server-side RPCs should clamp limits to a small maximum.
- Avoid `select('*')` on list screens when the UI only needs specific fields.
- Do not load hidden, archived, or private rows unless the current screen and
  current user are allowed to see them.
- Do not load all participants, comments, or applications by default.

## Cache Policy

- Keep provider state when switching tabs so feed, events, and notifications do
  not refetch on every rebuild.
- Pull-to-refresh or explicit refresh should reset pagination to the first page.
- After create/update/delete actions, prefer local state updates when safe.
- Privacy-sensitive changes should invalidate or refresh the affected profile,
  feed, event, and gallery providers.
- Public profile preview requests may reuse in-flight requests, but should not
  be cached aggressively across privacy or follow-state changes.

## Media Cost Notes

- Keep avatar and image fallbacks so broken URLs do not break layout.
- Use existing thumbnail/smaller image fields if the schema adds them later.
- Do not add image compression or media proxy packages without a separate
  product/infra task.

## Do Not Cache Aggressively

- Profile privacy and follow state.
- Business approval/deletion state.
- Notifications unread state.
- Event participation, join requests, or attendance state.
- Admin application review queues.
