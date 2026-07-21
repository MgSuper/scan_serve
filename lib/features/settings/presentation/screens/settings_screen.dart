import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:startup_launch/app/localization/locale_cubit.dart';
import 'package:startup_launch/app/theme/theme_cubit.dart';
import 'package:startup_launch/core/extensions/l10n.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.settings,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionHeader(title: context.l10n.changeLanguage),
          const SizedBox(height: 16),
          LanguageSelector(),
          const SizedBox(height: 32),
          _SectionHeader(
            title: context.l10n.appearance,
          ), // You can add this to l10n later
          const SizedBox(height: 16),
          ThemeSelector(),
        ],
      ),
    );
  }
}

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final languages = [
      {'name': 'English', 'code': 'en', 'flag': '🇺🇸'},
      {'name': 'Tiếng Việt', 'code': 'vi', 'flag': '🇻🇳'},
      {'name': '日本語', 'code': 'ja', 'flag': '🇯🇵'},
      {'name': 'ไทย', 'code': 'th', 'flag': '🇹🇭'},
    ];

    return BlocBuilder<LocaleCubit, Locale>(
      builder: (context, currentLocale) {
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.5,
          ),
          itemCount: languages.length,
          itemBuilder: (context, index) {
            final lang = languages[index];
            final isSelected = currentLocale.languageCode == lang['code'];

            return GestureDetector(
              onTap: () => context.read<LocaleCubit>().change(lang['code']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey.withValues(alpha: 0.2),
                    width: 2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(lang['flag']!, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text(
                        lang['name']!,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class ThemeSelector extends StatelessWidget {
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, mode) {
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              _ThemeOption(
                icon: Icons.light_mode,
                label: context.l10n.light,
                isSelected: mode == ThemeMode.light,
                onTap: () => context.read<ThemeCubit>().setLight(),
              ),
              _ThemeOption(
                icon: Icons.dark_mode,
                label: context.l10n.dark,
                isSelected: mode == ThemeMode.dark,
                onTap: () => context.read<ThemeCubit>().setDark(),
              ),
              _ThemeOption(
                icon: Icons.settings_brightness,
                label: context.l10n.auto,
                isSelected: mode == ThemeMode.system,
                onTap: () => context.read<ThemeCubit>().setSystem(),
              ),
            ],
          ),
        );
      },
    );
  }
}

// --- Supporting Small Widgets ---

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.grey),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }
}
