import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/route_utils.dart';
import '../models/leave_models.dart';
import '../services/leave_service.dart';
import 'leave_apply_screen.dart';
import 'leave_detail_screen.dart';

enum LeaveFilter {
  all,
  pendingAudit,
  auditing,
  audited;

  String getLocalizedLabel(BuildContext context) => switch (this) {
        LeaveFilter.all => context.l10n.all,
        LeaveFilter.pendingAudit => context.l10n.statusPendingAudit,
        LeaveFilter.auditing => context.l10n.statusAuditing,
        LeaveFilter.audited => context.l10n.statusAudited,
      };

  bool matches(LeaveRecord item) => switch (this) {
        LeaveFilter.all => true,
        LeaveFilter.pendingAudit => item.auditStatus == '0',
        LeaveFilter.auditing => item.auditStatus == '8',
        LeaveFilter.audited => item.auditStatus == '9',
      };
}

/// 请假申请 - 功能页（记录列表）
class LeaveListScreen extends ConsumerStatefulWidget {
  const LeaveListScreen({super.key});

  @override
  ConsumerState<LeaveListScreen> createState() => _LeaveListScreenState();
}

class _LeaveListScreenState extends ConsumerState<LeaveListScreen> {
  List<LeaveRecord> _items = [];
  bool _loading = true;
  String? _error;
  LeaveFilter _filter = LeaveFilter.all;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _getErrorMessage(dynamic e) {
    if (e is LeaveException) {
      if (e.message.contains('统一认证已过期')) return context.l10n.ssoExpiredRelogin;
      if (e.message.contains('登录已失效')) return context.l10n.studentSystemSessionExpired;
      return e.message;
    }
    return context.l10n.loadFailedCheckNetwork;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(leaveServiceProvider);
      final items = await service.fetchList();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _getErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openApply() async {
    final changed = await Navigator.of(context).push<bool>(
      createSlideUpRoute(const LeaveApplyScreen()),
    );
    if (changed == true && mounted) _load();
  }

  Future<void> _delete(LeaveRecord item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = context.colors;
        return AlertDialog(
          title: Text(context.l10n.cancelLeavePromptTitle),
          content: Text(
            context.l10n.confirmRevokeLeaveItem(
              item.typeName.isEmpty ? context.l10n.leaveApplication : item.typeName,
              item.timeRange,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                context.l10n.revoke,
                style: TextStyle(color: colors.danger),
              ),
            ),
          ],
        );
      },
    );
    if (confirm != true || _deleting) return;
    setState(() => _deleting = true);
    try {
      await ref.read(leaveServiceProvider).delete(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.revokedSuccess),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is LeaveException ? e.message : context.l10n.revokeFailedRetry),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final filtered = _items.where((item) => _filter.matches(item)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.leaveApplication),
        actions: [
          IconButton(
            tooltip: context.l10n.refresh,
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading && _items.isEmpty
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page, AppSpacing.lg, AppSpacing.page, 40),
                children: [
                  if (_loading) const LinearProgressIndicator(),
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: AppRadius.cardAll,
                        border: Border.all(color: colors.border),
                      ),
                      padding: const EdgeInsets.all(AppSpacing.card),
                      child: Center(
                        child: Column(
                          children: [
                            Text(_error!),
                            const SizedBox(height: AppSpacing.sm),
                            TextButton(
                              onPressed: _load,
                              child: Text(context.l10n.retry),
                            ),
                          ],
                        ),
                      ),
                    ),
                  _buildApplyCard(colors),
                  const SizedBox(height: AppSpacing.xl),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: LeaveFilter.values
                        .map((filter) => _buildFilterChip(filter, colors))
                        .toList(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (filtered.isEmpty && _error == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: Text(
                          context.l10n.noLeaveRecordsFound,
                          style: AppText.bodyDense
                              .copyWith(color: colors.textMuted),
                        ),
                      ),
                    ),
                  ...filtered.map((item) => _buildItemCard(item, colors)),
                ],
              ),
            ),
    );
  }

  Widget _buildApplyCard(AppSemanticColors colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: colors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.cardAll,
          onTap: _openApply,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.card, vertical: 14),
            child: Row(
              children: [
                Icon(
                  Icons.edit_note_rounded,
                  color: colors.brand,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  context.l10n.leaveApplication,
                  style:
                      AppText.sectionTitle.copyWith(color: colors.text),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: colors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(LeaveFilter filter, AppSemanticColors colors) {
    final isSelected = _filter == filter;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _filter = filter),
        borderRadius: AppRadius.controlAll,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.statusBg(colors.brand)
                : Colors.transparent,
            borderRadius: AppRadius.controlAll,
            border: Border.all(
              color: isSelected ? colors.brand : colors.border,
            ),
          ),
          child: Text(
            filter.getLocalizedLabel(context),
            style: AppText.caption.copyWith(
              color: isSelected ? colors.brandText : colors.text,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(LeaveRecord item, AppSemanticColors colors) {
    final statusColor = switch (item.auditStatus) {
      '0' => colors.info,
      '8' => colors.warning,
      '9' => colors.brand,
      _ => colors.textMuted,
    };
    final typeTitle = item.typeName.isEmpty ? context.l10n.leaveApplication : item.typeName;
    final duration = item.getLocalizedDuration(context);
    final titleText = duration.isNotEmpty ? '$typeTitle · $duration' : typeTitle;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: colors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.cardAll,
          onTap: () async {
            final changed = await Navigator.of(context).push<bool>(
              createSlideUpRoute(LeaveDetailScreen(item: item)),
            );
            if (changed == true && mounted) _load();
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.card),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        titleText,
                        style: AppText.sectionTitle.copyWith(
                          color: colors.text,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (item.canDelete)
                      InkWell(
                        onTap: () => _delete(item),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Text(
                            context.l10n.revoke,
                            style: AppText.caption
                                .copyWith(color: colors.textMuted),
                          ),
                        ),
                      )
                    else
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 13,
                        color: colors.textMuted,
                      ),
                  ],
                ),
                if (item.timeRange.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    item.timeRange,
                    style: AppText.caption.copyWith(color: colors.textMuted),
                  ),
                ],
                if (item.reason.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.reason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(color: colors.textMuted),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.statusBg(statusColor),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    item.getLocalizedStatus(context),
                    style: AppText.caption.copyWith(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
