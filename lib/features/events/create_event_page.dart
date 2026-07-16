import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/sport_types.dart';
import '../../core/constants/turkey_locations.dart';
import '../../core/layout/responsive_layout.dart';
import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/sport_icon.dart';
import '../../services/location_service.dart';
import '../../services/location_autocomplete_service.dart';
import '../auth/auth_provider.dart';
import '../business/business_models.dart';
import '../business/business_provider.dart';
import '../profile/profile_provider.dart';
import 'events_models.dart';
import 'events_provider.dart';

class CreateEventPage extends ConsumerStatefulWidget {
  const CreateEventPage({super.key, this.eventId});

  final String? eventId;

  @override
  ConsumerState<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends ConsumerState<CreateEventPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sportTypeController = TextEditingController();
  final _customSportController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _locationTextController = TextEditingController();
  final _locationDescriptionController = TextEditingController();
  final _eventDateController = TextEditingController();
  final _capacityTotalController = TextEditingController();
  final _capacityMaleController = TextEditingController(text: '0');
  final _capacityFemaleController = TextEditingController(text: '0');
  final _capacityAnyController = TextEditingController(text: '0');
  final _priceController = TextEditingController();
  final _openTimeController = TextEditingController();
  final _closeTimeController = TextEditingController();
  final _locationService = const LocationService();
  final _autocompleteService = const LocationAutocompleteService();
  List<LocationSuggestion> _suggestions = [];

  DateTime? _selectedEventDate;
  double? _locationLat;
  double? _locationLng;
  double? _userLat;
  double? _userLng;
  bool _locating = false;
  String? _locationHelperText;
  String? _prefilledEventId;
  Event? _editingEvent;
  TimeOfDay? _selectedOpenTime;
  TimeOfDay? _selectedCloseTime;

  bool _useBusinessDefaults = false;
  String _priceType = 'free';

  bool get _usesCustomSport => _sportTypeController.text == SportTypes.other;

  bool get _isEditing => widget.eventId?.trim().isNotEmpty == true;

  DateTime get _normalEventCreationMaxDate =>
      DateTime.now().add(const Duration(days: 28));

  DateTime get _plusEventPickerMaxDate {
    final now = DateTime.now();
    return DateTime(now.year + 5, now.month, now.day);
  }

  DateTime get _eventPickerMaxDate {
    final maxDate = _canUseBusinessPlusHorizon
        ? _plusEventPickerMaxDate
        : _normalEventCreationMaxDate;
    final existingDate = _editingEvent?.eventDate;
    if (existingDate != null && existingDate.isAfter(maxDate)) {
      return existingDate;
    }
    return maxDate;
  }

  bool get _canUseBusinessPlusHorizon {
    final businessAccount = ref.read(myBusinessAccountProvider).account;
    final profile = ref.read(profileControllerProvider).profile;
    final editingEvent = _editingEvent;
    final isBusinessEvent =
        editingEvent?.isBusinessEvent ??
        CreateEventInput.canUseBusinessEventFields(
          isBusinessAccount: profile?.isBusinessAccount == true,
          businessAccount: businessAccount,
        );
    return isBusinessEvent && businessAccount?.isPlusActive == true;
  }

  @override
  void initState() {
    super.initState();
    _initUserLocation();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(profileControllerProvider.notifier).loadMyProfile();
      ref.read(myBusinessAccountProvider.notifier).loadMyBusinessAccount();
    });
  }

  Future<void> _initUserLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 2),
        );
        if (mounted) {
          setState(() {
            _userLat = position.latitude;
            _userLng = position.longitude;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _sportTypeController.dispose();
    _customSportController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _locationTextController.dispose();
    _locationDescriptionController.dispose();
    _eventDateController.dispose();
    _capacityTotalController.dispose();
    _capacityMaleController.dispose();
    _capacityFemaleController.dispose();
    _capacityAnyController.dispose();
    _priceController.dispose();
    _openTimeController.dispose();
    _closeTimeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (ref.read(eventsControllerProvider).isMutating) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final city =
        TurkeyLocations.normalizeCityName(_cityController.text) ??
        _cityController.text.trim();
    final district =
        TurkeyLocations.normalizeDistrictName(city, _districtController.text) ??
        _districtController.text.trim();
    final businessAccount = ref.read(myBusinessAccountProvider).account;
    final profile = ref.read(profileControllerProvider).profile;
    final editingEvent = _editingEvent;
    final isBusinessEvent =
        editingEvent?.isBusinessEvent ??
        CreateEventInput.canUseBusinessEventFields(
          isBusinessAccount: profile?.isBusinessAccount == true,
          businessAccount: businessAccount,
        );
    final eventDate = _currentEventDateForSubmit();
    final horizonMessage = _eventHorizonError(eventDate);
    if (horizonMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(horizonMessage)));
      return;
    }
    final capacityTotal = _capacityPartsTotal();
    if (capacityTotal < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az bir kontenjan seçmelisin.')),
      );
      return;
    }

    if (editingEvent != null) {
      final editLockMessage = editingEvent.editLockMessage();
      if (editLockMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(editLockMessage)));
        return;
      }

      final input = UpdateEventInput(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        sportType: _resolvedSportType(),
        city: city,
        district: district,
        locationText: _locationTextController.text.trim(),
        locationLat: _locationLat,
        locationLng: _locationLng,
        eventDate: eventDate,
        capacityTotal: capacityTotal,
        capacityMale: _parseIntOrZero(_capacityMaleController.text),
        capacityFemale: _parseIntOrZero(_capacityFemaleController.text),
        capacityAny: _parseIntOrZero(_capacityAnyController.text),
        isBusinessEvent: isBusinessEvent,
        isPaid: isBusinessEvent && (_priceType == 'pay_at_business'),
        priceAmount: _parsePrice(_priceController.text),
        businessOpenTime: isBusinessEvent
            ? _openTimeController.text.trim()
            : null,
        businessCloseTime: isBusinessEvent
            ? _closeTimeController.text.trim()
            : null,
        eventStartTime: isBusinessEvent
            ? _openTimeController.text.trim()
            : null,
        eventEndTime: isBusinessEvent ? _closeTimeController.text.trim() : null,
        priceType: isBusinessEvent ? _priceType : 'free',
        locationDescription: _locationDescriptionController.text.trim(),
      );

      final event = await ref
          .read(eventsControllerProvider.notifier)
          .updateEvent(eventId: editingEvent.id, input: input);

      if (!mounted) return;
      if (event != null) {
        ref.invalidate(eventDetailProvider(editingEvent.id));
        final messenger = ScaffoldMessenger.of(context);
        context.goNamed(
          RouteNames.eventDetail,
          pathParameters: {'eventId': editingEvent.id},
        );
        messenger.showSnackBar(
          const SnackBar(content: Text('Etkinlik güncellendi.')),
        );
        return;
      }

      final message = ref.read(eventsControllerProvider).mutationMessage;
      if (message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }

    final input = CreateEventInput(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      sportType: _resolvedSportType(),
      city: city,
      district: district,
      locationText: _locationTextController.text.trim(),
      locationLat: _locationLat,
      locationLng: _locationLng,
      eventDate: eventDate,
      capacityTotal: capacityTotal,
      capacityMale: _parseIntOrZero(_capacityMaleController.text),
      capacityFemale: _parseIntOrZero(_capacityFemaleController.text),
      capacityAny: _parseIntOrZero(_capacityAnyController.text),
      organizerType: isBusinessEvent
          ? EventOrganizerType.business
          : EventOrganizerType.user,
      businessAccount: isBusinessEvent ? businessAccount : null,
      isPaid: isBusinessEvent && (_priceType == 'pay_at_business'),
      priceAmount: _parsePrice(_priceController.text),
      businessOpenTime: isBusinessEvent
          ? _openTimeController.text.trim()
          : null,
      businessCloseTime: isBusinessEvent
          ? _closeTimeController.text.trim()
          : null,
      eventStartTime: isBusinessEvent ? _openTimeController.text.trim() : null,
      eventEndTime: isBusinessEvent ? _closeTimeController.text.trim() : null,
      priceType: isBusinessEvent ? _priceType : 'free',
      locationDescription: _locationDescriptionController.text.trim(),
    );

    final event = await ref
        .read(eventsControllerProvider.notifier)
        .createEvent(input);

    if (!mounted) return;
    if (event != null) {
      context.goNamed(RouteNames.events);
      return;
    }

    final message = ref.read(eventsControllerProvider).mutationMessage;
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _selectSport() async {
    final sportValues = SportTypes.values;
    final selected = await _showOptionSheet(
      title: 'Etkinlik türü seç',
      values: sportValues,
      selectedValue: _sportTypeController.text,
      searchable: false,
      showSportIcons: true,
    );
    if (selected == null) return;

    setState(() {
      _sportTypeController.text = selected;
      if (selected != SportTypes.other) _customSportController.clear();
    });
  }

  Future<void> _selectCity() async {
    final selected = await _showOptionSheet(
      title: 'Şehir seç',
      values: TurkeyLocations.getCities(),
      selectedValue: _cityController.text,
      searchHint: 'Şehir ara',
    );
    if (selected == null) return;

    setState(() {
      _cityController.text = selected;
      _districtController.clear();
    });
  }

  Future<void> _selectDistrict() async {
    final city = _cityController.text.trim();
    if (!TurkeyLocations.isValidCity(city)) return;

    final selected = await _showOptionSheet(
      title: 'İlçe seç',
      values: TurkeyLocations.getDistricts(city),
      selectedValue: _districtController.text,
      searchHint: 'İlçe ara',
    );
    if (selected == null) return;

    setState(() => _districtController.text = selected);
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initial = _selectedEventDate ?? now.add(const Duration(days: 1));
    final lastDate = _eventPickerMaxDate;
    final date = await showDatePicker(
      context: context,
      locale: const Locale('tr', 'TR'),
      initialDate: initial.isAfter(lastDate) ? lastDate : initial,
      firstDate: now,
      lastDate: lastDate,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Tarih seç',
      cancelText: 'İptal',
      confirmText: 'Tamam',
      fieldLabelText: 'Tarih',
      fieldHintText: 'GG.AA.YYYY',
      errorFormatText: 'Tarihi GG.AA.YYYY formatında gir.',
      errorInvalidText: 'Geçerli bir tarih seç.',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      initialEntryMode: TimePickerEntryMode.dialOnly,
      helpText: 'Saat seç',
      cancelText: 'İptal',
      confirmText: 'Tamam',
      hourLabelText: 'Saat',
      minuteLabelText: 'Dakika',
      errorInvalidText: 'Geçerli bir saat seç.',
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
              secondary: AppColors.primary,
              surface: AppColors.surface,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: AppColors.surface,
              dialHandColor: AppColors.primary,
              dialBackgroundColor: AppColors.primarySoft,
              hourMinuteColor: AppColors.primarySoft,
              hourMinuteTextColor: AppColors.textPrimary,
              entryModeIconColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
          ),
          child: MediaQuery(
            data: mediaQuery.copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        );
      },
    );
    if (time == null) return;

    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      _selectedEventDate = selected;
      _eventDateController.text = DateFormatter.formatEventDateTime(selected);
    });
  }

  String? _eventHorizonError(DateTime? value) {
    if (value == null) return null;
    if (_canUseBusinessPlusHorizon) return null;

    final maxDate = _normalEventCreationMaxDate;
    if (!value.isAfter(maxDate)) return null;

    final existingDate = _editingEvent?.eventDate;
    if (existingDate != null &&
        existingDate.isAfter(maxDate) &&
        !value.isAfter(existingDate)) {
      return null;
    }

    if (value.isAfter(maxDate)) {
      return 'Etkinlik tarihi en fazla 28 gün sonrası olabilir.';
    }
    return null;
  }

  DateTime _currentEventDateForSubmit() {
    final visibleDate = _parseEventDateController();
    if (visibleDate != null) {
      _selectedEventDate = visibleDate;
      return visibleDate;
    }
    return _selectedEventDate!;
  }

  DateTime? _parseEventDateController() {
    final value = _eventDateController.text.trim();
    final match = RegExp(
      r'^(\d{1,2})\.(\d{1,2})\.(\d{4})\s+(\d{1,2}):(\d{2})$',
    ).firstMatch(value);
    if (match == null) return null;

    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);
    final hour = int.tryParse(match.group(4)!);
    final minute = int.tryParse(match.group(5)!);
    if (day == null ||
        month == null ||
        year == null ||
        hour == null ||
        minute == null) {
      return null;
    }

    final parsed = DateTime(year, month, day, hour, minute);
    if (parsed.year != year ||
        parsed.month != month ||
        parsed.day != day ||
        parsed.hour != hour ||
        parsed.minute != minute) {
      return null;
    }
    return parsed;
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);

    try {
      final position = await _locationService.getCurrentPosition();
      final address = await _locationService.getAddressFromCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      final locationLabel =
          address ??
          _locationService.formatCoordinates(
            position.latitude,
            position.longitude,
          );
      if (!mounted) return;

      setState(() {
        _locationLat = position.latitude;
        _locationLng = position.longitude;
        _userLat = position.latitude;
        _userLng = position.longitude;
        _locationTextController.text = locationLabel;
        _locationHelperText = address == null
            ? 'Konum koordinatları kaydedildi'
            : 'Otomatik konum kullanılıyor';
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Konum seçildi.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_locationErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _clearLocation() {
    setState(() {
      _locationLat = null;
      _locationLng = null;
      _locationTextController.clear();
      _locationHelperText = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);
    final eventsState = ref.watch(eventsControllerProvider);
    final businessAccount = ref.watch(myBusinessAccountProvider).account;
    final authState = ref.watch(authControllerProvider);
    final editEventAsync = _isEditing
        ? ref.watch(eventDetailProvider(widget.eventId!.trim()))
        : null;

    if (editEventAsync != null) {
      if (editEventAsync.isLoading) {
        return const Scaffold(body: SafeArea(child: AppLoader()));
      }
      if (editEventAsync.hasError) {
        return Scaffold(
          appBar: _CreateEventAppBar(onBack: () => _goBack(context)),
          body: const SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'Etkinlik bilgileri yüklenemedi.',
                  style: AppTextStyles.title,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        );
      }

      final event = editEventAsync.valueOrNull;
      if (event != null) {
        _prefillForEdit(event);
        if (!event.isHost(authState.userId)) {
          return Scaffold(
            appBar: _CreateEventAppBar(onBack: () => _goBack(context)),
            body: const SafeArea(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'Bu etkinliği sadece ev sahibi düzenleyebilir.',
                    style: AppTextStyles.title,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        }
        final editLockMessage = event.editLockMessage();
        if (editLockMessage != null) {
          return Scaffold(
            appBar: _CreateEventAppBar(onBack: () => _goBack(context)),
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    editLockMessage,
                    style: AppTextStyles.title,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        }
        if (!event.canBeEdited) {
          return Scaffold(
            appBar: _CreateEventAppBar(onBack: () => _goBack(context)),
            body: const SafeArea(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'Geçmiş veya iptal edilmiş etkinlikler düzenlenemez.',
                    style: AppTextStyles.title,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        }
      }
    }

    if (profileState.status == ProfileStatus.initial ||
        profileState.isLoading) {
      return const Scaffold(body: SafeArea(child: AppLoader()));
    }

    if (profileState.status == ProfileStatus.error) {
      return Scaffold(
        appBar: _CreateEventAppBar(onBack: () => _goBack(context)),
        body: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Profil bilgileri kontrol edilemedi.',
                style: AppTextStyles.title,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    if (!_isEditing && !profileState.canCreateEvent) {
      return Scaffold(
        appBar: _CreateEventAppBar(onBack: () => _goBack(context)),
        body: SafeArea(
          child: Padding(
            padding: AppResponsive.pagePadding(context),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Profilini tamamla',
                  style: AppTextStyles.title,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Etkinlik oluşturmadan önce profil bilgilerini tamamlamalısın.',
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Profili tamamla',
                  onPressed: () => context.pushNamed(
                    RouteNames.profileComplete,
                    queryParameters: {
                      'mode': RoutePaths.profileCompleteModeEventRequirements,
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Vazgeç',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => context.goNamed(RouteNames.events),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isBusinessIdentity = profileState.profile?.isBusinessAccount == true;
    final editingEvent = _editingEvent;
    final isBusinessEvent =
        editingEvent?.isBusinessEvent ??
        CreateEventInput.canUseBusinessEventFields(
          isBusinessAccount: isBusinessIdentity,
          businessAccount: businessAccount,
        );
    final city = _cityController.text.trim();
    final districts = TurkeyLocations.getDistricts(city);

    return Scaffold(
      appBar: _CreateEventAppBar(onBack: () => _goBack(context)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: AppResponsive.pagePadding(context),
            children: [
              Text(
                _isEditing ? 'Etkinliği düzenle' : 'Etkinlik Oluştur',
                style: AppTextStyles.headline,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _isEditing
                    ? 'Etkinlik bilgilerini güncel tut.'
                    : 'Ekibini topla, sahaya çık.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (isBusinessEvent &&
                  businessAccount != null &&
                  defaultTargetPlatform != TargetPlatform.iOS) ...[
                CheckboxListTile(
                  title: const Text(
                    'İşletme bilgilerini varsayılan olarak kullan',
                  ),
                  subtitle: const Text(
                    'Konum ve çalışma saatleri işletme profilinden alınır.',
                  ),
                  value: _useBusinessDefaults,
                  onChanged: _onUseBusinessDefaultsChanged,
                  activeColor: AppColors.primary,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: AppSpacing.md),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: businessAccount.isPlusActive
                        ? AppColors.tertiary.withValues(alpha: 0.1)
                        : AppColors.primarySoft,
                    borderRadius: AppRadius.lgBorder,
                    border: Border.all(
                      color: businessAccount.isPlusActive
                          ? AppColors.tertiary
                          : AppColors.primary,
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Icon(
                          businessAccount.isPlusActive
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: businessAccount.isPlusActive
                              ? AppColors.tertiary
                              : AppColors.primary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                businessAccount.isPlusActive
                                    ? 'Business Plus Aktif'
                                    : 'Business Plus (Plus aktif değil)',
                                style: AppTextStyles.bodyStrong.copyWith(
                                  color: businessAccount.isPlusActive
                                      ? AppColors.textPrimary
                                      : AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                businessAccount.isPlusActive
                                    ? 'Aylık 30 etkinlik oluşturma limitiniz var.'
                                    : 'Aylık 3 etkinlik oluşturma limitiniz var. Limitleri artırmak için Plus\'a geç.',
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                        if (!businessAccount.isPlusActive) ...[
                          const SizedBox(width: AppSpacing.sm),
                          TextButton(
                            onPressed: () =>
                                context.pushNamed(RouteNames.businessPlus),
                            child: const Text('Plus\'a geç'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              _FormCard(
                child: Column(
                  children: [
                    AppTextField(
                      label: 'Başlık',
                      controller: _titleController,
                      prefixIcon: const Icon(Icons.event_available_outlined),
                      validator: Validators.eventTitle,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Açıklama',
                      controller: _descriptionController,
                      prefixIcon: const Icon(Icons.notes_outlined),
                      maxLines: 3,
                      validator: Validators.eventDescription,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Etkinlik türü',
                      controller: _sportTypeController,
                      readOnly: true,
                      onTap: _selectSport,
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(12),
                        child: SportIcon(
                          sportType: _resolvedSportType(),
                          size: 20,
                          filled: false,
                        ),
                      ),
                      suffixIcon: const Icon(Icons.expand_more),
                      validator: (_) =>
                          _sportValidator(businessAccount, isBusinessEvent),
                    ),
                    if (_usesCustomSport) ...[
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Etkinlik türünü yaz',
                        controller: _customSportController,
                        prefixIcon: const Icon(Icons.edit_outlined),
                        validator: (_) =>
                            Validators.customSport(_customSportController.text),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Şehir',
                      controller: _cityController,
                      readOnly: true,
                      onTap: _selectCity,
                      prefixIcon: const Icon(Icons.location_city_outlined),
                      suffixIcon: const Icon(Icons.search),
                      validator: Validators.city,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'İlçe',
                      controller: _districtController,
                      readOnly: true,
                      onTap: districts.isEmpty ? null : _selectDistrict,
                      prefixIcon: const Icon(Icons.place_outlined),
                      suffixIcon: districts.isEmpty
                          ? null
                          : const Icon(Icons.search),
                      validator: (value) => Validators.district(
                        value,
                        city: _cityController.text,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Etkinlik tarihi',
                      hintText: 'GG.AA.YYYY SS:DD',
                      controller: _eventDateController,
                      readOnly: true,
                      onTap: _pickDateTime,
                      prefixIcon: const Icon(Icons.schedule),
                      suffixIcon: const Icon(Icons.calendar_today_outlined),
                      validator: (_) =>
                          Validators.eventDate(_selectedEventDate),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Tam adres veya buluşma noktası',
                      controller: _locationTextController,
                      prefixIcon: const Icon(Icons.map_outlined),
                      hintText: 'Örn: Ankara/Çankaya Atatürk Spor Tesisleri',
                      validator: Validators.eventLocation,
                      onChanged: (value) async {
                        setState(() {
                          if (_locationLat != null || _locationLng != null) {
                            _locationHelperText =
                                'Konum açıklaması güncellendi';
                          }
                        });
                        final results = await _autocompleteService
                            .getSuggestions(
                              query: value,
                              city: _cityController.text,
                              district: _districtController.text,
                              userLat: _userLat,
                              userLng: _userLng,
                            );
                        setState(() {
                          _suggestions = results;
                        });
                      },
                    ),
                    if (_suggestions.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadius.lgBorder,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _suggestions.length,
                          separatorBuilder: (context, index) => const Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                          ),
                          itemBuilder: (context, index) {
                            final suggestion = _suggestions[index];
                            return ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.location_on_outlined,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              title: Text(
                                suggestion.description,
                                style: AppTextStyles.bodySmall,
                              ),
                              onTap: () async {
                                final details = await _autocompleteService
                                    .getDetails(suggestion);
                                setState(() {
                                  _locationTextController.text =
                                      details?.description ??
                                      suggestion.description;
                                  if (details != null) {
                                    _locationLat = details.latitude;
                                    _locationLng = details.longitude;
                                    _locationHelperText =
                                        'Haritadan konum seçildi';
                                  }
                                  _suggestions = [];
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Harita aramasında şehir ve ilçe otomatik eklenecek.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (_locationHelperText != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: AppColors.primary,
                            size: 16,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              _locationHelperText!,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Açık adres',
                      controller: _locationDescriptionController,
                      prefixIcon: const Icon(Icons.info_outline),
                      hintText:
                          'Apartman, saha adı, kapı, tarif veya buluşma noktası',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _locating ? null : _useCurrentLocation,
                          icon: _locating
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.my_location_outlined),
                          label: Text(
                            _locating ? 'Konum alınıyor' : 'Konumumu bul',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.border),
                            shape: const StadiumBorder(),
                          ),
                        ),
                        if (_locationTextController.text.trim().isNotEmpty ||
                            _locationLat != null ||
                            _locationLng != null)
                          TextButton.icon(
                            onPressed: _clearLocation,
                            icon: const Icon(Icons.close),
                            label: const Text('Konumu temizle'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (isBusinessEvent) ...[
                _FormCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Etkinlik Saatleri', style: AppTextStyles.title),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              label: 'Etkinlik başlangıç saati',
                              controller: _openTimeController,
                              readOnly: true,
                              onTap: () => _pickTime(isOpenTime: true),
                              prefixIcon: const Icon(Icons.schedule_outlined),
                              validator: _openTimeValidator,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: AppTextField(
                              label: 'Etkinlik bitiş saati',
                              controller: _closeTimeController,
                              readOnly: true,
                              onTap: () => _pickTime(isOpenTime: false),
                              prefixIcon: const Icon(Icons.schedule_outlined),
                              validator: _closeTimeValidator,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _FormCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Fiyat', style: AppTextStyles.title),
                      const SizedBox(height: AppSpacing.md),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'free', label: Text('Ücretsiz')),
                          ButtonSegment(
                            value: 'pay_at_business',
                            label: Text('İşletmede ödeme'),
                          ),
                        ],
                        selected: {_priceType},
                        onSelectionChanged: (selection) {
                          setState(() {
                            _priceType = selection.first;
                            if (_priceType == 'free') {
                              _priceController.clear();
                            }
                          });
                        },
                      ),
                      if (_priceType == 'pay_at_business') ...[
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          label: 'Kişi başı ücret',
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          prefixIcon: const Icon(Icons.payments_outlined),
                          helperText: 'Para birimi: TRY',
                          validator: _priceValidator,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              _FormCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Kontenjan', style: AppTextStyles.title),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Karışık kontenjanı kadın/erkek fark etmeyen genel kontenjandır.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _CapacityStepper(
                      label: 'Karışık',
                      value: _parseIntOrZero(_capacityAnyController.text),
                      onChanged: (value) =>
                          _setCapacityValue(_capacityAnyController, value),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _CapacityStepper(
                      label: 'Erkek',
                      value: _parseIntOrZero(_capacityMaleController.text),
                      onChanged: (value) =>
                          _setCapacityValue(_capacityMaleController, value),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _CapacityStepper(
                      label: 'Kadın',
                      value: _parseIntOrZero(_capacityFemaleController.text),
                      onChanged: (value) =>
                          _setCapacityValue(_capacityFemaleController, value),
                    ),
                    if (_capacityPartsTotal() < 1) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'En az bir kontenjan seçmelisin.',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: _isEditing ? 'Etkinliği kaydet' : 'Etkinlik oluştur',
                isLoading: eventsState.isMutating,
                onPressed: eventsState.isMutating ? null : _submit,
              ),
              if (eventsState.mutationMessage != null &&
                  _capacityPartsTotal() > 0) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  eventsState.mutationMessage!,
                  style: const TextStyle(color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _prefillForEdit(Event event) {
    if (_prefilledEventId == event.id) return;

    _prefilledEventId = event.id;
    _editingEvent = event;
    _titleController.text = event.title;
    _descriptionController.text = event.description ?? '';
    final sportType = event.sportType?.trim() ?? '';
    if (!event.isBusinessEvent &&
        sportType.isNotEmpty &&
        !SportTypes.values.contains(sportType)) {
      _sportTypeController.text = SportTypes.other;
      _customSportController.text = sportType;
    } else {
      _sportTypeController.text = sportType;
      _customSportController.clear();
    }
    _cityController.text = event.city;
    _districtController.text = event.district ?? '';
    _locationTextController.text = event.locationText ?? '';
    _locationDescriptionController.text = event.locationDescription ?? '';
    _selectedEventDate = event.eventDate;
    _eventDateController.text = DateFormatter.formatEventDateTime(
      event.eventDate,
    );
    _capacityTotalController.text = event.safeCapacityTotal.toString();
    _capacityMaleController.text = event.maleCapacity.toString();
    _capacityFemaleController.text = event.femaleCapacity.toString();
    _capacityAnyController.text = event.genericCapacity.toString();
    _locationLat = event.locationLat;
    _locationLng = event.locationLng;
    final priceAmount = event.priceAmount;
    _priceController.text = priceAmount == null
        ? ''
        : priceAmount.toStringAsFixed(
            priceAmount == priceAmount.roundToDouble() ? 0 : 2,
          );
    _locationHelperText = event.hasCoordinates
        ? 'Kayıtlı konum kullanılıyor'
        : null;

    _openTimeController.text =
        event.eventStartTime ?? event.businessOpenTime ?? '';
    _closeTimeController.text =
        event.eventEndTime ?? event.businessCloseTime ?? '';

    final openTimeStr = event.eventStartTime ?? event.businessOpenTime;
    if (openTimeStr != null && openTimeStr.isNotEmpty) {
      final parts = openTimeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]) ?? 9;
        final minute = int.tryParse(parts[1]) ?? 0;
        _selectedOpenTime = TimeOfDay(hour: hour, minute: minute);
      }
    } else {
      _selectedOpenTime = null;
    }

    final closeTimeStr = event.eventEndTime ?? event.businessCloseTime;
    if (closeTimeStr != null && closeTimeStr.isNotEmpty) {
      final parts = closeTimeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]) ?? 18;
        final minute = int.tryParse(parts[1]) ?? 0;
        _selectedCloseTime = TimeOfDay(hour: hour, minute: minute);
      }
    } else {
      _selectedCloseTime = null;
    }

    _priceType = event.priceType ?? (event.isPaid ? 'pay_at_business' : 'free');
  }

  String _resolvedSportType() {
    if (_usesCustomSport) return _customSportController.text.trim();
    return _sportTypeController.text.trim();
  }

  void _onUseBusinessDefaultsChanged(bool? value) {
    if (value == null) return;
    setState(() {
      _useBusinessDefaults = value;
      if (value) {
        final businessAccount = ref.read(myBusinessAccountProvider).account;
        if (businessAccount != null) {
          _applyBusinessDefaults(businessAccount);
        }
      }
    });
  }

  void _applyBusinessDefaults(BusinessAccount businessAccount) {
    setState(() {
      _cityController.text = businessAccount.city;
      _districtController.text = businessAccount.district;
      _locationTextController.text = businessAccount.address ?? '';
      _locationLat = businessAccount.latitude;
      _locationLng = businessAccount.longitude;
      _locationHelperText = 'Konum işletme profilinden alındı.';

      if (businessAccount.workingHours != null) {
        final open = businessAccount.workingHours!['open']?.toString();
        final close = businessAccount.workingHours!['close']?.toString();
        if (open != null && open.isNotEmpty) {
          _openTimeController.text = open;
          final parts = open.split(':');
          if (parts.length >= 2) {
            _selectedOpenTime = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          }
        }
        if (close != null && close.isNotEmpty) {
          _closeTimeController.text = close;
          final parts = close.split(':');
          if (parts.length >= 2) {
            _selectedCloseTime = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          }
        }
      }
    });
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.goNamed(RouteNames.events);
  }

  // ignore: unused_element
  String? _capacityTotalValidator(String? value) {
    final capacityError = Validators.capacityTotal(value);
    if (capacityError != null) return capacityError;

    final capacityTotal = int.tryParse(value?.trim() ?? '');
    final capacityParts = _capacityPartsTotal();
    if (capacityTotal != null && capacityParts > capacityTotal) {
      return 'Kapasite dağılımı toplam kapasiteyi aşamaz.';
    }

    return null;
  }

  // ignore: unused_element
  String? _capacityPartValidator(String? value) {
    final partError = Validators.nonNegativeNumber(value);
    if (partError != null) return partError;

    final capacityTotal = int.tryParse(_capacityTotalController.text.trim());
    if (capacityTotal != null && _capacityPartsTotal() > capacityTotal) {
      return 'Kapasite dağılımı toplam kapasiteyi aşamaz.';
    }

    return null;
  }

  int _capacityPartsTotal() {
    return _parseIntOrZero(_capacityMaleController.text) +
        _parseIntOrZero(_capacityFemaleController.text) +
        _parseIntOrZero(_capacityAnyController.text);
  }

  void _setCapacityValue(TextEditingController controller, int value) {
    final otherPartsTotal =
        _capacityPartsTotal() - _parseIntOrZero(controller.text);
    final maxAllowedValue = 100 - otherPartsTotal;
    final clampedValue = value.clamp(0, maxAllowedValue);

    setState(() {
      controller.text = clampedValue.toString();
      _capacityTotalController.text = _capacityPartsTotal().toString();
    });
  }

  int _parseIntOrZero(String value) {
    return int.tryParse(value.trim()) ?? 0;
  }

  double? _parsePrice(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  String? _priceValidator(String? value) {
    final profile = ref.read(profileControllerProvider).profile;
    final businessAccount = ref.read(myBusinessAccountProvider).account;
    final isBusinessEvent = CreateEventInput.canUseBusinessEventFields(
      isBusinessAccount: profile?.isBusinessAccount == true,
      businessAccount: businessAccount,
    );
    if (!isBusinessEvent || _priceType != 'pay_at_business') {
      return null;
    }
    final price = _parsePrice(value ?? '');
    if (price == null || price <= 0) return 'Fiyat 0’dan büyük olmalı.';
    return null;
  }

  String? _sportValidator(
    BusinessAccount? businessAccount,
    bool isBusinessEvent,
  ) {
    return Validators.sportType(_resolvedSportType());
  }

  String? _openTimeValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'İşletme etkinliği için etkinlik saatlerini belirtmelisin.';
    }
    return null;
  }

  String? _closeTimeValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'İşletme etkinliği için etkinlik saatlerini belirtmelisin.';
    }
    final openTime = _selectedOpenTime;
    final closeTime = _selectedCloseTime;
    if (openTime != null && closeTime != null) {
      final openMinutes = openTime.hour * 60 + openTime.minute;
      final closeMinutes = closeTime.hour * 60 + closeTime.minute;
      if (closeMinutes <= openMinutes) {
        return 'Bitiş saati başlangıç saatinden sonra olmalı.';
      }
    }
    return null;
  }

  Future<void> _pickTime({required bool isOpenTime}) async {
    final initial = isOpenTime
        ? (_selectedOpenTime ?? const TimeOfDay(hour: 9, minute: 0))
        : (_selectedCloseTime ?? const TimeOfDay(hour: 18, minute: 0));
    final time = await showTimePicker(
      context: context,
      initialTime: initial,
      initialEntryMode: TimePickerEntryMode.dialOnly,
      helpText: isOpenTime ? 'Açılış saati seç' : 'Kapanış saati seç',
      cancelText: 'İptal',
      confirmText: 'Tamam',
      hourLabelText: 'Saat',
      minuteLabelText: 'Dakika',
      errorInvalidText: 'Geçerli bir saat seç.',
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
              secondary: AppColors.primary,
              surface: AppColors.surface,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: AppColors.surface,
              dialHandColor: AppColors.primary,
              dialBackgroundColor: AppColors.primarySoft,
              hourMinuteColor: AppColors.primarySoft,
              hourMinuteTextColor: AppColors.textPrimary,
              entryModeIconColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
          ),
          child: MediaQuery(
            data: mediaQuery.copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        );
      },
    );
    if (time == null) return;

    setState(() {
      final formatted =
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      if (isOpenTime) {
        _selectedOpenTime = time;
        _openTimeController.text = formatted;
      } else {
        _selectedCloseTime = time;
        _closeTimeController.text = formatted;
      }
    });
  }

  String _locationErrorMessage(Object error) {
    final message = '$error';
    if (message.contains('servisleri')) {
      return 'Konum servisleri kapalı. Manuel konum yazabilirsin.';
    }
    if (message.contains('kal') || message.contains('forever')) {
      return 'Konum izni kalıcı olarak kapalı. Ayarlardan açabilir veya manuel konum yazabilirsin.';
    }
    if (message.contains('izin') || message.contains('denied')) {
      return 'Konum izni verilmedi. Manuel konum yazabilirsin.';
    }
    return 'Konum alınamadı. Manuel konum yazabilirsin.';
  }

  Future<String?> _showOptionSheet({
    required String title,
    required List<String> values,
    required String selectedValue,
    bool searchable = true,
    bool showSportIcons = false,
    String searchHint = 'Ara',
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        return _OptionSheet(
          title: title,
          values: values,
          selectedValue: selectedValue,
          searchable: searchable,
          showSportIcons: showSportIcons,
          searchHint: searchHint,
        );
      },
    );
  }
}

class _CreateEventAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _CreateEventAppBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        tooltip: 'Geri',
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back),
      ),
      title: const AppLogo(size: 32, showText: true),
    );
  }
}

class _OptionSheet extends StatefulWidget {
  const _OptionSheet({
    required this.title,
    required this.values,
    required this.selectedValue,
    required this.searchable,
    required this.showSportIcons,
    required this.searchHint,
  });

  final String title;
  final List<String> values;
  final String selectedValue;
  final bool searchable;
  final bool showSportIcons;
  final String searchHint;

  @override
  State<_OptionSheet> createState() => _OptionSheetState();
}

class _OptionSheetState extends State<_OptionSheet> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final visibleHeight = MediaQuery.sizeOf(context).height - bottomInset;
    final query = _searchController.text;
    final values = widget.searchable
        ? widget.values.where((value) {
            final normalizedValue = _normalize(value);
            final normalizedQuery = _normalize(query);
            if (normalizedQuery.isEmpty) return true;
            return normalizedValue.startsWith(normalizedQuery) ||
                normalizedValue.contains(normalizedQuery);
          }).toList()
        : widget.values;

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: visibleHeight * 0.72,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: AppRadius.pillBorder,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(widget.title, style: AppTextStyles.title),
                if (widget.searchable) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: widget.searchHint,
                      prefixIcon: const Icon(Icons.search),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: ListView.separated(
                    itemCount: values.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, index) {
                      final value = values[index];
                      final selected = value == widget.selectedValue;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: widget.showSportIcons
                            ? SportIcon(sportType: value, size: 18)
                            : null,
                        title: Text(value, style: AppTextStyles.bodySmall),
                        trailing: selected
                            ? const Icon(Icons.check, color: AppColors.primary)
                            : null,
                        onTap: () => Navigator.of(context).pop(value),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
        .replaceAll('ü', 'u');
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgBorder,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: child,
      ),
    );
  }
}

class _CapacityStepper extends StatelessWidget {
  const _CapacityStepper({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.lgBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyStrong,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _CapacityIconButton(
              icon: Icons.remove,
              tooltip: '$label azalt',
              onPressed: value <= 0 ? null : () => onChanged(value - 1),
            ),
            SizedBox(
              width: 44,
              child: Text(
                value.toString(),
                style: AppTextStyles.title,
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ),
            _CapacityIconButton(
              icon: Icons.add,
              tooltip: '$label artır',
              onPressed: value >= 100 ? null : () => onChanged(value + 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapacityIconButton extends StatelessWidget {
  const _CapacityIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      visualDensity: VisualDensity.compact,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(36),
        backgroundColor: AppColors.primarySoft,
        foregroundColor: AppColors.primary,
        disabledBackgroundColor: AppColors.border.withValues(alpha: 0.45),
        disabledForegroundColor: AppColors.textMuted,
      ),
    );
  }
}
