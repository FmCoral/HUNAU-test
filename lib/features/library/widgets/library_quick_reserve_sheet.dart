import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_extension.dart';
import '../models/library_models.dart';
import '../utils/library_time_utils.dart';

/// 快速预约选择结果
class LibraryQuickReserveResult {
  final String day;
  final String startTime;
  final String endTime;

  const LibraryQuickReserveResult({
    required this.day,
    required this.startTime,
    required this.endTime,
  });
}

/// 弹出快速预约日期与时段选择面板
Future<LibraryQuickReserveResult?> showLibraryQuickReserveSheet({
  required BuildContext context,
  required LibraryReserveModel item,
}) {
  return showModalBottomSheet<LibraryQuickReserveResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => LibraryQuickReserveSheet(item: item),
  );
}

class LibraryQuickReserveSheet extends StatefulWidget {
  final LibraryReserveModel item;

  const LibraryQuickReserveSheet({
    super.key,
    required this.item,
  });

  @override
  State<LibraryQuickReserveSheet> createState() =>
      _LibraryQuickReserveSheetState();
}

class _LibraryQuickReserveSheetState extends State<LibraryQuickReserveSheet> {
  late List<String> _availableDays;
  late String _selectedDay;
  String? _selectedStartTime;
  String? _selectedEndTime;

  @override
  void initState() {
    super.initState();
    _initDaysAndTimes();
  }

  void _initDaysAndTimes() {
    final now = DateTime.now();
    _availableDays = LibraryTimeUtils.availableReserveDays(now: now);

    // 如果 22:00 后或今天已没有可约时段（比如晚上 21:30 之后），且明天可选，默认切到明天
    final beijing = LibraryTimeUtils.getBeijingNow(now);
    final todayStarts =
        LibraryTimeUtils.availableStartSlots(_availableDays[0], now: now);
    if ((beijing.hour >= 22 || todayStarts.isEmpty) && _availableDays.length > 1) {
      _selectedDay = _availableDays[1];
    } else {
      _selectedDay = _availableDays[0];
    }

    _initTimesForSelectedDay(now: now);
  }

  void _initTimesForSelectedDay({DateTime? now}) {
    final currentNow = now ?? DateTime.now();
    final timeFormat = DateFormat('HH:mm');
    final historyStart = timeFormat.format(widget.item.startTime);
    final historyEnd = timeFormat.format(widget.item.endTime);

    // 如果历史预约的时间段在所选日期合法，优先使用历史时间段
    if (LibraryTimeUtils.isValidRange(
      _selectedDay,
      historyStart,
      historyEnd,
      now: currentNow,
    )) {
      _selectedStartTime = historyStart;
      _selectedEndTime = historyEnd;
      return;
    }

    // 否则使用默认推荐时段
    final defaultStart =
        LibraryTimeUtils.defaultStartTime(_selectedDay, now: currentNow);
    _selectedStartTime = defaultStart;
    _selectedEndTime = defaultStart != null
        ? LibraryTimeUtils.defaultEndTime(defaultStart)
        : null;
  }

  void _onDaySelected(String day) {
    if (_selectedDay == day) return;
    setState(() {
      _selectedDay = day;
      final now = DateTime.now();
      final availableStarts =
          LibraryTimeUtils.availableStartSlots(_selectedDay, now: now);

      if (_selectedStartTime == null ||
          !availableStarts.contains(_selectedStartTime)) {
        _selectedStartTime =
            LibraryTimeUtils.defaultStartTime(_selectedDay, now: now);
      }

      if (_selectedStartTime != null) {
        final availableEnds =
            LibraryTimeUtils.availableEndSlots(_selectedStartTime!);
        if (_selectedEndTime == null ||
            !availableEnds.contains(_selectedEndTime)) {
          _selectedEndTime =
              LibraryTimeUtils.defaultEndTime(_selectedStartTime!);
        }
      } else {
        _selectedEndTime = null;
      }
    });
  }

  String _formatDayLabel(BuildContext context, String dayStr) {
    return LibraryTimeUtils.formatDayLabelLocalized(context, dayStr);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final now = DateTime.now();
    final allSlots = LibraryTimeUtils.buildTimeSlots();
    final availableStarts =
        LibraryTimeUtils.availableStartSlots(_selectedDay, now: now);
    final candidateEnds =
        LibraryTimeUtils.candidateEndSlots(_selectedDay, now: now);

    final startIndex =
        _selectedStartTime == null ? -1 : allSlots.indexOf(_selectedStartTime!);
    final canConfirm = _selectedStartTime != null &&
        _selectedEndTime != null &&
        LibraryTimeUtils.isValidRange(
          _selectedDay,
          _selectedStartTime!,
          _selectedEndTime!,
          now: now,
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部标题与关闭按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.quickReserve,
                style: AppText.sectionTitle.copyWith(color: colors.text),
              ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: colors.textMuted,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          // 目标座位信息卡片
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 10),
            decoration: BoxDecoration(
              color: colors.statusBg(colors.brand),
              borderRadius: AppRadius.controlAll,
              border: Border.all(color: colors.brand),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.event_seat_rounded,
                  size: 18,
                  color: colors.brand,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.seatWithNumber(widget.item.seatNum),
                        style: AppText.bodyDense.copyWith(
                          color: colors.brandText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.item.fullRoomName,
                        style:
                            AppText.caption.copyWith(color: colors.text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // 1. 选择日期
          Text(
            context.l10n.selectDate,
            style: AppText.caption.copyWith(
              color: colors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _availableDays.map((day) {
                final isSelected = day == _selectedDay;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(_formatDayLabel(context, day)),
                    selected: isSelected,
                    selectedColor: colors.statusBg(colors.brand),
                    labelStyle: AppText.caption.copyWith(
                      color: isSelected ? colors.brandText : colors.text,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.controlAll,
                      side: BorderSide(
                        color:
                            isSelected ? colors.brand : colors.border,
                      ),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        _onDaySelected(day);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 14),

          // 2. 开始时间
          Text(
            context.l10n.startTime,
            style: AppText.caption.copyWith(
              color: colors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (availableStarts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                context.l10n.noAvailableSlotsForDate,
                style: AppText.caption.copyWith(
                  color: colors.warning,
                ),
              ),
            )
          else
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: availableStarts.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final slot = availableStarts[index];
                  final isSelected = slot == _selectedStartTime;
                  return ChoiceChip(
                    label: Text(slot),
                    selected: isSelected,
                    selectedColor: colors.statusBg(colors.brand),
                    labelStyle: AppText.caption.copyWith(
                      color: isSelected ? colors.brandText : colors.text,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.controlAll,
                      side: BorderSide(
                        color:
                            isSelected ? colors.brand : colors.border,
                      ),
                    ),
                    onSelected: (selected) {
                      if (!selected) return;
                      setState(() {
                        _selectedStartTime = slot;
                        final slotIndex = allSlots.indexOf(slot);
                        final currentEndIndex = _selectedEndTime == null
                            ? -1
                            : allSlots.indexOf(_selectedEndTime!);
                        if (currentEndIndex <= slotIndex) {
                          _selectedEndTime =
                              LibraryTimeUtils.defaultEndTime(slot);
                        }
                      });
                    },
                  );
                },
              ),
            ),

          const SizedBox(height: 14),

          // 3. 结束时间
          Text(
            context.l10n.endTime,
            style: AppText.caption.copyWith(
              color: colors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: candidateEnds.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final slot = candidateEnds[index];
                final isAvailable =
                    startIndex >= 0 && allSlots.indexOf(slot) > startIndex;
                final isSelected = slot == _selectedEndTime;
                return ChoiceChip(
                  label: Text(slot),
                  selected: isSelected,
                  selectedColor: colors.statusBg(colors.brand),
                  labelStyle: AppText.caption.copyWith(
                    color: !isAvailable
                        ? colors.textMuted.withValues(alpha: 0.5)
                        : (isSelected ? colors.brandText : colors.text),
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.controlAll,
                    side: BorderSide(
                      color: isSelected ? colors.brand : colors.border,
                    ),
                  ),
                  onSelected: isAvailable
                      ? (selected) {
                          if (selected) {
                            setState(() => _selectedEndTime = slot);
                          }
                        }
                      : null,
                );
              },
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // 确认预约按钮
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: canConfirm
                  ? () => Navigator.pop(
                        context,
                        LibraryQuickReserveResult(
                          day: _selectedDay,
                          startTime: _selectedStartTime!,
                          endTime: _selectedEndTime!,
                        ),
                      )
                  : null,
              child: Text(
                canConfirm
                    ? context.l10n.confirmReservationPeriod(
                        _selectedDay,
                        _selectedStartTime!,
                        _selectedEndTime!,
                      )
                    : context.l10n.pleaseSelectValidPeriod,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
