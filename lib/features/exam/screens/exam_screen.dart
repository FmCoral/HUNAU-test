import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/route_utils.dart';
import '../../../core/theme/app_tokens.dart';
import '../../workspace/screens/webview_detail_screen.dart';
import '../models/exam_schedule_model.dart';
import '../providers/exam_provider.dart';

class ExamScreen extends ConsumerStatefulWidget {
  const ExamScreen({super.key});

  @override
  ConsumerState<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends ConsumerState<ExamScreen> {
  Object? _dismissedError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(examProvider.notifier).pruneExpiredManualExams();
    });
  }

  @override
  Widget build(BuildContext context) {
    final examsAsync = ref.watch(currentSemesterExamsProvider);

    final error = examsAsync.hasError ? examsAsync.error : null;
    final exams = examsAsync.valueOrNull ?? [];
    final bool showErrorCard = error != null && _dismissedError != error;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.examSchedule),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: context.l10n.addExam,
            onPressed: () => _showAddExamSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            tooltip: context.l10n.refreshTimetable,
            onPressed: () {
              setState(() {
                _dismissedError = null;
              });
              ref.read(examProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _dismissedError = null;
          });
          await ref.read(examProvider.notifier).refresh();
        },
        child: (examsAsync.isLoading && !examsAsync.hasValue)
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page, vertical: AppSpacing.md),
                children: [
                  if (showErrorCard) ...[
                    _buildErrorCard(context, error),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (exams.isEmpty)
                    _buildEmptyState(context)
                  else
                    for (final exam in exams)
                      _buildExamCard(context, exam),
                ],
              ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, Object error) {
    var errorMsg = error.toString().replaceFirst('Exception: ', '');
    if (errorMsg.contains('超星') &&
        (errorMsg.contains('验证') ||
            errorMsg.contains('反爬') ||
            errorMsg.contains('202'))) {
      errorMsg = '触发了超星安全验证';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.statusBg(context.colors.danger),
        borderRadius: AppRadius.innerAll,
        border: Border.all(
          color: context.colors.danger.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: context.colors.danger,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              errorMsg,
              style: AppText.caption.copyWith(color: context.colors.danger),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            color: context.colors.textMuted,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              minimumSize: Size.zero,
              padding: const EdgeInsets.all(4),
            ),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () {
              setState(() {
                _dismissedError = error;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          vertical: 48, horizontal: AppSpacing.xxl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_turned_in_outlined,
              size: 64,
              color: context.colors.textMuted,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              context.l10n.noCurrentSemesterExams,
              style:
                  AppText.body.copyWith(color: context.colors.textMuted),
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: () => _showAddExamSheet(context),
              icon: const Icon(Icons.add_rounded),
              label: Text(context.l10n.addExam),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamCard(BuildContext context, ExamScheduleModel exam) {
    final now = DateTime.now();
    final isPast = exam.time.isBefore(now);

    final primaryTitle =
        exam.courseName.isNotEmpty ? exam.courseName : exam.title;
    final secondaryTitle =
        (exam.courseName.isNotEmpty &&
                exam.title.trim().isNotEmpty &&
                exam.title.trim() != exam.courseName.trim())
            ? exam.title.trim()
            : '';
    final statusChip = _buildStatusChip(context, exam, isPast);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: context.colors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.cardAll,
        child: InkWell(
          borderRadius: AppRadius.cardAll,
          onTap: exam.detailUrl.isNotEmpty
              ? () {
                  Navigator.push(
                    context,
                    createSlideUpRoute(
                      WebViewDetailScreen(
                        title: exam.title,
                        url: exam.detailUrl,
                        userAgent: AppConstants.campusCardUA,
                      ),
                    ),
                  );
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.card),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部：课程/考试名称 + 删除按钮 (若为手动)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        primaryTitle,
                        style: AppText.sectionTitle.copyWith(
                          color: context.colors.text,
                        ),
                      ),
                    ),
                    if (statusChip != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      statusChip,
                    ],
                    if (exam.isManual) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 20),
                        color: context.colors.danger,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.all(4),
                        ),
                        tooltip: context.l10n.delete,
                        onPressed: () => _confirmDeleteExam(context, exam),
                      ),
                    ],
                  ],
                ),
                if (secondaryTitle.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    secondaryTitle,
                    style: AppText.caption.copyWith(
                      color: context.colors.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                // 时间行
                Builder(
                  builder: (context) {
                    final String timeDisplay;
                    if (exam.endTime != null) {
                      if (exam.time.year == exam.endTime!.year &&
                          exam.time.month == exam.endTime!.month &&
                          exam.time.day == exam.endTime!.day) {
                        timeDisplay =
                            '${DateFormat('yyyy-MM-dd HH:mm').format(exam.time)} ~ ${DateFormat('HH:mm').format(exam.endTime!)}';
                      } else {
                        timeDisplay =
                            '${DateFormat('yyyy-MM-dd HH:mm').format(exam.time)} ~ ${DateFormat('yyyy-MM-dd HH:mm').format(exam.endTime!)}';
                      }
                    } else {
                      timeDisplay = DateFormat('yyyy-MM-dd HH:mm').format(exam.time);
                    }

                    return Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 16,
                          color: context.colors.textMuted,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            timeDisplay,
                            style: AppText.bodyDense.copyWith(
                              color: context.colors.text,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                // 地点行 (若有)
                if (exam.location != null && exam.location!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: context.colors.textMuted,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          exam.location!,
                          style: AppText.caption.copyWith(
                            color: context.colors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                // 备注行 (若有)
                if (exam.remarks != null && exam.remarks!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.notes_rounded,
                          size: 16,
                          color: context.colors.textMuted,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          exam.remarks!,
                          style: AppText.caption.copyWith(
                            color: context.colors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                // 学习通考试点击跳转提示 (若有跳转链接)
                if (exam.detailUrl.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        context.l10n.openInChaoXing,
                        style: AppText.caption.copyWith(
                          color: context.colors.info,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: context.colors.info,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildStatusChip(BuildContext context, ExamScheduleModel exam, bool isPast) {
    String label;
    Color color;

    if (exam.status.isNotEmpty) {
      if (exam.status == '待考' || exam.status == context.l10n.examStatusPending) {
        return null;
      }
      label = exam.status;
      if (exam.status == '已完成') {
        color = context.colors.brand;
      } else if (exam.status == '未交') {
        color = context.colors.warning;
      } else if (exam.status == '进行中') {
        color = context.colors.info;
      } else {
        color = isPast ? context.colors.textMuted : context.colors.brand;
      }
    } else {
      if (!isPast) {
        return null;
      }
      label = context.l10n.examStatusEnded;
      color = context.colors.textMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: context.colors.statusBg(color),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppText.caption.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  void _confirmDeleteExam(BuildContext context, ExamScheduleModel exam) {
    final messenger = ScaffoldMessenger.of(context);
    final deletedMessage = context.l10n.examDeleted;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(context.l10n.delete),
        content: Text(context.l10n.deleteExamConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await ref.read(examProvider.notifier).deleteExam(exam.id);
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(content: Text(deletedMessage)),
              );
            },
            child: Text(context.l10n.delete,
                style: TextStyle(color: context.colors.danger)),
          ),
        ],
      ),
    );
  }

  void _showAddExamSheet(BuildContext context) {
    String title = '';
    String course = '';
    DateTime? selectedTime;
    String location = '';
    String remarks = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final timeStr = selectedTime != null
              ? DateFormat('yyyy-MM-dd HH:mm').format(selectedTime!)
              : null;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.l10n.addExam,
                        style: AppText.sectionTitle.copyWith(
                          fontSize: 18,
                          color: context.colors.text,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // 所属课程（必填）
                  TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: context.l10n.examCourse,
                      hintText: context.l10n.inputExamCourseHint,
                      prefixIcon: const Icon(Icons.school_outlined),
                    ),
                    onChanged: (v) => course = v,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // 考试名称（选填）
                  TextField(
                    decoration: InputDecoration(
                      labelText: context.l10n.examTitle,
                      hintText: context.l10n.inputExamTitleHint,
                      prefixIcon: const Icon(Icons.quiz_outlined),
                    ),
                    onChanged: (v) => title = v,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // 考试时间（必填）
                  InkWell(
                    borderRadius: AppRadius.controlAll,
                    onTap: () async {
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedTime != null && !selectedTime!.isBefore(today)
                            ? selectedTime!
                            : today,
                        firstDate: today,
                        lastDate: now.add(const Duration(days: 365)),
                      );
                      if (date != null && context.mounted) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: selectedTime != null
                              ? TimeOfDay(
                                  hour: selectedTime!.hour,
                                  minute: selectedTime!.minute,
                                )
                              : TimeOfDay.now(),
                        );
                        if (time != null) {
                          setSheetState(() {
                            selectedTime = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                          });
                        }
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: context.l10n.examTime,
                        prefixIcon: const Icon(Icons.access_time_rounded),
                        suffixIcon: selectedTime != null
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 20),
                                onPressed: () {
                                  setSheetState(() => selectedTime = null);
                                },
                              )
                            : null,
                      ),
                      child: Text(
                        timeStr ?? context.l10n.selectExamTimeHint,
                        style: AppText.bodyDense.copyWith(
                          color: timeStr != null
                              ? context.colors.text
                              : context.colors.textMuted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // 考场地点（可选）
                  TextField(
                    decoration: InputDecoration(
                      labelText: context.l10n.examLocation,
                      hintText: context.l10n.inputExamLocationHint,
                      prefixIcon: const Icon(Icons.location_on_outlined),
                    ),
                    onChanged: (v) => location = v,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // 备注（可选）
                  TextField(
                    decoration: InputDecoration(
                      labelText: context.l10n.examRemarks,
                      hintText: context.l10n.inputExamRemarksHint,
                      prefixIcon: const Icon(Icons.notes_rounded),
                    ),
                    onChanged: (v) => remarks = v,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  // 保存按钮
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final effCourse = course.trim();
                        final effTitle = title.trim();
                        if (effCourse.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(context.l10n.inputExamCourseHint)),
                          );
                          return;
                        }
                        if (selectedTime == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(context.l10n.selectExamTimeHint)),
                          );
                          return;
                        }

                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(context);
                        final addedMessage = context.l10n.examAdded;

                        await ref.read(examProvider.notifier).addManualExam(
                              title: effTitle,
                              courseName: effCourse,
                              time: selectedTime!,
                              location: location,
                              remarks: remarks,
                            );

                        if (!mounted) return;
                        navigator.pop();
                        messenger.showSnackBar(
                          SnackBar(content: Text(addedMessage)),
                        );
                      },
                      child: Text(context.l10n.save),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
