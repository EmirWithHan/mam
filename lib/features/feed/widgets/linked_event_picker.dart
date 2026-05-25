import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/sport_icon.dart';
import '../feed_models.dart';
import '../feed_provider.dart';

class LinkedEventPicker extends ConsumerWidget {
  const LinkedEventPicker({
    super.key,
    required this.selectedEventId,
    required this.onChanged,
  });

  final String? selectedEventId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsValue = ref.watch(linkedEventsProvider);
    final selectedEvent = eventsValue.maybeWhen(
      data: (events) {
        for (final event in events) {
          if (event.id == selectedEventId) return event;
        }
        return null;
      },
      orElse: () => null,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: AppRadius.lgBorder,
        onTap: () => _openPicker(context),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.event_available_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Etkinlik bağla', style: AppTextStyles.bodyStrong),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      selectedEvent == null
                          ? 'Etkinlik seçilmedi'
                          : selectedEvent.title,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: selectedEvent == null
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (selectedEvent != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${selectedEvent.sportType} • ${selectedEvent.locationLabel}',
                        style: AppTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.expand_more, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _LinkedEventPickerSheet(selectedEventId: selectedEventId);
      },
    );

    if (value == null) return;
    onChanged(value.isEmpty ? null : value);
  }
}

class _LinkedEventPickerSheet extends ConsumerStatefulWidget {
  const _LinkedEventPickerSheet({required this.selectedEventId});

  final String? selectedEventId;

  @override
  ConsumerState<_LinkedEventPickerSheet> createState() =>
      _LinkedEventPickerSheetState();
}

class _LinkedEventPickerSheetState
    extends ConsumerState<_LinkedEventPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventsValue = ref.watch(linkedEventsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.35),
                      borderRadius: AppRadius.pillBorder,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Etkinlik bağla', style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'İstersen bu paylaşımı katıldığın bir etkinlikle ilişkilendirebilirsin.',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Etkinlik ara',
                  controller: _searchController,
                  prefixIcon: const Icon(Icons.search),
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: eventsValue.when(
                    loading: () => const AppLoader(),
                    error: (error, _) => ErrorView(
                      message: 'Etkinlikler yüklenemedi.',
                      onRetry: () => ref.invalidate(linkedEventsProvider),
                    ),
                    data: (events) {
                      final filteredEvents = _filterEvents(events);
                      if (events.isEmpty) {
                        return const EmptyState(
                          title: 'Bağlanacak etkinlik yok',
                          message:
                              'Katıldığın veya oluşturduğun etkinlikler burada görünür.',
                          icon: Icons.event_busy_outlined,
                        );
                      }

                      return ListView.separated(
                        controller: scrollController,
                        itemCount: filteredEvents.length + 1,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _ClearEventTile(
                              isSelected: widget.selectedEventId == null,
                            );
                          }

                          final event = filteredEvents[index - 1];
                          return _LinkableEventTile(
                            event: event,
                            isSelected: event.id == widget.selectedEventId,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<LinkableEvent> _filterEvents(List<LinkableEvent> events) {
    final normalizedQuery = _query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return events;
    final searchQuery = _normalizeSearchText(normalizedQuery);
    return events
        .where((event) => event.searchText.contains(searchQuery))
        .toList();
  }
}

class _ClearEventTile extends StatelessWidget {
  const _ClearEventTile({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
      tileColor: isSelected ? AppColors.primarySoft : AppColors.surface,
      leading: const CircleAvatar(
        backgroundColor: AppColors.primarySoft,
        child: Icon(Icons.link_off_outlined, color: AppColors.primary),
      ),
      title: const Text('Etkinlik bağlama'),
      subtitle: const Text('Bu paylaşım bağımsız fotoğraf olarak kalır.'),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppColors.primary)
          : null,
      onTap: () => Navigator.of(context).pop(''),
    );
  }
}

class _LinkableEventTile extends StatelessWidget {
  const _LinkableEventTile({required this.event, required this.isSelected});

  final LinkableEvent event;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
      tileColor: isSelected ? AppColors.primarySoft : AppColors.surface,
      leading: SportIcon(
        sportType: event.sportType,
        size: 20,
        color: isSelected ? Colors.white : AppColors.primary,
        backgroundColor: isSelected ? AppColors.primary : AppColors.primarySoft,
      ),
      title: Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${event.sportType} • ${event.locationLabel}\n${event.displayDate}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppColors.primary)
          : const Icon(Icons.chevron_right, color: AppColors.primary),
      onTap: () => Navigator.of(context).pop(event.id),
    );
  }
}

String _normalizeSearchText(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('ç', 'c')
      .replaceAll('ğ', 'g')
      .replaceAll('ı', 'i')
      .replaceAll('i̇', 'i')
      .replaceAll('ö', 'o')
      .replaceAll('ş', 's')
      .replaceAll('ü', 'u');
}
