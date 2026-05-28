import 'package:flutter/material.dart';

import 'profile_activity_models.dart';
import 'profile_models.dart';

enum ProfileBadgeStatus { earned, locked, upcoming }

class ProfileBadge {
  const ProfileBadge({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.status,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
  final ProfileBadgeStatus status;

  bool get isEarned => status == ProfileBadgeStatus.earned;
}

class ProfileBadgeCatalog {
  const ProfileBadgeCatalog._();

  static const previewLimit = 5;

  static List<ProfileBadge> forProfile({
    Profile? profile,
    PublicProfileDetail? publicProfile,
    List<ProfileActivityEvent> events = const [],
    List<PublicProfileEventHistoryItem> publicEvents = const [],
  }) {
    final trustScore =
        profile?.trustScore ??
        publicProfile?.trustScore ??
        profile?.trustScoreValue;
    final completed = profile?.isProfileCompleted ?? false;
    final allEventsCount = events.length + publicEvents.length;
    final hostedEvents =
        events.where((event) => event.isHost).length +
        publicEvents.where((event) => event.role == 'host').length;

    return [
      ProfileBadge(
        id: 'first_event',
        label: 'İlk Etkinlik',
        description:
            'İlk etkinlik katılımı veya ev sahipliği tamamlandığında açılır.',
        icon: Icons.flag_outlined,
        status: allEventsCount > 0
            ? ProfileBadgeStatus.earned
            : ProfileBadgeStatus.locked,
      ),
      ProfileBadge(
        id: 'reliable_participant',
        label: 'Güvenilir Katılımcı',
        description: 'Güven puanı güçlendikçe kazanılır.',
        icon: Icons.verified_outlined,
        status: (trustScore ?? 0) >= 70
            ? ProfileBadgeStatus.earned
            : ProfileBadgeStatus.locked,
      ),
      ProfileBadge(
        id: 'active_player',
        label: 'Aktif Oyuncu',
        description: 'Birden fazla etkinlik hareketiyle açılır.',
        icon: Icons.directions_run,
        status: allEventsCount >= 3
            ? ProfileBadgeStatus.earned
            : ProfileBadgeStatus.locked,
      ),
      ProfileBadge(
        id: 'organizer',
        label: 'Organizatör',
        description: 'Etkinlik oluşturan kullanıcılar için.',
        icon: Icons.groups_2_outlined,
        status: hostedEvents > 0
            ? ProfileBadgeStatus.earned
            : ProfileBadgeStatus.locked,
      ),
      ProfileBadge(
        id: 'team_player',
        label: 'Takım Oyuncusu',
        description: 'Etkinlik döngüsüne düzenli katkıyla açılır.',
        icon: Icons.handshake_outlined,
        status: completed
            ? ProfileBadgeStatus.locked
            : ProfileBadgeStatus.upcoming,
      ),
      const ProfileBadge(
        id: 'social',
        label: 'Sosyal',
        description: 'Sosyal etkileşim rozetleri sonraki sürümde genişleyecek.',
        icon: Icons.forum_outlined,
        status: ProfileBadgeStatus.upcoming,
      ),
      const ProfileBadge(
        id: 'early_joiner',
        label: 'Erken Katılan',
        description:
            'Erken katılım sinyalleri sonraki rozet altyapısına bağlı.',
        icon: Icons.bolt_outlined,
        status: ProfileBadgeStatus.upcoming,
      ),
    ];
  }

  static List<ProfileBadge> preview(List<ProfileBadge> badges) {
    return badges.where((badge) => badge.isEarned).take(previewLimit).toList();
  }
}
