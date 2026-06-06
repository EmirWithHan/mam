import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/turkey_locations.dart';
import '../../core/layout/responsive_layout.dart';
import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/phone_verification.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../auth/auth_provider.dart';
import 'profile_models.dart';
import 'profile_provider.dart';
import 'widgets/safe_avatar.dart';

class ProfileCompletionPage extends ConsumerStatefulWidget {
  const ProfileCompletionPage({super.key, this.mode, this.returnTo});

  final String? mode;
  final String? returnTo;

  @override
  ConsumerState<ProfileCompletionPage> createState() =>
      _ProfileCompletionPageState();
}

class _ProfileCompletionPageState extends ConsumerState<ProfileCompletionPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _genderController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _imagePicker = ImagePicker();

  String? _tag;
  String? _avatarUrl;
  Uint8List? _avatarBytes;
  String? _avatarFileName;
  String? _avatarContentType;
  DateTime? _selectedBirthDate;

  static const _genderOptions = ['Erkek', 'Kadın', 'Belirtmek istemiyorum'];

  bool get _isEventRequirementsMode =>
      widget.mode == RoutePaths.profileCompleteModeEventRequirements;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadProfile);
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    final profile = await ref
        .read(profileControllerProvider.notifier)
        .createEmptyProfileIfMissing();
    if (!mounted || profile == null) return;

    _usernameController.text = profile.username ?? '';
    _nameController.text = profile.firstName ?? '';
    _selectedBirthDate = profile.birthDate;
    _birthDateController.text = _formatBirthDate(profile.birthDate);
    _genderController.text = profile.gender ?? '';
    final city = TurkeyLocations.normalizeCityName(profile.city ?? '');
    final district = city == null
        ? null
        : TurkeyLocations.normalizeDistrictName(city, profile.district ?? '');
    _cityController.text = city ?? profile.city ?? '';
    _districtController.text = district ?? '';
    _phoneController.text = profile.phoneNumber ?? profile.phone ?? '';
    _bioController.text = profile.bio ?? '';
    _avatarUrl = profile.avatarUrl;
    _tag = profile.tag;
    setState(() {});
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _birthDateController.dispose();
    _genderController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    var avatarUrl = _avatarUrl;
    final avatarBytes = _avatarBytes;
    final avatarFileName = _avatarFileName;
    if (avatarBytes != null && avatarFileName != null) {
      avatarUrl = await ref
          .read(profileControllerProvider.notifier)
          .uploadAvatar(
            bytes: avatarBytes,
            fileName: avatarFileName,
            contentType: _avatarContentType,
          );

      if (!mounted) return;
      if (avatarUrl == null) {
        final message = ref.read(profileControllerProvider).message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message ?? 'Avatar upload failed.')),
        );
        return;
      }
    }

    final city =
        TurkeyLocations.normalizeCityName(_cityController.text) ??
        _cityController.text.trim();
    final district =
        TurkeyLocations.normalizeDistrictName(city, _districtController.text) ??
        _districtController.text.trim();

    final formData = ProfileFormData(
      username: _usernameController.text.trim(),
      tag: _tag,
      firstName: _nameController.text.trim(),
      birthDate: _selectedBirthDate,
      gender: _genderController.text.trim(),
      city: city.isEmpty ? null : city,
      district: district.isEmpty ? null : district,
      phone: _phoneController.text.trim(),
      bio: _bioController.text.trim(),
      avatarUrl: avatarUrl,
    );

    final profile = await ref
        .read(profileControllerProvider.notifier)
        .updateProfile(formData);

    if (!mounted) return;
    if (profile != null) {
      ref
          .read(authControllerProvider.notifier)
          .markProfileCompletion(isCompleted: profile.hasCoreIdentity);
      _navigateAfterSave(context);
      return;
    }

    final message = ref.read(profileControllerProvider).message;
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      if (!mounted) return;

      setState(() {
        _avatarBytes = bytes;
        _avatarFileName = image.name;
        _avatarContentType = image.mimeType;
      });
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fotoğraf seçilemedi. Galeri iznini kontrol et.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fotoğraf seçilemedi. Tekrar dene.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);
    final selectedCity = _cityController.text.trim();
    final districts = TurkeyLocations.getDistricts(selectedCity);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => _goBack(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('MaM'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: AppResponsive.pagePadding(context),
            children: [
              Text('Profilini tamamla', style: AppTextStyles.headline),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _isEventRequirementsMode
                    ? 'Etkinliklere katılmak için profilini tamamlamalısın. Gerekli bilgiler: şehir, ilçe ve doğum tarihi.'
                    : 'Devam etmek için kullanıcı adını ve adını ekle. Diğer bilgileri sonra tamamlayabilirsin.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.lg),
              _FormCard(
                child: Column(
                  children: [
                    _AvatarPicker(
                      imageBytes: _avatarBytes,
                      avatarUrl: _avatarUrl,
                      onPickAvatar: _pickAvatar,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Kullanıcı adı',
                      controller: _usernameController,
                      prefixIcon: const Icon(Icons.alternate_email),
                      validator: ProfileUsername.validate,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Ad',
                      controller: _nameController,
                      prefixIcon: const Icon(Icons.person_outline),
                      validator: Validators.firstName,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: _isEventRequirementsMode
                          ? 'Doğum tarihi'
                          : 'Doğum tarihi (opsiyonel)',
                      hintText: 'Tarih seç',
                      controller: _birthDateController,
                      readOnly: true,
                      onTap: _selectBirthDate,
                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                      suffixIcon: const Icon(Icons.expand_more),
                      validator: _birthDateValidator,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Cinsiyet (opsiyonel)',
                      controller: _genderController,
                      readOnly: true,
                      onTap: _selectGender,
                      prefixIcon: const Icon(Icons.badge_outlined),
                      suffixIcon: const Icon(Icons.expand_more),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: _isEventRequirementsMode
                          ? 'Şehir'
                          : 'Şehir (opsiyonel)',
                      controller: _cityController,
                      readOnly: true,
                      onTap: _selectCity,
                      prefixIcon: const Icon(Icons.location_city_outlined),
                      suffixIcon: const Icon(Icons.expand_more),
                      validator: _isEventRequirementsMode
                          ? Validators.city
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: _isEventRequirementsMode
                          ? 'İlçe'
                          : 'İlçe (opsiyonel)',
                      controller: _districtController,
                      readOnly: true,
                      onTap: districts.isEmpty ? null : _selectDistrict,
                      prefixIcon: const Icon(Icons.place_outlined),
                      suffixIcon: districts.isEmpty
                          ? null
                          : const Icon(Icons.expand_more),
                      validator: _isEventRequirementsMode
                          ? (value) => Validators.district(
                              value,
                              city: _cityController.text,
                            )
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Telefon numarası',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      prefixIcon: const Icon(Icons.phone_outlined),
                      validator: PhoneVerification.validateOptional,
                      helperText: 'Örn. 05xx xxx xx xx',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _PhoneVerificationStatus(
                      profile: profileState.profile,
                      onVerifyTap: _showPhoneVerificationComingSoon,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Bio',
                      hintText:
                          'Kısaca kendinden ve sevdiğin aktivitelerden bahset.',
                      controller: _bioController,
                      prefixIcon: const Icon(Icons.notes_outlined),
                      maxLines: 3,
                      helperText: 'En fazla 160 karakter',
                      validator: Validators.bio,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Devam et',
                isLoading: profileState.isLoading,
                onPressed: _submit,
              ),
              if (profileState.status == ProfileStatus.error &&
                  profileState.message != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  profileState.message!,
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

  Future<void> _selectBirthDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(1900);
    final picked = await showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: now,
      initialDate: _initialBirthDate(now, firstDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;
    setState(() {
      _selectedBirthDate = picked;
      _birthDateController.text = _formatBirthDate(picked);
    });
  }

  DateTime _initialBirthDate(DateTime now, DateTime firstDate) {
    final fallback = DateTime(now.year - 18, now.month, now.day);
    final selected = _selectedBirthDate;
    if (selected == null ||
        selected.isAfter(now) ||
        selected.isBefore(firstDate)) {
      return fallback;
    }
    return selected;
  }

  Future<void> _selectGender() async {
    final value = await _showOptionSheet(
      title: 'Cinsiyet seç',
      initialOptions: _genderOptions,
      search: (query) {
        final normalizedQuery = query.trim().toLowerCase();
        if (normalizedQuery.isEmpty) return _genderOptions;
        return _genderOptions
            .where((option) => option.toLowerCase().contains(normalizedQuery))
            .toList();
      },
      searchable: false,
    );
    if (value == null || !mounted) return;
    setState(() => _genderController.text = value);
  }

  Future<void> _selectCity() async {
    final value = await _showOptionSheet(
      title: 'Şehir seç',
      initialOptions: TurkeyLocations.getCities(),
      search: TurkeyLocations.searchCities,
    );
    if (value == null || !mounted) return;

    final previousDistrict = _districtController.text.trim();
    setState(() {
      _cityController.text = value;
      if (!TurkeyLocations.isValidDistrict(value, previousDistrict)) {
        _districtController.clear();
      }
    });
  }

  Future<void> _selectDistrict() async {
    final city = _cityController.text.trim();
    if (!TurkeyLocations.isValidCity(city)) return;

    final value = await _showOptionSheet(
      title: 'İlçe seç',
      initialOptions: TurkeyLocations.getDistricts(city),
      search: (query) => TurkeyLocations.searchDistricts(city, query),
    );
    if (value == null || !mounted) return;
    setState(() => _districtController.text = value);
  }

  Future<String?> _showOptionSheet({
    required String title,
    required List<String> initialOptions,
    required List<String> Function(String query) search,
    bool searchable = true,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SelectionSheet(
          title: title,
          initialOptions: initialOptions,
          search: search,
          searchable: searchable,
        );
      },
    );
  }

  void _goBack(BuildContext context) {
    final returnTo = widget.returnTo;
    if (RoutePaths.isSafeReturnPath(returnTo)) {
      context.go(returnTo!);
      return;
    }
    if (_isEventRequirementsMode && context.canPop()) {
      context.pop();
      return;
    }
    context.goNamed(RouteNames.profile);
  }

  void _navigateAfterSave(BuildContext context) {
    final returnTo = widget.returnTo;
    if (RoutePaths.isSafeReturnPath(returnTo)) {
      context.go(returnTo!);
      return;
    }
    if (_isEventRequirementsMode && context.canPop()) {
      context.pop();
      return;
    }
    context.goNamed(RouteNames.home);
  }

  String? _birthDateValidator(String? value) {
    if (_isEventRequirementsMode && _selectedBirthDate == null) {
      return 'Doğum tarihi seçmelisin.';
    }
    return null;
  }

  String _formatBirthDate(DateTime? value) {
    if (value == null) return '';
    return DateFormatter.shortDate(value);
  }

  void _showPhoneVerificationComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Telefon doğrulama yakında eklenecek.')),
    );
  }
}

class _PhoneVerificationStatus extends StatelessWidget {
  const _PhoneVerificationStatus({
    required this.profile,
    required this.onVerifyTap,
  });

  final Profile? profile;
  final VoidCallback onVerifyTap;

  @override
  Widget build(BuildContext context) {
    final verified = PhoneVerification.isPhoneVerified(profile);

    return Row(
      children: [
        Icon(
          verified ? Icons.verified_outlined : Icons.info_outline,
          color: verified ? AppColors.primary : AppColors.textMuted,
          size: 18,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            PhoneVerification.statusLabel(profile),
            style: AppTextStyles.caption,
          ),
        ),
        TextButton(
          onPressed: onVerifyTap,
          child: const Text('Telefonu doğrula'),
        ),
      ],
    );
  }
}

class _SelectionSheet extends StatefulWidget {
  const _SelectionSheet({
    required this.title,
    required this.initialOptions,
    required this.search,
    required this.searchable,
  });

  final String title;
  final List<String> initialOptions;
  final List<String> Function(String query) search;
  final bool searchable;

  @override
  State<_SelectionSheet> createState() => _SelectionSheetState();
}

class _SelectionSheetState extends State<_SelectionSheet> {
  final _searchController = TextEditingController();
  late List<String> _options;

  @override
  void initState() {
    super.initState();
    _options = widget.initialOptions;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _options = widget.search(value));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.42,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.35),
                      borderRadius: AppRadius.pillBorder,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(widget.title, style: AppTextStyles.title),
                if (widget.searchable) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Ara',
                    controller: _searchController,
                    prefixIcon: const Icon(Icons.search),
                    onChanged: _onSearchChanged,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: _options.isEmpty
                      ? Center(
                          child: Text(
                            'Sonuç bulunamadı.',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: _options.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: AppSpacing.xs),
                          itemBuilder: (context, index) {
                            final option = _options[index];
                            return ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: AppRadius.mdBorder,
                              ),
                              tileColor: AppColors.surface,
                              title: Text(option),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: AppColors.primary,
                              ),
                              onTap: () => Navigator.of(context).pop(option),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
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
      child: Padding(padding: AppResponsive.cardPadding(context), child: child),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.imageBytes,
    required this.avatarUrl,
    required this.onPickAvatar,
  });

  final Uint8List? imageBytes;
  final String? avatarUrl;
  final VoidCallback onPickAvatar;

  @override
  Widget build(BuildContext context) {
    final currentAvatarUrl = avatarUrl?.trim();

    return Column(
      children: [
        InkWell(
          borderRadius: AppRadius.pillBorder,
          onTap: onPickAvatar,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              SafeAvatar(
                radius: 48,
                imageBytes: imageBytes,
                avatarUrl: currentAvatarUrl,
                fallbackIcon: Icons.person,
              ),
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.photo_camera_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          onPressed: onPickAvatar,
          icon: const Icon(Icons.upload_outlined),
          label: const Text('Upload avatar'),
        ),
      ],
    );
  }
}
