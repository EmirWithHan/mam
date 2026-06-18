# Project: Match A Man (MAM) Features & Modernization

## Architecture
Match A Man is a Flutter cross-platform social sports/activity mobile application using:
- **State Management**: Riverpod (`StateNotifierProvider`, immutable state models, controller-service pattern).
- **Database/Backend**: Supabase (via `supabase_flutter`), including database triggers, functions (RPCs), and tables.
- **Routing/Navigation**: GoRouter (5-tab shell navigation).
- **Styling**: Material 3, Plus Jakarta Sans, Primary Coral (`#FF7E79`), Secondary Sky Blue (`#7CB9E8`), Warm White background.

## Milestones

### Track 1: E2E Testing Track (Parallel)
| Milestone | Name | Scope | Dependencies | Status |
|---|---|---|---|---|
| E2E-M1 | Test Infrastructure Design | Create test runner, define format and layout, setup base harness | None | PLANNED |
| E2E-M2 | Test Case Implementation | Write tests for Tiers 1-4 covering all features (R1-R9) | E2E-M1 | PLANNED |
| E2E-M3 | Publish TEST_READY.md | Finalize tests, run verification, publish coverage metrics | E2E-M2 | PLANNED |

### Track 2: Implementation Track
| Milestone | Name | Scope | Dependencies | Status |
|---|---|---|---|---|
| IMP-M1 | DB Migrations & RPC Updates | R1 trigger/constraint, R6 rate limit RPC, R7 `business_plus_subscriptions` schema | None | PLANNED |
| IMP-M2 | Profile, Settings & Rate Limiting | R1 settings UI, R6 RateLimitService integration, R7 Business models & customizable fields | IMP-M1 | PLANNED |
| IMP-M3 | Photo Cropper & Notification Redesign | R2 cropper utility & post/avatar upload integrations, R5 Instagram-style notifications | IMP-M2 | PLANNED |
| IMP-M4 | Events & Feed Algorithmic Features | R3 events tabs (Featured vs Following + suggestions), R4 home mixed feed (4 sources) | IMP-M3 | PLANNED |
| IMP-M5 | UI Modernization & iOS Compatibility | R8 theme & deprecated UI cleanups, R9 iOS Cupertino adaptations & platform testing | IMP-M4 | PLANNED |
| IMP-M6 | Acceptance & Hardening | Pass 100% E2E tests (Tier 1-4), Tier 5 Challenger-driven adversarial test hardening | IMP-M5, E2E-M3 | PLANNED |

## Interface Contracts

### 1. Business Profile Privacy Rule (R1)
- **Database Constraint**: `ALTER TABLE profiles ADD CONSTRAINT chk_business_not_private CHECK (NOT (account_type = 'business' AND is_private = true));`
- **Database Trigger**: Trigger on UPDATE to profiles. If `account_type` is changed to `'business'`, automatically set `is_private = false`.
- **RPC Update**: `switch_profile_account_type` must ensure that if account type is set to business, `is_private` is updated to `false`.

### 2. Daily Event Posting Limits (R6)
- **RPC Signature update**: `check_and_record_rate_limit(user_id uuid, action text, target_id uuid DEFAULT null)`
- Actions to verify:
  - `'create_event'`: checks trust score of `user_id`.
    - If `trust_score` < 60: limit is 2 per day.
    - If `trust_score` >= 60: limit is 3 per day.
    - If `profiles.account_type` == 'business': limit is 3 per month (unless Plus subscription active).
- Returns: boolean (allowed/disallowed) or throws error with localized custom message.

### 3. Business Plus Subscriptions (R7)
- **New Table**: `business_plus_subscriptions`
  ```sql
  CREATE TABLE business_plus_subscriptions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_account_id uuid REFERENCES business_accounts(id) ON DELETE CASCADE,
    is_active boolean DEFAULT true,
    expires_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now()
  );
  ```
- **New columns in `business_accounts`**:
  - `custom_theme_color` (text, hex color value)
  - `pinned_event_id` (uuid, reference to events)
  - `gallery_urls` (text array)

### 4. Algorithmic Events & Mixed Feed (R3, R4)
- **Featured Events sorting algorithm**:
  - Order by: `is_sponsored DESC`, `sponsored_priority DESC`, `profiles.trust_score DESC`, participant count DESC.
- **Mixed Feed aggregation rules**:
  - Merge and shuffle/interleave:
    1. Posts/events of followed users.
    2. Discover events (not yet followed).
    3. Past participants' profiles (as recommendation cards).
    4. Past participants' posts (even if not followed).

## Code Layout
- `lib/features/auth/` - Authentication flow
- `lib/features/profile/` - User profile, avatar uploads
- `lib/features/settings/` - App and privacy settings
- `lib/features/business/` - Business details, stats, Plus packages
- `lib/features/events/` - Event lists, detail, registration, check-ins
- `lib/features/feed/` - Posts, comments, likes, mixed feed
- `lib/features/notifications/` - Follow requests, activity logs
- `lib/services/` - Storage, rate-limiting, and core network wrappers
- `supabase/migrations/` - Database SQL migrations
