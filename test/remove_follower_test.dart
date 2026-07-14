import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_a_man/features/follow/follow_service.dart';
import 'package:match_a_man/features/profile/profile_follow_list_provider.dart';
import 'package:match_a_man/features/profile/profile_models.dart';
import 'package:match_a_man/features/profile/profile_service.dart';

void main() {
  group('remove follower backend contract', () {
    final migration = File(
      'supabase/migrations/20260714120000_allow_users_to_remove_followers.sql',
    );

    test('uses canonical directional follows relationship', () {
      final sql = migration.readAsStringSync();
      final service = File(
        'lib/features/follow/follow_service.dart',
      ).readAsStringSync();
      final removeMethod = service.substring(
        service.indexOf('Future<void> removeFollower'),
        service.indexOf('Future<FollowActionResult?> toggleFollow'),
      );

      expect(sql, contains('on public.follows'));
      expect(removeMethod, contains(".eq('follower_id', followerId)"));
      expect(removeMethod, contains(".eq('following_id', userId)"));
      expect(removeMethod, isNot(contains('notifications')));
      expect(removeMethod, isNot(contains('blocks')));
    });

    test('RLS permits only a relationship participant to delete', () {
      final sql = migration.readAsStringSync();

      expect(sql, contains('to authenticated'));
      expect(sql, contains('follower_id = auth.uid()'));
      expect(sql, contains('or following_id = auth.uid()'));
      expect(sql, contains('Users can unfollow their own follows'));
      expect(sql, contains('revoke delete on table public.follows from anon'));
      expect(sql, isNot(contains('security definer')));
    });

    test('counts remain canonical query results without counter mutation', () {
      final followContract = File(
        'supabase/migrations/20260704100000_follow_request_privacy_refresh_alignment.sql',
      ).readAsStringSync();
      final sql = migration.readAsStringSync();

      expect(
        followContract,
        contains(
          'select count(*) from public.follows rows where rows.following_id',
        ),
      );
      expect(sql, isNot(contains('update public.profiles')));
      expect(sql, isNot(contains('insert into public.notifications')));
    });
  });

  group('remove follower controller', () {
    const ownerId = 'owner-1';
    const followerId = 'follower-1';
    const follower = PublicProfileFollowListItem(
      userId: followerId,
      username: 'follower',
      followsMe: true,
    );

    test('sends the follower id and removes the item after success', () async {
      final followService = _FakeFollowService(currentUserIdValue: ownerId);
      final controller = _controller(
        ownerId: ownerId,
        followService: followService,
        items: const [follower],
      );
      await controller.loadInitial();

      final success = await controller.removeFollower(follower);

      expect(success, isTrue);
      expect(followService.removedFollowerIds, [followerId]);
      expect(controller.state.items, isEmpty);
      expect(controller.state.removingUserIds, isEmpty);
    });

    test('keeps the item when backend removal fails', () async {
      final followService = _FakeFollowService(
        currentUserIdValue: ownerId,
        error: StateError('database detail'),
      );
      final controller = _controller(
        ownerId: ownerId,
        followService: followService,
        items: const [follower],
      );
      await controller.loadInitial();

      final success = await controller.removeFollower(follower);

      expect(success, isFalse);
      expect(controller.state.items, const [follower]);
      expect(controller.state.message, 'Takipçi çıkarılamadı. Tekrar dene.');
    });

    test('blocks duplicate removal while the first call is pending', () async {
      final pending = Completer<void>();
      final followService = _FakeFollowService(
        currentUserIdValue: ownerId,
        pending: pending,
      );
      final controller = _controller(
        ownerId: ownerId,
        followService: followService,
        items: const [follower],
      );
      await controller.loadInitial();

      final first = controller.removeFollower(follower);
      final second = await controller.removeFollower(follower);

      expect(second, isFalse);
      expect(followService.removedFollowerIds, [followerId]);
      pending.complete();
      expect(await first, isTrue);
    });

    test('rejects removal outside the owner followers list', () async {
      final followService = _FakeFollowService(currentUserIdValue: ownerId);
      final otherOwnerController = _controller(
        ownerId: 'other-owner',
        followService: followService,
        items: const [follower],
      );
      final followingController = _controller(
        ownerId: ownerId,
        type: ProfileFollowListType.following,
        followService: followService,
        items: const [follower],
      );

      expect(await otherOwnerController.removeFollower(follower), isFalse);
      expect(await followingController.removeFollower(follower), isFalse);
      expect(followService.removedFollowerIds, isEmpty);
    });

    test('UI keeps remove separate and requires confirmation', () {
      final page = File(
        'lib/features/profile/profile_follow_list_page.dart',
      ).readAsStringSync();

      expect(page, contains('widget.type == ProfileFollowListType.followers'));
      expect(page, contains('currentUserId == widget.userId'));
      expect(page, contains("title: 'Takipçiyi çıkar?'"));
      expect(page, contains("cancelLabel: 'Vazgeç'"));
      expect(page, contains('confirmed != true'));
      expect(page, contains("Text('Takipçilerden çıkar')"));
      expect(page, isNot(contains("Text('Engelle')")));
    });
  });
}

ProfileFollowListController _controller({
  required String ownerId,
  ProfileFollowListType type = ProfileFollowListType.followers,
  required _FakeFollowService followService,
  required List<PublicProfileFollowListItem> items,
}) {
  return ProfileFollowListController(
    args: ProfileFollowListArgs(userId: ownerId, type: type),
    profileService: _FakeProfileService(items),
    followService: followService,
  );
}

class _FakeProfileService extends ProfileService {
  const _FakeProfileService(this.items);

  final List<PublicProfileFollowListItem> items;

  @override
  Future<List<PublicProfileFollowListItem>> fetchFollowers(
    String userId, {
    int limit = 50,
    int offset = 0,
  }) async => items;

  @override
  Future<List<PublicProfileFollowListItem>> fetchFollowing(
    String userId, {
    int limit = 50,
    int offset = 0,
  }) async => items;
}

class _FakeFollowService extends FollowService {
  _FakeFollowService({
    required this.currentUserIdValue,
    this.error,
    this.pending,
  });

  final String? currentUserIdValue;
  final Object? error;
  final Completer<void>? pending;
  final removedFollowerIds = <String>[];

  @override
  String? get currentUserId => currentUserIdValue;

  @override
  Future<void> removeFollower(String followerId) async {
    removedFollowerIds.add(followerId);
    if (error != null) throw error!;
    await pending?.future;
  }
}
