import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/webview_cache_service.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/brand_switch.dart';
import '../../cloudisk/services/cloud_backup_manager.dart';
import '../providers/settings_provider.dart';
import '../services/backup_export_service.dart';
import '../services/backup_provider_refresh.dart';

/// 数据同步页：云备份自动同步开关 + 手动备份导出 + 备份导入。
class DataSyncSettingsScreen extends ConsumerStatefulWidget {
  const DataSyncSettingsScreen({super.key});

  @override
  ConsumerState<DataSyncSettingsScreen> createState() =>
      _DataSyncSettingsScreenState();
}

class _DataSyncSettingsScreenState
    extends ConsumerState<DataSyncSettingsScreen> {
  bool _exporting = false;
  bool _importing = false;
  bool _clearingCache = false;
  bool _analyticsEnabled = true;

  @override
  void initState() {
    super.initState();
    AnalyticsService.isEnabled().then((val) {
      if (mounted) setState(() => _analyticsEnabled = val);
    });
  }

  Future<void> _handleClearWebViewCache() async {
    if (_clearingCache) return;
    final l10n = context.l10n;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.clearWebViewCacheConfirmTitle),
        content: Text(l10n.clearWebViewCacheConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _clearingCache = true);
    try {
      await WebViewCacheService.clearCache(
        includeDiskFiles: true,
        clearStorage: true,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.clearWebViewCacheSuccess),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: context.colors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _clearingCache = false);
    }
  }

  Future<void> _handleExportBackup() async {
    if (_exporting || _importing) return;
    setState(() => _exporting = true);
    try {
      await BackupExportService.exportAndShare(
        shareText: context.l10n.backupShareText,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.backupExportSuccess),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.backupExportFailed(e.toString())),
            backgroundColor: context.colors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _handleImportBackup() async {
    if (_exporting || _importing) return;
    final l10n = context.l10n;

    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.dataImportFailed(e.toString())),
            backgroundColor: context.colors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    if (picked == null || picked.files.isEmpty) return; // 用户取消
    final path = picked.files.single.path;
    if (path == null || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.dataImportInvalidFile),
            backgroundColor: context.colors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    late final Map<String, dynamic> backup;
    try {
      backup = await BackupExportService.readBackupFile(path);
    } on FormatException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.dataImportInvalidFile),
            backgroundColor: context.colors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    } on UnsupportedError {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.dataImportVersionTooNew),
            backgroundColor: context.colors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.dataImportFailed(e.toString())),
            backgroundColor: context.colors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.dataImportConfirmTitle),
        content: Text(l10n.dataImportConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _importing = true);
    try {
      await BackupExportService.applyBackupData(backup);
      await BackupProviderRefresh.refreshAfterRestore(ref, backup);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.dataImportSuccess),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on FormatException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.dataImportInvalidFile),
            backgroundColor: context.colors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on UnsupportedError {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.dataImportVersionTooNew),
            backgroundColor: context.colors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.dataImportFailed(e.toString())),
            backgroundColor: context.colors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    final switchItems = <Widget>[
      _buildSwitchItem(
        context,
        icon: Icons.cloud_sync_outlined,
        title: l10n.cloudBackupAutoSync,
        subtitle: l10n.cloudBackupAutoSyncSubtitle,
        value: ref.watch(
          settingsProvider.select((s) => s.cloudBackupAutoSyncEnabled),
        ),
        onChanged: (v) async {
          final result = await ref
              .read(settingsProvider.notifier)
              .setCloudBackupAutoSyncEnabled(v);
          // 开启后若从云端拉了最新，先刷新界面再提示
          if (v &&
              result?.outcome == InitialSyncOutcome.pulled &&
              result?.backup != null &&
              context.mounted) {
            await BackupProviderRefresh.refreshAfterRestore(
                ref, result!.backup!);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.dataImportSuccess),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        },
      ),
      _buildSwitchItem(
        context,
        icon: Icons.analytics_outlined,
        title: l10n.analyticsAnonymousTitle,
        subtitle: l10n.analyticsAnonymousSubtitle,
        value: _analyticsEnabled,
        onChanged: (v) async {
          setState(() => _analyticsEnabled = v);
          await AnalyticsService.setEnabled(v);
        },
      ),
    ];

    final actionItems = <Widget>[
      _buildSettingItem(
        context,
        icon: Icons.upload_outlined,
        title: l10n.dataBackup,
        trailing: _exporting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
        showChevron: !_exporting,
        onTap: _handleExportBackup,
      ),
      _buildSettingItem(
        context,
        icon: Icons.download_outlined,
        title: l10n.dataImport,
        trailing: _importing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
        showChevron: !_importing,
        onTap: _handleImportBackup,
      ),
      _buildSettingItem(
        context,
        icon: Icons.cleaning_services_outlined,
        title: l10n.clearWebViewCache,
        trailing: _clearingCache
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
        showChevron: !_clearingCache,
        onTap: _handleClearWebViewCache,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dataSyncSettings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          _buildCard(colors, switchItems),
          const SizedBox(height: AppSpacing.md),
          _buildCard(colors, actionItems),
        ],
      ),
    );
  }

  Widget _buildCard(AppSemanticColors colors, List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 54, color: colors.border),
            items[i],
          ],
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

    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
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
                    style: AppText.body.copyWith(color: colors.text),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style:
                          AppText.caption.copyWith(color: colors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            BrandSwitch(value: value, onChanged: onChanged),
          ],
        ),
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
    required VoidCallback onTap,
  }) {
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.body.copyWith(color: colors.text),
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
    );
  }
}
