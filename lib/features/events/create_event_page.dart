import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../profile/profile_provider.dart';
import 'events_models.dart';
import 'events_provider.dart';

class CreateEventPage extends ConsumerStatefulWidget {
  const CreateEventPage({super.key});

  @override
  ConsumerState<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends ConsumerState<CreateEventPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sportTypeController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _locationTextController = TextEditingController();
  final _eventDateController = TextEditingController();
  final _capacityTotalController = TextEditingController();
  final _capacityMaleController = TextEditingController(text: '0');
  final _capacityFemaleController = TextEditingController(text: '0');
  final _capacityAnyController = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(profileControllerProvider.notifier).loadMyProfile();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _sportTypeController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _locationTextController.dispose();
    _eventDateController.dispose();
    _capacityTotalController.dispose();
    _capacityMaleController.dispose();
    _capacityFemaleController.dispose();
    _capacityAnyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final input = CreateEventInput(
      title: _titleController.text,
      description: _descriptionController.text,
      sportType: _sportTypeController.text,
      city: _cityController.text,
      district: _districtController.text,
      locationText: _locationTextController.text,
      eventDate: _parseEventDate(_eventDateController.text.trim())!,
      capacityTotal: int.parse(_capacityTotalController.text.trim()),
      capacityMale: _parseIntOrZero(_capacityMaleController.text),
      capacityFemale: _parseIntOrZero(_capacityFemaleController.text),
      capacityAny: _parseIntOrZero(_capacityAnyController.text),
    );

    final event = await ref
        .read(eventsControllerProvider.notifier)
        .createEvent(input);

    if (!mounted) return;
    if (event != null) {
      context.goNamed(RouteNames.events);
      return;
    }

    final message = ref.read(eventsControllerProvider).message;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);
    final eventsState = ref.watch(eventsControllerProvider);

    if (profileState.status == ProfileStatus.initial ||
        profileState.isLoading) {
      return const Scaffold(
        body: SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (!profileState.canCreateEvent) {
      return Scaffold(
        appBar: AppBar(title: const Text('Create event')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Complete your profile before creating an event.',
                  style: AppTextStyles.title,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'You can keep browsing events now and finish your player card when you are ready to host.',
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Complete profile',
                  onPressed: () =>
                      context.goNamed(RouteNames.profileComplete),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Browse events',
                  onPressed: () => context.goNamed(RouteNames.events),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Create event')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text('Host a match', style: AppTextStyles.title),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Title',
                controller: _titleController,
                validator: _requiredValidator('Title'),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Description',
                controller: _descriptionController,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Sport type',
                controller: _sportTypeController,
                validator: _requiredValidator('Sport type'),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'City',
                controller: _cityController,
                validator: _requiredValidator('City'),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'District',
                controller: _districtController,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Location',
                controller: _locationTextController,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Event date',
                hintText: 'YYYY-MM-DD HH:mm',
                controller: _eventDateController,
                keyboardType: TextInputType.datetime,
                validator: _eventDateValidator,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Capacity total',
                controller: _capacityTotalController,
                keyboardType: TextInputType.number,
                validator: _capacityTotalValidator,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Capacity male',
                controller: _capacityMaleController,
                keyboardType: TextInputType.number,
                validator: _capacityPartValidator,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Capacity female',
                controller: _capacityFemaleController,
                keyboardType: TextInputType.number,
                validator: _capacityPartValidator,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Capacity any',
                controller: _capacityAnyController,
                keyboardType: TextInputType.number,
                validator: _capacityPartValidator,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Create event',
                isLoading: eventsState.isLoading,
                onPressed: _submit,
              ),
              if (eventsState.status == EventsStatus.error &&
                  eventsState.message != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  eventsState.message!,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String? Function(String?) _requiredValidator(String label) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return '$label is required.';
      }
      return null;
    };
  }

  String? _eventDateValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Event date is required.';
    }
    if (_parseEventDate(value.trim()) == null) {
      return 'Use YYYY-MM-DD HH:mm format.';
    }
    return null;
  }

  String? _capacityTotalValidator(String? value) {
    final capacityTotal = int.tryParse(value?.trim() ?? '');
    if (capacityTotal == null || capacityTotal <= 0) {
      return 'Capacity total must be greater than 0.';
    }

    final capacityParts = _capacityPartsTotal();
    if (capacityParts > capacityTotal) {
      return 'Capacity parts must not exceed total.';
    }

    return null;
  }

  String? _capacityPartValidator(String? value) {
    final capacity = int.tryParse(value?.trim().isEmpty == true
        ? '0'
        : value?.trim() ?? '0');
    if (capacity == null || capacity < 0) {
      return 'Use 0 or greater.';
    }

    final capacityTotal = int.tryParse(_capacityTotalController.text.trim());
    if (capacityTotal != null && _capacityPartsTotal() > capacityTotal) {
      return 'Capacity parts must not exceed total.';
    }

    return null;
  }

  int _capacityPartsTotal() {
    return _parseIntOrZero(_capacityMaleController.text) +
        _parseIntOrZero(_capacityFemaleController.text) +
        _parseIntOrZero(_capacityAnyController.text);
  }

  int _parseIntOrZero(String value) {
    return int.tryParse(value.trim()) ?? 0;
  }

  DateTime? _parseEventDate(String value) {
    if (value.length != 16) return null;
    final normalized = value.replaceFirst(' ', 'T');
    return DateTime.tryParse(normalized);
  }
}
