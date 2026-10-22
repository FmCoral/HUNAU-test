import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/state/auth_state.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/date_format_utils.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/brand_switch.dart';
import '../../timetable/services/timetable_service.dart';
import '../../timetable/services/timetable_storage.dart';
import '../providers/settings_provider.dart';
import 'timetable_subscription_screen.dart';

/// 课表设置页：自动同步开关 + 手动指定本学期第一周周一。
class TimetableSettingsScreen extends ConsumerWidget {
  const TimetableSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final autoSyncEnabled =
        ref.watch(settingsProvider).timetableAutoSyncEnabled;
    final showEndTime =
        ref.watch(settingsProvider.select((s) => s.timetableShowEndTime));
    final manualIso =
        ref.watch(settingsProvider.select((s) => s.manualFirstWeekMondayIso));
    final manualMonday =
        manualIso != null ? DateTime.tryParse(manualIso) : null;

    // 第二行仅在自动同步关闭时可设置
    final mondayEnabled = !autoSyncEnabled;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.timetableSettings),
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
                _buildSwitchItem(
                  context,
                  icon: Icons.sync_rounded,
                  title: l10n.timetableAutoSync,
                  value: autoSyncEnabled,
                  onChanged: (v) => _onAutoSyncToggle(context, ref, v),
                ),
                Divider(height: 1, indent: 54, color: colors.border),
                _buildSwitchItem(
                  context,
                  icon: Icons.schedule_rounded,
                  title: l10n.timetableShowEndTime,
                  value: showEndTime,
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .setTimetableShowEndTime(v),
                ),
                Divider(height: 1, indent: 54, color: colors.border),
                InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TimetableSubscriptionScreen(),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                    child: Row(
                      children: [
                        Icon(Icons.rss_feed_rounded,
                            size: 22, color: colors.textMuted),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Text(
                            l10n.timetableSubscription,
                            style: AppText.body.copyWith(color: colors.text),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: colors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, indent: 54, color: colors.border),
                Opacity(
                  opacity: mondayEnabled ? 1.0 : 0.5,
                  child: InkWell(
                    onTap: mondayEnabled
                        ? () => _pickFirstWeekMonday(context, ref)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                      child: Row(
                        children: [
                          Icon(Icons.date_range_outlined,
                              size: 22, color: colors.textMuted),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: Text(
                              l10n.firstWeekMonday,
                              style: AppText.body.copyWith(color: colors.text),
                            ),
                          ),
                          FutureBuilder<DateTime>(
                            // 未手动设置时显示当前生效值（元数据 > 按月份猜）
                            future: TimetableStorage().resolveFirstWeekMonday(),
                            builder: (context, snapshot) {
                              final monday = snapshot.data ?? manualMonday;
                              return Text(
                                monday != null
                                    ? formatYMMMd(
                                        monday,
                                        Localizations.localeOf(context)
                                            .toString(),
                                      )
                                    : l10n.notSet,
                                style: AppText.bodyDense.copyWith(
                                  color: colors.textMuted,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: AppSpacing.xs),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 22, color: colors.textMuted),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: subtitle == null
                ? Text(
                    title,
                    style: AppText.body.copyWith(color: colors.text),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppText.body.copyWith(color: colors.text),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppText.caption.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
          ),
          BrandSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  /// 自动同步开关切换。关闭时二次确认（会删本地课表、保留规则与元数据）；
  /// 开启且已登录时立即同步一次，免得等到下次登录。
  Future<void> _onAutoSyncToggle(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    final l10n = context.l10n;

    if (!value) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(l10n.disableAutoSyncTitle),
          content: Text(l10n.disableAutoSyncMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(l10n.confirm),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;

      await ref
          .read(settingsProvider.notifier)
          .setTimetableAutoSyncEnabled(false);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.localTimetableDeleted),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await ref.read(settingsProvider.notifier).setTimetableAutoSyncEnabled(true);
    if (!context.mounted) return;

    final authed =
        ref.read(authStateProvider).status == AuthStatus.authenticated;
    if (!authed) return;

    try {
      await TimetableService().downloadAndSaveTimetable(
        semester: AppConstants.defaultSemester,
      );
      await ref.read(settingsProvider.notifier).rescheduleNotifications();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.timetableRefreshed),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.timetableRefreshFailed(e.toString())),
          backgroundColor: context.colors.danger,
        ),
      );
    }
  }

  /// 选择本学期第一周周一（自动归一到所选周的周一）。
  /// 保存后课表页通过 settings 监听自动重载。
  Future<void> _pickFirstWeekMonday(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final now = DateTime.now();
    final currentIso =
        ref.read(settingsProvider).manualFirstWeekMondayIso;
    final initial =
        currentIso != null ? DateTime.tryParse(currentIso) ?? now : now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      helpText: context.l10n.selectFirstWeekMondayHelp,
    );

    if (picked == null || !context.mounted) return;
    await ref
        .read(settingsProvider.notifier)
        .setManualFirstWeekMonday(picked);
  }
}
