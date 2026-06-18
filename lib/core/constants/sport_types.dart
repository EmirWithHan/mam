import 'package:flutter/material.dart';

class SportTypes {
  const SportTypes._();

  static const other = 'Diğer';

  static const values = [
    'Futbol',
    'Basketbol',
    'Voleybol',
    'Tenis',
    'Padel',
    'Fitness',
    'Yoga',
    'Pilates',
    'Koşu',
    'Bisiklet',
    'Yüzme',
    'Masa tenisi',
    'Dövüş sporları',
    'Dans',
    'Kamp',
    'Paintball',
    'Balık tutma',
    'Doğa yürüyüşü',
    'Trekking',
    'Piknik',
    'Bowling',
    'Bilardo',
    'Karting',
    'Kayak / Snowboard',
    'Tırmanış',
    'Satranç',
    'Masa oyunları',
    other,
  ];
}

class EventCoverStyle {
  const EventCoverStyle({
    required this.label,
    required this.icon,
    required this.startColor,
    required this.endColor,
    required this.accentColor,
  });

  final String label;
  final IconData icon;
  final Color startColor;
  final Color endColor;
  final Color accentColor;
}

String sportLabelFor(String? sportType) {
  final value = _normalizeSportType(sportType);

  if (value.contains('football') || value.contains('futbol')) return 'Futbol';
  if (value.contains('basketball') || value.contains('basketbol')) {
    return 'Basketbol';
  }
  if (value.contains('volleyball') || value.contains('voleybol')) {
    return 'Voleybol';
  }
  if (value.contains('running') || value.contains('kosu')) return 'Koşu';
  if (value.contains('cycling') || value.contains('bisiklet')) {
    return 'Bisiklet';
  }
  if (value.contains('tennis') ||
      value.contains('tenis') ||
      value.contains('padel')) {
    return 'Tenis';
  }
  if (value.contains('hiking') ||
      value.contains('outdoor') ||
      value.contains('doga') ||
      value.contains('trekking') ||
      value.contains('yuruyus') ||
      value.contains('kamp') ||
      value.contains('piknik') ||
      value.contains('balik')) {
    return 'Outdoor';
  }

  final trimmed = sportType?.trim();
  if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  return 'Spor';
}

EventCoverStyle eventCoverStyleForSport(String? sportType) {
  final value = _normalizeSportType(sportType);

  if (value.contains('football') || value.contains('futbol')) {
    return const EventCoverStyle(
      label: 'Futbol',
      icon: Icons.sports_soccer,
      startColor: Color(0xFF2E9B68),
      endColor: Color(0xFF123D2D),
      accentColor: Color(0xFFFFE4E1),
    );
  }
  if (value.contains('basketball') || value.contains('basketbol')) {
    return const EventCoverStyle(
      label: 'Basketbol',
      icon: Icons.sports_basketball,
      startColor: Color(0xFFE8762F),
      endColor: Color(0xFF6E2E12),
      accentColor: Color(0xFFFFD966),
    );
  }
  if (value.contains('volleyball') || value.contains('voleybol')) {
    return const EventCoverStyle(
      label: 'Voleybol',
      icon: Icons.sports_volleyball,
      startColor: Color(0xFF7CB9E8),
      endColor: Color(0xFF315B82),
      accentColor: Color(0xFFFFE4E1),
    );
  }
  if (value.contains('running') || value.contains('kosu')) {
    return const EventCoverStyle(
      label: 'Koşu',
      icon: Icons.directions_run,
      startColor: Color(0xFFFF7E79),
      endColor: Color(0xFF9B3A49),
      accentColor: Color(0xFFFFFFFF),
    );
  }
  if (value.contains('cycling') || value.contains('bisiklet')) {
    return const EventCoverStyle(
      label: 'Bisiklet',
      icon: Icons.directions_bike,
      startColor: Color(0xFF43A6A0),
      endColor: Color(0xFF1D4D58),
      accentColor: Color(0xFFFFD966),
    );
  }
  if (value.contains('tennis') ||
      value.contains('tenis') ||
      value.contains('padel')) {
    return const EventCoverStyle(
      label: 'Tenis',
      icon: Icons.sports_tennis,
      startColor: Color(0xFFB7D94E),
      endColor: Color(0xFF4B6F28),
      accentColor: Color(0xFFFFFFFF),
    );
  }
  if (value.contains('hiking') ||
      value.contains('outdoor') ||
      value.contains('doga') ||
      value.contains('trekking') ||
      value.contains('yuruyus') ||
      value.contains('kamp') ||
      value.contains('piknik') ||
      value.contains('balik')) {
    return const EventCoverStyle(
      label: 'Outdoor',
      icon: Icons.hiking,
      startColor: Color(0xFF6DAF7A),
      endColor: Color(0xFF355B44),
      accentColor: Color(0xFFFFF5CF),
    );
  }

  return const EventCoverStyle(
    label: 'Spor',
    icon: Icons.sports_handball,
    startColor: Color(0xFFFF7E79),
    endColor: Color(0xFF7CB9E8),
    accentColor: Color(0xFFFFFFFF),
  );
}

IconData sportIconFor(String? sportType) {
  final value = _normalizeSportType(sportType);

  if (value.contains('football') || value.contains('futbol')) {
    return Icons.sports_soccer;
  }
  if (value.contains('basketball') || value.contains('basketbol')) {
    return Icons.sports_basketball;
  }
  if (value.contains('tennis') ||
      value.contains('tenis') ||
      value.contains('padel')) {
    return Icons.sports_tennis;
  }
  if (value.contains('volleyball') || value.contains('voleybol')) {
    return Icons.sports_volleyball;
  }
  if (value.contains('yoga') || value.contains('pilates')) {
    return Icons.self_improvement;
  }
  if (value.contains('running') || value.contains('kosu')) {
    return Icons.directions_run;
  }
  if (value.contains('swimming') || value.contains('yuzme')) {
    return Icons.pool;
  }
  if (value.contains('walking') || value.contains('yuruyus')) {
    return Icons.directions_walk;
  }
  if (value.contains('cycling') || value.contains('bisiklet')) {
    return Icons.directions_bike;
  }
  if (value.contains('fitness') || value.contains('gym')) {
    return Icons.fitness_center;
  }
  if (value.contains('hiking') ||
      value.contains('doga') ||
      value.contains('trekking') ||
      value.contains('yuruyus')) {
    return Icons.hiking;
  }
  if (value.contains('badminton') || value.contains('masa tenisi')) {
    return Icons.sports_tennis;
  }
  if (value.contains('dovus') || value.contains('combat')) {
    return Icons.sports_martial_arts;
  }
  if (value.contains('dans') || value.contains('dance')) {
    return Icons.music_note;
  }
  if (value.contains('kamp') || value.contains('camp')) {
    return Icons.explore;
  }
  if (value.contains('paintball')) {
    return Icons.adjust;
  }
  if (value.contains('balik') || value.contains('fishing')) {
    return Icons.waves;
  }
  if (value.contains('piknik') || value.contains('picnic')) {
    return Icons.outdoor_grill;
  }
  if (value.contains('bowling')) {
    return Icons.adjust;
  }
  if (value.contains('bilardo') || value.contains('billiards')) {
    return Icons.lens;
  }
  if (value.contains('karting') || value.contains('race')) {
    return Icons.directions_car;
  }
  if (value.contains('kayak') ||
      value.contains('ski') ||
      value.contains('snowboard')) {
    return Icons.downhill_skiing;
  }
  if (value.contains('tirmanis') || value.contains('climbing')) {
    return Icons.terrain;
  }
  if (value.contains('satranc') || value.contains('chess')) {
    return Icons.extension;
  }
  if (value.contains('board') ||
      value.contains('masa oyun') ||
      value.contains('game')) {
    return Icons.casino;
  }
  if (value.contains('other') || value.contains('diger')) {
    return Icons.sports_handball;
  }

  return Icons.sports_handball;
}

String _normalizeSportType(String? value) {
  return (value ?? '')
      .trim()
      .toLowerCase()
      .replaceAll('ç', 'c')
      .replaceAll('ğ', 'g')
      .replaceAll('ı', 'i')
      .replaceAll('i̇', 'i')
      .replaceAll('ö', 'o')
      .replaceAll('ş', 's')
      .replaceAll('ü', 'u')
      .replaceAll('Ã§', 'c')
      .replaceAll('ÄŸ', 'g')
      .replaceAll('Ä±', 'i')
      .replaceAll('Ã¶', 'o')
      .replaceAll('ÅŸ', 's')
      .replaceAll('Ã¼', 'u');
}
