# Demo Data Plan

This plan describes safe, fictional demo data for the current Supabase-only MVP. Do not use real personal data, real phone numbers, or production user accounts.

## Demo Users

| Role | Display name | Username | City/District | Bio | Avatar suggestion | Trust score target | Demo role |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Host user | Kerem Yıldız | `kerem.host` | İstanbul / Kadıköy | Haftalık futbol ve koşu etkinlikleri düzenlerim. | Bright outdoor football portrait | 88-94 | Event host, approve/reject requests, chat/call gate demo |
| Approved participant | Mert Kaya | `mert.run` | İstanbul / Beşiktaş | Koşu, basketbol ve hafta sonu maçlarına varım. | Running track portrait | 78-86 | Approved participant, chat/call access, leave event |
| Pending requester | Ege Demir | `ege.pending` | İstanbul / Üsküdar | Yeni takımlar ve düzenli maç grupları arıyorum. | Casual gym portrait | 62-72 | Pending join request and cancel pending request |
| Rejected requester | Arda Çelik | `arda.tryagain` | İstanbul / Ataşehir | Futbol ve tenis denemeleri için buradayım. | Tennis court portrait | 50-60 | Rejected request state and friendly empty access |
| Social/feed-heavy user | Deniz Acar | `deniz.social` | İzmir / Karşıyaka | Spor sonrası kahve, maç yorumu ve fotoğraf paylaşmayı severim. | Volleyball or cycling portrait | 80-90 | Feed, gallery, follow, comments, likes |
| New empty user | Selin Koç | `selin.new` | Ankara / Çankaya | Profilini yeni tamamladı. | Simple neutral profile image | 40-55 | Empty profile, empty feed/profile states, first join request |

## Demo Events

Use dates relative to the demo day so the script stays fresh.

| Title | Sport | City/District | Date/time | Capacity | Current participant state | Expected join-request scenario |
| --- | --- | --- | --- | --- | --- | --- |
| Kadıköy Akşam Halı Saha | Futbol | İstanbul / Kadıköy | Demo day + 1, 20:30 | 10 total | Host + 6 approved, 1 pending | Pending requester sends/cancels request; host approves one request |
| Beşiktaş 3x3 Basket | Basketbol | İstanbul / Beşiktaş | Demo day + 2, 19:00 | 6 total | Host + 4 approved | Show almost-full capacity and approved participant list |
| Karşıyaka Sahil Voleybol | Voleybol | İzmir / Karşıyaka | Demo day + 3, 18:30 | 8 total | Host + 5 approved | Social user joins and receives approved notification |
| Sabah Tempo Koşusu | Koşu | Ankara / Çankaya | Demo day + 1, 07:30 | 12 total | Host + 3 approved | New user requests to join after profile completion |
| Pazar Bisiklet Turu | Bisiklet | İzmir / Bornova | Demo day + 4, 09:00 | 15 total | Host + 8 approved | Demonstrate filters and city/district selection |
| Kort Arkadaşı Aranıyor | Tenis | İstanbul / Ataşehir | Demo day + 5, 17:00 | 2 total | Host only | Demonstrate small-capacity event and full state after approval |
| Belgrad Ormanı Yürüyüşü | Doğa Yürüyüşü | İstanbul / Sarıyer | Demo day + 6, 10:00 | 20 total | Host + 10 approved | Demonstrate outdoor/social sport event detail |
| Maç Sonrası Sosyal Buluşma | Sosyal Spor | İstanbul / Kadıköy | Demo day + 2, 21:45 | 12 total | Host + 7 approved | Casual social/sport event and feed-linked post |

## Demo Feed Posts

| Post idea | Author | Linked entity | Purpose |
| --- | --- | --- | --- |
| "Kadıköy akşam maçı için iki kişi daha arıyoruz." | Kerem | Kadıköy Akşam Halı Saha | Event-linked post |
| "Sahil voleybolundan kareler." | Deniz | Gallery media | Gallery-style social post |
| "3x3 basket maç sonucu: son periyot efsaneydi." | Mert | Beşiktaş 3x3 Basket | Sport result post |
| "Tenis için düzenli partner arıyorum." | Arda | Kort Arkadaşı Aranıyor | Looking-for-player post |
| "Sabah koşusu temposu 6:00/km civarı olacak." | Selin | Sabah Tempo Koşusu | New user engagement |
| "Bisiklet turu için kask ve ışık unutmayın." | Deniz | Pazar Bisiklet Turu | Safety/info post |
| "Yürüyüş rotası ve buluşma noktası güncellendi." | Kerem | Belgrad Ormanı Yürüyüşü | Host update post |
| "Moderasyon demosu için raporlanabilir örnek içerik." | Demo-only account | None | Report/block flow, keep harmless and clearly fake |

## Demo Notifications

Prepare notification records through normal app flows where possible:

- `event_join_request`: Pending requester sends a request to Kerem's event.
- `event_join_approved`: Kerem approves Mert or Selin for an event.
- `event_join_rejected`: Kerem rejects Arda's request.
- `event_join_cancelled`: Ege cancels a pending request.
- `event_left`: Mert leaves an approved event.
- `follow`: Deniz follows Kerem or Selin.
- `system`: A harmless demo message such as "Kapalı beta demosuna hoş geldin."

## Safety Notes

- Use fictional names, bios, usernames, avatars, captions, and comments.
- Avoid real phone numbers, private addresses, or sensitive personal details.
- Prefer app UI flows over direct production writes.
- If seed data is needed later, create it for a staging Supabase project first.
