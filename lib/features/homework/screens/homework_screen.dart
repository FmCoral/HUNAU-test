import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/homework_provider.dart';
import '../models/homework_model.dart';
import '../../../core/state/auth_state.dart';
import '../../../core/widgets/login_required_placeholder.dart';
import '../../../core/theme/app_tokens.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import '../../workspace/screens/webview_detail_screen.dart';
import '../../../core/network/cookie_manager.dart';
import '../../../core/utils/route_utils.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/date_format_utils.dart';


class HomeworkScreen extends ConsumerStatefulWidget {
  const HomeworkScreen({super.key});

  @override
  ConsumerState<HomeworkScreen> createState() => _HomeworkScreenState();
}

class _HomeworkScreenState extends ConsumerState<HomeworkScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 0: 存档, 1: 已完成, 2: 未完成. 初始选中 2
    _tabController = TabController(length: 3, vsync: this, initialIndex: 2);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final homeworkState = ref.watch(homeworkProvider);
    final authState = ref.watch(authStateProvider);

    return _buildBody(authState, homeworkState);
  }

  Widget _buildBody(AuthState authState, AsyncValue<List<HomeworkModel>> homeworkState) {
    // 直接返回带有 FAB 的 Scaffold
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddHomeworkSheet(context),
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _buildSubHeader(),
          Expanded(
            child: homeworkState.when(
              data: (list) {
                // 如果处于正在登录中，或者已经登录，显示全部内容（包含之前的缓存）
                final displayList = (authState.status == AuthStatus.authenticated ||
                                     authState.status == AuthStatus.authenticating)
                    ? list
                    : list.where((e) => e.isManual).toList();

                // 如果显示列表为空，且处于未登录状态，显示登录占位
                if (displayList.isEmpty && authState.status == AuthStatus.unauthenticated) {
                   return LoginRequiredPlaceholder(
                    title: context.l10n.homeworkLoginTitle,
                    message: context.l10n.homeworkLoginMessage,
                    icon: Icons.assignment_late_outlined,
                  );
                }

                // 正常显示作业内容
                final archiveList = displayList.where((e) => e.status == HomeworkStatus.archived).toList();
                final completedList = displayList.where((e) => e.status == HomeworkStatus.completed).toList();
                final pendingList = displayList.where((e) => e.status == HomeworkStatus.pending).toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRefreshableList(archiveList, Icons.inventory_2_outlined, context.l10n.homeworkEmptyArchived, authState.username, isPending: false),
                    _buildRefreshableList(completedList, Icons.task_alt, context.l10n.homeworkEmptyCompleted, authState.username, isPending: false),
                    _buildRefreshableList(pendingList, Icons.assignment_outlined, context.l10n.homeworkEmptyPending, authState.username, isPending: true),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: context.colors.danger),
                    const SizedBox(height: AppSpacing.lg),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
                      child: Text(
                        context.l10n.homeworkLoadFailed(err.toString()),
                        textAlign: TextAlign.center,
                        style: AppText.bodyDense.copyWith(color: context.colors.textMuted),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton(
                      onPressed: () => ref.read(homeworkProvider.notifier).refresh(authState.username ?? ''),
                      child: Text(context.l10n.retry),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubHeader() {
    return Container(
      height: 52,
      alignment: Alignment.centerLeft,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(
            width: 3,
            color: context.colors.brand,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
          ),
          insets: const EdgeInsets.symmetric(horizontal: 4),
        ),
        tabs: [
          _buildDynamicTab(index: 0, icon: Icons.inventory_2_outlined, label: context.l10n.homeworkTabArchived),
          _buildDynamicTab(index: 1, icon: Icons.task_alt, label: context.l10n.homeworkTabCompleted),
          _buildDynamicTab(index: 2, icon: Icons.assignment_outlined, label: context.l10n.homeworkTabPending),
        ],
      ),
    );
  }

  Widget _buildDynamicTab({required int index, required IconData icon, required String label}) {
    return AnimatedBuilder(
      animation: _tabController.animation!,
      builder: (context, _) {
        final double value = _tabController.animation?.value ?? _tabController.index.toDouble();
        double progress;
        if (_tabController.indexIsChanging) {
          final int from = _tabController.previousIndex;
          final int to = _tabController.index;
          if (from == to) {
            progress = (index == to) ? 1.0 : 0.0;
          } else {
            final double t = ((value - from) / (to - from)).clamp(0.0, 1.0);
            if (index == to) {
              progress = t;
            } else if (index == from) {
              progress = 1.0 - t;
            } else {
              progress = 0.0;
            }
          }
        } else {
          progress = (1.0 - (value - index).abs()).clamp(0.0, 1.0);
        }

        return Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Opacity(
                    opacity: progress,
                    child: Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.sm),
                      child: Text(
                        label,
                        style: const TextStyle(fontSize: 16),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(IconData icon, String msg) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        Center(
          child: Column(
            children: [
              Icon(icon, size: 64, color: context.colors.textMuted),
              const SizedBox(height: AppSpacing.lg),
              Text(
                msg,
                style: AppText.bodyDense.copyWith(color: context.colors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 包装了下拉刷新的列表
  Widget _buildRefreshableList(List<HomeworkModel> items, IconData emptyIcon, String emptyMsg, String? username, {required bool isPending}) {
    return RefreshIndicator(
      onRefresh: () => ref.read(homeworkProvider.notifier).refresh(username ?? ''),
      child: isPending
          ? _buildPendingList(items, emptyIcon, emptyMsg)
          : _buildSimpleList(items, emptyIcon, emptyMsg),
    );
  }

  /// 待办列表 (按日期聚合并显示)
  Widget _buildPendingList(List<HomeworkModel> items, IconData emptyIcon, String emptyMsg) {
    if (items.isEmpty) return _buildEmptyState(emptyIcon, emptyMsg);

    // 1. 分离有无时间的
    final withTime = items.where((e) => e.endTime != null).toList()
      ..sort((a, b) => a.endTime!.compareTo(b.endTime!));
    final noTime = items.where((e) => e.endTime == null).toList();

    // 2. 按日期对有时间的进行分组
    final locale = Localizations.localeOf(context).toString();
    final Map<String, List<HomeworkModel>> grouped = {};
    for (var item in withTime) {
      final dateKey = formatMMMd(item.endTime!, locale);
      grouped.putIfAbsent(dateKey, () => []).add(item);
    }

    final sortedDateKeys = grouped.keys.toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        for (var dateKey in sortedDateKeys) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.page, AppSpacing.xl, AppSpacing.page, AppSpacing.sm),
            child: Text(
              dateKey,
              style: AppText.bodyDense.copyWith(
                fontWeight: FontWeight.w600,
                color: context.colors.text,
              ),
            ),
          ),
          ...grouped[dateKey]!.map((item) => _buildHomeworkItem(item, showDate: false)),
        ],

        if (noTime.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.page, AppSpacing.xxl, AppSpacing.page, AppSpacing.sm),
            child: Text(
              context.l10n.noDeadlineHomework,
              style: AppText.bodyDense.copyWith(
                fontWeight: FontWeight.w600,
                color: context.colors.textMuted,
              ),
            ),
          ),
          ...noTime.map((item) => _buildHomeworkItem(item, showDate: false)),
        ],
      ],
    );
  }

  /// 已完成/存档列表
  Widget _buildSimpleList(List<HomeworkModel> items, IconData emptyIcon, String emptyMsg) {
    if (items.isEmpty) return _buildEmptyState(emptyIcon, emptyMsg);

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildHomeworkItem(item);
      },
    );
  }

  Widget _buildHomeworkItem(HomeworkModel item, {bool showDate = true}) {
    final bool hasTime = item.endTime != null;
    final locale = Localizations.localeOf(context).toString();
    final String timeDisplay = hasTime
        ? (showDate
            ? formatMMMdHm(item.endTime!, locale)
            : formatHm(item.endTime!, locale))
        : '';

    final bool isCompleted = item.status == HomeworkStatus.completed;

    Widget content = InkWell(
      onTap: () async {
        if (item.isManual) {
          _showHomeworkDetailDialog(item);
        } else if (item.dataUrl.isNotEmpty) {
           // 如果正在登录中，提示并返回，防止未授权打开详情
           final auth = ref.read(authStateProvider);
           if (auth.status == AuthStatus.authenticating) {
             if (context.mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text(context.l10n.homeworkLoggingInWait), duration: const Duration(seconds: 2)),
               );
             }
             return;
           }

           _logger.i('Opening homework detail: ${item.dataUrl}');
           await AppCookieManager().injectAllChaoxingCookies();
           if (context.mounted) {
             Navigator.push(context, createSlideUpRoute(WebViewDetailScreen(title: context.l10n.homeworkDetail, url: item.dataUrl)));
           }
        }
      },
      child: Container(
        color: context.colors.surface,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.page, vertical: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: SizedBox(
                width: 20, height: 20,
                child: Checkbox(
                  value: isCompleted,
                  onChanged: (val) {
                    if (item.isManual) {
                      ref.read(homeworkProvider.notifier).toggleStatus(item.id);
                    }
                  },
                  shape: const CircleBorder(),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AppText.body.copyWith(
                      fontWeight: FontWeight.w500,
                      color: context.colors.text,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (item.courseName.isNotEmpty) ...[
                    Text(
                      item.courseName,
                      style: AppText.caption.copyWith(color: context.colors.textMuted),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  Row(
                    children: [
                      if (hasTime) ...[
                        Icon(Icons.access_time_rounded, size: 12, color: context.colors.textMuted),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          timeDisplay,
                          style: AppText.caption.copyWith(fontSize: 12, color: context.colors.textMuted),
                        ),
                        const SizedBox(width: AppSpacing.md),
                      ],
                      if (!item.isManual && item.dataUrl.contains('chaoxing.com')) ...[
                        Icon(Icons.open_in_new_rounded, size: 12, color: context.colors.textMuted),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          context.l10n.completeInChaoXing,
                          style: AppText.caption.copyWith(fontSize: 12, color: context.colors.textMuted),
                        ),
                      ] else if (item.isManual) ...[
                        Icon(Icons.edit_note_rounded, size: 14, color: context.colors.textMuted),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          context.l10n.manualAdd,
                          style: AppText.caption.copyWith(fontSize: 12, color: context.colors.textMuted),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (item.isManual) {
      return Dismissible(
        key: Key(item.id),
        background: _buildDismissBackground(isDelete: true),
        secondaryBackground: _buildDismissBackground(isDelete: false, isArchive: item.status != HomeworkStatus.archived),
        onDismissed: (direction) {
          if (direction == DismissDirection.endToStart) {
            // 左滑：存档/撤销存档
            final isArchiving = item.status != HomeworkStatus.archived;
            ref.read(homeworkProvider.notifier).setArchived(item.id, isArchiving);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isArchiving ? context.l10n.movedToArchive : context.l10n.movedOutOfArchive), duration: const Duration(seconds: 2)));
          } else {
            // 右滑：删除
            final oldList = ref.read(homeworkProvider).valueOrNull ?? [];
            ref.read(homeworkProvider.notifier).deleteHomework(item.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.homeworkDeleted),
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: context.l10n.undo,
                  onPressed: () => ref.read(homeworkProvider.notifier).restoreList(oldList),
                ),
              ),
            );
          }
        },
        child: content,
      );
    }
    return content;
  }

  Widget _buildDismissBackground({required bool isDelete, bool isArchive = true}) {
    return Container(
      color: isDelete ? context.colors.danger : context.colors.info,
      alignment: isDelete ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Icon(
        isDelete ? Icons.delete_outline : (isArchive ? Icons.archive_outlined : Icons.unarchive_outlined),
        color: Colors.white,
      ),
    );
  }

  void _showAddHomeworkSheet(BuildContext context) {
    String title = '';
    String course = '';
    DateTime? endTime;
    String remarks = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.sm),
                child: TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: context.l10n.homeworkTitleHint,
                    hintStyle: AppText.sectionTitle
                        .copyWith(color: context.colors.textMuted),
                  ),
                  style: AppText.sectionTitle.copyWith(color: context.colors.text),
                  onChanged: (v) => title = v,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.history_edu_rounded,
                        size: 22,
                        color: course.isNotEmpty
                            ? context.colors.brand
                            : context.colors.textMuted,
                      ),
                      onPressed: () async {
                        if (course.isNotEmpty) {
                          setSheetState(() => course = '');
                        } else {
                          final val = await _showInputDialog(context.l10n.courseName, context.l10n.inputCourseHint);
                          if (val != null && val.trim().isNotEmpty) setSheetState(() => course = val);
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.schedule_rounded,
                        size: 22,
                        color: endTime != null
                            ? context.colors.brand
                            : context.colors.textMuted,
                      ),
                      onPressed: () async {
                        if (endTime != null) {
                          setSheetState(() => endTime = null);
                        } else {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365))
                          );
                          if (date != null && context.mounted) {
                            final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                            if (time != null) setSheetState(() => endTime = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                          }
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.notes,
                        size: 22,
                        color: remarks.isNotEmpty
                            ? context.colors.brand
                            : context.colors.textMuted,
                      ),
                      onPressed: () async {
                        if (remarks.isNotEmpty) {
                          setSheetState(() => remarks = '');
                        } else {
                          final val = await _showInputDialog(context.l10n.remark, context.l10n.addRemarkHint);
                          if (val != null && val.trim().isNotEmpty) setSheetState(() => remarks = val);
                        }
                      },
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        if (title.trim().isNotEmpty) {
                          ref.read(homeworkProvider.notifier).addManualHomework(title: title, courseName: course, endTime: endTime, remarks: remarks);
                          Navigator.pop(context);
                        }
                      },
                      child: Text(context.l10n.save,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _showInputDialog(String title, String hint) async {
    String val = '';
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(autofocus: true, decoration: InputDecoration(hintText: hint), onChanged: (v) => val = v),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, val), child: Text(context.l10n.confirm)),
        ],
      ),
    );
  }

  void _showHomeworkDetailDialog(HomeworkModel item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.courseName.isNotEmpty) ...[
              Text(context.l10n.courseLabel,
                  style: AppText.caption.copyWith(color: context.colors.textMuted)),
              Text(item.courseName, style: AppText.body.copyWith(color: context.colors.text)),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (item.endTime != null) ...[
              Text(context.l10n.deadlinePrefix,
                  style: AppText.caption.copyWith(color: context.colors.textMuted)),
              Text(DateFormat('yyyy-MM-dd HH:mm').format(item.endTime!),
                  style: AppText.body.copyWith(color: context.colors.text)),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (item.remarks.isNotEmpty) ...[
              Text(context.l10n.remark,
                  style: AppText.caption.copyWith(color: context.colors.textMuted)),
              Text(item.remarks, style: AppText.body.copyWith(color: context.colors.text)),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.close)),
        ],
      ),
    );
  }

  final _logger = Logger();
}
