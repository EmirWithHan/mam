import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/error_messages.dart';
import '../follow/follow_service.dart';
import 'profile_models.dart';
import 'profile_provider.dart';
import 'profile_service.dart';

enum ProfileFollowListType {
  followers,
  following;

  String get title {
    switch (this) {
      case ProfileFollowListType.followers:
        return 'Takipçiler';
      case ProfileFollowListType.following:
        return 'Takip Edilenler';
    }
  }

  String get emptyTitle {
    switch (this) {
      case ProfileFollowListType.followers:
        return 'Henüz takipçi yok.';
      case ProfileFollowListType.following:
        return 'Henüz kimse takip edilmiyor.';
    }
  }
}

class ProfileFollowListArgs {
  const ProfileFollowListArgs({required this.userId, required this.type});

  final String userId;
  final ProfileFollowListType type;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ProfileFollowListArgs &&
            other.userId == userId &&
            other.type == type;
  }

  @override
  int get hashCode => Object.hash(userId, type);
}

class ProfileFollowListState {
  const ProfileFollowListState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.message,
    this.togglingUserIds = const {},
  });

  final List<PublicProfileFollowListItem> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? message;
  final Set<String> togglingUserIds;

  bool get hasError => message != null;

  ProfileFollowListState copyWith({
    List<PublicProfileFollowListItem>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? message,
    bool clearMessage = false,
    Set<String>? togglingUserIds,
  }) {
    return ProfileFollowListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      message: clearMessage ? null : message ?? this.message,
      togglingUserIds: togglingUserIds ?? this.togglingUserIds,
    );
  }
}

final profileFollowListControllerProvider =
    StateNotifierProvider.family<
      ProfileFollowListController,
      ProfileFollowListState,
      ProfileFollowListArgs
    >((ref, args) {
      return ProfileFollowListController(
        args: args,
        profileService: ref.watch(profileServiceProvider),
        followService: const FollowService(),
      );
    });

class ProfileFollowListController
    extends StateNotifier<ProfileFollowListState> {
  ProfileFollowListController({
    required ProfileFollowListArgs args,
    required ProfileService profileService,
    required FollowService followService,
  }) : _args = args,
       _profileService = profileService,
       _followService = followService,
       super(const ProfileFollowListState());

  static const _pageSize = 30;

  final ProfileFollowListArgs _args;
  final ProfileService _profileService;
  final FollowService _followService;

  Future<void> loadInitial() async {
    if (state.isLoading) return;
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      clearMessage: true,
    );

    try {
      final items = await _fetchPage(offset: 0);
      state = ProfileFollowListState(
        items: items,
        hasMore: items.length == _pageSize,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        message: friendlyErrorMessage(error),
      );
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(clearMessage: true);

    try {
      final items = await _fetchPage(offset: 0);
      state = ProfileFollowListState(
        items: items,
        hasMore: items.length == _pageSize,
      );
    } catch (error) {
      state = state.copyWith(message: friendlyErrorMessage(error));
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true, clearMessage: true);

    try {
      final nextItems = await _fetchPage(offset: state.items.length);
      final existingIds = state.items.map((item) => item.userId).toSet();
      final mergedItems = [
        ...state.items,
        ...nextItems.where((item) => !existingIds.contains(item.userId)),
      ];

      state = state.copyWith(
        items: mergedItems,
        isLoadingMore: false,
        hasMore: nextItems.length == _pageSize,
      );
    } catch (error) {
      state = state.copyWith(
        isLoadingMore: false,
        message: friendlyErrorMessage(error),
      );
    }
  }

  Future<void> toggleFollow(PublicProfileFollowListItem item) async {
    if (state.togglingUserIds.contains(item.userId)) return;

    state = state.copyWith(
      togglingUserIds: {...state.togglingUserIds, item.userId},
      clearMessage: true,
    );

    final wasFollowing = item.isFollowingByMe;
    final wasPending = item.pendingFollowRequestByMe;

    try {
      final result = await _followService.toggleFollow(
        targetUserId: item.userId,
        currentlyFollowing: wasFollowing,
        requestPending: wasPending,
      );
      _updateItemFollowState(
        item.userId,
        isFollowing: result?.isFollowing ?? false,
        requestPending: result?.isRequested ?? false,
        followerDelta: wasFollowing
            ? -1
            : (result?.isFollowing ?? false)
            ? 1
            : 0,
      );
    } catch (error) {
      state = state.copyWith(message: friendlyErrorMessage(error));
    } finally {
      final togglingIds = {...state.togglingUserIds}..remove(item.userId);
      state = state.copyWith(togglingUserIds: togglingIds);
    }
  }

  Future<List<PublicProfileFollowListItem>> _fetchPage({required int offset}) {
    switch (_args.type) {
      case ProfileFollowListType.followers:
        return _profileService.fetchFollowers(
          _args.userId,
          limit: _pageSize,
          offset: offset,
        );
      case ProfileFollowListType.following:
        return _profileService.fetchFollowing(
          _args.userId,
          limit: _pageSize,
          offset: offset,
        );
    }
  }

  void _updateItemFollowState(
    String userId, {
    required bool isFollowing,
    required bool requestPending,
    required int followerDelta,
  }) {
    state = state.copyWith(
      items: [
        for (final item in state.items)
          if (item.userId == userId)
            item.copyWith(
              isFollowingByMe: isFollowing,
              pendingFollowRequestByMe: requestPending,
              followerCount: (item.followerCount + followerDelta)
                  .clamp(0, 1 << 31)
                  .toInt(),
            )
          else
            item,
      ],
    );
  }
}
