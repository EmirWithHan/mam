import 'package:flutter/material.dart';

import '../../../core/constants/sport_types.dart';
import '../../../core/constants/turkey_locations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/sport_icon.dart';
import '../events_models.dart';

class EventFilterSheet extends StatefulWidget {
  const EventFilterSheet({super.key, required this.initialFilters});

  final EventFilters initialFilters;

  @override
  State<EventFilterSheet> createState() => _EventFilterSheetState();
}

class _EventFilterSheetState extends State<EventFilterSheet> {
  late EventFilters _filters;
  final _citySearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters;
  }

  @override
  void dispose() {
    _citySearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          minChildSize: 0.45,
          maxChildSize: 0.94,
          builder: (context, scrollController) {
            return DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppRadius.xl),
                ),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(AppSpacing.lg),
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
                  Text('Filtrele', style: AppTextStyles.title),
                  const SizedBox(height: AppSpacing.lg),
                  _SectionCard(
                    title: 'Etkinlik türü',
                    child: _SportOptions(
                      selectedSportType: _filters.selectedSportType,
                      onChanged: (value) {
                        setState(() {
                          _filters = _filters.copyWith(
                            selectedSportType: value,
                            clearSportType: value == null,
                          );
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SectionCard(
                    title: 'Şehir',
                    child: _CityOptions(
                      controller: _citySearchController,
                      selectedCity: _filters.selectedCity,
                      onChanged: (value) {
                        setState(() {
                          _filters = _filters.copyWith(
                            selectedCity: value,
                            clearCity: value == null,
                          );
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SectionCard(
                    title: 'Tarih',
                    child: _DateOptions(
                      selectedFilter: _filters.dateFilter,
                      onChanged: (value) {
                        setState(() {
                          _filters = _filters.copyWith(dateFilter: value);
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SectionCard(
                    title: 'Fiyat',
                    child: _PriceOptions(
                      selectedFilter: _filters.priceFilter,
                      onChanged: (value) {
                        setState(() {
                          _filters = _filters.copyWith(priceFilter: value);
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SectionCard(
                    title: 'Sıralama',
                    child: _SortOptions(
                      selectedOption: _filters.sortOption,
                      onChanged: (value) {
                        setState(() {
                          _filters = _filters.copyWith(sortOption: value);
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SectionCard(
                    title: 'Uygun kontenjan',
                    child: SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: AppColors.primary,
                      title: Text(
                        'Sadece kontenjanı olanlar',
                        style: AppTextStyles.bodySmall,
                      ),
                      value: _filters.onlyAvailableSpots,
                      onChanged: (value) {
                        setState(() {
                          _filters = _filters.copyWith(
                            onlyAvailableSpots: value,
                          );
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Temizle',
                          variant: AppButtonVariant.secondary,
                          onPressed: () {
                            Navigator.of(context).pop(const EventFilters());
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppButton(
                          label: 'Uygula',
                          onPressed: () => Navigator.of(context).pop(_filters),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.lgBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppTextStyles.bodyStrong),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _SportOptions extends StatelessWidget {
  const _SportOptions({
    required this.selectedSportType,
    required this.onChanged,
  });

  final String? selectedSportType;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final values = ['Tümü', ...SportTypes.values];

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: values.map((value) {
        final isAll = value == 'Tümü';
        final selected = isAll
            ? selectedSportType == null
            : selectedSportType == value;
        return FilterChip(
          selected: selected,
          showCheckmark: false,
          avatar: isAll
              ? null
              : SportIcon(sportType: value, size: 15, filled: false),
          label: Text(value),
          selectedColor: AppColors.primarySoft,
          onSelected: (_) => onChanged(isAll ? null : value),
        );
      }).toList(),
    );
  }
}

class _CityOptions extends StatefulWidget {
  const _CityOptions({
    required this.controller,
    required this.selectedCity,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String? selectedCity;
  final ValueChanged<String?> onChanged;

  @override
  State<_CityOptions> createState() => _CityOptionsState();
}

class _CityOptionsState extends State<_CityOptions> {
  @override
  Widget build(BuildContext context) {
    final query = widget.controller.text.trim();
    final cities = query.isEmpty
        ? TurkeyLocations.getCities().take(12).toList()
        : TurkeyLocations.searchCities(query).take(12).toList();
    final values = ['Tümü', ...cities];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          label: 'Şehir ara',
          controller: widget.controller,
          prefixIcon: const Icon(Icons.search),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: values.map((value) {
            final isAll = value == 'Tümü';
            final selected = isAll
                ? widget.selectedCity == null
                : widget.selectedCity == value;
            return FilterChip(
              selected: selected,
              showCheckmark: false,
              label: Text(value),
              selectedColor: AppColors.primarySoft,
              onSelected: (_) => widget.onChanged(isAll ? null : value),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _DateOptions extends StatelessWidget {
  const _DateOptions({required this.selectedFilter, required this.onChanged});

  final EventDateFilter selectedFilter;
  final ValueChanged<EventDateFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = {
      EventDateFilter.all: 'Tümü',
      EventDateFilter.today: 'Bugün',
      EventDateFilter.tomorrow: 'Yarın',
      EventDateFilter.thisWeek: 'Bu hafta',
      EventDateFilter.weekend: 'Hafta sonu',
      EventDateFilter.upcoming: 'Yaklaşanlar',
    };

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: options.entries.map((entry) {
        return ChoiceChip(
          selected: selectedFilter == entry.key,
          label: Text(entry.value),
          selectedColor: AppColors.primarySoft,
          onSelected: (_) => onChanged(entry.key),
        );
      }).toList(),
    );
  }
}

class _PriceOptions extends StatelessWidget {
  const _PriceOptions({required this.selectedFilter, required this.onChanged});

  final EventPriceFilter selectedFilter;
  final ValueChanged<EventPriceFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = {
      EventPriceFilter.all: 'Tümü',
      EventPriceFilter.free: 'Ücretsiz',
      EventPriceFilter.paid: 'Ücretli',
    };

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: options.entries.map((entry) {
        return ChoiceChip(
          selected: selectedFilter == entry.key,
          label: Text(entry.value),
          selectedColor: AppColors.primarySoft,
          onSelected: (_) => onChanged(entry.key),
        );
      }).toList(),
    );
  }
}

class _SortOptions extends StatelessWidget {
  const _SortOptions({required this.selectedOption, required this.onChanged});

  final EventSortOption selectedOption;
  final ValueChanged<EventSortOption> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = {
      EventSortOption.recommended: 'Önerilen',
      EventSortOption.newest: 'En yeni',
      EventSortOption.oldest: 'En eski',
      EventSortOption.dateAsc: 'Yaklaşan tarih',
      EventSortOption.dateDesc: 'Uzak tarih',
    };

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: options.entries.map((entry) {
        return ChoiceChip(
          selected: selectedOption == entry.key,
          label: Text(entry.value),
          selectedColor: AppColors.primarySoft,
          onSelected: (_) => onChanged(entry.key),
        );
      }).toList(),
    );
  }
}
