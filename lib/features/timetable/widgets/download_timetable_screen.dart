import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/state/auth_state.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/date_format_utils.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../../auth/screens/login_screen.dart';
import '../services/timetable_service.dart';
import '../../profile/providers/settings_provider.dart';

/// 导入课表页面
class DownloadTimetableScreen extends ConsumerStatefulWidget {
  const DownloadTimetableScreen({super.key});

  @override
  ConsumerState<DownloadTimetableScreen> createState() => _DownloadTimetableScreenState();
}

class _DownloadTimetableScreenState extends ConsumerState<DownloadTimetableScreen> {
  final TimetableService _timetableService = TimetableService();
  
  String? _selectedSemester;
  DateTime? _selectedDate;
  bool _isLoading = false;
  String _syncStatus = '';
  
  late final List<String> _semesters;

  @override
  void initState() {
    super.initState();
    _semesters = _generateSemesters();
    if (_semesters.isNotEmpty) {
      _selectedSemester = _semesters.first;
    }
  }

  List<String> _generateSemesters() {
    final now = DateTime.now();
    final x = now.year;
    final List<String> list = [];
    
    // 如果是 1-6 月，最新学期是 (x-1)-x-2
    // 如果是 7-12 月，最新学期是 x-(x+1)-1
    if (now.month <= 6) {
      // 从 (x-1)-x-2 开始往前推
      int startYear = x - 1;
      for (int i = 0; i < 5; i++) {
        int y = startYear - i;
        list.add('$y-${y + 1}-2');
        list.add('$y-${y + 1}-1');
      }
    } else {
      // 从 x-(x+1)-1 开始往前推
      int startYear = x;
      for (int i = 0; i < 5; i++) {
        int y = startYear - i;
        list.add('$y-${y + 1}-1');
        list.add('${y - 1}-$y-2');
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // 输入框装饰交给全局 inputDecorationTheme，仅提供标签与前缀图标
    InputDecoration md2InputDecoration(String label, IconData icon) => InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
    );

    return PopScope(
      canPop: !_isLoading, // 加载中时禁用手势/物理返回
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          automaticallyImplyLeading: false, // 禁用默认返回
          leading: IconButton(
            icon: Icon(
              Icons.close,
              color: _isLoading
                  ? colors.textMuted.withValues(alpha: 0.4)
                  : colors.textMuted,
            ),
            onPressed: _isLoading ? null : () => Navigator.maybePop(context),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.xxl),

              // 学年学期选择
              DropdownButtonFormField<String>(
                value: _selectedSemester,
                decoration: md2InputDecoration(context.l10n.academicSemester, Icons.calendar_today_outlined),
                isExpanded: true,
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: colors.textMuted,
                ),
                dropdownColor: colors.surface,
                borderRadius: AppRadius.controlAll,
                items: _semesters.map((semester) {
                  return DropdownMenuItem(
                    value: semester,
                    child: Text(semester, style: const TextStyle(fontSize: 15)),
                  );
                }).toList(),
                onChanged: _isLoading ? null : (value) {
                  setState(() {
                    _selectedSemester = value;
                  });
                },
              ),

              const SizedBox(height: AppSpacing.xxl),

              // 第一周周一日期选择
              InkWell(
                onTap: _isLoading ? null : _selectDate,
                borderRadius: AppRadius.controlAll,
                child: IgnorePointer(
                  child: TextFormField(
                    controller: TextEditingController(
                      text: _selectedDate != null
                          ? formatYMMMd(
                              _selectedDate!,
                              Localizations.localeOf(context).toString(),
                            )
                          : '',
                    ),
                    decoration: md2InputDecoration(context.l10n.firstWeekMonday, Icons.date_range_outlined).copyWith(
                      hintText: context.l10n.selectDateHint,
                      suffixIcon: const Icon(Icons.edit_calendar_outlined, size: 18),
                    ),
                    readOnly: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isLoading)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _syncStatus,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.brandText,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                    ),
                  ),
                ElevatedButton.icon(
                  onPressed: (_canConfirm() && !_isLoading) ? _confirm : null,
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: Text(context.l10n.importButton),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _canConfirm() => _selectedSemester != null && _selectedDate != null;
  
  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      helpText: context.l10n.selectFirstWeekMondayHelp,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            useMaterial3: true,
            colorScheme: isDark
              ? const ColorScheme.dark(
                  primary: AppColors.brandDark,
                  onPrimary: AppColors.bgDark,
                  surface: AppColors.surfaceDark,
                  onSurface: AppColors.textDark,
                )
              : const ColorScheme.light(
                  primary: AppColors.brand,
                  onPrimary: Colors.white,
                  surface: AppColors.surface,
                  onSurface: AppColors.text,
                ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      final monday = _getMondayOfWeek(picked);
      setState(() {
        _selectedDate = monday;
      });
    }
  }
  
  DateTime _getMondayOfWeek(DateTime date) {
    final daysFromMonday = date.weekday - DateTime.monday;
    return date.subtract(Duration(days: daysFromMonday));
  }
  
  Future<void> _confirm() async {
    if (_selectedSemester == null || _selectedDate == null) return;
    
    final authState = ref.read(authStateProvider);
    if (authState.status != AuthStatus.authenticated) {
      await Navigator.push(context, LoginScreen.route());
      
      final newAuthState = ref.read(authStateProvider);
      if (newAuthState.status != AuthStatus.authenticated) return;
    }
    
    setState(() { _isLoading = true; });
    final l10n = context.l10n;
    
    try {
      await _timetableService.downloadAndSaveTimetable(
        semester: _selectedSemester!,
        firstWeekMonday: _selectedDate!,
        onProgress: (status) {
          if (mounted) {
            setState(() { _syncStatus = status; });
          }
        },
      );
      
      // ✨ 导入成功后，重新安排上课提醒通知
      await ref.read(settingsProvider.notifier).rescheduleNotifications();
      
      if (mounted) {
        // 先返回 true 给上一级页面，通知导入成功
        Navigator.of(context).pop(true);
        
        // 在全局提示成功
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.timetableImportSuccess),
            backgroundColor: context.colors.brand,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.importFailed(e.toString())), backgroundColor: context.colors.danger),
        );
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }
}
