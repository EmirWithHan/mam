import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_loader.dart';
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
  String _selectedSport = 'All Events';

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

    return Scaffold(
      appBar: AppBar(title: const Text('MaM')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Find a Game!', style: AppTextStyles.headline),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.sports_soccer,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Discover friendly matches nearby.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.md),
              _SearchBox(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.md),
              _CategoryChips(
                selectedSport: _selectedSport,
                onSelected: (sport) => setState(() => _selectedSport = sport),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Host an Event',
                onPressed: () => context.goNamed(RouteNames.createEvent),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: _EventsBody(
                  eventsState: eventsState,
                  searchQuery: _searchController.text,
                  selectedSport: _selectedSport,
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
    required this.selectedSport,
  });

  final EventsState eventsState;
  final String searchQuery;
  final String selectedSport;

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
      final sportMatches = selectedSport == 'All Events' ||
          event.sportType.toLowerCase() == selectedSport.toLowerCase();
      final query = searchQuery.trim().toLowerCase();
      if (query.isEmpty) return sportMatches;

      final textMatches = [
        event.title,
        event.sportType,
        event.locationLabel,
        event.locationText ?? '',
      ].any((value) => value.toLowerCase().contains(query));

      return sportMatches && textMatches;
    }).toList();

    if (eventsState.events.isEmpty) {
      return const EmptyState(
        title: 'No events yet.',
        message: 'Create the first sports plan and bring people together.',
      );
    }

    if (filteredEvents.isEmpty) {
      return const EmptyState(
        title: 'No matching events.',
        message: 'Try another sport or search term.',
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

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.selectedSport,
    required this.onSelected,
  });

  final String selectedSport;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    const sports = [
      'All Events',
      'Football',
      'Tennis',
      'Running',
      'Basketball',
      'Volleyball',
    ];

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: sports
          .map(
            (sport) => _CategoryChip(
              label: sport,
              selected: selectedSport == sport,
              onTap: () => onSelected(sport),
            ),
          )
          .toList(),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.pillBorder,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
          borderRadius: AppRadius.pillBorder,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.22),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            label,
            style: AppTextStyles.label.copyWith(
              color: selected ? Colors.white : AppColors.primary,
            ),
          ),
        ),
      ),
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
