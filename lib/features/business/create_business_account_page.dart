import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/turkey_locations.dart';
import '../../core/layout/responsive_layout.dart';
import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/adaptive_dialog.dart';
import '../../services/location_service.dart';
import '../../services/location_autocomplete_service.dart';
import '../auth/auth_provider.dart';
import '../events/events_provider.dart';
import '../profile/profile_provider.dart';
import 'business_models.dart';
import 'business_provider.dart';

class CreateBusinessAccountPage extends ConsumerStatefulWidget {
  const CreateBusinessAccountPage({super.key});

  @override
  ConsumerState<CreateBusinessAccountPage> createState() =>
      _CreateBusinessAccountPageState();
}

class _CreateBusinessAccountPageState
    extends ConsumerState<CreateBusinessAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _customCategoryController = TextEditingController();
  final _websiteController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();

  double? _latitude;
  double? _longitude;
  double? _userLat;
  double? _userLng;
  String? _defaultOpenTime;
  String? _defaultCloseTime;
  List<String> _selectedAmenities = [];
  bool _locating = false;
  bool _hasPrefilled = false;

  final _locationService = const LocationService();
  final _autocompleteService = const LocationAutocompleteService();
  List<LocationSuggestion> _suggestions = [];

  static const _allAmenities = [
    'Duş var',
    'Soyunma odası var',
    'Otopark var',
    'Ekipman kiralama var',
    'Kadınlara uygun alan var',
    'Kafe var',
    'Kapalı alan',
    'Açık alan',
  ];

  @override
  void initState() {
    super.initState();
    _initUserLocation();
    Future.microtask(() async {
      if (!mounted) return;
      await ref
          .read(myBusinessAccountProvider.notifier)
          .loadMyBusinessAccount();
      if (!mounted) return;
      final account = ref.read(myBusinessAccountProvider).account;
      if (account != null) {
        _prefillForm(account);
      }
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

  void _prefillForm(BusinessAccount account) {
    if (_hasPrefilled) return;
    _hasPrefilled = true;
    _nameController.text = account.name;
    _phoneController.text = account.phone ?? '';
    _addressController.text = account.address ?? '';
    _customCategoryController.text = account.customCategory ?? account.category;
    _websiteController.text = account.website ?? '';
    _descriptionController.text = account.description ?? '';
    _cityController.text = account.city;
    _districtController.text = account.district;
    _latitude = account.latitude;
    _longitude = account.longitude;

    if (account.workingHours != null) {
      _defaultOpenTime = account.workingHours!['open']?.toString();
      _defaultCloseTime = account.workingHours!['close']?.toString();
    }

    if (account.amenities != null) {
      _selectedAmenities = List<String>.from(account.amenities!);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _customCategoryController.dispose();
    _websiteController.dispose();
    _descriptionController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    super.dispose();
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

  Future<void> _pickTime({required bool isOpenTime}) async {
    TimeOfDay initial = isOpenTime
        ? const TimeOfDay(hour: 9, minute: 0)
        : const TimeOfDay(hour: 18, minute: 0);

    if (isOpenTime && _defaultOpenTime != null) {
      final parts = _defaultOpenTime!.split(':');
      if (parts.length >= 2) {
        initial = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    } else if (!isOpenTime && _defaultCloseTime != null) {
      final parts = _defaultCloseTime!.split(':');
      if (parts.length >= 2) {
        initial = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    }

    final time = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppColors.primary),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
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
        _defaultOpenTime = formatted;
      } else {
        _defaultCloseTime = formatted;
      }
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
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _userLat = position.latitude;
        _userLng = position.longitude;
        if (address != null && _addressController.text.trim().isEmpty) {
          _addressController.text = address;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konum koordinatları başarıyla alındı.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konum alınamadı. Lütfen konum iznini kontrol edin.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myBusinessAccountProvider);
    final account = state.account;
    final application = state.application;
    final isPending = application?.isPending == true;

    if (account != null && !_hasPrefilled) {
      _prefillForm(account);
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Geri',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _goBack(context),
        ),
        title: const AppLogo(size: 32, showText: true),
      ),
      body: SafeArea(
        child: ListView(
          padding: AppResponsive.pagePadding(context),
          children: [
            Text(
              account == null
                  ? 'İşletme hesabı başvurusu'
                  : 'İşletme hesabını düzenle',
              style: AppTextStyles.headline,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              account == null
                  ? 'Başvurun onaylanınca aynı profilin işletme moduna yükseltilir.'
                  : 'İşletme hesabı aynı profil üzerinde yönetilir ve bu varsayılanlar kullanılır.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (isPending)
              _PendingApplicationCard(application: application!)
            else
              Form(
                key: _formKey,
                child: _FormCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        label: 'İşletme adı',
                        controller: _nameController,
                        prefixIcon: const Icon(Icons.storefront_outlined),
                        validator: BusinessApplicationValidators.name,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'İşletme telefon numarası',
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        prefixIcon: const Icon(Icons.phone_outlined),
                        validator: BusinessApplicationValidators.phone,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'İşletme kategorisi',
                        controller: _customCategoryController,
                        prefixIcon: const Icon(Icons.category_outlined),
                        validator: BusinessApplicationValidators.manualCategory,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Şehir',
                        controller: _cityController,
                        readOnly: true,
                        onTap: _selectCity,
                        prefixIcon: const Icon(Icons.location_city_outlined),
                        suffixIcon: const Icon(Icons.search),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Şehir seçmelisin.'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'İlçe',
                        controller: _districtController,
                        readOnly: true,
                        onTap: _cityController.text.isEmpty
                            ? null
                            : _selectDistrict,
                        prefixIcon: const Icon(Icons.place_outlined),
                        suffixIcon: const Icon(Icons.search),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'İlçe seçmelisin.'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Tam konum/adres',
                        controller: _addressController,
                        prefixIcon: const Icon(Icons.place_outlined),
                        maxLines: 3,
                        validator: BusinessApplicationValidators.fullAddress,
                        onChanged: (value) async {
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
                                    _addressController.text =
                                        details?.description ??
                                        suggestion.description;
                                    if (details != null) {
                                      _latitude = details.latitude;
                                      _longitude = details.longitude;
                                    }
                                    _suggestions = [];
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _latitude != null && _longitude != null
                                  ? 'Koordinatlar: ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                                  : 'Harita konumu belirtilmedi.',
                              style: AppTextStyles.caption.copyWith(
                                color: _latitude != null
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
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
                            label: const Text('Konum Al'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.border),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Website',
                        controller: _websiteController,
                        keyboardType: TextInputType.url,
                        prefixIcon: const Icon(Icons.language_outlined),
                        validator: BusinessApplicationValidators.website,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Açıklama',
                        controller: _descriptionController,
                        prefixIcon: const Icon(Icons.notes_outlined),
                        maxLines: 3,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Varsayılan Çalışma Saatleri',
                        style: AppTextStyles.title,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _pickTime(isOpenTime: true),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Açılış',
                                  prefixIcon: Icon(Icons.login_outlined),
                                ),
                                child: Text(_defaultOpenTime ?? 'Seçiniz'),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: InkWell(
                              onTap: () => _pickTime(isOpenTime: false),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Kapanış',
                                  prefixIcon: Icon(Icons.logout_outlined),
                                ),
                                child: Text(_defaultCloseTime ?? 'Seçiniz'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Tesis Özellikleri / İmkânlar',
                        style: AppTextStyles.title,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: _allAmenities.map((amenity) {
                          final isSelected = _selectedAmenities.contains(
                            amenity,
                          );
                          return FilterChip(
                            label: Text(amenity),
                            selected: isSelected,
                            onSelected: (checked) {
                              setState(() {
                                if (checked) {
                                  _selectedAmenities.add(amenity);
                                } else {
                                  _selectedAmenities.remove(amenity);
                                }
                              });
                            },
                            selectedColor: AppColors.primarySoft,
                            checkmarkColor: AppColors.primary,
                          );
                        }).toList(),
                      ),
                      if (state.message != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          state.message!,
                          style: const TextStyle(color: AppColors.error),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      AppButton(
                        label: account == null
                            ? 'Başvur'
                            : 'Varsayılanları Kaydet',
                        isLoading: state.isLoading,
                        onPressed: _submitForm,
                      ),
                    ],
                  ),
                ),
              ),
            if (account != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'İşletme hesabımı sil',
                isLoading: state.isLoading,
                variant: AppButtonVariant.outlined,
                onPressed: state.isLoading
                    ? null
                    : () => _confirmDeleteBusinessAccount(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final state = ref.read(myBusinessAccountProvider);
    final account = state.account;

    final input = BusinessAccountInput(
      name: _nameController.text.trim(),
      username:
          account?.username ??
          _nameController.text.trim().toLowerCase().replaceAll(
            RegExp(r'\s+'),
            '_',
          ),
      category: account?.category ?? BusinessCategories.other,
      customCategory: _customCategoryController.text.trim(),
      city: _cityController.text.trim(),
      district: _districtController.text.trim(),
      address: _addressController.text.trim(),
      description: _descriptionController.text.trim(),
      phone: _phoneController.text.trim(),
      website: _websiteController.text.trim(),
      instagram: account?.instagram,
      latitude: _latitude,
      longitude: _longitude,
      workingHours: _defaultOpenTime != null || _defaultCloseTime != null
          ? {'open': _defaultOpenTime, 'close': _defaultCloseTime}
          : null,
      amenities: _selectedAmenities.isNotEmpty ? _selectedAmenities : null,
    );

    if (account != null) {
      final updated = await ref
          .read(myBusinessAccountProvider.notifier)
          .updateBusinessAccount(id: account.id, input: input);

      if (!mounted) return;
      if (updated != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İşletme bilgileri güncellendi.')),
        );
        context.goNamed(RouteNames.settings);
      }
      return;
    }

    final appInput = BusinessApplicationInput(
      businessName: _nameController.text.trim(),
      businessPhone: _phoneController.text.trim(),
      fullAddress: _addressController.text.trim(),
      category: BusinessCategories.other,
      customCategory: _customCategoryController.text.trim(),
      website: _websiteController.text.trim(),
      description: _descriptionController.text.trim(),
    );

    final application = await ref
        .read(myBusinessAccountProvider.notifier)
        .submitApplication(appInput);

    if (!mounted || application == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('İşletme başvurun alındı.')));
    context.goNamed(RouteNames.settings);
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.goNamed(RouteNames.settings);
  }

  Future<void> _confirmDeleteBusinessAccount(BuildContext context) async {
    final confirmed = await showAdaptiveConfirmDialog(
      context,
      title: 'İşletme hesabını sil?',
      content:
          'İşletme bilgilerin pasifleştirilecek ve gelecekteki işletme '
          'etkinliklerin yayından kaldırılacak. Hesabın kullanıcı hesabı '
          'olarak devam edecek.',
      confirmLabel: 'İşletme hesabımı sil',
      cancelLabel: 'Vazgeç',
      isDestructive: true,
    );

    if (confirmed != true) return;

    final success = await ref
        .read(myBusinessAccountProvider.notifier)
        .deleteMyBusinessAccount();
    if (!context.mounted) return;

    if (!success) {
      final message = ref.read(myBusinessAccountProvider).message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message ?? 'İşletme hesabı silinemedi. Tekrar dene.'),
        ),
      );
      return;
    }

    await ref.read(profileControllerProvider.notifier).loadMyProfile();
    final profile = ref.read(profileControllerProvider).profile;
    ref
        .read(authControllerProvider.notifier)
        .markProfileCompletion(
          isCompleted: profile?.hasMinimumProfile ?? false,
        );
    await ref.read(myBusinessAccountProvider.notifier).loadMyBusinessAccount();
    await ref.read(eventsControllerProvider.notifier).refreshEvents();
    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('İşletme hesabı silindi.')));
    context.goNamed(RouteNames.settings);
  }

  Future<String?> _showOptionSheet({
    required String title,
    required List<String> values,
    required String selectedValue,
    bool searchable = true,
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
          searchHint: searchHint,
        );
      },
    );
  }
}

class _PendingApplicationCard extends StatelessWidget {
  const _PendingApplicationCard({required this.application});

  final BusinessApplication application;

  @override
  Widget build(BuildContext context) {
    return _FormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('İşletme başvurun inceleniyor.', style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.sm),
          Text(application.businessName, style: AppTextStyles.bodyStrong),
          const SizedBox(height: AppSpacing.xs),
          Text(application.fullAddress, style: AppTextStyles.bodySmall),
        ],
      ),
    );
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

class _OptionSheet extends StatefulWidget {
  const _OptionSheet({
    required this.title,
    required this.values,
    required this.selectedValue,
    required this.searchable,
    required this.searchHint,
  });

  final String title;
  final List<String> values;
  final String selectedValue;
  final bool searchable;
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
