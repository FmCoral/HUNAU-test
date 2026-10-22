import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/brand_switch.dart';
import '../../timetable/services/timetable_subscription_service.dart';
import '../providers/settings_provider.dart';

/// 课表订阅与在线同步页：管理调停后课表的 Cloudflare R2 云端日历订阅。
class TimetableSubscriptionScreen extends ConsumerStatefulWidget {
  const TimetableSubscriptionScreen({super.key});

  @override
  ConsumerState<TimetableSubscriptionScreen> createState() =>
      _TimetableSubscriptionScreenState();
}

class _TimetableSubscriptionScreenState
    extends ConsumerState<TimetableSubscriptionScreen> {
  bool _isSwitching = false;
  bool _isResetting = false;

  Future<void> _handleToggle(bool value) async {
    if (_isSwitching) return;
    setState(() => _isSwitching = true);
    final l10n = context.l10n;

    try {
      await ref
          .read(settingsProvider.notifier)
          .setTimetableSubscriptionEnabled(value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.syncFailed(e.toString())),
            backgroundColor: context.colors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSwitching = false);
    }
  }

  Future<void> _handleCopyUrl(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.subscriptionUrlCopied),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }


  Future<void> _handleResetUrl() async {
    if (_isResetting) return;
    final l10n = context.l10n;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.resetSubscriptionConfirmTitle),
        content: Text(l10n.resetSubscriptionConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
                foregroundColor: context.colors.danger),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isResetting = true);
    try {
      await ref
          .read(settingsProvider.notifier)
          .resetTimetableSubscriptionUuid();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.syncFailed(e.toString())),
            backgroundColor: context.colors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final state = ref.watch(settingsProvider);
    final isEnabled = state.timetableSubscriptionEnabled;
    final uuid = state.timetableSubscriptionUuid ?? '';
    final subscriptionUrl = uuid.isNotEmpty
        ? TimetableSubscriptionService.buildSubscriptionUrl(uuid)
        : '';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.timetableSubscription),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          // 开关项
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: AppRadius.cardAll,
              border: Border.all(color: colors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _isSwitching ? null : () => _handleToggle(!isEnabled),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 22,
                      color: colors.textMuted,
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Text(
                        l10n.timetableSubscriptionAutoUpload,
                        style: AppText.body.copyWith(color: colors.text),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (_isSwitching)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      BrandSwitch(
                        value: isEnabled,
                        onChanged: _handleToggle,
                      ),
                  ],
                ),
              ),
            ),
          ),

          if (isEnabled && subscriptionUrl.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: AppRadius.cardAll,
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.timetableSubscriptionUrl,
                    style: AppText.bodyDense.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // URL 显示框
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.surfaceSubtle,
                      borderRadius: AppRadius.innerAll,
                      border: Border.all(color: colors.border),
                    ),
                    child: SelectableText(
                      subscriptionUrl,
                      style: AppText.caption.copyWith(
                        fontFamily: 'monospace',
                        color: colors.info,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // 操作按钮组：只保留复制链接和重置链接，同一行右对齐并对齐样式
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _handleCopyUrl(subscriptionUrl),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: Text(l10n.copySubscriptionUrl),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      TextButton.icon(
                        onPressed: _isResetting ? null : _handleResetUrl,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(l10n.resetSubscriptionUrl),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
