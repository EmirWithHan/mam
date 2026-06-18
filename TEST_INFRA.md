# Match A Man — E2E Test Infrastructure Design (Milestone E2E-M1)

This document describes the offline E2E Test Infrastructure designed for **Match A Man (MAM)** to support automated opaque-box testing without hitting external network endpoints or live Supabase backends.

---

## 1. Test Architecture

The test infrastructure isolates the application from external dependencies to ensure fast, reproducible, and offline-compatible execution.

```
+-------------------------------------------------------------+
|                       Flutter Widget                        |
+-------------------------------------------------------------+
                               |
                               v
+-------------------------------------------------------------+
|                 Riverpod Provider Overrides                 |
+-------------------------------------------------------------+
       |                       |                       |
       v                       v                       v
+-------------+         +-------------+         +-------------+
|  Fake Auth  |         |Fake Profile |         | Fake Events |
|   Service   |         |   Service   |         |   Service   |
+-------------+         +-------------+         +-------------+
                               |
                               v
                +------------------------------+
                |     In-Memory Repository     |
                |          (State)             |
                +------------------------------+
```

### Key Components

1. **Riverpod Override Injector (`lib/app.dart`)**:
   - `MatchAManApp` has been updated to accept `overrides` in its constructor, which are passed directly to the root `ProviderScope`.
   - In E2E tests, real services are replaced with in-memory service fakes.

2. **In-Memory Service Fakes (`test/e2e/harness/fakes/`)**:
   - `FakeAuthService`: Emulates the Supabase auth stream and methods (login, registration, terms acceptance, sign out) in-memory.
   - `FakeProfileService`: Simulates database queries and mutations for profiles.
   - `FakeEventsService`: Emulates queries and mutations for events, as well as featured event sorting.
   - `FakeStorageService`: Intercepts file upload methods, returning simulated storage URIs instantly.

3. **Platform Method Channel Mocks (`test/e2e/harness/mocks/`)**:
   - Intercepts native API communications to eliminate real device dependencies:
     - `mock_geolocator.dart`: Mocks gps permissions, coordinates lookup, and service availability.
     - `mock_geocoding.dart`: Mocks geocoding lookup mapping coordinates to physical addresses.
     - `mock_image_picker.dart`: Mocks media selection and returns mock local files.

---

## 2. Feature Inventory (F1 to F9)

| Feature ID | Requirement Code | Name | Description |
|---|---|---|---|
| **F1** | **R1** | Business Privacy Lock | Restricts business accounts from being set to private. Switches private business accounts to public automatically. |
| **F2** | **R2** | Photo Cropper Tool | Integrates a photo cropper to crop avatar and post images prior to upload. |
| **F3** | **R3** | Featured vs Following Events Tab | Splits the events page into Featured (sponsored and high trust) and Following tabs. |
| **F4** | **R4** | Homepage Mixed Feed | Combines posts of followed users, discover events, recommendations, and past participants' posts. |
| **F5** | **R5** | Instagram-style Notifications | Consolidates activity logs, follow requests, and approved events under an activity feed. |
| **F6** | **R6** | Daily Event Posting Limits | Implements posting limits based on user trust score (2/day for <60, 3/day for >=60) and business quotas (3/month without subscription). |
| **F7** | **R7** | Business Plus Subscriptions | Adds premium subscriptions enabling custom theme color, event pinning, and media galleries. |
| **F8** | **R8** | UI Modernization | Cleans up deprecated widgets and modernizes app elements according to design rules. |
| **F9** | **R9** | iOS Compatibility | Optimizes the app for iOS gestures and adapts components to Cupertino specifications. |

---

## 3. Planned Test Counts

To achieve complete coverage, tests are distributed across **four testing tiers** (totaling **104 planned test cases**):

```
+--------------------------------------------------------------+
| Tier 1: Feature Coverage (Happy Path)             [45 Tests] |
| - Verify normal lifecycle of F1-F9 features                  |
+--------------------------------------------------------------+
| Tier 2: Boundary & Corner Cases                   [45 Tests] |
| - Validate strict bounds, rate limits, and errors            |
+--------------------------------------------------------------+
| Tier 3: Cross-Feature Combinations                [9 Tests]  |
| - Verify interactions between features pairwise              |
+--------------------------------------------------------------+
| Tier 4: Real-world Workloads                      [5 Tests]  |
| - Complex application flow simulations                       |
+--------------------------------------------------------------+
| Total Planned Test Cases                          [104 Tests]|
+--------------------------------------------------------------+
```

### Matrix Breakdown

1. **Tier 1: Feature Coverage (Happy Path) — 45 Tests**
   - Asserts basic functionality of F1 to F9: profile creations, standard event post submissions, notification triggers, subscriptions toggling, and layout loading.

2. **Tier 2: Boundary & Corner Cases — 45 Tests**
   - Asserts limits and error conditions:
     - F1: Setting business account to private (verifying it is locked out/reset).
     - F6: Creating a 3rd/4th event in a single day and verifying rejection based on trust score.
     - F7: Expired subscription downgrades and boundary date conditions.
     - Simulating database timeout, slow network shimmer fallback, and local media loading failures.

3. **Tier 3: Cross-Feature Combinations — 9 Tests**
   - Verifies pairwise feature interactions (e.g., how the rate-limiter F6 behaves for F7 Business Plus accounts, or F3 Featured sorting under F1 Privacy rules).

4. **Tier 4: Real-world Workloads — 5 Tests**
   - Full flow walkthroughs: New user signs up -> does onboarding -> creates profile -> uploads avatar -> creates event -> other user requests to join -> approval -> chat messaging -> photo uploading.
