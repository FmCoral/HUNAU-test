import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/route_utils.dart';
import '../../../core/utils/l10n_extension.dart';
import 'button_reorder_screen.dart';

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    final items = <({IconData icon, String title, VoidCallback onTap})>[
      (
        icon: Icons.home_outlined,
        title: l10n.homeButtonsSetting,
        onTap: () {
          Navigator.push(
            context,
            createSlideHorizontalRoute(ButtonReorderScreen(
              title: l10n.homeButtonsTitle,
              listType: 'home',
            )),
          );
        },
      ),
      (
        icon: Icons.grid_view_outlined,
        title: l10n.functionsButtonsSetting,
        onTap: () {
          Navigator.push(
            context,
            createSlideHorizontalRoute(ButtonReorderScreen(
              title: l10n.functionsButtonsTitle,
              listType: 'functions',
            )),
          );
        },
      ),
      (
        icon: Icons.view_agenda_outlined,
        title: l10n.feedButtonsSetting,
        onTap: () {
          Navigator.push(
            context,
            createSlideHorizontalRoute(ButtonReorderScreen(
              title: l10n.feedButtonsTitle,
              listType: 'feed',
            )),
          );
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appearanceSettings),
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
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, indent: 54, color: colors.border),
                  _buildSettingItem(
                    context,
                    icon: items[i].icon,
                    title: items[i].title,
                    onTap: items[i].onTap,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(BuildContext context,
      {required IconData icon,
      required String title,
      required VoidCallback onTap}) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(
            children: [
              Icon(icon, size: 22, color: colors.textMuted),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Text(
                  title,
                  style: AppText.body.copyWith(color: colors.text),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
