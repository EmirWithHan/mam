import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
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
      appBar: AppBar(title: const Text('Events')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
      return const Center(child: CircularProgressIndicator());
    }

    if (eventsState.status == EventsStatus.error) {
      return Center(
        child: Text(
          eventsState.message ?? 'Could not load events.',
          textAlign: TextAlign.center,
        ),
      );
    }

    if (eventsState.events.isEmpty) {
      return Center(
        child: Text(
          'No events yet.',
          style: AppTextStyles.body,
          textAlign: TextAlign.center,
        ),
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
