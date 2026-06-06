import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../business/business_models.dart';
import '../business/business_provider.dart';
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
  final _customSportController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _locationTextController = TextEditingController();
  final _eventDateController = TextEditingController();
  final _capacityTotalController = TextEditingController();
  final _capacityMaleController = TextEditingController(text: '0');
  final _capacityFemaleController = TextEditingController(text: '0');
  final _capacityAnyController = TextEditingController(text: '0');
  final _priceController = TextEditingController();
  final _locationService = const LocationService();

  DateTime? _selectedEventDate;
  double? _locationLat;
  double? _locationLng;
  bool _locating = false;
  bool _isPaidBusinessEvent = false;
  String? _locationHelperText;

  bool get _usesCustomSport => _sportTypeController.text == SportTypes.other;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(profileControllerProvider.notifier).loadMyProfile();
      ref.read(myBusinessAccountProvider.notifier).loadMyBusinessAccount();
    });
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
    _eventDateController.dispose();
    _capacityTotalController.dispose();
    _capacityMaleController.dispose();
    _capacityFemaleController.dispose();
    _capacityAnyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final city =
        TurkeyLocations.normalizeCityName(_cityController.text) ??
        _cityController.text.trim();
    final district =
        TurkeyLocations.normalizeDistrictName(city, _districtController.text) ??
        _districtController.text.trim();
    final businessAccount = ref.read(myBusinessAccountProvider).account;
    final profile = ref.read(profileControllerProvider).profile;
    final isBusinessEvent = CreateEventInput.canUseBusinessEventFields(
      isBusinessAccount: profile?.isBusinessAccount == true,
      businessAccount: businessAccount,
    );

    final input = CreateEventInput(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      sportType: _resolvedSportType(),
      city: city,
      district: district,
      locationText: _locationTextController.text.trim(),
      locationLat: _locationLat,
      locationLng: _locationLng,
      eventDate: _selectedEventDate!,
      capacityTotal: int.parse(_capacityTotalController.text.trim()),
      capacityMale: _parseIntOrZero(_capacityMaleController.text),
      capacityFemale: _parseIntOrZero(_capacityFemaleController.text),
      capacityAny: _parseIntOrZero(_capacityAnyController.text),
      organizerType: isBusinessEvent
          ? EventOrganizerType.business
          : EventOrganizerType.user,
      businessAccount: isBusinessEvent ? businessAccount : null,
      isPaid: isBusinessEvent && _isPaidBusinessEvent,
      priceAmount: _parsePrice(_priceController.text),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _selectSport() async {
    final profile = ref.read(profileControllerProvider).profile;
    final businessAccount = ref.read(myBusinessAccountProvider).account;
    final isBusinessEvent = CreateEventInput.canUseBusinessEventFields(
      isBusinessAccount: profile?.isBusinessAccount == true,
      businessAccount: businessAccount,
    );
    final activeBusinessAccount = isBusinessEvent ? businessAccount : null;
    final sportValues = isBusinessEvent
        ? BusinessCategories.allowedActivitiesForBusinessCategory(
            category: activeBusinessAccount!.category,
            customCategory: activeBusinessAccount.customCategory,
          )
        : SportTypes.values;
    final selected = await _showOptionSheet(
      title: 'Spor veya aktivite seç',
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
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
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

    if (!profileState.canCreateEvent) {
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
                  'Etkinliklere katılmak için profilini tamamlamalısın.',
                  style: AppTextStyles.title,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Gerekli bilgiler: şehir, ilçe ve doğum tarihi.',
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
                      'returnTo': RoutePaths.createEvent,
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Etkinlikleri keşfet',
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
    final isBusinessEvent = CreateEventInput.canUseBusinessEventFields(
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
              Text('Etkinlik Oluştur', style: AppTextStyles.headline),
              const SizedBox(height: AppSpacing.sm),
              Text('Ekibini topla, sahaya çık.', style: AppTextStyles.body),
              const SizedBox(height: AppSpacing.lg),
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
                      label: 'Spor türü',
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
                      hintText: 'Tarih ve saat seç',
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
                      label: 'Konum',
                      controller: _locationTextController,
                      prefixIcon: const Icon(Icons.map_outlined),
                      hintText: 'Adres, saha adı veya buluşma noktası',
                      onChanged: (_) {
                        setState(() {
                          if (_locationLat != null || _locationLng != null) {
                            _locationHelperText = 'Otomatik konum kullanılıyor';
                          }
                        });
                      },
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
                      Text('Fiyat', style: AppTextStyles.title),
                      const SizedBox(height: AppSpacing.md),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('Ücretsiz')),
                          ButtonSegment(value: true, label: Text('Ücretli')),
                        ],
                        selected: {_isPaidBusinessEvent},
                        onSelectionChanged: (selection) {
                          setState(() {
                            _isPaidBusinessEvent = selection.first;
                            if (!_isPaidBusinessEvent) {
                              _priceController.clear();
                            }
                          });
                        },
                      ),
                      if (_isPaidBusinessEvent) ...[
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          label: 'Fiyat',
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
                  children: [
                    AppTextField(
                      label: 'Toplam kontenjan',
                      controller: _capacityTotalController,
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(Icons.groups_outlined),
                      validator: _capacityTotalValidator,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Erkek kontenjanı',
                      controller: _capacityMaleController,
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(Icons.person_outline),
                      validator: _capacityPartValidator,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Kadın kontenjanı',
                      controller: _capacityFemaleController,
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(Icons.person_outline),
                      validator: _capacityPartValidator,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Karma kontenjan',
                      controller: _capacityAnyController,
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(Icons.diversity_3_outlined),
                      validator: _capacityPartValidator,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Etkinlik oluştur',
                isLoading: eventsState.isLoading,
                onPressed: _submit,
              ),
              if (eventsState.status == EventsStatus.error &&
                  eventsState.message != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  eventsState.message!,
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

  String _resolvedSportType() {
    if (_usesCustomSport) return _customSportController.text.trim();
    return _sportTypeController.text.trim();
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.goNamed(RouteNames.events);
  }

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
    if (!isBusinessEvent || !_isPaidBusinessEvent) {
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
    final sportError = Validators.sportType(_resolvedSportType());
    if (sportError != null) return sportError;
    if (!isBusinessEvent || businessAccount == null) return null;
    if (BusinessCategories.canCreateActivity(
      category: businessAccount.category,
      customCategory: businessAccount.customCategory,
      activity: _resolvedSportType(),
    )) {
      return null;
    }
    return 'Bu etkinlik türü işletme kategorinle uyumlu değil.';
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
        tooltip: 'Back',
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
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.separated(
                shrinkWrap: true,
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
