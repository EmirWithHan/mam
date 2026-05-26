# Match A Man Demo Data Plan

Use this plan for staging/demo preparation only. Do not use real personal data, production emails, real phone numbers, real secrets, or real user photos without permission.

## Demo Users

City and district values are for internal setup and event matching. Public presentation should emphasize profile, sport, trust, and event context rather than exact location.

| Demo role | Display name | Handle | City / district | Bio | Avatar suggestion | Trust target | Privacy | Follow/request state | Profile completeness |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Host user | Emir Kaya | emir_kaptan#1932 | Istanbul / Kadikoy | Hali saha, kosu ve hafta sonu turnuvalari organize eder. | Friendly football host portrait | 92 | Public | Followed by approved participant and social user | Core complete, event-ready |
| Approved participant | Deniz Arslan | denizfit#6385 | Istanbul / Besiktas | Basketbol, tenis ve karma spor etkinliklerini sever. | Sporty outdoor portrait | 84 | Public | Follows host, approved in one event | Core complete, event-ready |
| Pending event requester | Mert Yilmaz | mert_join#0047 | Istanbul / Uskudar | Yeni takim arkadaslari ariyor. | Casual gym portrait | 68 | Public | Has pending event join request | Core complete, event-ready |
| Rejected event requester | Can Demir | candemir#5821 | Istanbul / Sisli | Voleybol ve sosyal spor bulusmalarina katilir. | Neutral profile portrait | 55 | Public | Has rejected event join request | Core complete, event-ready |
| Social/feed-heavy user | Zeynep Acar | zeynepaktif#7420 | Izmir / Karsiyaka | Mac sonrasi yorum, fotograf ve rota paylasir. | Energetic running portrait | 88 | Public | Follows host and posts often | Core complete, event-ready |
| Private profile user | Elif Sari | elif_private#3188 | Ankara / Cankaya | Galeri ve Gecmis Events alanini sadece takipcileriyle paylasir. | Minimal private-account portrait | 79 | Private | Has one pending follow request | Core complete, event-ready |
| Follow request requester | Bora Tekin | bora_request#9064 | Ankara / Yenimahalle | Kosu ve outdoor etkinlikleri ariyor. | Friendly runner portrait | 61 | Public | Sent pending follow request to private profile | Core complete, event-ready |
| New empty user | Ali Yeni | aliyeni#2715 | Bursa / Nilufer | Profili yeni olusturuldu. | Default initials avatar | 50 | Public | No follows, events, posts, or notifications | Core complete, not event-ready until city/district/birth date are saved |
| Safety/report demo user | Cem Safe | cemsafe#4550 | Istanbul / Atasehir | Guvenli rapor/blok demosu icin zararsiz icerik hesabi. | Plain placeholder avatar | 45 | Public | Can be reported/blocked in demo without real user impact | Core complete, event-ready |

## Demo Events

Use relative dates so the script can be reused on any demo day.

| Title | Sport | City / district | Date / time | Capacity | Current participant state | Join/request scenario | Status | Expected UI behavior |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Kadikoy Aksam Hali Saha | Football | Istanbul / Kadikoy | Demo day + 1, 20:00 | 10 | Host + 6 approved | Pending requester sends request, host approves | Upcoming | Join request creates pending state and host notification |
| Besiktas 3x3 Basket | Basketball | Istanbul / Besiktas | Demo day + 2, 19:30 | 6 | Host + 4 approved | Approved participant joins open slot | Upcoming | Capacity count updates after approval/join |
| Sahil Voleybol Bulusmasi | Volleyball | Izmir / Karsiyaka | Demo day + 3, 18:00 | 8 | Host + 5 approved | Rejected requester is declined | Upcoming | Rejection notification appears, private participant data stays protected |
| Sabah Kosu Ekibi | Running | Ankara / Cankaya | Demo day + 1, 07:30 | 12 | Host + 3 approved | New empty user is prompted for event-required profile fields | Upcoming | "Profili tamamla" opens profile completion/edit |
| Bogaz Bisiklet Turu | Cycling | Istanbul / Sariyer | Demo day + 5, 09:00 | 15 | Host + 8 approved | Approved participant leaves later | Upcoming | Leave action refreshes participant state |
| Kortta Tanisma Maci | Tennis | Istanbul / Bakirkoy | Demo day + 4, 17:00 | 4 | Host + 2 approved | Pending requester cancels request | Upcoming | Cancelled request notification is shown to host |
| Belgrad Ormani Yuruyusu | Hiking/outdoor | Istanbul / Sariyer | Demo day + 6, 10:00 | 14 | Host + 9 approved | Private profile visibility is shown from participant profile | Upcoming | Followers can see private gallery/history, non-followers see locked state |
| Kahve Sonrasi Mini Turnuva | Casual social/sport | Bursa / Nilufer | Demo day + 2, 16:00 | 10 | Host + 5 approved | Feed post links to event detail | Upcoming | Event-linked post opens the event safely |
| Dolu Kontenjan Maci | Football | Istanbul / Atasehir | Demo day + 1, 21:00 | 8 | Full: host + 7 approved | Extra user attempts to join | Upcoming/full | Full-capacity state appears before profile requirement |
| Gecen Haftanin Basket Maci | Basketball | Istanbul / Besiktas | Demo day - 7, 20:00 | 8 | Historical approved users | User attempts to join a past event | Past | "Bu etkinlik geçmişte kaldı." appears and join is disabled |
| Pendingli Tenis Antrenmani | Tennis | Istanbul / Uskudar | Demo day + 3, 12:00 | 4 | Host + 1 approved + 1 pending | Host opens request queue | Upcoming | Host can approve or reject pending requester |
| Iptalden Donen Kosu | Running | Izmir / Bornova | Demo day + 4, 08:00 | 20 | Host + 4 approved + 1 cancelled/rejected history | User re-requests if allowed | Upcoming | State labels remain clear after cancel/reject |

## Demo Feed Posts

| Post idea | Owner | Purpose |
| --- | --- | --- |
| Event-linked post for Kadikoy Aksam Hali Saha | Emir Kaya | Opens event detail from feed |
| Gallery-style match photo post | Zeynep Acar | Shows gallery and image viewer |
| Sport result post: "8-6 bitti, guzel mac!" | Deniz Arslan | Demonstrates likes and comments |
| Looking-for-player post: "Bu aksam 1 kisi eksik" | Emir Kaya | Demonstrates quick event coordination |
| Comment-heavy post | Zeynep Acar | Checks long text wrapping and comment UX |
| Follow demo post | Zeynep Acar | Shows follow from social/feed surfaces |
| Private profile visibility post | Elif Sari | Opens private profile locked states |
| Follow request demo post | Bora Tekin | Sends request to private profile |
| Archived gallery item demo | Elif Sari | Owner sees archived item, others do not |
| Safe report/block demo post | Cem Safe | Demonstrates report/block without harmful real content |
| Trust/safety themed post | Emir Kaya | Explains reliable participation and event etiquette |

## Demo Notifications

| Type | Scenario | Expected behavior |
| --- | --- | --- |
| event_join_request | Mert requests Kadikoy Aksam Hali Saha | Host sees a new join request notification |
| event_join_approved | Host approves Deniz or Mert | Requester sees approval and can open event detail |
| event_join_rejected | Host rejects Can | Requester sees rejection without private participant data |
| event_join_cancelled | Mert cancels a pending tennis request | Host sees cancellation notification |
| event_left | Deniz leaves Bogaz Bisiklet Turu | Host sees participant-left notification |
| follow | Zeynep follows Emir's public profile | Emir sees a follow notification and can open profile |
| follow_request | Bora requests to follow Elif's private profile | Elif sees Onayla/Reddet actions |
| follow_request_approved | Elif approves Bora | Bora sees request approval |
| follow_request_rejected | Elif rejects a request | Requester sees request rejection |
| system | Closed beta welcome notice | General in-app notification appears safely |

## Setup Notes

- Keep all demo passwords outside this document.
- Use staging/test accounts only.
- Create one public account that can be followed instantly.
- Create one private account with one pending follow request.
- Prepare one requester that can be approved and one that can be rejected.
- Prepare at least one archived gallery item owned by the private account.
- Prepare one true empty user to demonstrate empty feed, event-required profile fields, and list states.
- Do not seed or write directly to production data from this document.
