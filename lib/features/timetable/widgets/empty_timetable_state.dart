import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_extension.dart';

/// 课表空状态组件
class EmptyTimetableState extends StatelessWidget {
  /// 自动同步是否开启。
  final bool autoSyncEnabled;

  /// 是否正在后台执行自动同步。仅在自动同步开启且真正同步中时显示“正在同步”及转圈；
  /// 同步完成后或关闭时退出转圈，显示暂无课表并提示点刷新按钮手动同步。
  final bool isSyncing;

  const EmptyTimetableState({
    super.key,
    this.autoSyncEnabled = true,
    this.isSyncing = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final showLoading = autoSyncEnabled && isSyncing;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              decoration: BoxDecoration(
                color: colors.statusBg(colors.brand),
                shape: BoxShape.circle,
              ),
              child: Icon(
                showLoading
                    ? Icons.calendar_today_outlined
                    : (autoSyncEnabled
                        ? Icons.calendar_today_outlined
                        : Icons.cloud_off_outlined),
                size: 64,
                color: colors.brand,
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            Text(
              showLoading
                  ? context.l10n.timetableSyncing
                  : context.l10n.noLocalTimetable,
              textAlign: TextAlign.center,
              style: AppText.pageTitle.copyWith(color: colors.text),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              showLoading
                  ? context.l10n.timetableSyncingDesc
                  : context.l10n.tapRefreshButtonToSync,
              textAlign: TextAlign.center,
              style: AppText.bodyDense.copyWith(color: colors.textMuted, height: 1.5),
            ),
            if (showLoading) ...[
              const SizedBox(height: AppSpacing.xxxl),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
