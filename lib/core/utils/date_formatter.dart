class DateFormatter {
  const DateFormatter._();

  static String shortDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  static String dateTime(DateTime value) {
    return '${shortDate(value)} ${time(value)}';
  }

  static String time(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String longDate(DateTime value) {
    return '${value.day} ${_turkishMonth(value.month)} ${value.year}';
  }

  static String shortMonthDate(DateTime value) {
    return '${value.day} ${_shortTurkishMonth(value.month)} ${value.year}';
  }

  static String formatEventDateTime(DateTime value) {
    return dateTime(value);
  }

  static String turkishEventDateTime(DateTime value) {
    return '${longDate(value)}, ${time(value)}';
  }

  static DateTime? parseTurkishDate(String value) {
    final match = RegExp(
      r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$',
    ).firstMatch(value.trim());
    if (match == null) return null;

    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);
    if (day == null || month == null || year == null) return null;

    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  static String _turkishMonth(int month) {
    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    return months[month - 1];
  }

  static String _shortTurkishMonth(int month) {
    const months = [
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];
    return months[month - 1];
  }

  static String relativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inSeconds < 1) return 'Şimdi';
    if (difference.inSeconds < 60) return '${difference.inSeconds}sn';
    if (difference.inMinutes < 60) return '${difference.inMinutes}dk';
    if (difference.inHours < 24) return '${difference.inHours}sa';
    if (difference.inDays < 7) return '${difference.inDays}g';
    final weeks = (difference.inDays / 7).floor();
    if (weeks < 4) return '${weeks}h';
    return shortMonthDate(date);
  }
}
