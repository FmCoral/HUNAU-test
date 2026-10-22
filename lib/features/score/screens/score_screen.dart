import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/score_provider.dart';
import '../models/score_model.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/theme/app_tokens.dart';

class ScoreScreen extends ConsumerWidget {
  const ScoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scoreProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.scoreQuery),
        actions: [
          IconButton(
            tooltip: context.l10n.refresh,
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: () => ref.read(scoreProvider.notifier).refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. 学期选择栏 (扁平化设计)
          _buildSemesterPicker(context, ref, state),

          const Divider(height: 1),

          // 2. 成绩列表
          Expanded(
            child: _buildScoreList(context, ref, state),
          ),
        ],
      ),
    );
  }

  Widget _buildSemesterPicker(
      BuildContext context, WidgetRef ref, ScoreState state) {
    if (state.semesters.isEmpty && !state.isLoading) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Row(
        children: [
          Text(
            context.l10n.currentSemester,
            style: AppText.bodyDense.copyWith(
              fontWeight: FontWeight.w600,
              color: context.colors.text,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          if (state.isLoading && state.semesters.isEmpty)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: DropdownButton<SemesterModel>(
                  value: state.selectedSemester,
                  underline: const SizedBox(),
                  icon: Icon(Icons.arrow_drop_down_rounded,
                      color: context.colors.textMuted),
                  style: AppText.bodyDense.copyWith(
                    color: context.colors.brandText,
                    fontWeight: FontWeight.w600,
                  ),
                  isExpanded: true,
                  items: state.semesters.map((s) {
                    return DropdownMenuItem(
                      value: s,
                      child: Text(s.name, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(scoreProvider.notifier).changeSemester(val);
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScoreList(
      BuildContext context, WidgetRef ref, ScoreState state) {
    if (state.isLoading && state.scores.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null && state.scores.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: context.colors.danger),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
              child: Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: AppText.bodyDense
                    .copyWith(color: context.colors.textMuted),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            OutlinedButton(
              onPressed: () => ref.read(scoreProvider.notifier).refresh(),
              child: Text(context.l10n.retry),
            ),
          ],
        ),
      );
    }

    if (state.scores.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in_outlined,
                size: 64, color: context.colors.textMuted),
            const SizedBox(height: AppSpacing.lg),
            Text(
              context.l10n.noScoreData,
              style:
                  AppText.bodyDense.copyWith(color: context.colors.textMuted),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(scoreProvider.notifier).refresh(),
      child: Stack(
        children: [
          ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.page, AppSpacing.lg, AppSpacing.page, 40),
            itemCount: state.scores.length,
            itemBuilder: (context, index) {
              final score = state.scores[index];
              return _buildScoreCard(context, score);
            },
          ),
          if (state.isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(BuildContext context, ScoreModel score) {
    final courseNatureParts = [
      if (score.courseNature != null && score.courseNature!.trim().isNotEmpty)
        score.courseNature!.trim(),
      if (score.courseCode != null && score.courseCode!.trim().isNotEmpty)
        score.courseCode!.trim(),
    ];
    final bool hasCourseNature = courseNatureParts.isNotEmpty;
    final String secondaryText = hasCourseNature
        ? courseNatureParts.join(' · ')
        : (score.credit != null && score.credit!.trim().isNotEmpty
            ? context.l10n.scoreCredit(score.credit!.trim())
            : '');
    final bool showCreditInWrap = hasCourseNature;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: context.colors.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  score.courseName,
                  style: AppText.sectionTitle.copyWith(
                    color: context.colors.text,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                score.score,
                style: AppText.keyNumber.copyWith(
                  color: context.colors.text,
                ),
              ),
            ],
          ),
          if (secondaryText.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              secondaryText,
              style:
                  AppText.caption.copyWith(color: context.colors.textMuted),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              if (showCreditInWrap &&
                  score.credit != null &&
                  score.credit!.trim().isNotEmpty)
                Text(
                  context.l10n.scoreCredit(score.credit!.trim()),
                  style: AppText.caption
                      .copyWith(color: context.colors.textMuted),
                ),
              Text(
                score.examType ?? context.l10n.normalExam,
                style:
                    AppText.caption.copyWith(color: context.colors.textMuted),
              ),
              if (score.dailyScore != null &&
                  score.dailyScore!.trim().isNotEmpty)
                Text(
                  '平时: ${score.dailyScore!.trim()}',
                  style: AppText.caption
                      .copyWith(color: context.colors.textMuted),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
