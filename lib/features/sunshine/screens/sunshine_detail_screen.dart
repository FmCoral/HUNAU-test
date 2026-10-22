import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_extension.dart';
import '../models/sunshine_models.dart';
import '../services/sunshine_service.dart';

class SunshineDetailScreen extends ConsumerStatefulWidget {
  final String id;
  final SunshineLetter? initialLetter;

  const SunshineDetailScreen({
    super.key,
    required this.id,
    this.initialLetter,
  });

  @override
  ConsumerState<SunshineDetailScreen> createState() =>
      _SunshineDetailScreenState();
}

class _SunshineDetailScreenState extends ConsumerState<SunshineDetailScreen> {
  SunshineTicketDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _getErrorMessage(dynamic e) {
    if (e is SunshineException) {
      if (e.message.contains('暂时不可用')) return context.l10n.sunshineServiceUnavailable;
      if (e.message.contains('未能读取')) return context.l10n.sunshineDataReadFailed;
      if (e.message.contains('格式异常')) return context.l10n.sunshineDataFormatError;
      if (e.message.contains('未找到诉求工单详情')) return context.l10n.sunshineTicketNotFound;
      if (e.message.contains('响应超时')) return context.l10n.sunshineFormTimeout;
      if (e.message.contains('统一认证已过期')) return context.l10n.ssoExpiredRelogin;
      if (e.message.contains('登录已失效')) return context.l10n.sunshineSessionExpired;
      if (e.message.contains('暂无可用受理单位')) return context.l10n.noDepartmentsAvailable;
      return e.message;
    }
    return context.l10n.fetchSunshineDetailFailed;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = ref.read(sunshineServiceProvider);
      final detail = await service.fetchTicketDetail(widget.id);
      if (!mounted) return;
      setState(() {
        _detail = detail;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = _getErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final title = _detail?.title ?? widget.initialLetter?.title ?? context.l10n.appealDetails;
    final status = _detail?.status ?? widget.initialLetter?.status ?? '';
    final statusLabel = _detail?.getLocalizedStatus(context) ??
        widget.initialLetter?.getLocalizedStatus(context) ??
        context.l10n.statusUnknown;
    final isCompleted = status == '2';

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.appealDetails),
        actions: [
          IconButton(
            tooltip: context.l10n.refresh,
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(colors, title, statusLabel, isCompleted),
    );
  }

  Widget _buildBody(
    AppSemanticColors colors,
    String title,
    String statusLabel,
    bool isCompleted,
  ) {
    if (_loading && _detail == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null && _detail == null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(AppSpacing.xxl),
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppRadius.cardAll,
            border: Border.all(color: colors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: colors.warning,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppText.bodyDense.copyWith(color: colors.text),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(context.l10n.reload),
              ),
            ],
          ),
        ),
      );
    }

    final detail = _detail!;
    final hasRemark = detail.remark.trim().isNotEmpty;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.page, AppSpacing.sm, AppSpacing.page, 40),
        children: [
          if (_loading) const LinearProgressIndicator(),

          // 1. 标题与状态（文字直接呈现，去除卡片）
          _buildHeaderSection(colors, title, statusLabel, isCompleted, detail),

          const SizedBox(height: AppSpacing.xxl),

          // 2. 流转信息（无卡片边框、无分割线）
          _buildMetaSection(colors, detail),

          const SizedBox(height: AppSpacing.xxl),

          // 3. 诉求内容（无卡片边框）
          _buildContentSection(colors, detail),

          // 4. 处理结果（如果没有处理结果就不显示）
          if (hasRemark) ...[
            const SizedBox(height: AppSpacing.xxl),
            _buildRemarkSection(colors, detail),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderSection(
    AppSemanticColors colors,
    String title,
    String statusLabel,
    bool isCompleted,
    SunshineTicketDetail detail,
  ) {
    final statusColor = isCompleted ? colors.brand : colors.warning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colors.statusBg(statusColor),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                statusLabel,
                style: AppText.caption.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
            if (detail.type.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  detail.type,
                  style:
                      AppText.caption.copyWith(color: colors.textMuted),
                ),
              ),
            ],
            const Spacer(),
            // 去掉《工单》两个字，仅保留 #ID
            if (detail.id.isNotEmpty)
              Text(
                '#${detail.id}',
                style: AppText.caption.copyWith(color: colors.textMuted),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SelectableText(
          title,
          style: AppText.pageTitle.copyWith(color: colors.text),
        ),
      ],
    );
  }

  Widget _buildMetaSection(
      AppSemanticColors colors, SunshineTicketDetail detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.transferInfo,
          style: AppText.sectionTitle.copyWith(color: colors.text),
        ),
        const SizedBox(height: AppSpacing.md),
        // 提交人只保留到姓，保持正常黑灰色，不带分割线
        _buildMetaRow(
          colors,
          icon: Icons.person_outline_rounded,
          label: context.l10n.submitter,
          value: detail.submitter.isNotEmpty ? detail.submitter : context.l10n.anonymous,
        ),
        if (detail.expectedDepartment.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildMetaRow(
            colors,
            icon: Icons.account_balance_outlined,
            label: context.l10n.expectedDepartment,
            value: detail.expectedDepartment,
          ),
        ],
        if (detail.handlingDepartment.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildMetaRow(
            colors,
            icon: Icons.business_rounded,
            label: context.l10n.handlingDepartment,
            value: detail.handlingDepartment,
          ),
        ],
        if (detail.finishTime.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildMetaRow(
            colors,
            icon: Icons.event_available_rounded,
            label: context.l10n.expectedResolveTime,
            value: detail.finishTime,
          ),
        ],
        if (detail.jieTime.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildMetaRow(
            colors,
            icon: Icons.access_time_rounded,
            label: context.l10n.acceptedTime,
            value: detail.jieTime,
          ),
        ],
        if (detail.wanTime.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildMetaRow(
            colors,
            icon: Icons.check_circle_outline_rounded,
            label: context.l10n.finishedTime,
            value: detail.wanTime,
          ),
        ],
      ],
    );
  }

  Widget _buildMetaRow(
    AppSemanticColors colors, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: colors.textMuted,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: AppText.caption.copyWith(color: colors.textMuted),
        ),
        const Spacer(),
        Text(
          value,
          style: AppText.caption.copyWith(color: colors.text),
        ),
      ],
    );
  }

  Widget _buildContentSection(
      AppSemanticColors colors, SunshineTicketDetail detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.article_outlined,
              size: 18,
              color: colors.brand,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              context.l10n.appealContent,
              style: AppText.sectionTitle.copyWith(color: colors.text),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SelectableText(
          detail.content.isNotEmpty ? detail.content : context.l10n.noDescriptionAvailable,
          style: AppText.bodyDense.copyWith(
              color: colors.text, height: 1.6),
        ),
      ],
    );
  }

  Widget _buildRemarkSection(
      AppSemanticColors colors, SunshineTicketDetail detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.task_alt_rounded,
              size: 18,
              color: colors.brand,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              context.l10n.processingResult,
              style: AppText.sectionTitle.copyWith(color: colors.text),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SelectableText(
          detail.remark,
          style: AppText.bodyDense.copyWith(
              color: colors.text, height: 1.6),
        ),
      ],
    );
  }
}
