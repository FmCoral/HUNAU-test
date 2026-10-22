import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_extension.dart';
import '../utils/library_time_utils.dart';

/// 统一的预约时段选择弹窗。
///
/// 开始时间会根据 [day] 和当前时刻过滤，今天只能选择严格晚于当前时刻的
/// 半小时刻度；结束时间始终必须晚于开始时间。
Future<LibraryTimeRangeSelection?> showLibraryTimeRangePicker({
  required BuildContext context,
  required String day,
  String? initialStartTime,
  String? initialEndTime,
}) async {
  final openedAt = DateTime.now();
  final allSlots = LibraryTimeUtils.buildTimeSlots();
  final availableStarts = LibraryTimeUtils.availableStartSlots(
    day,
    now: openedAt,
  );
  final candidateEnds = LibraryTimeUtils.candidateEndSlots(
    day,
    now: openedAt,
  );

  var tempStart = initialStartTime;
  if (tempStart == null || !availableStarts.contains(tempStart)) {
    tempStart = LibraryTimeUtils.defaultStartTime(day, now: openedAt);
  }

  var tempEnd = initialEndTime;
  if (tempStart == null ||
      !LibraryTimeUtils.availableEndSlots(tempStart).contains(tempEnd)) {
    tempEnd =
        tempStart == null ? null : LibraryTimeUtils.defaultEndTime(tempStart);
  }

  return showModalBottomSheet<LibraryTimeRangeSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final colors = context.colors;
          final startIndex =
              tempStart == null ? -1 : allSlots.indexOf(tempStart!);
          final canConfirm = tempStart != null &&
              tempEnd != null &&
              LibraryTimeUtils.isValidRange(
                day,
                tempStart!,
                tempEnd!,
                now: DateTime.now(),
              );

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.selectReservationPeriod,
                      style:
                          AppText.sectionTitle.copyWith(color: colors.text),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: colors.textMuted,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  context.l10n.startTime,
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
                    itemCount: availableStarts.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final slot = availableStarts[index];
                      final isSelected = slot == tempStart;
                      return ChoiceChip(
                        label: Text(slot),
                        selected: isSelected,
                        selectedColor: colors.statusBg(colors.brand),
                        labelStyle: AppText.caption.copyWith(
                          color: isSelected
                              ? colors.brandText
                              : colors.text,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.controlAll,
                          side: BorderSide(
                            color: isSelected
                                ? colors.brand
                                : colors.border,
                          ),
                        ),
                        onSelected: (selected) {
                          if (!selected) return;
                          setModalState(() {
                            tempStart = slot;
                            final slotIndex = allSlots.indexOf(slot);
                            final currentEndIndex = tempEnd == null
                                ? -1
                                : allSlots.indexOf(tempEnd!);
                            if (currentEndIndex <= slotIndex) {
                              tempEnd = LibraryTimeUtils.defaultEndTime(slot);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                if (availableStarts.isEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    context.l10n.noAvailableSlotsForDate,
                    style: AppText.caption.copyWith(
                      color: colors.warning,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
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
                      final isSelected = slot == tempEnd;
                      return ChoiceChip(
                        label: Text(slot),
                        selected: isSelected,
                        selectedColor: colors.statusBg(colors.brand),
                        labelStyle: AppText.caption.copyWith(
                          color: !isAvailable
                              ? colors.textMuted.withValues(alpha: 0.5)
                              : (isSelected ? colors.brandText : colors.text),
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.controlAll,
                          side: BorderSide(
                            color: isSelected
                                ? colors.brand
                                : colors.border,
                          ),
                        ),
                        onSelected: isAvailable
                            ? (selected) {
                                if (selected) {
                                  setModalState(() => tempEnd = slot);
                                }
                              }
                            : null,
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: canConfirm
                        ? () => Navigator.pop(
                              ctx,
                              LibraryTimeRangeSelection(
                                startTime: tempStart!,
                                endTime: tempEnd!,
                              ),
                            )
                        : null,
                    child: Text(
                      context.l10n.confirmPeriod,
                      style:
                          const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
