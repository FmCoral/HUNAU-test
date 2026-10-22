import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state/locale_provider.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_extension.dart';

class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final currentLocale = ref.watch(localeProvider);
    final currentCode = LocaleNotifier.localeToCode(currentLocale);

    final currentOption = LocaleNotifier.supportedLanguages.firstWhere(
      (opt) => opt.code == currentCode,
      orElse: () => LocaleNotifier.supportedLanguages.first,
    );
    final otherOptions = LocaleNotifier.supportedLanguages
        .where((opt) => opt.code != currentOption.code)
        .toList();
    final languages = [currentOption, ...otherOptions];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.language),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: AppRadius.cardAll,
              border: Border.all(color: colors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < languages.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, indent: 16, color: colors.border),
                  Builder(builder: (context) {
                    final option = languages[i];
                    final isSelected = currentCode == option.code;
                    final title =
                        LocaleNotifier.getDisplayTitle(option, context);
                    return ListTile(
                      title: Text(
                        title,
                        style: AppText.body.copyWith(
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color:
                              isSelected ? colors.brandText : colors.text,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_rounded, color: colors.brand)
                          : null,
                      onTap: () {
                        ref
                            .read(localeProvider.notifier)
                            .setLocale(option.locale);
                      },
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
