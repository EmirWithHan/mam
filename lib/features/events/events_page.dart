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
import 'events_provider.dart';
import 'widgets/event_card.dart';

class EventsPage extends ConsumerStatefulWidget {
  const EventsPage({super.key});

  @override
  ConsumerState<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends ConsumerState<EventsPage> {
  final _searchController = TextEditingController();

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
          IconButton(
            tooltip: 'Bildirimler',
            onPressed: () => context.pushNamed(RouteNames.notifications),
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.primary,
            ),
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
              _SearchBox(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventsBody extends StatelessWidget {
  const _EventsBody({
    required this.eventsState,
    required this.searchQuery,
  });

  final EventsState eventsState;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    if (eventsState.isLoading) {
      return const AppLoader();
    }

    if (eventsState.status == EventsStatus.error) {
      return ErrorView(
        message: eventsState.message ?? 'Could not load events.',
      );
    }

    final filteredEvents = eventsState.events.where((event) {
      final query = searchQuery.trim().toLowerCase();
      if (query.isEmpty) return true;

      final textMatches = [
        event.title,
        event.sportType,
        event.locationLabel,
        event.locationText ?? '',
      ].any((value) => value.toLowerCase().contains(query));

      return textMatches;
    }).toList();

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
      return const EmptyState(
        title: 'Eşleşen etkinlik yok',
        message: 'Başka bir etkinlik adı, spor veya konum aramayı dene.',
      );
    }

    return ListView.separated(
      itemCount: filteredEvents.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        return EventCard(event: filteredEvents[index]);
      },
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: const InputDecoration(
        hintText: 'Search sport, area, or event',
        prefixIcon: Icon(Icons.search),
      ),
    );
  }
}
