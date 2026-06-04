class SupabasePageSizes {
  const SupabasePageSizes._();

  static const feed = 20;
  static const events = 20;
  static const notifications = 30;
  static const comments = 20;
  static const followList = 30;
  static const adminApplications = 20;
  static const gallery = 24;
}

List<T> appendUniqueByKey<T, K>(
  List<T> current,
  List<T> next,
  K Function(T item) keyOf,
) {
  final seen = current.map(keyOf).toSet();
  return [...current, ...next.where((item) => seen.add(keyOf(item)))];
}

bool pageHasMore(int loadedCount, int pageSize) => loadedCount == pageSize;
