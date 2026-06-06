import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/error_messages.dart';
import 'profile_badges.dart';
import 'profile_models.dart';
import 'profile_service.dart';

enum ProfileStatus { initial, loading, success, error }

class ProfileState {
  const ProfileState({required this.status, this.profile, this.message});

  const ProfileState.initial()
    : status = ProfileStatus.initial,
      profile = null,
      message = null;

  final ProfileStatus status;
  final Profile? profile;
  final String? message;

  bool get isLoading => status == ProfileStatus.loading;
  bool get isProfileCompleted => profile?.hasCoreIdentity ?? false;
  bool get canCreateEvent =>
      EventProfileRequirements.hasRequiredFields(profile);
  bool get canRequestToJoinEvent =>
      EventProfileRequirements.hasRequiredFields(profile);

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

final publicProfileDetailProvider =
    FutureProvider.family<PublicProfileDetail?, String>((ref, userId) {
      return ref.watch(profileServiceProvider).fetchPublicProfileDetail(userId);
    });

final publicProfileGalleryProvider =
    FutureProvider.family<List<PublicProfileGalleryItem>, String>((
      ref,
      userId,
    ) {
      return ref
          .watch(profileServiceProvider)
          .fetchPublicProfileGallery(userId);
    });

final publicProfileEventHistoryProvider =
    FutureProvider.family<List<PublicProfileEventHistoryItem>, String>((
      ref,
      userId,
    ) {
      return ref
          .watch(profileServiceProvider)
          .fetchPublicProfileEventHistory(userId);
    });

final profileBadgesProvider = FutureProvider.family<List<ProfileBadge>, String>(
  (ref, userId) {
    return ref.watch(profileServiceProvider).fetchProfileBadges(userId);
  },
);

class ProfileController extends StateNotifier<ProfileState> {
  ProfileController(this._profileService) : super(const ProfileState.initial());

  final ProfileService _profileService;

  Future<void> loadMyProfile() async {
    state = state.copyWith(status: ProfileStatus.loading);

    try {
      final profile = await _profileService.getMyProfile();
      state = ProfileState(status: ProfileStatus.success, profile: profile);
    } catch (error) {
      state = ProfileState(
        status: ProfileStatus.error,
        message: friendlyErrorMessage(error),
      );
    }
  }

  Future<void> refreshMyProfile() => loadMyProfile();

  Future<Profile?> createEmptyProfileIfMissing() async {
    state = state.copyWith(status: ProfileStatus.loading);

    try {
      final profile = await _profileService.createEmptyProfileIfMissing();
      state = ProfileState(status: ProfileStatus.success, profile: profile);
      return profile;
    } catch (error) {
      state = ProfileState(
        status: ProfileStatus.error,
        message: friendlyErrorMessage(error),
      );
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
      state = ProfileState(
        status: ProfileStatus.error,
        message: friendlyErrorMessage(error),
      );
      return null;
    }
  }

  Future<bool> updatePrivacy({required bool isPrivate}) async {
    state = state.copyWith(status: ProfileStatus.loading);

    try {
      final profile = await _profileService.updateMyProfilePrivacy(
        isPrivate: isPrivate,
      );
      state = ProfileState(status: ProfileStatus.success, profile: profile);
      return true;
    } catch (error) {
      state = ProfileState(
        status: ProfileStatus.error,
        profile: state.profile,
        message: friendlyErrorMessage(error),
      );
      return false;
    }
  }

  Future<bool> switchAccountType(String accountType) async {
    state = state.copyWith(status: ProfileStatus.loading);

    try {
      final profile = await _profileService.updateMyAccountType(accountType);
      state = ProfileState(status: ProfileStatus.success, profile: profile);
      return true;
    } catch (error) {
      state = ProfileState(
        status: ProfileStatus.error,
        profile: state.profile,
        message: accountType == ProfileAccountType.user
            ? 'Hesap türü değiştirilemedi. Tekrar dene.'
            : friendlyErrorMessage(error),
      );
      return false;
    }
  }

  Future<bool> requestAccountDeletion() async {
    state = state.copyWith(status: ProfileStatus.loading);

    try {
      await _profileService.requestMyAccountDeletion();
      final profile = await _profileService.getMyProfile();
      state = ProfileState(status: ProfileStatus.success, profile: profile);
      return true;
    } catch (error) {
      state = ProfileState(
        status: ProfileStatus.error,
        profile: state.profile,
        message: friendlyErrorMessage(error),
      );
      return false;
    }
  }

  Future<String?> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
    String? contentType,
  }) async {
    state = state.copyWith(status: ProfileStatus.loading);

    try {
      return await _profileService.uploadAvatar(
        bytes: bytes,
        fileName: fileName,
        contentType: contentType,
      );
    } catch (error) {
      state = ProfileState(
        status: ProfileStatus.error,
        profile: state.profile,
        message: friendlyErrorMessage(error),
      );
      return null;
    }
  }
}
