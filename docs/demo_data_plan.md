# Match A Man Demo Data Plan

This plan is for staging/demo preparation only. Do not use real personal data, production emails, real phone numbers, or real user photos without permission.

## Demo Users

City/district values are for internal setup and event matching. Other users' public profiles should not rely on location as a main visible signal.

| Role | Display name | Username | City / District | Bio | Avatar suggestion | Trust score target | Privacy | Follow state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Host user | Emir Kaya | emir_kaptan | İstanbul / Kadıköy | Halı saha ve koşu grupları organize eder. | Friendly football host portrait | 92 | Public | Followed by approved participant and social user |
| Approved participant | Deniz Arslan | denizfit | İstanbul / Beşiktaş | Basketbol, tenis ve hafta sonu maçları. | Sporty outdoor portrait | 84 | Public | Follows host, approved in one event |
| Pending event requester | Mert Yılmaz | mert_join | İstanbul / Üsküdar | Yeni takım arkadaşları arıyor. | Casual gym portrait | 68 | Public | Has pending event join request |
| Rejected event requester | Can Demir | candemir | İstanbul / Şişli | Voleybol ve sosyal etkinlikleri sever. | Neutral profile portrait | 55 | Public | Has rejected event join request |
| Social/feed-heavy user | Zeynep Acar | zeynepaktif | İzmir / Karşıyaka | Maç sonrası yorum, fotoğraf ve rota paylaşır. | Energetic running portrait | 88 | Public | Follows host and posts often |
| Private profile user | Elif Sarı | elif_private | Ankara / Çankaya | Galeri ve Geçmiş Events alanını sadece takipçileriyle paylaşır. | Minimal private-account portrait | 79 | Private | Has one pending follow request |
| Follow request requester | Bora Tekin | bora_request | Ankara / Yenimahalle | Koşu ve hafta sonu outdoor etkinlikleri arıyor. | Friendly runner portrait | 61 | Public | Sent pending follow request to private profile |
| New empty user | Ali Yeni | aliyeni | Bursa / Nilüfer | Profili yeni tamamlandı. | Simple placeholder avatar | 50 | Public | No follows, events, posts, or notifications |

## Demo Events

Use relative dates so the script can be reused on any demo day.

| Title | Sport | City / District | Date / time | Capacity | Participant state | Expected join-request scenario | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Kadıköy Akşam Halı Saha | Football | İstanbul / Kadıköy | Demo day + 1, 20:00 | 10 | Host + 6 approved | Pending requester sends request, host approves | Active/upcoming |
| Beşiktaş 3x3 Basket | Basketball | İstanbul / Beşiktaş | Demo day + 2, 19:30 | 6 | Host + 4 approved | One open slot, approved participant joins | Active/upcoming |
| Sahil Voleybol Buluşması | Volleyball | İzmir / Karşıyaka | Demo day + 3, 18:00 | 8 | Host + 5 approved | Rejected requester is declined | Active/upcoming |
| Sabah Koşu Ekibi | Running | Ankara / Çankaya | Demo day + 1, 07:30 | 12 | Host + 3 approved | New empty user sends first request | Active/upcoming |
| Boğaz Bisiklet Turu | Cycling | İstanbul / Sarıyer | Demo day + 5, 09:00 | 15 | Host + 8 approved | Approved participant leaves later | Active/upcoming |
| Kortta Tanışma Maçı | Tennis | İstanbul / Bakırköy | Demo day + 4, 17:00 | 4 | Host + 2 approved | Pending requester cancels request | Active/upcoming |
| Belgrad Ormanı Yürüyüşü | Hiking/outdoor | İstanbul / Sarıyer | Demo day + 6, 10:00 | 14 | Host + 9 approved | Private profile visibility is shown from participant profile | Active/upcoming |
| Kahve Sonrası Mini Turnuva | Casual social/sport | Bursa / Nilüfer | Demo day + 2, 16:00 | 10 | Host + 5 approved | Feed post links to event detail | Active/upcoming |
| Dolu Kontenjan Maçı | Football | İstanbul / Ataşehir | Demo day + 1, 21:00 | 8 | Full: host + 7 approved | Join button shows full-capacity state | Active/upcoming |
| Geçen Haftanın Basket Maçı | Basketball | İstanbul / Beşiktaş | Demo day - 7, 20:00 | 8 | Historical approved users | Can be viewed, cannot be joined | Past |

## Demo Feed Posts

| Post idea | Owner | Purpose |
| --- | --- | --- |
| Event-linked post for Kadıköy Akşam Halı Saha | Emir Kaya | Opens event detail from feed. |
| Gallery-style post with match photos | Zeynep Acar | Shows gallery and image viewer. |
| Sport result post: "8-6 bitti, güzel maç!" | Deniz Arslan | Shows likes/comments on a normal post. |
| Looking-for-player post: "Bu akşam 1 kişi eksik" | Emir Kaya | Demonstrates fast social coordination. |
| Comment-heavy post | Zeynep Acar | Demonstrates comments, likes, and long text wrapping. |
| Follow demo post from social user | Zeynep Acar | Shows public-account direct follow from social surfaces. |
| Private profile visibility post | Elif Sarı | Non-followers can see basic profile but locked gallery/events. |
| Follow request demo post | Bora Tekin | Opens private profile and sends follow request. |
| Archived gallery item demo | Elif Sarı | Owner sees lock overlay, others do not see the item. |
| Safe report/block demo post | Can Demir | Uses harmless copy to demonstrate report/block controls. |

## Demo Notifications

| Type | Scenario | Expected behavior |
| --- | --- | --- |
| event_join_request | Mert requests Kadıköy Akşam Halı Saha | Host sees a new join request notification. |
| event_join_approved | Host approves Deniz or Mert | Requester sees approval and can open event detail. |
| event_join_rejected | Host rejects Can | Requester sees rejection without private participant data. |
| event_join_cancelled | Mert cancels a pending tennis request | Host sees cancellation notification. |
| event_left | Deniz leaves Boğaz Bisiklet Turu | Host sees participant-left notification. |
| follow | Zeynep follows Emir's public profile | Emir sees "Yeni takipçi" and can open profile. |
| follow_request | Bora requests to follow Elif's private profile | Elif sees "Takip isteği" with Onayla/Reddet actions. |
| follow_request_approved | Elif approves Bora | Bora sees "Takip isteğin onaylandı." |
| follow_request_rejected | Elif rejects a request | Requester sees "Takip isteğin reddedildi." |
| system | Demo system notice | Shows general in-app notification copy. |

## Setup Notes

- Use staging/test accounts only.
- Keep all demo passwords outside this document.
- Prepare one public account that can be followed instantly.
- Prepare one private account with one pending follow request.
- Prepare one requester that can be approved and one that can be rejected if the demo needs both paths.
- Prepare at least one archived gallery item owned by the private account.
- Prepare one true empty user to demonstrate empty profile, feed, and list states.
