import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../notifications/notifications_provider.dart';
import 'events_models.dart';
import 'events_provider.dart';
import 'widgets/event_card.dart';
import 'widgets/event_filter_sheet.dart';

class EventsPage extends ConsumerStatefulWidget {
  const EventsPage({super.key});

  @override
  ConsumerState<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends ConsumerState<EventsPage> {
  final _searchController = TextEditingController();
  var _filters = const EventFilters();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(eventsControllerProvider.notifier).loadEvents();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventsState = ref.watch(eventsControllerProvider);
    final compact = MediaQuery.sizeOf(context).height < 720;
    final pagePadding = compact ? AppSpacing.md : AppSpacing.lg;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const AppLogo(size: 32, showText: true),
        actions: [
          _NotificationBell(
            unreadCount:
                ref.watch(notificationsUnreadCountProvider).valueOrNull ?? 0,
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Find a Game!', style: AppTextStyles.headline),
                  ),
                  if (!compact) const AppLogo(size: 44),
                ],
              ),
              SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
              Text(
                'Discover friendly matches nearby.',
                style: AppTextStyles.body,
              ),
              SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
              _SearchFilterRow(
                controller: _searchController,
                filtersActive: _filters.isActive,
                onSearchChanged: (_) => setState(() {}),
                onFilterPressed: _openFilterSheet,
              ),
              SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
              AppButton(
                label: 'Host an Event',
                onPressed: () => context.pushNamed(RouteNames.createEvent),
              ),
              SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
              Expanded(
                child: _EventsBody(
                  eventsState: eventsState,
                  searchQuery: _searchController.text,
                  filters: _filters,
                  onClearFilters: _clearSearchAndFilters,
                  onLoadMore: () => ref
                      .read(eventsControllerProvider.notifier)
                      .loadMoreEvents(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openFilterSheet() async {
    final filters = await showModalBottomSheet<EventFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventFilterSheet(initialFilters: _filters),
    );
    if (filters == null || !mounted) return;
    setState(() => _filters = filters);
  }

  void _clearSearchAndFilters() {
    setState(() {
      _filters = const EventFilters();
      _searchController.clear();
    });
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Bildirimler',
      onPressed: () => context.pushNamed(RouteNames.notifications),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(
            Icons.notifications_none_rounded,
            color: AppColors.primary,
          ),
          if (unreadCount > 0)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EventsBody extends StatelessWidget {
  const _EventsBody({
    required this.eventsState,
    required this.searchQuery,
    required this.filters,
    required this.onClearFilters,
    required this.onLoadMore,
  });

  final EventsState eventsState;
  final String searchQuery;
  final EventFilters filters;
  final VoidCallback onClearFilters;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (eventsState.isLoading) return const AppLoader();

    if (eventsState.status == EventsStatus.error) {
      return ErrorView(
        message: eventsState.message ?? 'Etkinlikler yüklenemedi.',
      );
    }

    final filteredEvents = eventsState.events
        .where((event) => _matchesSearch(event, searchQuery))
        .where((event) => _matchesFilters(event, filters))
        .toList();

    if (eventsState.events.isEmpty) {
      return EmptyState(
        title: 'Henüz etkinlik yok',
        message:
            'İlk etkinliği sen oluşturabilir ya da daha sonra tekrar keşfe çıkabilirsin.',
        icon: Icons.event_available_outlined,
        actionLabel: 'Etkinlik oluştur',
        onAction: () => context.pushNamed(RouteNames.createEvent),
        secondaryActionLabel: 'Profilini tamamla',
        onSecondaryAction: () => context.pushNamed(RouteNames.profileComplete),
      );
    }

    if (filteredEvents.isEmpty) {
      return EmptyState(
        title: 'Etkinlik bulunamadı',
        message: 'Arama veya filtreleri değiştirerek tekrar dene.',
        actionLabel: 'Filtreleri temizle',
        onAction: onClearFilters,
      );
    }

    final placedEvents = eventsWithSponsoredPlacement(filteredEvents);

    return ListView.separated(
      itemCount: placedEvents.length + 1,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        if (index == placedEvents.length) {
          if (!eventsState.hasMore) {
            return Text(
              'Daha fazla içerik yok.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            );
          }
          return AppButton(
            label: 'Daha fazla yükle',
            isLoading: eventsState.isLoadingMore,
            onPressed: eventsState.isLoadingMore ? null : onLoadMore,
          );
        }
        return EventCard(event: placedEvents[index]);
      },
    );
  }

  bool _matchesSearch(Event event, String searchQuery) {
    final query = _normalize(searchQuery);
    if (query.isEmpty) return true;
    return [
      event.title,
      event.sportType ?? '',
      event.city,
      event.district ?? '',
      event.locationText ?? '',
    ].any((value) => _normalize(value).contains(query));
  }

  bool _matchesFilters(Event event, EventFilters filters) {
    final sport = filters.selectedSportType;
    if (sport != null &&
        _normalize(event.sportType ?? '') != _normalize(sport)) {
      return false;
    }

    final city = filters.selectedCity;
    if (city != null && _normalize(event.city) != _normalize(city)) {
      return false;
    }

    if (filters.onlyAvailableSpots &&
        event.approvedCount >= event.capacityTotal) {
      return false;
    }

    final now = DateTime.now();
    switch (filters.dateFilter) {
      case EventDateFilter.all:
        return true;
      case EventDateFilter.today:
        return DateUtils.isSameDay(event.eventDate, now);
      case EventDateFilter.thisWeek:
        final today = DateTime(now.year, now.month, now.day);
        final end = today.add(const Duration(days: 7));
        return !event.eventDate.isBefore(today) &&
            event.eventDate.isBefore(end);
      case EventDateFilter.upcoming:
        return event.eventDate.isAfter(now);
    }
  }

  String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('i̇', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u')
        .replaceAll('Ã§', 'c')
        .replaceAll('ÄŸ', 'g')
        .replaceAll('Ä±', 'i')
        .replaceAll('Ã¶', 'o')
        .replaceAll('ÅŸ', 's')
        .replaceAll('Ã¼', 'u');
  }
}

class _SearchFilterRow extends StatelessWidget {
  const _SearchFilterRow({
    required this.controller,
    required this.onSearchChanged,
    required this.onFilterPressed,
    required this.filtersActive,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFilterPressed;
  final bool filtersActive;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Search sport, area, or event',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Material(
          color: filtersActive ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onFilterPressed,
            child: SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.tune,
                    color: filtersActive ? Colors.white : AppColors.primary,
                  ),
                  if (filtersActive)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
