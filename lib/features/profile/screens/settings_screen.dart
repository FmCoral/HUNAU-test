import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state/locale_provider.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/route_utils.dart';
import '../../../core/widgets/embedded_detail_pane.dart';
import 'notification_settings_screen.dart';
import 'appearance_settings_screen.dart';
import 'button_reorder_screen.dart';
import 'ai_settings_screen.dart';
import 'data_sync_settings_screen.dart';
import 'language_settings_screen.dart';
import 'timetable_settings_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Widget? _embeddedScreen;
  String? _selectedSettingKey;
  bool _isTransitioningToRoute = false;

  void _safeNavigate(
    BuildContext context,
    Widget screen, {
    required String key,
    required bool isLargeScreen,
  }) {
    if (isLargeScreen) {
      if (_selectedSettingKey == key && _embeddedScreen != null) {
        return;
      }
      setState(() {
        _embeddedScreen = screen;
        _selectedSettingKey = key;
      });
    } else {
      Navigator.push(
        context,
        createSlideHorizontalRoute(screen),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth >= 600;

        // 当窗口宽度变窄不足以分屏，但当前有嵌入展示的子设置页时，
        // 自动清空嵌入状态并作为纯正全屏路由推入 Navigator，平滑降级
        if (!isLargeScreen && _embeddedScreen != null && !_isTransitioningToRoute) {
          _isTransitioningToRoute = true;
          final screenToOpen = _embeddedScreen!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _embeddedScreen = null;
              _selectedSettingKey = null;
              _isTransitioningToRoute = false;
            });
            Navigator.of(context).push(
              createSlideHorizontalRoute(screenToOpen),
            );
          });
        }

        final masterContent =
            _buildMaster(context, isLargeScreen: isLargeScreen);

        if (isLargeScreen && _embeddedScreen != null) {
          final colors = context.colors;
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              setState(() {
                _embeddedScreen = null;
                _selectedSettingKey = null;
              });
            },
            child: Scaffold(
              body: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: masterContent,
                  ),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: colors.border,
                  ),
                  Expanded(
                    flex: 1,
                    child: EmbeddedDetailPane(
                      key: ValueKey(
                          _selectedSettingKey ?? _embeddedScreen.runtimeType),
                      onClose: () {
                        setState(() {
                          _embeddedScreen = null;
                          _selectedSettingKey = null;
                        });
                      },
                      child: _embeddedScreen!,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return masterContent;
      },
    );
  }

  Widget _buildMaster(BuildContext context, {required bool isLargeScreen}) {
    final colors = context.colors;
    final l10n = context.l10n;
    final currentLocale = ref.watch(localeProvider);

    final currentCode = LocaleNotifier.localeToCode(currentLocale);
    final currentOption = LocaleNotifier.supportedLanguages.firstWhere(
      (opt) => opt.code == currentCode,
      orElse: () => LocaleNotifier.supportedLanguages.first,
    );
    final currentLanguageLabel = currentOption.getLocalizedName(context);

    final items = <Widget>[
      _buildSettingItem(
        context,
        icon: Icons.language_rounded,
        title: l10n.language,
        isSelected: isLargeScreen && _selectedSettingKey == 'language',
        trailing: Text(
          currentLanguageLabel,
          style: AppText.bodyDense.copyWith(color: colors.textMuted),
        ),
        onTap: () => _safeNavigate(
          context,
          const LanguageSettingsScreen(),
          key: 'language',
          isLargeScreen: isLargeScreen,
        ),
      ),
      _buildSettingItem(
        context,
        icon: Icons.code_rounded,
        title: l10n.agentSettings,
        isSelected: isLargeScreen && _selectedSettingKey == 'agent',
        onTap: () => _safeNavigate(
          context,
          const AiSettingsScreen(),
          key: 'agent',
          isLargeScreen: isLargeScreen,
        ),
      ),
      _buildSettingItem(
        context,
        icon: Icons.palette_outlined,
        title: l10n.appearanceSettings,
        isSelected: isLargeScreen && _selectedSettingKey == 'appearance',
        onTap: () => _safeNavigate(
          context,
          const AppearanceSettingsScreen(),
          key: 'appearance',
          isLargeScreen: isLargeScreen,
        ),
      ),
      _buildSettingItem(
        context,
        icon: Icons.widgets_outlined,
        title: l10n.widgetSettings,
        isSelected: isLargeScreen && _selectedSettingKey == 'widget',
        onTap: () => _safeNavigate(
          context,
          ButtonReorderScreen(
            title: l10n.widgetSettings,
            listType: 'widget',
          ),
          key: 'widget',
          isLargeScreen: isLargeScreen,
        ),
      ),
      _buildSettingItem(
        context,
        icon: Icons.notifications_none_rounded,
        title: l10n.notificationSettings,
        isSelected: isLargeScreen && _selectedSettingKey == 'notification',
        onTap: () => _safeNavigate(
          context,
          const NotificationSettingsScreen(),
          key: 'notification',
          isLargeScreen: isLargeScreen,
        ),
      ),
      _buildSettingItem(
        context,
        icon: Icons.calendar_month_outlined,
        title: l10n.timetableSettings,
        isSelected: isLargeScreen && _selectedSettingKey == 'timetable',
        onTap: () => _safeNavigate(
          context,
          const TimetableSettingsScreen(),
          key: 'timetable',
          isLargeScreen: isLargeScreen,
        ),
      ),
      _buildSettingItem(
        context,
        icon: Icons.sync_rounded,
        title: l10n.dataSyncSettings,
        isSelected: isLargeScreen && _selectedSettingKey == 'data_sync',
        onTap: () => _safeNavigate(
          context,
          const DataSyncSettingsScreen(),
          key: 'data_sync',
          isLargeScreen: isLargeScreen,
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
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
                  items[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    bool showChevron = true,
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;

    return Material(
      color: isSelected ? colors.surfaceSubtle : Colors.transparent,
      child: InkWell(
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppText.body.copyWith(
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: colors.text,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: AppText.caption.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  trailing,
                  const SizedBox(width: AppSpacing.xs),
                ],
                if (showChevron)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: colors.textMuted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
