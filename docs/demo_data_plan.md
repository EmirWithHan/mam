# Match A Man Demo Data Plan

This plan is for staging/demo preparation only. Do not use real personal data, real phone numbers, production emails, or real user photos without permission.

## Demo Users

| Role | Display name | Username | City / District | Bio | Avatar suggestion | Trust score target | Privacy |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Host user | Emir Kaya | emir_kaptan | Istanbul / Kadikoy | Hali saha ve kosu gruplari organize eder. | Friendly football host portrait | 92 | Public |
| Approved participant | Deniz Arslan | denizfit | Istanbul / Besiktas | Basketbol, tenis ve hafta sonu maclari. | Sporty outdoor portrait | 84 | Public |
| Pending requester | Mert Yilmaz | mert_join | Istanbul / Uskudar | Yeni takim arkadaslari ariyor. | Casual gym portrait | 68 | Public |
| Rejected requester | Can Demir | candemir | Istanbul / Sisli | Voleybol ve sosyal etkinlikleri sever. | Neutral profile portrait | 55 | Public |
| Social/feed-heavy user | Zeynep Acar | zeynepaktif | Izmir / Karsiyaka | Mac sonrasi yorum, fotograf ve rota paylasir. | Energetic running portrait | 88 | Public |
| Private profile user | Elif Sari | elif_private | Ankara / Cankaya | Sadece takipçileriyle galeri ve Geçmiş Events paylaşır. | Minimal private-account portrait | 79 | Private |
| New empty user | Ali Yeni | aliyeni | Bursa / Nilufer | Profili yeni tamamlandi. | Simple placeholder avatar | 50 | Public |

## Demo Events

Use relative dates so the script can be reused on any demo day.

| Title | Sport | City / District | Date / time | Capacity | Participant state | Join-request scenario | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Kadikoy Aksam Hali Saha | Football | Istanbul / Kadikoy | Demo day + 1, 20:00 | 10 | Host + 6 approved | Pending user requests, host approves | Active/upcoming |
| Besiktas 3x3 Basket | Basketball | Istanbul / Besiktas | Demo day + 2, 19:30 | 6 | Host + 4 approved | One open slot, request accepted | Active/upcoming |
| Sahil Voleybol Bulusmasi | Volleyball | Izmir / Karsiyaka | Demo day + 3, 18:00 | 8 | Host + 5 approved | Rejected user is declined | Active/upcoming |
| Sabah Kosu Ekibi | Running | Ankara / Cankaya | Demo day + 1, 07:30 | 12 | Host + 3 approved | New user sends first request | Active/upcoming |
| Bogaz Bisiklet Turu | Cycling | Istanbul / Sariyer | Demo day + 5, 09:00 | 15 | Host + 8 approved | Participant later leaves | Active/upcoming |
| Kortta Tanisma Maci | Tennis | Istanbul / Bakirkoy | Demo day + 4, 17:00 | 4 | Host + 2 approved | Pending user cancels request | Active/upcoming |
| Belgrad Ormani YuruYus | Hiking/outdoor | Istanbul / Sariyer | Demo day + 6, 10:00 | 14 | Host + 9 approved | Profile privacy shown through host profile | Active/upcoming |
| Kahve Sonrasi Mini Turnuva | Casual social/sport | Bursa / Nilufer | Demo day + 2, 16:00 | 10 | Host + 5 approved | Social feed post links to event | Active/upcoming |
| Dolu Kontenjan Maci | Football | Istanbul / Atasehir | Demo day + 1, 21:00 | 8 | Full: host + 7 approved | Join button shows full-capacity state | Active/upcoming |
| Gecen Haftanin Basket Maci | Basketball | Istanbul / Besiktas | Demo day - 7, 20:00 | 8 | Historical approved users | Can be viewed, cannot be joined | Past |

## Demo Feed Posts

| Post idea | Owner | Purpose |
| --- | --- | --- |
| Event-linked post for Kadikoy Aksam Hali Saha | Emir Kaya | Opens event detail from feed. |
| Gallery-style post with match photos | Zeynep Acar | Shows gallery and image viewer. |
| Sport result post: "8-6 bitti, guzel mac!" | Deniz Arslan | Shows likes/comments on a normal post. |
| Looking-for-player post: "Bu aksam 1 kisi eksik" | Emir Kaya | Demonstrates fast social coordination. |
| Comment-heavy post | Zeynep Acar | Demonstrates comments and long text wrapping. |
| Like demo post | Deniz Arslan | Shows local like state. |
| Follow demo post from social user | Zeynep Acar | Follow/unfollow from feed and profile. |
| Private profile visibility demo | Elif Sari | Non-followers can see basic profile but locked gallery/events. |
| Archived gallery item demo | Elif Sari | Owner sees lock overlay, others do not see the item. |
| Safe report/block demo post | Can Demir | Use harmless copy to demonstrate report/block controls. |

## Demo Notifications

| Type | Scenario | Expected behavior |
| --- | --- | --- |
| event_join_request | Mert requests Kadikoy Aksam Hali Saha | Host sees a new join request notification. |
| event_join_approved | Host approves Deniz or Mert | Requester sees approval and can open event detail. |
| event_join_rejected | Host rejects Can | Requester sees rejection without private participant data. |
| event_join_cancelled | Mert cancels a pending tennis request | Host sees cancellation notification. |
| event_left | Deniz leaves Bogaz Bisiklet Turu | Host sees participant-left notification. |
| follow | Zeynep follows Emir | Emir sees new follower notification and can open profile. |
| system | Demo system notice | Shows general in-app notification copy. |

## Setup Notes

- Use staging/test accounts only.
- Keep all demo passwords outside this document.
- Prepare at least one private account and one follower of that private account.
- Prepare at least one archived gallery item owned by the private account.
- Prepare one true empty user to demonstrate empty profile, feed, and list states.
