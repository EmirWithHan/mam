import '../../core/utils/error_messages.dart';
import '../../services/supabase_service.dart';
import 'business_models.dart';

class BusinessAccountException implements Exception {
  const BusinessAccountException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BusinessAccountService {
  const BusinessAccountService();

  Future<BusinessAccount?> fetchMyBusinessAccount() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return null;

    final data = await SupabaseService.client
        .from('business_accounts')
        .select()
        .eq('owner_user_id', userId)
        .maybeSingle();

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
        .maybeSingle();

    if (data == null) return null;
    return BusinessAccount.fromJson(data);
  }

  Future<BusinessAccount> createBusinessAccount(
    BusinessAccountInput input,
  ) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw const BusinessAccountException(
        'Isletme hesabi olusturmak icin giris yapmalisin.',
      );
    }

    try {
      final data = await SupabaseService.client
          .from('business_accounts')
          .insert(input.toCreateJson(ownerUserId: userId))
          .select()
          .single();

      return BusinessAccount.fromJson(data);
    } catch (error) {
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

      return BusinessAccount.fromJson(data);
    } catch (error) {
      throw BusinessAccountException(_friendlyBusinessError(error));
    }
  }
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
