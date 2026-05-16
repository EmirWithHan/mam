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
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(eventsControllerProvider.notifier).loadEvents();
    });
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
              Text('Events', style: AppTextStyles.headline),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Find your next match, run, or social sports plan.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.md),
              const _CategoryChips(),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Create event',
                onPressed: () => context.goNamed(RouteNames.createEvent),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(child: _EventsBody(eventsState: eventsState)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventsBody extends StatelessWidget {
  const _EventsBody({required this.eventsState});

  final EventsState eventsState;

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

    if (eventsState.events.isEmpty) {
      return const EmptyState(
        title: 'No events yet.',
        message: 'Create the first sports plan and bring people together.',
      );
    }

    return ListView.separated(
      itemCount: eventsState.events.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        return EventCard(event: eventsState.events[index]);
      },
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: const [
        _CategoryChip(label: 'All Events', selected: true),
        _CategoryChip(label: 'Football'),
        _CategoryChip(label: 'Tennis'),
        _CategoryChip(label: 'Running'),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    this.selected = false,
  });

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : AppColors.surface,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
        ),
        borderRadius: AppRadius.pillBorder,
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
    );
  }
}
