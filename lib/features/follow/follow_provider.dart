import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/error_messages.dart';
import '../home/home_feed_provider.dart';
import '../profile/profile_follow_list_provider.dart';
import '../profile/profile_provider.dart';
import '../profile/public_profile_provider.dart';
import 'follow_models.dart';
import 'follow_service.dart';

class FollowState {
  const FollowState({this.loading = false, this.message, this.stats});

  final bool loading;
  final String? message;
  final FollowStats? stats;

  FollowState copyWith({
    bool? loading,
    String? message,
    FollowStats? stats,
    bool clearMessage = false,
  }) {
    return FollowState(
      loading: loading ?? this.loading,
      message: clearMessage ? null : message ?? this.message,
      stats: stats ?? this.stats,
    );
  }
}

final followServiceProvider = Provider<FollowService>((ref) {
  return const FollowService();
});

final followControllerProvider =
    StateNotifierProvider.family<FollowController, FollowState, String>((
      ref,
      targetUserId,
    ) {
      return FollowController(
        targetUserId: targetUserId,
        service: ref.watch(followServiceProvider),
        ref: ref,
      );
    });

class FollowController extends StateNotifier<FollowState> {
  FollowController({
    required this.targetUserId,
    required FollowService service,
    required Ref ref,
  }) : _service = service,
       _ref = ref,
       super(const FollowState());

  final String targetUserId;
  final FollowService _service;
  final Ref _ref;

  Future<void> loadStats() async {
    state = state.copyWith(loading: true, clearMessage: true);

    try {
      final stats = await _service.fetchFollowStats(targetUserId);
      state = state.copyWith(loading: false, stats: stats);
    } catch (error) {
      state = state.copyWith(
        loading: false,
        message: friendlyErrorMessage(error),
      );
    }
  }

  Future<void> followUser() async {
    state = state.copyWith(loading: true, clearMessage: true);

    try {
      await _service.followUser(targetUserId);
      final stats = await _service.fetchFollowStats(targetUserId);
      state = state.copyWith(loading: false, stats: stats);
      _refreshAfterMutation();
    } catch (error) {
      state = state.copyWith(loading: false, message: 'İstek gönderilemedi.');
    }
  }

  Future<void> unfollowUser() async {
    state = state.copyWith(loading: true, clearMessage: true);

    try {
      await _service.unfollowUser(targetUserId);
      final stats = await _service.fetchFollowStats(targetUserId);
      state = state.copyWith(loading: false, stats: stats);
      _refreshAfterMutation();
    } catch (error) {
      state = state.copyWith(
        loading: false,
        message: friendlyErrorMessage(error),
      );
    }
  }

  Future<void> toggleFollow() async {
    final currentlyFollowing = state.stats?.isFollowedByMe ?? false;
    final requestPending = state.stats?.hasPendingRequestByMe ?? false;
    state = state.copyWith(loading: true, clearMessage: true);

    try {
      await _service.toggleFollow(
        targetUserId: targetUserId,
        currentlyFollowing: currentlyFollowing,
        requestPending: requestPending,
      );
      final stats = await _service.fetchFollowStats(targetUserId);
      state = state.copyWith(loading: false, stats: stats);
      _refreshAfterMutation();
    } catch (error) {
      state = state.copyWith(
        loading: false,
        message: currentlyFollowing
            ? friendlyErrorMessage(error)
            : 'İstek gönderilemedi.',
      );
    }
  }

  void _refreshAfterMutation() {
    _ref.invalidate(publicProfileDetailProvider(targetUserId));
    _ref.invalidate(publicProfileGalleryProvider(targetUserId));
    _ref.invalidate(publicProfileEventHistoryProvider(targetUserId));
    _ref.invalidate(publicProfilePreviewProvider(targetUserId));
    _ref.invalidate(homeFeedProvider);

    final currentUserId = _service.currentUserId;
    if (currentUserId != null) {
      _ref.invalidate(
        profileFollowListControllerProvider(
          ProfileFollowListArgs(
            userId: currentUserId,
            type: ProfileFollowListType.following,
          ),
        ),
      );
    }
    _ref.invalidate(
      profileFollowListControllerProvider(
        ProfileFollowListArgs(
          userId: targetUserId,
          type: ProfileFollowListType.followers,
        ),
      ),
    );
  }
}
