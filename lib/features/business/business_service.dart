import '../../core/utils/pagination.dart';
import '../../core/utils/error_messages.dart';
import '../../core/utils/rate_limits.dart';
import '../../services/rate_limit_service.dart';
import '../../services/supabase_service.dart';
import '../profile/profile_badges.dart';
import 'business_models.dart';

class BusinessAccountException implements Exception {
  const BusinessAccountException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BusinessAccountService {
  const BusinessAccountService({
    RateLimitService rateLimitService = const RateLimitService(),
  }) : _rateLimitService = rateLimitService;

  final RateLimitService _rateLimitService;

  Future<BusinessAccount?> fetchMyBusinessAccount() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return null;

    final data = await SupabaseService.client
        .from('business_accounts')
        .select()
        .eq('owner_user_id', userId)
        .inFilter('status', ['active', 'pending'])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle()
        .catchError((Object error) {
          logSupabaseDebug('Business', 'fetchMyBusinessAccount', error);
          throw error;
        });

    if (data == null) return null;
    return BusinessAccount.fromJson(data);
  }

  Future<BusinessAccount?> fetchBusinessAccountById(String id) async {
    final trimmedId = id.trim();
    if (trimmedId.isEmpty) return null;

    final data = await SupabaseService.client
        .from('business_accounts')
        .select()
        .eq('id', trimmedId)
        .eq('status', BusinessAccountStatus.active)
        .maybeSingle()
        .catchError((Object error) {
          logSupabaseDebug('Business', 'fetchBusinessAccountById', error);
          throw error;
        });

    if (data == null) return null;
    return BusinessAccount.fromJson(data);
  }

  Future<BusinessPlusSubscription?> fetchLatestBusinessPlusSubscription({
    required String businessAccountId,
  }) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return null;

    final data = await SupabaseService.client
        .from('business_plus_subscriptions')
        .select(
          'id,business_account_id,entitlement_status,store_subscription_status,current_period_start,current_period_end,auto_renew_enabled,cancellation_time,grace_period_end,revocation_time,updated_at',
        )
        .eq('business_account_id', businessAccountId)
        .eq('owner_user_id', userId)
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle()
        .catchError((Object error) {
          logSupabaseDebug(
            'Business',
            'fetchLatestBusinessPlusSubscription',
            error,
          );
          throw error;
        });

    if (data == null) return null;
    return BusinessPlusSubscription.fromJson(data);
  }

  Future<BusinessAccount> createBusinessAccount(
    BusinessAccountInput input,
  ) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw const BusinessAccountException(
        'İşletme hesabı oluşturmak için giriş yapmalısın.',
      );
    }

    try {
      final existing = await fetchMyBusinessAccount();
      if (existing != null) {
        return updateBusinessAccount(id: existing.id, input: input);
      }

      final data = await SupabaseService.client
          .from('business_accounts')
          .insert(input.toCreateJson(ownerUserId: userId))
          .select()
          .single();

      final account = BusinessAccount.fromJson(data);
      return account;
    } catch (error) {
      if (_isMissingBusinessSchema(error)) {
        try {
          final data = await SupabaseService.client
              .from('business_accounts')
              .insert(input.toLegacyCreateJson(ownerUserId: userId))
              .select()
              .single();
          return BusinessAccount.fromJson(data);
        } catch (legacyError) {
          throw BusinessAccountException(_friendlyBusinessError(legacyError));
        }
      }
      throw BusinessAccountException(_friendlyBusinessError(error));
    }
  }

  Future<BusinessAccount> updateBusinessAccount({
    required String id,
    required BusinessAccountInput input,
  }) async {
    try {
      final data = await SupabaseService.client
          .from('business_accounts')
          .update(input.toUpdateJson())
          .eq('id', id)
          .select()
          .single();

      final account = BusinessAccount.fromJson(data);
      return account;
    } catch (error) {
      if (_isMissingBusinessSchema(error)) {
        try {
          final data = await SupabaseService.client
              .from('business_accounts')
              .update(input.toLegacyUpdateJson())
              .eq('id', id)
              .select()
              .single();
          return BusinessAccount.fromJson(data);
        } catch (legacyError) {
          throw BusinessAccountException(_friendlyBusinessError(legacyError));
        }
      }
      throw BusinessAccountException(_friendlyBusinessError(error));
    }
  }

  Future<BusinessAccount> updateCustomizations({
    required String id,
    String? customThemeColor,
    String? pinnedEventId,
    List<String>? galleryUrls,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (customThemeColor != null) {
        updates['custom_theme_color'] = customThemeColor;
      }
      updates['pinned_event_id'] =
          (pinnedEventId == null ||
              pinnedEventId.isEmpty ||
              pinnedEventId == 'null')
          ? null
          : pinnedEventId;
      if (galleryUrls != null) {
        updates['gallery_urls'] = galleryUrls;
      }

      final data = await SupabaseService.client
          .from('business_accounts')
          .update(updates)
          .eq('id', id)
          .select()
          .single();

      return BusinessAccount.fromJson(data);
    } catch (error) {
      throw BusinessAccountException(_friendlyBusinessError(error));
    }
  }

  Future<void> deleteMyBusinessAccount() async {
    try {
      await SupabaseService.client.rpc('delete_my_business_account');
    } catch (error) {
      _debugPrintSupabaseError('delete_my_business_account', error);
      throw BusinessAccountException(
        friendlyBusinessAccountDeleteErrorMessage(error),
      );
    }
  }

  Future<BusinessApplication?> fetchMyLatestApplication() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return null;

    final data = await SupabaseService.client
        .from('business_applications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle()
        .catchError((Object error) {
          logSupabaseDebug('Business', 'fetchMyLatestApplication', error);
          throw error;
        });

    if (data == null) return null;
    return BusinessApplication.fromJson(data);
  }

  Future<BusinessApplication> submitApplication(
    BusinessApplicationInput input,
  ) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw const BusinessAccountException(
        'İşletme başvurusu için giriş yapmalısın.',
      );
    }

    try {
      await _rateLimitService.submitBusinessApplication();
      final data = await SupabaseService.client
          .from('business_applications')
          .insert(input.toCreateJson(userId: userId))
          .select()
          .single();
      return BusinessApplication.fromJson(data);
    } catch (error) {
      throw BusinessAccountException(_friendlyBusinessApplicationError(error));
    }
  }

  Future<List<ProfileBadge>> fetchBusinessBadges(String businessId) async {
    final data = await SupabaseService.client
        .rpc('get_business_badges', params: {'p_business_id': businessId})
        .catchError((Object error) {
          logSupabaseDebug('Business', 'get_business_badges', error);
          throw error;
        });
    return (data as List<dynamic>)
        .whereType<Map>()
        .map((row) => ProfileBadge.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<bool> isCurrentUserAdmin() async {
    final data = await SupabaseService.client
        .rpc('is_current_user_admin')
        .catchError((Object error) {
          logSupabaseDebug('Business', 'is_current_user_admin', error);
          throw error;
        });
    return data == true;
  }

  Future<List<BusinessApplication>> fetchPendingApplications({
    int limit = SupabasePageSizes.adminApplications,
    int offset = 0,
  }) async {
    final data = await SupabaseService.client
        .rpc(
          'list_pending_business_applications',
          params: {'p_limit': limit, 'p_offset': offset},
        )
        .catchError((Object error) {
          logSupabaseDebug(
            'Business',
            'list_pending_business_applications',
            error,
          );
          throw error;
        });
    return (data as List<dynamic>)
        .whereType<Map>()
        .map(
          (row) => BusinessApplication.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }

  Future<void> approveApplication({
    required String applicationId,
    String? adminNote,
  }) async {
    try {
      await _rateLimitService.checkAndRecord(
        action: RateLimitActions.businessApplicationReview,
        targetId: applicationId,
      );
      await SupabaseService.client.rpc(
        'approve_business_application',
        params: {'p_application_id': applicationId, 'p_admin_note': adminNote},
      );
    } catch (error) {
      throw BusinessAccountException(
        friendlyBusinessApplicationReviewErrorMessage(error),
      );
    }
  }

  Future<void> rejectApplication({
    required String applicationId,
    String? adminNote,
  }) async {
    try {
      await _rateLimitService.checkAndRecord(
        action: RateLimitActions.businessApplicationReview,
        targetId: applicationId,
      );
      await SupabaseService.client.rpc(
        'reject_business_application',
        params: {'p_application_id': applicationId, 'p_admin_note': adminNote},
      );
    } catch (error) {
      throw BusinessAccountException(
        friendlyBusinessApplicationReviewErrorMessage(error),
      );
    }
  }

  Future<Map<String, dynamic>> fetchBusinessPlusAnalytics(
    String businessId,
  ) async {
    final response = await SupabaseService.client
        .rpc(
          'get_business_plus_analytics',
          params: {'p_business_account_id': businessId},
        )
        .catchError((Object error) {
          logSupabaseDebug('Business', 'get_business_plus_analytics', error);
          throw error;
        });
    return Map<String, dynamic>.from(response as Map);
  }
}

String _friendlyBusinessApplicationError(Object error) {
  return friendlyBusinessApplicationErrorMessage(error);
}

String friendlyBusinessApplicationErrorMessage(Object error) {
  final message = error.toString().toLowerCase();
  if (isRateLimitError(error)) {
    return friendlyRateLimitMessage;
  }
  if (message.contains('business_applications_one_pending_per_user') ||
      message.contains('duplicate') ||
      message.contains('23505')) {
    return 'Bekleyen bir işletme başvurun var.';
  }
  if (message.contains('42501') ||
      message.contains('permission denied') ||
      message.contains('row-level security') ||
      message.contains('violates row-level security policy')) {
    return 'Başvuru gönderilemedi. Yetki ayarları kontrol edilmeli.';
  }
  if (message.contains('not_admin')) {
    return 'Bu işlem için yönetici yetkisi gerekli.';
  }
  if (message.contains('invalid_business_application_phone')) {
    return 'Geçerli bir işletme telefon numarası gir.';
  }
  return 'Başvuru gönderilemedi. Tekrar dene.';
}

String friendlyBusinessApplicationReviewErrorMessage(Object error) {
  if (isRateLimitError(error)) {
    return friendlyRateLimitMessage;
  }
  return 'Başvuru onaylanamadı. Tekrar dene.';
}

String _friendlyBusinessError(Object error) {
  return friendlyBusinessAccountErrorMessage(error);
}

String friendlyBusinessAccountErrorMessage(Object error) {
  final message = error.toString().toLowerCase();
  if (message.contains('42501') || message.contains('permission denied')) {
    return 'İşletme hesabı oluşturulamadı. Yetki ayarları kontrol edilmeli.';
  }
  if (message.contains('business_accounts_username_business_tag_key') ||
      message.contains('business_accounts_username_key') ||
      message.contains('duplicate key')) {
    return 'Bu işletme kullanıcı adı alınmış.';
  }
  if (message.contains('business_accounts_owner_one_account_idx')) {
    return 'Zaten bir işletme hesabın var.';
  }
  final friendly = friendlyErrorMessage(error);
  if (friendly.trim().isNotEmpty) return friendly;
  return 'İşletme hesabı oluşturulamadı. Tekrar dene.';
}

String friendlyBusinessAccountDeleteErrorMessage(Object error) {
  return 'İşletme hesabı silinemedi. Tekrar dene.';
}

void _debugPrintSupabaseError(String action, Object error) {
  logSupabaseDebug('Business', action, error);
}

bool _isMissingBusinessSchema(Object error) {
  final message = error.toString().toLowerCase();
  return (message.contains('latitude') ||
          message.contains('longitude') ||
          message.contains('working_hours') ||
          message.contains('amenities')) &&
      (message.contains('column') ||
          message.contains('schema') ||
          message.contains('pgrst') ||
          message.contains('42703'));
}
