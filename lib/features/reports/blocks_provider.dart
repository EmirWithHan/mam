import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'blocks_models.dart';
import 'blocks_service.dart';

class BlockState {
  const BlockState({
    this.loading = false,
    this.message,
    this.userBlockState,
  });

  final bool loading;
  final String? message;
  final UserBlockState? userBlockState;

  BlockState copyWith({
    bool? loading,
    String? message,
    UserBlockState? userBlockState,
    bool clearMessage = false,
  }) {
    return BlockState(
      loading: loading ?? this.loading,
      message: clearMessage ? null : message ?? this.message,
      userBlockState: userBlockState ?? this.userBlockState,
    );
  }
}

final blocksServiceProvider = Provider<BlocksService>((ref) {
  return const BlocksService();
});

final myBlockedUserIdsProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(blocksServiceProvider).fetchMyBlockedUserIds();
});

final blockControllerProvider =
    StateNotifierProvider.family<BlockController, BlockState, String>(
  (ref, targetUserId) {
    return BlockController(
      targetUserId: targetUserId,
      service: ref.watch(blocksServiceProvider),
    );
  },
);

class BlockController extends StateNotifier<BlockState> {
  BlockController({
    required this.targetUserId,
    required BlocksService service,
  })  : _service = service,
        super(const BlockState());

  final String targetUserId;
  final BlocksService _service;

  Future<void> loadBlockState() async {
    state = state.copyWith(loading: true, clearMessage: true);

    try {
      final userId = _service.currentUserId;
      final isMe = userId == targetUserId;
      final isBlocked = isMe ? false : await _service.isUserBlocked(targetUserId);
      state = state.copyWith(
        loading: false,
        userBlockState: UserBlockState(
          targetUserId: targetUserId,
          isBlockedByMe: isBlocked,
          isMe: isMe,
        ),
      );
    } catch (error) {
      state = state.copyWith(loading: false, message: '$error');
    }
  }

  Future<bool> toggleBlock() async {
    final currentlyBlocked = state.userBlockState?.isBlockedByMe ?? false;
    state = state.copyWith(loading: true, clearMessage: true);

    try {
      await _service.toggleBlock(
        targetUserId: targetUserId,
        currentlyBlocked: currentlyBlocked,
      );
      final isBlocked = await _service.isUserBlocked(targetUserId);
      state = state.copyWith(
        loading: false,
        userBlockState: UserBlockState(
          targetUserId: targetUserId,
          isBlockedByMe: isBlocked,
          isMe: false,
        ),
      );
      return true;
    } catch (error) {
      state = state.copyWith(loading: false, message: '$error');
      return false;
    }
  }
}
