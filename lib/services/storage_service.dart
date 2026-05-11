import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class StorageService {
  const StorageService();

  static const postImagesBucket = 'post-images';

  Future<String> uploadPostImage({
    required Uint8List bytes,
    required String fileName,
    String? contentType,
  }) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to upload post images.');
    }

    final safeFileName = fileName
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path =
        '$userId/${DateTime.now().millisecondsSinceEpoch}_$safeFileName';

    await SupabaseService.client.storage.from(postImagesBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );

    return SupabaseService.client.storage
        .from(postImagesBucket)
        .getPublicUrl(path);
  }
}
