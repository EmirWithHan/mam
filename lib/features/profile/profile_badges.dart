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

  static List<ProfileBadge> fallbackCatalog() {
    return const [
      ProfileBadge(
        id: 'onayli_profil',
        label: 'Onaylı profil',
        description: 'Profil bilgilerini eksiksiz tamamladı.',
        icon: Icons.verified_outlined,
        status: ProfileBadgeStatus.locked,
        sortOrder: 20,
      ),
    ];
  }

  static List<ProfileBadge> withUpcoming(List<ProfileBadge> badges) {
    return List<ProfileBadge>.from(badges)..sort(_sortBadges);
  }

  static List<ProfileBadge> launchVisible(List<ProfileBadge> badges) {
    return badges;
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
    'verified_user' => Icons.verified_user_outlined,
    'run' => Icons.directions_run,
    'group' => Icons.group_outlined,
    'groups' => Icons.groups_outlined,
    'workspace_premium' => Icons.workspace_premium_outlined,
    'home' => Icons.home_outlined,
    'military_tech' => Icons.military_tech_outlined,
    'sports_soccer' => Icons.sports_soccer,
    'directions_run' => Icons.directions_run,
    'pool' => Icons.pool,
    'sports_tennis' => Icons.sports_tennis,
    'category' => Icons.category_outlined,
    'schedule' => Icons.schedule_outlined,
    'explore' => Icons.explore_outlined,
    'terrain' => Icons.terrain_outlined,
    'hiking' => Icons.hiking,
    'casino' => Icons.casino_outlined,
    'fitness_center' => Icons.fitness_center,
    'sports_handball' => Icons.sports_handball,
    'music_note' => Icons.music_note,
    'directions_bike' => Icons.directions_bike,
    'bolt' => Icons.bolt,
    'star' => Icons.star_outline,
    'trending_up' => Icons.trending_up,
    'chat' => Icons.forum_outlined,
    'team' => Icons.handshake_outlined,
    _ => Icons.workspace_premium_outlined,
  };
}
