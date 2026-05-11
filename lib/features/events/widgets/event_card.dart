import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../events_models.dart';

class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
  });

  final Event event;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => context.goNamed(
          RouteNames.eventDetail,
          pathParameters: {'eventId': event.id},
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(event.title, style: AppTextStyles.title),
                  ),
                  if (event.isSponsored)
                    const Text(
                      'Sponsored',
                      style: TextStyle(color: AppColors.accent),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(event.sportType, style: AppTextStyles.body),
              const SizedBox(height: AppSpacing.xs),
              Text(event.locationLabel, style: AppTextStyles.caption),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _formatDateTime(event.eventDate),
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(event.capacityLabel, style: AppTextStyles.caption),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }
}
