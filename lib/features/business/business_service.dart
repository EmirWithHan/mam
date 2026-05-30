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
        .inFilter('status', ['active', 'pending'])
        .order('created_at', ascending: false)
        .limit(1)
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
        'İşletme hesabı oluşturmak için giriş yapmalısın.',
      );
    }

    try {
      final existing = await fetchMyBusinessAccount();
      if (existing != null) {
        final account = await updateBusinessAccount(
          id: existing.id,
          input: input,
        );
        await _markProfileAsBusiness();
        return account;
      }

      final data = await SupabaseService.client
          .from('business_accounts')
          .insert(input.toCreateJson(ownerUserId: userId))
          .select()
          .single();

      final account = BusinessAccount.fromJson(data);
      await _markProfileAsBusiness();
      return account;
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

      final account = BusinessAccount.fromJson(data);
      await _markProfileAsBusiness();
      return account;
    } catch (error) {
      throw BusinessAccountException(_friendlyBusinessError(error));
    }
  }
}

Future<void> _markProfileAsBusiness() async {
  await SupabaseService.client.rpc(
    'switch_profile_account_type',
    params: {'p_account_type': 'business'},
  );
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
