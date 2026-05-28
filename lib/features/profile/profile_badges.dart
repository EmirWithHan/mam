import 'package:flutter/material.dart';

enum ProfileBadgeStatus { earned, locked, upcoming }

class ProfileBadge {
  const ProfileBadge({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.status,
    this.earnedAt,
    this.sortOrder = 0,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
  final ProfileBadgeStatus status;
  final DateTime? earnedAt;
  final int sortOrder;

  bool get isEarned => status == ProfileBadgeStatus.earned;

  factory ProfileBadge.fromJson(Map<String, dynamic> json) {
    final earnedAt = _dateTimeFromJson(json['earned_at']);
    return ProfileBadge(
      id: json['id'].toString(),
      label: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      icon: _iconForKey(json['icon_key'] as String?),
      status: earnedAt == null
          ? ProfileBadgeStatus.locked
          : ProfileBadgeStatus.earned,
      earnedAt: earnedAt,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class ProfileBadgeCatalog {
  const ProfileBadgeCatalog._();

  static const previewLimit = 5;

  static const upcomingBadges = [
    ProfileBadge(
      id: 'team_player',
      label: 'Takım Oyuncusu',
      description: 'Takım sporları rozetleri sonraki kurallarla açılacak.',
      icon: Icons.handshake_outlined,
      status: ProfileBadgeStatus.upcoming,
      sortOrder: 90,
    ),
    ProfileBadge(
      id: 'early_joiner',
      label: 'Erken Katılan',
      description: 'Erken katılım sinyalleri sonraki rozet altyapısına bağlı.',
      icon: Icons.bolt_outlined,
      status: ProfileBadgeStatus.upcoming,
      sortOrder: 100,
    ),
  ];

  static List<ProfileBadge> fallbackCatalog() {
    return const [
      ProfileBadge(
        id: 'first_step',
        label: 'İlk Adım',
        description: 'Profilini tamamladı.',
        icon: Icons.flag_outlined,
        status: ProfileBadgeStatus.locked,
        sortOrder: 10,
      ),
      ProfileBadge(
        id: 'first_event',
        label: 'İlk Etkinlik',
        description: 'İlk etkinliğine katıldı.',
        icon: Icons.event_available_outlined,
        status: ProfileBadgeStatus.locked,
        sortOrder: 20,
      ),
      ProfileBadge(
        id: 'reliable_participant',
        label: 'Güvenilir Katılımcı',
        description: 'Toplulukta güven kazandı.',
        icon: Icons.verified_outlined,
        status: ProfileBadgeStatus.locked,
        sortOrder: 30,
      ),
      ProfileBadge(
        id: 'active_player',
        label: 'Aktif Oyuncu',
        description: 'Birden fazla etkinlikte yer aldı.',
        icon: Icons.directions_run,
        status: ProfileBadgeStatus.locked,
        sortOrder: 40,
      ),
      ProfileBadge(
        id: 'organizer',
        label: 'Organizatör',
        description: 'Etkinlik organize etti.',
        icon: Icons.groups_2_outlined,
        status: ProfileBadgeStatus.locked,
        sortOrder: 50,
      ),
      ProfileBadge(
        id: 'social',
        label: 'Sosyal',
        description: 'Toplulukta aktif paylaşım yaptı.',
        icon: Icons.forum_outlined,
        status: ProfileBadgeStatus.locked,
        sortOrder: 60,
      ),
    ];
  }

  static List<ProfileBadge> withUpcoming(List<ProfileBadge> badges) {
    final existingIds = badges.map((badge) => badge.id).toSet();
    return [
      ...badges,
      ...upcomingBadges.where((badge) => !existingIds.contains(badge.id)),
    ]..sort(_sortBadges);
  }

  static List<ProfileBadge> preview(List<ProfileBadge> badges) {
    return badges.where((badge) => badge.isEarned).take(previewLimit).toList();
  }
}

int _sortBadges(ProfileBadge a, ProfileBadge b) {
  if (a.isEarned != b.isEarned) return a.isEarned ? -1 : 1;
  if (a.status == ProfileBadgeStatus.upcoming &&
      b.status != ProfileBadgeStatus.upcoming) {
    return 1;
  }
  if (b.status == ProfileBadgeStatus.upcoming &&
      a.status != ProfileBadgeStatus.upcoming) {
    return -1;
  }
  final order = a.sortOrder.compareTo(b.sortOrder);
  if (order != 0) return order;
  return a.id.compareTo(b.id);
}

DateTime? _dateTimeFromJson(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

IconData _iconForKey(String? key) {
  return switch (key) {
    'flag' => Icons.flag_outlined,
    'event' => Icons.event_available_outlined,
    'verified' => Icons.verified_outlined,
    'run' => Icons.directions_run,
    'groups' => Icons.groups_2_outlined,
    'chat' => Icons.forum_outlined,
    'bolt' => Icons.bolt_outlined,
    'team' => Icons.handshake_outlined,
    _ => Icons.workspace_premium_outlined,
  };
}
