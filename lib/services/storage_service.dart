import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/error_messages.dart';
import 'supabase_service.dart';

class StorageService {
  const StorageService();

  static const postImagesBucket = 'post-images';
  static const avatarsBucket = 'avatars';

  Future<String> uploadPostImage({
    required Uint8List bytes,
    required String fileName,
    String? contentType,
  }) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to upload post images.');
    }

    final safeFileName = safeStorageFileName(fileName);
    final resolvedContentType = imageContentTypeFor(
      fileName: safeFileName,
      contentType: contentType,
    );
    final path = postImagePath(
      userId: userId,
      fileName: safeFileName,
      now: DateTime.now(),
    );

    try {
      debugPrint(
        '[Storage] post image upload start bucket=$postImagesBucket '
        'bytes=${bytes.length} contentType=$resolvedContentType',
      );
      await SupabaseService.client.storage
          .from(postImagesBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: resolvedContentType),
          );
    } catch (error) {
      logSupabaseDebug('Storage', 'post image upload', error);
      rethrow;
    }

    return SupabaseService.client.storage
        .from(postImagesBucket)
        .getPublicUrl(path);
  }

  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
    String? contentType,
  }) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to upload an avatar.');
    }

    final safeFileName = safeStorageFileName(fileName);
    final path =
        '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}_$safeFileName';
    final resolvedContentType = imageContentTypeFor(
      fileName: safeFileName,
      contentType: contentType,
    );

    await SupabaseService.client.storage
        .from(avatarsBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: resolvedContentType),
        );

    return SupabaseService.client.storage
        .from(avatarsBucket)
        .getPublicUrl(path);
  }

  @visibleForTesting
  static String safeStorageFileName(String fileName) {
    final sanitized = fileName.trim().replaceAll(
      RegExp(r'[^A-Za-z0-9._-]'),
      '_',
    );
    if (sanitized.isEmpty || sanitized == '.' || sanitized == '..') {
      return 'photo.jpg';
    }
    return sanitized;
  }

  @visibleForTesting
  static String postImagePath({
    required String userId,
    required String fileName,
    required DateTime now,
  }) {
    return '$userId/${now.millisecondsSinceEpoch}_${safeStorageFileName(fileName)}';
  }

  @visibleForTesting
  static String imageContentTypeFor({
    required String fileName,
    String? contentType,
  }) {
    final normalized = contentType?.trim().toLowerCase();
    if (normalized != null && normalized.startsWith('image/')) {
      return normalized;
    }

    final lowerFileName = fileName.toLowerCase();
    if (lowerFileName.endsWith('.png')) return 'image/png';
    if (lowerFileName.endsWith('.webp')) return 'image/webp';
    if (lowerFileName.endsWith('.heic')) return 'image/heic';
    if (lowerFileName.endsWith('.heif')) return 'image/heif';
    return 'image/jpeg';
  }
}
