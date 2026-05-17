import 'package:flutter/material.dart';

class SportTypes {
  const SportTypes._();

  static const other = 'Diğer';

  static const values = [
    other,
    'Futbol',
    'Basketbol',
    'Tenis',
    'Voleybol',
    'Koşu',
    'Yürüyüş',
    'Bisiklet',
    'Yoga',
    'Yüzme',
    'Fitness',
    'Padel',
    'Masa Tenisi',
    'Badminton',
  ];
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
  if (value.contains('yoga')) return Icons.self_improvement;
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
      value.contains('trekking')) {
    return Icons.hiking;
  }
  if (value.contains('badminton')) return Icons.sports_tennis;
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
