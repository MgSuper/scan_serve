import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:startup_launch/app/localization/locale_cubit.dart';
import 'package:startup_launch/app/routes/app_routes.dart';
import 'package:startup_launch/core/extensions/l10n.dart';
import 'package:startup_launch/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:startup_launch/features/onboarding/presentation/cubit/onboarding_state.dart';
import 'package:startup_launch/features/onboarding/presentation/typewriter_text.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish(BuildContext context) async {
    await context.read<OnboardingCubit>().complete();
    if (!context.mounted) return;
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final titles = [
      l10n.onboardingTitle1,
      l10n.onboardingTitle2,
      l10n.onboardingTitle3,
      l10n.onboardingTitle4,
    ];

    final descs = [
      l10n.onboardingDesc1,
      l10n.onboardingDesc2,
      l10n.onboardingDesc3,
      l10n.onboardingDesc4,
    ];

    final totalPages = titles.length;

    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final isLastPage = state.currentPage == totalPages - 1;

        return Scaffold(
          appBar: AppBar(
            actions: [
              const _LanguageDropdown(),
              TextButton(
                onPressed: state.isSubmitting ? null : () => _finish(context),
                child: Text(context.l10n.skip),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: totalPages,
                      onPageChanged: (index) {
                        context.read<OnboardingCubit>().setPage(index);
                      },
                      itemBuilder: (context, index) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Spacer(),
                            TypewriterText(
                              key: ValueKey('title_$index'),
                              text: titles[index],
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              descs[index],
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                            ),
                            const Spacer(flex: 2),
                          ],
                        );
                      },
                    ),
                  ),
                  Row(
                    children: List.generate(
                      totalPages,
                      (index) => Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 6,
                          decoration: BoxDecoration(
                            color: state.currentPage == index
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: state.isSubmitting
                          ? null
                          : () async {
                              if (isLastPage) {
                                await _finish(context);
                              } else {
                                await _pageController.nextPage(
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeOut,
                                );
                              }
                            },
                      child: state.isSubmitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              isLastPage
                                  ? context.l10n.getStarted
                                  : context.l10n.next,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LanguageDropdown extends StatelessWidget {
  const _LanguageDropdown();

  @override
  Widget build(BuildContext context) {
    final items = [
      ('en', '🇺🇸 English'),
      ('vi', '🇻🇳 Tiếng Việt'),
      ('ja', '🇯🇵 日本語'),
      ('th', '🇹🇭 ไทย'),
    ];

    return BlocBuilder<LocaleCubit, Locale>(
      builder: (context, locale) {
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: locale.languageCode,
              borderRadius: BorderRadius.circular(12),
              icon: const Icon(Icons.keyboard_arrow_down),
              onChanged: (value) {
                if (value != null) {
                  context.read<LocaleCubit>().change(value);
                }
              },
              items: items.map((item) {
                return DropdownMenuItem(value: item.$1, child: Text(item.$2));
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
