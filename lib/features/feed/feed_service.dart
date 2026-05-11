import '../../services/storage_service.dart';
import '../../services/supabase_service.dart';
import 'feed_models.dart';

class FeedService {
  const FeedService({StorageService storageService = const StorageService()})
      : _storageService = storageService;

  final StorageService _storageService;

  Future<List<Post>> fetchPosts() async {
    final data = await SupabaseService.client
        .from('posts')
        .select()
        .order('created_at', ascending: false);

    return data.map(Post.fromJson).toList();
  }

  Future<Post> createPost(CreatePostInput input) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to create a post.');
    }

    final imageUrl = await _storageService.uploadPostImage(
      bytes: input.imageBytes,
      fileName: input.fileName,
      contentType: input.contentType,
    );

    final data = <String, dynamic>{
      'user_id': userId,
      'image_url': imageUrl,
      'caption': _nullableTrim(input.caption),
    };

    final eventId = _nullableTrim(input.eventId);
    if (eventId != null) {
      data['event_id'] = eventId;
    }

    final created = await SupabaseService.client
        .from('posts')
        .insert(data)
        .select()
        .single();

    return Post.fromJson(created);
  }
}

String? _nullableTrim(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
