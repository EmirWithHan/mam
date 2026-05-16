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

class MyBlocksState {
  const MyBlocksState({
    this.loading = false,
    this.message,
    this.blocks = const [],
  });

  final bool loading;
  final String? message;
  final List<Block> blocks;

  MyBlocksState copyWith({
    bool? loading,
    String? message,
    List<Block>? blocks,
    bool clearMessage = false,
  }) {
    return MyBlocksState(
      loading: loading ?? this.loading,
      message: clearMessage ? null : message ?? this.message,
      blocks: blocks ?? this.blocks,
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
      ref: ref,
    );
  },
);

final myBlocksControllerProvider =
    StateNotifierProvider<MyBlocksController, MyBlocksState>((ref) {
  return MyBlocksController(
    service: ref.watch(blocksServiceProvider),
    ref: ref,
  );
});

class BlockController extends StateNotifier<BlockState> {
  BlockController({
    required this.targetUserId,
    required BlocksService service,
    required Ref ref,
  })  : _service = service,
        _ref = ref,
        super(const BlockState());

  final String targetUserId;
  final BlocksService _service;
  final Ref _ref;

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
      _ref.invalidate(myBlockedUserIdsProvider);
      return true;
    } catch (error) {
      state = state.copyWith(loading: false, message: '$error');
      return false;
    }
  }
}

class MyBlocksController extends StateNotifier<MyBlocksState> {
  MyBlocksController({
    required BlocksService service,
    required Ref ref,
  })  : _service = service,
        _ref = ref,
        super(const MyBlocksState());

  final BlocksService _service;
  final Ref _ref;

  Future<void> loadBlocks() async {
    state = state.copyWith(loading: true, clearMessage: true);

    try {
      final blocks = await _service.fetchMyBlocks();
      state = state.copyWith(loading: false, blocks: blocks);
    } catch (error) {
      state = state.copyWith(loading: false, message: '$error');
    }
  }

  Future<void> refreshBlocks() => loadBlocks();

  Future<bool> unblockUser(String targetUserId) async {
    state = state.copyWith(loading: true, clearMessage: true);

    try {
      await _service.unblockUser(targetUserId);
      _ref.invalidate(myBlockedUserIdsProvider);
      final blocks = await _service.fetchMyBlocks();
      state = state.copyWith(loading: false, blocks: blocks);
      return true;
    } catch (error) {
      state = state.copyWith(loading: false, message: '$error');
      return false;
    }
  }
}
