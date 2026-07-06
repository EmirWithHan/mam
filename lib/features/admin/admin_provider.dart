import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_dashboard_models.dart';
import 'admin_service.dart';

final adminServiceProvider = Provider<AdminService>((ref) {
  return const AdminService();
});

final isAdminProvider = FutureProvider<bool>((ref) async {
  return ref.watch(adminServiceProvider).isCurrentUserAdmin();
});

final adminDashboardProvider = FutureProvider<AdminDashboardData>((ref) async {
  final data = await ref.watch(adminServiceProvider).fetchAdminDashboard();
  return AdminDashboardData.fromJson(data);
});

class AdminState {
  final bool loading;
  final String? errorMessage;
  final bool success;

  const AdminState({
    this.loading = false,
    this.errorMessage,
    this.success = false,
  });
}

class AdminController extends StateNotifier<AdminState> {
  AdminController(this._service, this._ref) : super(const AdminState());

  final AdminService _service;
  final Ref _ref;

  Future<bool> removeEvent(String eventId, String? reason) async {
    state = const AdminState(loading: true);
    try {
      await _service.removeEvent(eventId, reason);
      state = const AdminState(success: true);
      _ref.invalidate(adminDashboardProvider);
      return true;
    } catch (error) {
      final errStr = error.toString().toLowerCase();
      String message = 'Etkinlik kaldırılırken bir hata oluştu.';
      if (errStr.contains('not_admin')) {
        message = 'Bu sayfaya erişim yetkin yok.';
      }
      state = AdminState(errorMessage: message);
      return false;
    }
  }

  Future<bool> approveApplication(String applicationId, String? note) async {
    state = const AdminState(loading: true);
    try {
      await _service.approveBusinessApplication(applicationId, note);
      state = const AdminState(success: true);
      _ref.invalidate(adminDashboardProvider);
      return true;
    } catch (error) {
      final errStr = error.toString().toLowerCase();
      String message = 'İşletme başvurusu onaylanamadı.';
      if (errStr.contains('not_admin')) {
        message = 'Bu sayfaya erişim yetkin yok.';
      }
      state = AdminState(errorMessage: message);
      return false;
    }
  }

  Future<bool> rejectApplication(String applicationId, String? note) async {
    state = const AdminState(loading: true);
    try {
      await _service.rejectBusinessApplication(applicationId, note);
      state = const AdminState(success: true);
      _ref.invalidate(adminDashboardProvider);
      return true;
    } catch (error) {
      final errStr = error.toString().toLowerCase();
      String message = 'İşletme başvurusu reddedilemedi.';
      if (errStr.contains('not_admin')) {
        message = 'Bu sayfaya erişim yetkin yok.';
      }
      state = AdminState(errorMessage: message);
      return false;
    }
  }

  Future<bool> resolveReport({
    required String reportType,
    required String reportId,
    required String status,
    String? reason,
  }) async {
    state = const AdminState(loading: true);
    try {
      await _service.resolveReport(
        reportType: reportType,
        reportId: reportId,
        status: status,
        reason: reason,
      );
      state = const AdminState(success: true);
      _ref.invalidate(adminDashboardProvider);
      return true;
    } catch (error) {
      final errStr = error.toString();
      String message = 'Şikayet çözümlenirken bir hata oluştu: $errStr';
      if (errStr.toLowerCase().contains('not_admin')) {
        message = 'Bu sayfaya erişim yetkin yok.';
      }
      state = AdminState(errorMessage: message);
      return false;
    }
  }

  Future<bool> removeReportedContent({
    required String reportType,
    required String reportId,
    String? reason,
  }) async {
    state = const AdminState(loading: true);
    try {
      await _service.removeReportedContent(
        reportType: reportType,
        reportId: reportId,
        reason: reason,
      );
      state = const AdminState(success: true);
      _ref.invalidate(adminDashboardProvider);
      return true;
    } catch (error) {
      final errStr = error.toString();
      String message = 'İçerik kaldırılırken bir hata oluştu: $errStr';
      if (errStr.toLowerCase().contains('not_admin')) {
        message = 'Bu sayfaya erişim yetkin yok.';
      }
      state = AdminState(errorMessage: message);
      return false;
    }
  }
}

final adminControllerProvider =
    StateNotifierProvider<AdminController, AdminState>((ref) {
      return AdminController(ref.watch(adminServiceProvider), ref);
    });
