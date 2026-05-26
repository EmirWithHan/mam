class EventCallContact {
  const EventCallContact({required this.userId, this.firstName, this.phone});

  final String userId;
  final String? firstName;
  final String? phone;

  String get displayName {
    final parts = [
      firstName?.trim(),
    ].where((part) => part != null && part.isNotEmpty).cast<String>();

    final name = parts.join(' ');
    if (name.isNotEmpty) return name;
    return 'Member';
  }

  bool get hasPhone => phone?.trim().isNotEmpty ?? false;

  factory EventCallContact.fromJson(Map<String, dynamic> json) {
    return EventCallContact(
      userId: json['user_id'] as String,
      firstName: json['first_name'] as String?,
      phone: json['phone'] as String?,
    );
  }
}
