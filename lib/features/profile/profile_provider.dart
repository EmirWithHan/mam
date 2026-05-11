import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'profile_models.dart';
import 'profile_service.dart';

enum ProfileStatus {
  initial,
  loading,
  success,
  error,
}

class ProfileState {
  const ProfileState({
    required this.status,
    this.profile,
    this.message,
  });

  const ProfileState.initial()
      : status = ProfileStatus.initial,
        profile = null,
        message = null;

  final ProfileStatus status;
  final Profile? profile;
  final String? message;

  bool get isLoading => status == ProfileStatus.loading;
  bool get isProfileCompleted => profile?.isProfileCompleted ?? false;
  bool get canCreateEvent => isProfileCompleted;
  bool get canRequestToJoinEvent => isProfileCompleted;

  ProfileState copyWith({
    required ProfileStatus status,
    Profile? profile,
    String? message,
  }) {
    return ProfileState(
      status: status,
      profile: profile ?? this.profile,
      message: message,
    );
  }
}

final profileServiceProvider = Provider<ProfileService>((ref) {
  return const ProfileService();
});

final profileControllerProvider =
    StateNotifierProvider<ProfileController, ProfileState>((ref) {
  return ProfileController(ref.watch(profileServiceProvider));
});

class ProfileController extends StateNotifier<ProfileState> {
  ProfileController(this._profileService) : super(const ProfileState.initial());

  final ProfileService _profileService;

  Future<void> loadMyProfile() async {
    state = state.copyWith(status: ProfileStatus.loading);

    try {
      final profile = await _profileService.getMyProfile();
      state = ProfileState(status: ProfileStatus.success, profile: profile);
    } catch (error) {
      state = ProfileState(status: ProfileStatus.error, message: '$error');
    }
  }

  Future<Profile?> createEmptyProfileIfMissing() async {
    state = state.copyWith(status: ProfileStatus.loading);

    try {
      final profile = await _profileService.createEmptyProfileIfMissing();
      state = ProfileState(status: ProfileStatus.success, profile: profile);
      return profile;
    } catch (error) {
      state = ProfileState(status: ProfileStatus.error, message: '$error');
      return null;
    }
  }

  Future<Profile?> updateProfile(ProfileFormData formData) async {
    state = state.copyWith(status: ProfileStatus.loading);

    try {
      final profile = await _profileService.updateMyProfile(formData);
      state = ProfileState(status: ProfileStatus.success, profile: profile);
      return profile;
    } catch (error) {
      state = ProfileState(status: ProfileStatus.error, message: '$error');
      return null;
    }
  }
}
