import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/responsive_layout.dart';
import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../auth/auth_provider.dart';
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
      if (!mounted) return;
      ref.read(featuredEventsProvider.notifier).loadEvents();
      ref.read(followingEventsProvider.notifier).loadEvents();
      ref
          .read(notificationsControllerProvider.notifier)
          .startRealtime(ref.read(authControllerProvider).userId);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 720;

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
        child: DefaultTabController(
          length: 3,
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: AppResponsive.pagePadding(
                      context,
                      top: compact ? AppSpacing.sm : AppSpacing.md,
                      bottom: compact ? AppSpacing.sm : AppSpacing.md,
                    ),
                    child: _EventsHeader(
                      compact: compact,
                      controller: _searchController,
                      filtersActive: _filters.isActive,
                      onSearchChanged: (_) => setState(() {}),
                      onFilterPressed: _openFilterSheet,
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverTabBarDelegate(
                    TabBar(
                      labelColor: AppColors.primary,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: AppColors.primary,
                      tabs: const [
                        Tab(text: 'Öne Çıkanlar'),
                        Tab(text: 'Takip Ettiklerim'),
                        Tab(text: 'Katıldıklarım'),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              children: [
                _EventsTabList(
                  eventsState: ref.watch(featuredEventsProvider),
                  searchQuery: _searchController.text,
                  filters: _filters,
                  onLoadMore: () => ref
                      .read(featuredEventsProvider.notifier)
                      .loadMoreEvents(),
                  onRefresh: () =>
                      ref.read(featuredEventsProvider.notifier).refreshEvents(),
                  onClearFilters: _clearSearchAndFilters,
                ),
                _EventsTabList(
                  eventsState: ref.watch(followingEventsProvider),
                  searchQuery: _searchController.text,
                  filters: _filters,
                  onLoadMore: () => ref
                      .read(followingEventsProvider.notifier)
                      .loadMoreEvents(),
                  onRefresh: () => ref
                      .read(followingEventsProvider.notifier)
                      .refreshEvents(),
                  onClearFilters: _clearSearchAndFilters,
                ),
                _MyEventsTabList(
                  onRefresh: () => ref.refresh(myEventsProvider.future),
                ),
              ],
            ),
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

class _EventsTabList extends ConsumerWidget {
  const _EventsTabList({
    required this.eventsState,
    required this.searchQuery,
    required this.filters,
    required this.onLoadMore,
    required this.onRefresh,
    required this.onClearFilters,
  });

  final EventsState eventsState;
  final String searchQuery;
  final EventFilters filters;
  final VoidCallback onLoadMore;
  final Future<void> Function() onRefresh;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredEvents = eventsState.events
        .where((event) => _matchesSearch(event, searchQuery))
        .where((event) => _matchesFilters(event, filters))
        .toList();

    // Apply sorting
    switch (filters.sortOption) {
      case EventSortOption.recommended:
        break;
      case EventSortOption.newest:
        filteredEvents.sort((a, b) {
          final timeA = a.createdAt ?? a.eventDate;
          final timeB = b.createdAt ?? b.eventDate;
          return timeB.compareTo(timeA);
        });
        break;
      case EventSortOption.oldest:
        filteredEvents.sort((a, b) {
          final timeA = a.createdAt ?? a.eventDate;
          final timeB = b.createdAt ?? b.eventDate;
          return timeA.compareTo(timeB);
        });
        break;
      case EventSortOption.dateAsc:
        filteredEvents.sort((a, b) => a.eventDate.compareTo(b.eventDate));
        break;
      case EventSortOption.dateDesc:
        filteredEvents.sort((a, b) => b.eventDate.compareTo(a.eventDate));
        break;
    }

    final itemsList = eventsWithSponsoredPlacement(filteredEvents);

    if (eventsState.isLoading && eventsState.events.isEmpty) {
      return const Center(child: AppLoader());
    }

    if (eventsState.status == EventsStatus.error &&
        eventsState.events.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppResponsive.pagePadding(context),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.4,
              child: ErrorView(
                message: eventsState.message ?? 'Etkinlikler yüklenemedi.',
              ),
            ),
          ],
        ),
      );
    }

    if (itemsList.isEmpty) {
      final isEmptyState = eventsState.events.isEmpty;
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppResponsive.pagePadding(context),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.4,
              child: isEmptyState
                  ? EmptyState(
                      title: 'Henüz etkinlik yok',
                      message:
                          'İlk etkinliği sen oluşturabilir ya da daha sonra tekrar keşfe çıkabilirsin.',
                      icon: Icons.event_available_outlined,
                      actionLabel: 'Etkinlik oluştur',
                      onAction: () => context.pushNamed(RouteNames.createEvent),
                    )
                  : EmptyState(
                      title: 'Etkinlik bulunamadı',
                      message:
                          'Arama veya filtreleri değiştirerek tekrar dene.',
                      actionLabel: 'Filtreleri temizle',
                      onAction: onClearFilters,
                    ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppResponsive.pagePadding(context),
        itemCount: itemsList.length + (eventsState.hasMore ? 1 : 0),
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          if (index == itemsList.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: AppButton(
                label: 'Daha fazla yükle',
                isLoading: eventsState.isLoadingMore,
                onPressed: eventsState.isLoadingMore ? null : onLoadMore,
              ),
            );
          }

          final item = itemsList[index];
          return EventCard(event: item);
        },
      ),
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
        event.safeApprovedCount >= event.safeCapacityTotal) {
      return false;
    }

    // Price Filter
    switch (filters.priceFilter) {
      case EventPriceFilter.all:
        break;
      case EventPriceFilter.free:
        if (event.isPaid) return false;
        break;
      case EventPriceFilter.paid:
        if (!event.isPaid) return false;
        break;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (filters.dateFilter) {
      case EventDateFilter.all:
        return true;
      case EventDateFilter.today:
        return DateUtils.isSameDay(event.eventDate, now);
      case EventDateFilter.tomorrow:
        final tomorrow = today.add(const Duration(days: 1));
        return DateUtils.isSameDay(event.eventDate, tomorrow);
      case EventDateFilter.thisWeek:
        final end = today.add(const Duration(days: 7));
        return !event.eventDate.isBefore(today) &&
            event.eventDate.isBefore(end);
      case EventDateFilter.weekend:
        final weekday = event.eventDate.weekday;
        return weekday == DateTime.saturday || weekday == DateTime.sunday;
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
        .replaceAll('Ã¼', 'u')
        .replaceAll('ÃƒÂ§', 'c')
        .replaceAll('Ã„Å¸', 'g')
        .replaceAll('Ã„Â±', 'i')
        .replaceAll('ÃƒÂ¶', 'o')
        .replaceAll('Ã…Å¸', 's')
        .replaceAll('ÃƒÂ¼', 'u');
  }
}

class _EventsHeader extends StatelessWidget {
  const _EventsHeader({
    required this.compact,
    required this.controller,
    required this.onSearchChanged,
    required this.onFilterPressed,
    required this.filtersActive,
  });

  final bool compact;
  final TextEditingController controller;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFilterPressed;
  final bool filtersActive;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text('Etkinlik Bul', style: AppTextStyles.headline),
            ),
            if (!compact) const AppLogo(size: 40),
          ],
        ),
        SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
        Text(
          'Yakındaki sosyal spor etkinliklerini keşfet.',
          style: AppTextStyles.body,
        ),
        SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
        _SearchFilterRow(
          controller: controller,
          filtersActive: filtersActive,
          onSearchChanged: onSearchChanged,
          onFilterPressed: onFilterPressed,
        ),
        SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
        AppButton(
          label: 'Etkinlik oluştur',
          onPressed: () => context.pushNamed(RouteNames.createEvent),
        ),
      ],
    );
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
              hintText: 'Spor, bölge veya etkinlik ara',
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

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}

class _MyEventsTabList extends ConsumerWidget {
  const _MyEventsTabList({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myEventsAsync = ref.watch(myEventsProvider);

    return myEventsAsync.when(
      data: (items) {
        final now = DateTime.now();

        int getPriority(MyEventItem item) {
          final status = item.status;
          final isPast = item.event.eventDate.isBefore(now);
          if (status == 'cancelled' ||
              status == 'rejected' ||
              status == 'left' ||
              status == 'no_show') {
            return 4;
          }
          if (isPast) {
            return 3;
          }
          if (status == 'pending' ||
              status == 'pending_confirmation' ||
              status == 'waitlisted') {
            return 2;
          }
          return 1;
        }

        final sortedItems = List<MyEventItem>.from(items)
          ..sort((a, b) {
            final pA = getPriority(a);
            final pB = getPriority(b);
            if (pA != pB) {
              return pA.compareTo(pB);
            }
            if (pA == 1 || pA == 2) {
              return a.event.eventDate.compareTo(b.event.eventDate);
            } else {
              return b.event.eventDate.compareTo(a.event.eventDate);
            }
          });

        return _MyEventsSubList(
          items: sortedItems,
          emptyTitle: 'Henüz katıldığın veya istek gönderdiğin etkinlik yok.',
          emptyMessage:
              'Katıldığın, istek gönderdiğin veya düzenlediğin tüm etkinlikler burada listelenir.',
          onRefresh: onRefresh,
        );
      },
      loading: () => const Center(child: AppLoader()),
      error: (err, stack) => RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppResponsive.pagePadding(context),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.4,
              child: ErrorView(
                message: 'Etkinliklerim yüklenemedi. Lütfen tekrar dene.',
                onRetry: () => ref.invalidate(myEventsProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyEventsSubList extends StatelessWidget {
  const _MyEventsSubList({
    required this.items,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onRefresh,
  });

  final List<MyEventItem> items;
  final String emptyTitle;
  final String emptyMessage;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppResponsive.pagePadding(context),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.4,
              child: EmptyState(
                title: emptyTitle,
                message: emptyMessage,
                icon: Icons.event_available_outlined,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppResponsive.pagePadding(context),
        itemCount: items.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final item = items[index];
          return EventCard(event: item.event, status: item.status);
        },
      ),
    );
  }
}
