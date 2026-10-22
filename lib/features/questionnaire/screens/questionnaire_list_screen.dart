import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/route_utils.dart';
import '../models/questionnaire_models.dart';
import '../services/questionnaire_service.dart';
import 'questionnaire_detail_screen.dart';

enum QuestionnaireFilter {
  all,
  pending,
  submitted;

  String getLocalizedLabel(BuildContext context) => switch (this) {
        QuestionnaireFilter.all => context.l10n.all,
        QuestionnaireFilter.pending => context.l10n.statusPendingFill,
        QuestionnaireFilter.submitted => context.l10n.statusSubmitted,
      };

  bool matches(QuestionnaireItem item) => switch (this) {
        QuestionnaireFilter.all => true,
        QuestionnaireFilter.pending => !item.isSubmitted && !item.isExpired,
        QuestionnaireFilter.submitted => item.isSubmitted,
      };
}

/// 学工问卷 - 功能页
class QuestionnaireListScreen extends ConsumerStatefulWidget {
  const QuestionnaireListScreen({super.key});

  @override
  ConsumerState<QuestionnaireListScreen> createState() =>
      _QuestionnaireListScreenState();
}

class _QuestionnaireListScreenState
    extends ConsumerState<QuestionnaireListScreen> {
  List<QuestionnaireItem> _items = [];
  bool _loading = true;
  String? _error;
  QuestionnaireFilter _filter = QuestionnaireFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _getErrorMessage(dynamic e) {
    if (e is QuestionnaireException) {
      if (e.message.contains('统一认证已过期')) return context.l10n.ssoExpiredRelogin;
      if (e.message.contains('登录已失效')) return context.l10n.studentSystemSessionExpired;
      if (e.message.contains('未能读取')) return context.l10n.readQuestionnaireDataFailed;
      if (e.message.contains('格式异常')) return context.l10n.questionnaireListFormatError;
      if (e.message.contains('缺少任务标识')) return context.l10n.questionnaireMissingTaskId;
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
      final service = ref.read(questionnaireServiceProvider);
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final filtered = _items.where((item) => _filter.matches(item)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.studentWorkQuestionnaire),
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
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: QuestionnaireFilter.values
                        .map((filter) => _buildFilterChip(filter, colors))
                        .toList(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (filtered.isEmpty && _error == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: Text(
                          context.l10n.noQuestionnairesFound,
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

  Widget _buildFilterChip(QuestionnaireFilter filter, AppSemanticColors colors) {
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

  Widget _buildItemCard(QuestionnaireItem item, AppSemanticColors colors) {
    final statusColor = item.isSubmitted
        ? colors.brand
        : (item.isExpired ? colors.textMuted : colors.info);
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
              createSlideUpRoute(QuestionnaireDetailScreen(item: item)),
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
                        item.title.isEmpty ? context.l10n.unnamedQuestionnaire : item.title,
                        style: AppText.sectionTitle.copyWith(
                          color: colors.text,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
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
