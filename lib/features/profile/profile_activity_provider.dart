import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/error_messages.dart';
import 'profile_activity_models.dart';
import 'profile_activity_service.dart';

enum ProfileActivityStatus {
  initial,
  loading,
  success,
  error,
}

class ProfileActivityState {
  const ProfileActivityState({
    required this.status,
    this.galleryPosts = const [],
    this.events = const [],
    this.message,
  });

  const ProfileActivityState.initial()
      : status = ProfileActivityStatus.initial,
        galleryPosts = const [],
        events = const [],
        message = null;

  final ProfileActivityStatus status;
  final List<ProfileGalleryPost> galleryPosts;
  final List<ProfileActivityEvent> events;
  final String? message;

  bool get isLoading => status == ProfileActivityStatus.loading;

  ProfileActivityState copyWith({
    required ProfileActivityStatus status,
    List<ProfileGalleryPost>? galleryPosts,
    List<ProfileActivityEvent>? events,
    String? message,
  }) {
    return ProfileActivityState(
      status: status,
      galleryPosts: galleryPosts ?? this.galleryPosts,
      events: events ?? this.events,
      message: message,
    );
  }
}

final profileActivityServiceProvider = Provider<ProfileActivityService>((ref) {
  return const ProfileActivityService();
});

final profileActivityControllerProvider =
    StateNotifierProvider<ProfileActivityController, ProfileActivityState>(
  (ref) => ProfileActivityController(ref.watch(profileActivityServiceProvider)),
);

class ProfileActivityController extends StateNotifier<ProfileActivityState> {
  ProfileActivityController(this._activityService)
      : super(const ProfileActivityState.initial());

  final ProfileActivityService _activityService;

  Future<void> loadActivity() async {
    state = state.copyWith(status: ProfileActivityStatus.loading);

    try {
      final galleryPosts = await _activityService.fetchMyGalleryPosts();
      final events = await _activityService.fetchMyEvents();
      state = ProfileActivityState(
        status: ProfileActivityStatus.success,
        galleryPosts: galleryPosts,
        events: events,
      );
    } catch (error) {
      state = state.copyWith(
        status: ProfileActivityStatus.error,
        message: friendlyErrorMessage(error),
      );
    }
  }

  Future<void> refresh() => loadActivity();
}
