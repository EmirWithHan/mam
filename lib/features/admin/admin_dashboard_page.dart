import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/error_view.dart';
import '../feedback/feedback_provider.dart';
import 'admin_dashboard_models.dart';
import 'admin_provider.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      // Load initial feedback list for Geri Bildirimler tab
      ref.read(adminFeedbackProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAdminAsync = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Yönetim Paneli')),
      body: SafeArea(
        child: isAdminAsync.when(
          loading: () => const AppLoader(),
          error: (error, _) =>
              const ErrorView(message: 'Yetki kontrolü sırasında hata oluştu.'),
          data: (isAdmin) {
            if (!isAdmin) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.gpp_bad_outlined,
                      size: 64,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Bu sayfaya erişim yetkin yok.',
                      style: AppTextStyles.headline,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Yönetici yetkisine sahip olmayan hesaplar bu paneli görüntüleyemez.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: 'Geri Dön',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              );
            }

            final dashboardAsync = ref.watch(adminDashboardProvider);

            return dashboardAsync.when(
              loading: () => const AppLoader(),
              error: (error, _) => ErrorView(
                message: 'Yönetim paneli yüklenemedi.',
                onRetry: () => ref.invalidate(adminDashboardProvider),
              ),
              data: (data) => _AdminDashboardBody(data: data),
            );
          },
        ),
      ),
    );
  }
}

class _AdminDashboardBody extends StatelessWidget {
  const _AdminDashboardBody({required this.data});

  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    label: 'Toplam Kullanıcı',
                    value: '${data.totalUsers}',
                    icon: Icons.person_outline,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _SummaryCard(
                    label: 'Toplam Etkinlik',
                    value: '${data.totalEvents}',
                    icon: Icons.calendar_month_outlined,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _SummaryCard(
                    label: 'Bekleyen Başvuru',
                    value: '${data.pendingBusinessAppsCount}',
                    icon: Icons.business_center_outlined,
                    color: AppColors.tertiary,
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.primary,
            isScrollable: true,
            tabs: [
              const Tab(text: 'Başvurular'),
              const Tab(text: 'Etkinlikler'),
              Tab(text: 'Şikayetler (${data.pendingReportsCount})'),
              Tab(
                text: 'Mesaj Şikayetleri (${data.pendingMessageReportsCount})',
              ),
              const Tab(text: 'Geri Bildirimler'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _BusinessAppsList(apps: data.pendingBusinessApps),
                _EventsList(events: data.recentEvents),
                _ReportsList(reports: data.recentReports),
                _MessageReportsList(reports: data.recentMessageReports),
                const _FeedbackListTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: AppSpacing.xs),
            Text(value, style: AppTextStyles.headline),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(fontSize: 10),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _BusinessAppsList extends ConsumerWidget {
  const _BusinessAppsList({required this.apps});

  final List<AdminPendingBusinessApp> apps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (apps.isEmpty) {
      return Center(
        child: Text(
          'Bekleyen işletme başvurusu bulunmamaktadır.',
          style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: apps.length,
      separatorBuilder: (_, index) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final app = apps[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.lgBorder,
            side: const BorderSide(color: AppColors.border),
          ),
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        app.businessName,
                        style: AppTextStyles.bodyStrong,
                      ),
                    ),
                    _Badge(label: app.category),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Adres: ${app.fullAddress}',
                  style: AppTextStyles.bodySmall,
                ),
                Text(
                  'Telefon: ${app.businessPhone}',
                  style: AppTextStyles.bodySmall,
                ),
                if (app.website != null)
                  Text(
                    'Web Sitesi: ${app.website}',
                    style: AppTextStyles.bodySmall,
                  ),
                if (app.description != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Açıklama: ${app.description}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Reddet',
                        variant: AppButtonVariant.outlined,
                        onPressed: () => _showActionDialog(
                          context,
                          ref,
                          title: 'Başvuruyu Reddet',
                          hintText: 'Reddetme sebebi (isteğe bağlı)',
                          buttonLabel: 'Reddet',
                          onConfirm: (reason) => ref
                              .read(adminControllerProvider.notifier)
                              .rejectApplication(app.id, reason),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppButton(
                        label: 'Onayla',
                        onPressed: () => _showActionDialog(
                          context,
                          ref,
                          title: 'Başvuruyu Onayla',
                          hintText: 'Onay notu (isteğe bağlı)',
                          buttonLabel: 'Onayla',
                          onConfirm: (note) => ref
                              .read(adminControllerProvider.notifier)
                              .approveApplication(app.id, note),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EventsList extends ConsumerWidget {
  const _EventsList({required this.events});

  final List<AdminRecentEvent> events;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (events.isEmpty) {
      return Center(
        child: Text(
          'Etkinlik bulunmamaktadır.',
          style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: events.length,
      separatorBuilder: (_, index) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final event = events[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.lgBorder,
            side: const BorderSide(color: AppColors.border),
          ),
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(event.title, style: AppTextStyles.bodyStrong),
                    ),
                    if (event.isRemoved)
                      const _Badge(
                        label: 'Kaldırıldı',
                        color: Color(0xFFFEEBEE),
                        textColor: AppColors.error,
                      )
                    else
                      const _Badge(
                        label: 'Yayında',
                        color: Color(0xFFE8F5E9),
                        textColor: AppColors.success,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Tarih: ${event.eventDate.toLocal()}',
                  style: AppTextStyles.bodySmall,
                ),
                Text(
                  'Katılımcı: ${event.participantCount}',
                  style: AppTextStyles.bodySmall,
                ),
                if (!event.isRemoved) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Etkinliği Kaldır',
                    variant: AppButtonVariant.outlined,
                    onPressed: () => _showActionDialog(
                      context,
                      ref,
                      title: 'Etkinliği Kaldır',
                      hintText: 'Kaldırma sebebi (isteğe bağlı)',
                      buttonLabel: 'Kaldır',
                      onConfirm: (reason) => ref
                          .read(adminControllerProvider.notifier)
                          .removeEvent(event.id, reason),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FeedbackListTab extends ConsumerWidget {
  const _FeedbackListTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminFeedbackProvider);

    if (state.isLoading && state.feedback.isEmpty) {
      return const AppLoader();
    }

    if (state.message != null && state.feedback.isEmpty) {
      return const ErrorView(message: 'Geri bildirimler yüklenemedi.');
    }

    if (state.feedback.isEmpty) {
      return Center(
        child: Text(
          'Henüz geri bildirim yok.',
          style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(adminFeedbackProvider.notifier).load(force: true),
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: state.feedback.length,
        separatorBuilder: (_, index) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final feedback = state.feedback[index];
          final rating = feedback.rating == null
              ? 'Puan yok'
              : '${feedback.rating}/5';
          final category = feedback.category ?? 'Kategori yok';

          return DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: AppRadius.lgBorder,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$rating · $category',
                    style: AppTextStyles.bodyStrong,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Kullanıcı: ${feedback.userId}',
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    DateFormatter.dateTime(feedback.createdAt.toLocal()),
                    style: AppTextStyles.caption,
                  ),
                  if (feedback.source != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Kaynak: ${feedback.source}',
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (feedback.message != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(feedback.message!, style: AppTextStyles.body),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.color, this.textColor});

  final String label;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: textColor ?? AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}

class _ReportsList extends ConsumerWidget {
  const _ReportsList({required this.reports});

  final List<AdminUserReport> reports;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (reports.isEmpty) {
      return Center(
        child: Text(
          'Şikayet bulunmamaktadır.',
          style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: reports.length,
      separatorBuilder: (_, index) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final report = reports[index];
        final isOpen = report.status == 'open';

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.lgBorder,
            side: const BorderSide(color: AppColors.border),
          ),
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Şikayet Nedeni: ${report.reason}',
                        style: AppTextStyles.bodyStrong,
                      ),
                    ),
                    if (report.status == 'open')
                      const _Badge(
                        label: 'Açık',
                        color: Color(0xFFFFF3E0),
                        textColor: Colors.orange,
                      )
                    else if (report.status == 'resolved')
                      const _Badge(
                        label: 'Çözüldü',
                        color: Color(0xFFE8F5E9),
                        textColor: AppColors.success,
                      )
                    else
                      const _Badge(
                        label: 'Reddedildi',
                        color: Color(0xFFEEEEEE),
                        textColor: AppColors.textMuted,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Raporlanan Hedef: [${report.targetType}] ${report.targetId}',
                  style: AppTextStyles.bodySmall,
                ),
                Text(
                  'Şikayet Eden: ${report.reporterId}',
                  style: AppTextStyles.bodySmall,
                ),
                if (report.description != null &&
                    report.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Açıklama: ${report.description}',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                Text(
                  'Tarih: ${report.createdAt.toLocal()}',
                  style: AppTextStyles.bodySmall,
                ),
                if (isOpen) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showActionDialog(
                            context,
                            ref,
                            title: 'Şikayeti Reddet',
                            hintText: 'Reddetme gerekçesi (isteğe bağlı)',
                            buttonLabel: 'Reddet',
                            onConfirm: (reason) => ref
                                .read(adminControllerProvider.notifier)
                                .resolveReport(
                                  reportType: 'user',
                                  reportId: report.id,
                                  status: 'rejected',
                                  reason: reason,
                                ),
                          ),
                          child: const Text('Reddet'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _showActionDialog(
                            context,
                            ref,
                            title: 'Şikayeti Çözümle',
                            hintText: 'Çözüm notu (isteğe bağlı)',
                            buttonLabel: 'Çözümle',
                            onConfirm: (reason) => ref
                                .read(adminControllerProvider.notifier)
                                .resolveReport(
                                  reportType: 'user',
                                  reportId: report.id,
                                  status: 'resolved',
                                  reason: reason,
                                ),
                          ),
                          child: const Text('Çözümle'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MessageReportsList extends ConsumerWidget {
  const _MessageReportsList({required this.reports});

  final List<AdminMessageReport> reports;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (reports.isEmpty) {
      return Center(
        child: Text(
          'Mesaj şikayeti bulunmamaktadır.',
          style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: reports.length,
      separatorBuilder: (_, index) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final report = reports[index];
        final isPending = report.status == 'pending';

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.lgBorder,
            side: const BorderSide(color: AppColors.border),
          ),
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Şikayet Nedeni: ${report.reason}',
                        style: AppTextStyles.bodyStrong,
                      ),
                    ),
                    if (report.status == 'pending')
                      const _Badge(
                        label: 'Bekliyor',
                        color: Color(0xFFFFF3E0),
                        textColor: Colors.orange,
                      )
                    else if (report.status == 'resolved')
                      const _Badge(
                        label: 'Çözüldü',
                        color: Color(0xFFE8F5E9),
                        textColor: AppColors.success,
                      )
                    else
                      const _Badge(
                        label: 'Reddedildi',
                        color: Color(0xFFEEEEEE),
                        textColor: AppColors.textMuted,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Şikayet Edilen Mesaj ID: ${report.messageId}',
                  style: AppTextStyles.bodySmall,
                ),
                Text(
                  'Mesaj Sahibi: ${report.reportedUserId}',
                  style: AppTextStyles.bodySmall,
                ),
                Text(
                  'Şikayet Eden: ${report.reporterId}',
                  style: AppTextStyles.bodySmall,
                ),
                Text(
                  'Mesaj Tipi: ${report.messageType}',
                  style: AppTextStyles.bodySmall,
                ),
                if (report.eventId != null)
                  Text(
                    'Etkinlik ID: ${report.eventId}',
                    style: AppTextStyles.bodySmall,
                  ),
                if (report.conversationId != null)
                  Text(
                    'Sohbet ID: ${report.conversationId}',
                    style: AppTextStyles.bodySmall,
                  ),
                Text(
                  'Tarih: ${report.createdAt.toLocal()}',
                  style: AppTextStyles.bodySmall,
                ),
                if (isPending) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showActionDialog(
                            context,
                            ref,
                            title: 'Mesaj Şikayetini Reddet',
                            hintText: 'Reddetme gerekçesi (isteğe bağlı)',
                            buttonLabel: 'Reddet',
                            onConfirm: (reason) => ref
                                .read(adminControllerProvider.notifier)
                                .resolveReport(
                                  reportType: 'message',
                                  reportId: report.id,
                                  status: 'rejected',
                                  reason: reason,
                                ),
                          ),
                          child: const Text('Reddet'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _showActionDialog(
                            context,
                            ref,
                            title: 'Mesaj Şikayetini Çözümle',
                            hintText: 'Çözüm notu (isteğe bağlı)',
                            buttonLabel: 'Çözümle',
                            onConfirm: (reason) => ref
                                .read(adminControllerProvider.notifier)
                                .resolveReport(
                                  reportType: 'message',
                                  reportId: report.id,
                                  status: 'resolved',
                                  reason: reason,
                                ),
                          ),
                          child: const Text('Çözümle'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

void _showActionDialog(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String hintText,
  required String buttonLabel,
  required Future<bool> Function(String? reason) onConfirm,
}) {
  final controller = TextEditingController();

  showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title, style: AppTextStyles.title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 250,
          decoration: InputDecoration(
            hintText: hintText,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = controller.text;
              final success = await onConfirm(reason);
              if (context.mounted) {
                Navigator.of(context).pop();
                if (!success) {
                  final errorMsg =
                      ref.read(adminControllerProvider).errorMessage ??
                      'İşlem başarısız.';
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(errorMsg)));
                }
              }
            },
            child: Text(buttonLabel),
          ),
        ],
      );
    },
  );
}
