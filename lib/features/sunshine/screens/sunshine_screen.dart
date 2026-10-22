import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/route_utils.dart';
import '../models/sunshine_models.dart';
import '../services/sunshine_service.dart';
import 'sunshine_detail_screen.dart';
import 'sunshine_form_screen.dart';

enum SunshineFilter {
  all,
  inProgress,
  resolved;

  String getLocalizedLabel(BuildContext context) => switch (this) {
        SunshineFilter.all => context.l10n.all,
        SunshineFilter.inProgress => context.l10n.statusInProgress,
        SunshineFilter.resolved => context.l10n.statusResolved,
      };

  bool matches(SunshineLetter letter) => switch (this) {
        SunshineFilter.all => true,
        SunshineFilter.inProgress => letter.status == '0' || letter.status == '1',
        SunshineFilter.resolved => letter.status == '2',
      };
}

class SunshineScreen extends ConsumerStatefulWidget {
  const SunshineScreen({super.key});
  @override
  ConsumerState<SunshineScreen> createState() => _SunshineScreenState();
}

class _SunshineScreenState extends ConsumerState<SunshineScreen> {
  List<SunshineLetter> _letters = [];
  bool _loading = true;
  String? _error;
  SunshineFilter _filter = SunshineFilter.all;

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
    return context.l10n.loadFailedCheckNetwork;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(sunshineServiceProvider);
      final letters = await service.fetchLetters();
      if (!mounted) return;
      setState(() {
        _letters = letters;
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
    final letters = _letters
        .where((letter) => _filter.matches(letter))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.sunshineService),
        actions: [
          IconButton(
            tooltip: context.l10n.refresh,
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading && _letters.isEmpty
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

                  // 1. 填写诉求入口卡片
                  _buildQuickActionCard(colors),

                  const SizedBox(height: AppSpacing.xxl),

                  // 2. 近期公开诉求模块
                  Text(
                    context.l10n.recentPublicAppeals,
                    style: AppText.sectionTitle.copyWith(color: colors.text),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: SunshineFilter.values
                        .map((filter) => _buildFilterChip(filter, colors))
                        .toList(),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  if (letters.isEmpty && _error == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: Text(
                          context.l10n.noPublicAppeals,
                          style: AppText.bodyDense
                              .copyWith(color: colors.textMuted),
                        ),
                      ),
                    ),

                  // 3. 诉求列表卡片
                  ...letters.map((letter) => _buildLetterCard(letter, colors)),
                ],
              ),
            ),
    );
  }

  Widget _buildQuickActionCard(AppSemanticColors colors) {
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
          onTap: () async {
            final submitted = await Navigator.of(context).push<bool>(
              createSlideUpRoute(const SunshineFormScreen()),
            );
            if (submitted == true && mounted) _load();
          },
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
                  context.l10n.writeAppeal,
                  style: AppText.sectionTitle.copyWith(color: colors.text),
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

  Widget _buildFilterChip(SunshineFilter filter, AppSemanticColors colors) {
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

  Widget _buildLetterCard(SunshineLetter letter, AppSemanticColors colors) {
    final statusColor = letter.status == '2' ? colors.brand : colors.textMuted;
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
          onTap: () {
            Navigator.of(context).push(
              createSlideUpRoute(
                SunshineDetailScreen(
                  id: letter.id,
                  initialLetter: letter,
                ),
              ),
            );
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
                        letter.title,
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
                const SizedBox(height: AppSpacing.sm),
                Text(
                  letter.department,
                  style: AppText.caption.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: 4,
                  children: [
                    Text(
                      letter.type,
                      style:
                          AppText.caption.copyWith(color: colors.textMuted),
                    ),
                    Text(
                      letter.date,
                      style:
                          AppText.caption.copyWith(color: colors.textMuted),
                    ),
                    Text(
                      letter.getLocalizedStatus(context),
                      style: AppText.caption.copyWith(
                        color: statusColor,
                        fontWeight: letter.status == '2'
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
