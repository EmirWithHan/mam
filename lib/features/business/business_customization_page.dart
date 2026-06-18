import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/image_crop_helper.dart';
import '../../core/widgets/app_loader.dart';
import '../../services/storage_service.dart';
import '../../services/supabase_service.dart';
import '../events/events_models.dart';
import 'business_models.dart';
import 'business_provider.dart';

class BusinessCustomizationPage extends ConsumerStatefulWidget {
  const BusinessCustomizationPage({super.key, required this.account});

  final BusinessAccount account;

  @override
  ConsumerState<BusinessCustomizationPage> createState() =>
      _BusinessCustomizationPageState();
}

class _BusinessCustomizationPageState
    extends ConsumerState<BusinessCustomizationPage> {
  final _imagePicker = ImagePicker();
  final _storageService = const StorageService();

  late String? _selectedColor;
  late String? _selectedPinnedEventId;
  late List<String> _galleryUrls;

  List<Event> _myEvents = [];
  bool _loadingEvents = false;
  bool _saving = false;
  bool _uploading = false;

  final List<Map<String, String>> _presetColors = const [
    {'name': 'Varsayılan (Mercan)', 'hex': '#FF7E79'},
    {'name': 'Gök Mavisi', 'hex': '#7CB9E8'},
    {'name': 'Zümrüt Yeşili', 'hex': '#2E7D32'},
    {'name': 'Mor Alev', 'hex': '#6A1B9A'},
    {'name': 'Sıcak Turuncu', 'hex': '#F57C00'},
    {'name': 'Koyu Gece', 'hex': '#212121'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.account.customThemeColor;
    _selectedPinnedEventId = widget.account.pinnedEventId;
    _galleryUrls = List<String>.from(widget.account.galleryUrls ?? []);
    _loadMyEvents();
  }

  Future<void> _loadMyEvents() async {
    setState(() => _loadingEvents = true);
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId != null) {
        final data = await SupabaseService.client
            .from('events')
            .select('*')
            .eq('host_id', userId)
            .inFilter('status', ['active', 'completed'])
            .order('event_date', ascending: false);

        if (mounted) {
          setState(() {
            _myEvents = (data as List<dynamic>)
                .map((row) => Map<String, dynamic>.from(row))
                .map(Event.fromJson)
                .toList();
            _loadingEvents = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingEvents = false);
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    if (_uploading) return;
    setState(() => _uploading = true);

    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        final cropped = await cropImage(picked.path);
        if (cropped != null) {
          final bytes = await cropped.readAsBytes();
          final imageUrl = await _storageService.uploadPostImage(
            bytes: bytes,
            fileName:
                'business_gallery_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
          setState(() {
            _galleryUrls.add(imageUrl);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Fotoğraf yüklenemedi.')));
      }
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  Future<void> _saveChanges() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      await ref
          .read(myBusinessAccountProvider.notifier)
          .updateCustomizations(
            id: widget.account.id,
            customThemeColor: _selectedColor,
            pinnedEventId: _selectedPinnedEventId,
            galleryUrls: _galleryUrls,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Değişiklikler kaydedildi.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kaydedilirken hata oluştu.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Color _parseHexColor(String hex) {
    try {
      final buffer = StringBuffer();
      if (hex.length == 6 || hex.length == 7) buffer.write('ff');
      buffer.write(hex.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profili Özelleştir'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveChanges,
              child: Text(
                'Kaydet',
                style: AppTextStyles.bodyStrong.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              // Theme color section
              Text('Tema Rengi', style: AppTextStyles.title),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Profilinde butonlar ve vurgular için kullanılacak tema rengini seç.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 60,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _presetColors.length,
                  separatorBuilder: (_, index) =>
                      const SizedBox(width: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final preset = _presetColors[index];
                    final colorHex = preset['hex']!;
                    final color = _parseHexColor(colorHex);
                    final isSelected =
                        _selectedColor == colorHex ||
                        (_selectedColor == null && index == 0);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColor = colorHex;
                        });
                      },
                      child: Tooltip(
                        message: preset['name']!,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.black : Colors.black12,
                              width: isSelected ? 3.0 : 1.0,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 24,
                                )
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),

              const Divider(height: 40),

              // Pinned event section
              Text('Öne Çıkan Etkinlik', style: AppTextStyles.title),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Profilinin en üstünde sabitlenecek bir etkinlik seç.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              if (_loadingEvents)
                const Center(child: AppLoader())
              else if (_myEvents.isEmpty)
                Text(
                  'Henüz oluşturulmuş aktif bir etkinliğin bulunmuyor.',
                  style: AppTextStyles.body.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                DropdownButtonFormField<String?>(
                  initialValue:
                      _myEvents.any((e) => e.id == _selectedPinnedEventId)
                      ? _selectedPinnedEventId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Etkinlik Seç',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Hiçbiri (Sabitlemeyi Kaldır)'),
                    ),
                    ..._myEvents.map((event) {
                      return DropdownMenuItem<String?>(
                        value: event.id,
                        child: Text(
                          event.title.length > 35
                              ? '${event.title.substring(0, 35)}...'
                              : event.title,
                        ),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedPinnedEventId = val;
                    });
                  },
                ),

              const Divider(height: 40),

              // Gallery section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Fotoğraf Galerisi', style: AppTextStyles.title),
                  if (_uploading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      icon: const Icon(
                        Icons.add_a_photo_outlined,
                        color: AppColors.primary,
                      ),
                      onPressed: _pickAndUploadImage,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'İşletme profilinde gösterilecek fotoğrafları yükle.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              if (_galleryUrls.isEmpty)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.lgBorder,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 40,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Galeri henüz boş.',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _galleryUrls.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: AppSpacing.sm,
                    mainAxisSpacing: AppSpacing.sm,
                  ),
                  itemBuilder: (context, index) {
                    final url = _galleryUrls[index];
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: AppRadius.mdBorder,
                          child: Image.network(url, fit: BoxFit.cover),
                        ),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _galleryUrls.removeAt(index);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
          if (_saving)
            Container(
              color: Colors.black12,
              child: const Center(child: AppLoader()),
            ),
        ],
      ),
    );
  }
}
