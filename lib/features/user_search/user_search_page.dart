import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/empty_state.dart';
import '../profile/widgets/safe_avatar.dart';
import 'user_search_models.dart';
import 'user_search_provider.dart';

class UserSearchPage extends ConsumerStatefulWidget {
  const UserSearchPage({super.key});

  @override
  ConsumerState<UserSearchPage> createState() => _UserSearchPageState();
}

class _UserSearchPageState extends ConsumerState<UserSearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(userSearchControllerProvider, (previous, next) {
      final message = next.message;
      if (message == null || message == previous?.message) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });

    final state = ref.watch(userSearchControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Kullanıcı ara')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            AppTextField(
              label: 'Kullanıcı ara',
              hintText: 'Kullanıcı adı veya etiket ara',
              controller: _controller,
              prefixIcon: const Icon(Icons.search_rounded),
              textInputAction: TextInputAction.search,
              onChanged: _onQueryChanged,
              onFieldSubmitted: _searchNow,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(child: AppLoader()),
              )
            else if (state.status == UserSearchStatus.error)
              const EmptyState(
                title: 'Kullanıcılar yüklenemedi.',
                message: 'İşlem tamamlanamadı. Tekrar dene.',
                icon: Icons.search_off_rounded,
              )
            else if (state.canShowEmpty)
              const EmptyState(
                title: 'Sonuç bulunamadı.',
                message: 'Kullanıcı adı veya etiketi kontrol edip tekrar ara.',
                icon: Icons.person_search_rounded,
              )
            else
              ...state.results.map(
                (result) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _UserSearchResultTile(
                    result: result,
                    isLoading: state.isUserLoading(result.userId),
                    onTap: () => context.pushNamed(
                      RouteNames.publicProfile,
                      pathParameters: {'userId': result.userId},
                    ),
                    onFollow: () => ref
                        .read(userSearchControllerProvider.notifier)
                        .follow(result),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: UserSearchRules.debounceMilliseconds),
      () => _searchNow(value),
    );
  }

  void _searchNow(String value) {
    _debounce?.cancel();
    ref.read(userSearchControllerProvider.notifier).search(value);
  }
}

class _UserSearchResultTile extends StatelessWidget {
  const _UserSearchResultTile({
    required this.result,
    required this.isLoading,
    required this.onTap,
    required this.onFollow,
  });

  final UserSearchResult result;
  final bool isLoading;
  final VoidCallback onTap;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: AppRadius.mdBorder,
      child: InkWell(
        borderRadius: AppRadius.mdBorder,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              SafeAvatar(
                radius: 24,
                avatarUrl: result.avatarUrl,
                fallbackText: result.initials,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            result.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.title,
                          ),
                        ),
                        if (result.isBusinessAccount) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Icon(
                            result.businessIsVerified
                                ? Icons.verified_rounded
                                : Icons.storefront_outlined,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      [
                        result.handleLabel,
                        if (result.businessCategory != null)
                          result.businessCategory,
                      ].whereType<String>().join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _SearchActionButton(
                label: result.actionLabel,
                isLoading: isLoading,
                enabled: result.canFollow,
                onPressed: onFollow,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchActionButton extends StatelessWidget {
  const _SearchActionButton({
    required this.label,
    required this.isLoading,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: enabled && !isLoading ? onPressed : null,
      icon: isLoading
          ? const SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(enabled ? Icons.person_add_alt_1_rounded : Icons.check),
      label: Text(label),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        textStyle: AppTextStyles.label,
      ),
    );
  }
}
