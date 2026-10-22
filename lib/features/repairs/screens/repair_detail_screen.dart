import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_extension.dart';
import '../models/repair_models.dart';
import '../services/repair_service.dart';
import '../utils/repair_log_parse.dart';
import '../widgets/authenticated_bxpt_image.dart';

class RepairDetailScreen extends ConsumerStatefulWidget {
  final RepairOrder order;
  const RepairDetailScreen({super.key, required this.order});
  @override
  ConsumerState<RepairDetailScreen> createState() => _RepairDetailScreenState();
}

class _RepairDetailScreenState extends ConsumerState<RepairDetailScreen> {
  RepairOrder? _detail;
  bool _loading = true;
  bool _cancelling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data =
          await ref.read(repairServiceProvider).fetchOrderDetail(widget.order);
      if (mounted) setState(() => _detail = data);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is RepairException
            ? e.message
            : context.l10n.loadFailedCheckNetwork);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onCancel(RepairOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = context.colors;
        return AlertDialog(
          title: Text(context.l10n.repairsCancelConfirmTitle),
          content: Text(context.l10n.repairsCancelConfirmMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.danger,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.confirm),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await ref.read(repairServiceProvider).cancelOrder(order);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.l10n.repairsCancelSuccess),
        behavior: SnackBarBehavior.floating,
      ));
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is RepairException
              ? e.message
              : context.l10n.loadFailedCheckNetwork),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    final y = d.year;
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final h = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$y-$m-$day $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final order = _detail ?? widget.order;
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.repairsOrderDetail),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: context.l10n.refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading && _detail == null
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page, AppSpacing.md, AppSpacing.page, 32),
                children: [
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: colors.statusBg(colors.danger),
                        borderRadius: AppRadius.controlAll,
                      ),
                      child: Text(
                        _error!,
                        style:
                            AppText.bodyDense.copyWith(color: colors.danger),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // 1. 基本信息卡片
                  _buildHeaderCard(order, colors),
                  const SizedBox(height: 14),

                  // 2. 问题描述与处理情况
                  _buildContentCard(order, colors),
                  const SizedBox(height: 14),

                  // 3. 附件图片（如有）
                  if (order.attachments.isNotEmpty) ...[
                    _buildAttachmentsCard(order, colors),
                    const SizedBox(height: 14),
                  ],

                  // 4. 流转历史记录
                  _buildTimelineCard(order, colors),
                  const SizedBox(height: AppSpacing.xl),

                  // 5. 取消报修操作按钮（若当前节点支持）
                  if (order.canCancel) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed:
                              _cancelling ? null : () => _onCancel(order),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.danger,
                            foregroundColor:
                                Theme.of(context).colorScheme.onError,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 12),
                          ),
                          child: _cancelling
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color:
                                        Theme.of(context).colorScheme.onError,
                                  ),
                                )
                              : Text(context.l10n.cancel),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard(RepairOrder order, AppSemanticColors colors) {
    final statusColor = order.isDone
        ? colors.brand
        : (order.isDraft ? colors.warning : colors.info);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.card),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  order.title.isEmpty
                      ? context.l10n.repairsUnnamedOrder
                      : order.title,
                  style: AppText.sectionTitle.copyWith(color: colors.text),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.statusBg(statusColor),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  order.status,
                  style: AppText.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _row(context.l10n.repairsOrderNumber, order.code, colors),
          if (order.catalog.isNotEmpty)
            _row(context.l10n.repairsOrderType, order.catalog, colors),
          if (order.currentNode.isNotEmpty && order.currentNode != order.status)
            _row(context.l10n.repairsCurrentNode, order.currentNode, colors),
          if (order.priority.isNotEmpty)
            _row(context.l10n.repairsPriority, order.priority, colors),
          if (order.applicant.isNotEmpty)
            _row(context.l10n.repairsApplicant, order.applicant, colors),
          if (order.applicantDepartment.isNotEmpty)
            _row(context.l10n.repairsApplicantDepartment,
                order.applicantDepartment, colors),
          if (order.phone.isNotEmpty)
            _row(context.l10n.repairsPhone, order.phone, colors),
          if (order.department.isNotEmpty)
            _row(context.l10n.repairsDepartment, order.department, colors),
          if (order.handler.isNotEmpty)
            _row(context.l10n.repairsHandler, order.handler, colors),
          _row(context.l10n.repairsCreatedAt, _formatDate(order.createdAt),
              colors),
          if (order.closedAt != null)
            _row(context.l10n.repairsCompletedAt, _formatDate(order.closedAt),
                colors),
        ],
      ),
    );
  }

  Widget _buildContentCard(RepairOrder order, AppSemanticColors colors) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.card),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.repairsDescription,
            style: AppText.sectionTitle.copyWith(color: colors.text),
          ),
          const SizedBox(height: AppSpacing.sm),
          SelectableText(
            order.description.isEmpty
                ? context.l10n.repairsNoDescription
                : order.description,
            style: AppText.bodyDense.copyWith(
                color: colors.text, height: 1.6),
          ),
          if (order.handleResult.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              context.l10n.repairsHandleResult,
              style: AppText.sectionTitle.copyWith(color: colors.text),
            ),
            const SizedBox(height: AppSpacing.sm),
            SelectableText(
              order.handleResult,
              style:
                  AppText.bodyDense.copyWith(color: colors.text, height: 1.6),
            ),
          ],
          if (order.supplement.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              context.l10n.repairsSupplement,
              style: AppText.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              order.supplement,
              style:
                  AppText.bodyDense.copyWith(color: colors.text, height: 1.5),
            ),
          ],
          if (order.userResponse.isNotEmpty || order.score != null) ...[
            const SizedBox(height: 14),
            Row(children: [
              Text(
                context.l10n.repairsUserFeedback,
                style: AppText.bodyDense.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
              if (order.score != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.star_rounded, color: colors.warning, size: 18),
                Text(' ${order.score!.toStringAsFixed(1)}',
                    style: AppText.bodyDense.copyWith(
                        color: colors.text, fontWeight: FontWeight.w700)),
              ],
            ]),
            if (order.userResponse.isNotEmpty) ...[
              const SizedBox(height: 4),
              SelectableText(
                order.userResponse,
                style: AppText.bodyDense.copyWith(color: colors.text),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildAttachmentsCard(RepairOrder order, AppSemanticColors colors) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.card),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.repairsAttachments,
            style: AppText.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          ...order.attachments.map((file) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => _previewImage(file),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Row(
                      children: [
                        if (file.thumbnailUrl != null)
                          Container(
                            width: 36,
                            height: 36,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: colors.border),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: AuthenticatedBxptImage(
                              url: file.thumbnailUrl!,
                              fit: BoxFit.cover,
                              errorWidget: Icon(
                                Icons.image_outlined,
                                size: 18,
                                color: colors.brand,
                              ),
                            ),
                          )
                        else ...[
                          Icon(Icons.image_outlined,
                              size: 18, color: colors.brand),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        Expanded(
                          child: Text(
                            file.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption.copyWith(color: colors.text),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildLogDescription(
      RepairActivityLog log, bool isFirst, AppSemanticColors colors) {
    final baseStyle = AppText.caption.copyWith(
      fontWeight: isFirst ? FontWeight.w600 : FontWeight.w400,
      color: colors.text,
    );
    final segments = parseRepairLogDescription(log.description);
    if (segments.isEmpty) {
      return Text(log.description, style: baseStyle);
    }
    // 流转记录只做去标记的纯文本展示，附件查看走上方的附件照片卡片。
    return Text(
      segments.map((s) => s.text).join(),
      style: baseStyle,
    );
  }

  void _previewImage(RepairAttachment attachment) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AuthenticatedBxptImage(
                  url: attachment.downloadUrl,
                  fit: BoxFit.contain,
                  loadingWidget: const Center(
                      child:
                          CircularProgressIndicator(color: Colors.white)),
                  errorWidget: const Center(
                    child: Icon(Icons.broken_image_rounded,
                        size: 48, color: Colors.white70),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard(RepairOrder order, AppSemanticColors colors) {
    final logs = order.logs;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.card),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline_rounded, size: 20, color: colors.textMuted),
              const SizedBox(width: 6),
              Text(
                context.l10n.repairsActivityTimeline,
                style: AppText.sectionTitle.copyWith(color: colors.text),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (logs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                context.l10n.repairsNoActivity,
                style: AppText.caption.copyWith(color: colors.textMuted),
              ),
            )
          else
            ...List.generate(logs.length, (index) {
              final log = logs[index];
              final isLast = index == logs.length - 1;
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: index == 0 ? colors.brand : colors.border,
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: colors.border,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLogDescription(log, index == 0, colors),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                if (log.userName.isNotEmpty) ...[
                                  Text(
                                    log.userName,
                                    style: AppText.caption
                                        .copyWith(color: colors.textMuted),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                ],
                                if (log.time != null)
                                  Text(
                                    _formatDate(log.time),
                                    style: AppText.caption
                                        .copyWith(color: colors.textMuted),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _row(String label, String value, AppSemanticColors colors) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 82,
              child: Text(
                label,
                style: AppText.caption.copyWith(color: colors.textMuted),
              ),
            ),
            Expanded(
              child: SelectableText(
                value.isEmpty ? '—' : value,
                style: AppText.caption.copyWith(color: colors.text),
              ),
            ),
          ],
        ),
      );
}
