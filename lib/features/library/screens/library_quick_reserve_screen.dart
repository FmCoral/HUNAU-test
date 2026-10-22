import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_extension.dart';
import '../models/library_models.dart';
import '../providers/library_provider.dart';
import '../utils/library_time_utils.dart';
import '../widgets/library_time_range_picker.dart';

class LibraryQuickReserveScreen extends ConsumerStatefulWidget {
  const LibraryQuickReserveScreen({super.key});

  @override
  ConsumerState<LibraryQuickReserveScreen> createState() =>
      _LibraryQuickReserveScreenState();
}

class _LibraryQuickReserveScreenState
    extends ConsumerState<LibraryQuickReserveScreen> {
  late String _selectedDay;
  late String _startTime;
  late String _endTime;

  bool _isLoadingConfig = true;
  bool _isLoadingRooms = false;
  bool _isMatching = false;
  bool _isSubmitting = false;

  String _selectedFirstLevel = '图书馆';

  List<String> _secondLevels = [];
  String? _selectedSecondLevel;

  List<String> _thirdLevels = [];
  String? _selectedThirdLevel;

  LibraryMatchedSeatModel? _matchedSeat;
  String? _matchErrorMessage;

  int _cooldownRemaining = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _initTime();
    _loadConfig();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _initTime() {
    final now = DateTime.now();
    _selectedDay = LibraryTimeUtils.initialReserveDay(now: now);
    final defaultStart =
        LibraryTimeUtils.defaultStartTime(_selectedDay, now: now) ??
        (LibraryTimeUtils.availableStartSlots(_selectedDay, now: now).isNotEmpty
            ? LibraryTimeUtils.availableStartSlots(_selectedDay, now: now).first
            : '08:00');
    final defaultEnd =
        LibraryTimeUtils.defaultEndTime(defaultStart) ?? '10:00';
    _startTime = defaultStart;
    _endTime = defaultEnd;
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoadingConfig = true);
    final service = ref.read(libraryServiceProvider);

    try {
      // 1. 同步服务器开放时间与当前日期
      final startEndData = await service.fetchLiveStartEndTime();
      if (startEndData['ymd'] != null &&
          startEndData['ymd'].toString().isNotEmpty) {
        final serverYmd = startEndData['ymd'].toString();
        final now = DateTime.now();
        final effectiveDay =
            LibraryTimeUtils.resolveEffectiveDay(serverYmd, now: now);
        final dayChanged = effectiveDay != _selectedDay;
        _selectedDay = effectiveDay;
        if (dayChanged ||
            !LibraryTimeUtils.isValidRange(
                _selectedDay, _startTime, _endTime,
                now: now)) {
          final defaultStart =
              LibraryTimeUtils.defaultStartTime(_selectedDay, now: now) ??
                  (LibraryTimeUtils.availableStartSlots(_selectedDay, now: now)
                          .isNotEmpty
                      ? LibraryTimeUtils.availableStartSlots(_selectedDay,
                              now: now)
                          .first
                      : '08:00');
          final defaultEnd =
              LibraryTimeUtils.defaultEndTime(defaultStart) ?? '10:00';
          _startTime = defaultStart;
          _endTime = defaultEnd;
        }
      }

      // 2. 获取一级分类
      final firsts = await service.fetchLevels(type: 0);
      if (firsts.isNotEmpty) {
        _selectedFirstLevel = firsts.first;
      }

      // 3. 获取二级分类（楼层）
      final seconds = await service.fetchLevels(
        type: 1,
        firstLevelName: _selectedFirstLevel,
      );

      if (mounted) {
        setState(() {
          _secondLevels = seconds;
          _isLoadingConfig = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingConfig = false);
      }
    }
  }

  Future<void> _onFloorSelected(String? floor) async {
    if (_selectedSecondLevel == floor) return;

    setState(() {
      _selectedSecondLevel = floor;
      _selectedThirdLevel = null;
      _thirdLevels = [];
      _matchedSeat = null;
      _matchErrorMessage = null;
    });

    if (floor == null) return;

    setState(() => _isLoadingRooms = true);
    try {
      final service = ref.read(libraryServiceProvider);
      final rooms = await service.fetchLevels(
        type: 2,
        firstLevelName: _selectedFirstLevel,
        secondLevelName: floor,
      );
      if (mounted) {
        setState(() {
          _thirdLevels = rooms;
          _isLoadingRooms = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingRooms = false);
      }
    }
  }

  Future<void> _pickTimeRange() async {
    final result = await showLibraryTimeRangePicker(
      context: context,
      day: _selectedDay,
      initialStartTime: _startTime,
      initialEndTime: _endTime,
    );
    if (result == null || !mounted) return;

    setState(() {
      _startTime = result.startTime;
      _endTime = result.endTime;
      _matchedSeat = null;
      _matchErrorMessage = null;
    });
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownRemaining = 3);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownRemaining <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() => _cooldownRemaining = 0);
        }
      } else {
        if (mounted) {
          setState(() => _cooldownRemaining--);
        }
      }
    });
  }

  Future<void> _handleMatchSeat({bool isReMatch = false}) async {
    if (_isMatching || _isSubmitting) return;
    if (isReMatch && _cooldownRemaining > 0) return;

    setState(() {
      _isMatching = true;
      _matchErrorMessage = null;
      if (!isReMatch) {
        _matchedSeat = null;
      }
    });

    try {
      final service = ref.read(libraryServiceProvider);
      final matched = await service.matchSeat(
        startTime: _startTime,
        endTime: _endTime,
        firstLevelName: _selectedFirstLevel,
        secondLevelName: _selectedSecondLevel ?? '',
        thirdLevelName: _selectedThirdLevel ?? '',
      );

      if (mounted) {
        setState(() {
          _matchedSeat = matched;
          _isMatching = false;
        });
        _startCooldown();
      }
    } catch (e) {
      if (mounted) {
        final errorText = e.toString().replaceAll('Exception:', '').trim();
        setState(() {
          _isMatching = false;
          _matchErrorMessage = errorText;
        });
      }
    }
  }

  Future<void> _handleSubmitReservation() async {
    if (_matchedSeat == null || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final service = ref.read(libraryServiceProvider);
      final result = await service.submitQuickReservation(
        roomId: _matchedSeat!.roomId,
        seatNum: _matchedSeat!.seatNum,
        day: _selectedDay,
        startTime: _startTime,
        endTime: _endTime,
      );

      await ref
          .read(cachedLibraryReserveProvider.notifier)
          .addOrUpdateReserve(result);
      ref.read(libraryIndexProvider.notifier).refresh();

      if (!mounted) return;

      final colors = context.colors;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: colors.brand),
              const SizedBox(width: AppSpacing.sm),
              Text(
                context.l10n.reservationSuccess,
                style: AppText.sectionTitle.copyWith(color: colors.text),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.readingRoomLabel(_matchedSeat!.fullRoomName)),
              const SizedBox(height: 4),
              Text(context.l10n.seatNumberLabel(
                  result.seatNum.isNotEmpty ? result.seatNum : _matchedSeat!.seatNum)),
              const SizedBox(height: 4),
              Text(context.l10n.dateLabel(_selectedDay)),
              const SizedBox(height: 4),
              Text(context.l10n.timeValueLabel('$_startTime ~ $_endTime')),
              const SizedBox(height: AppSpacing.md),
              Text(
                context.l10n.reservationNotice,
                style: AppText.caption.copyWith(color: colors.textMuted),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 40),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true);
              },
              child: Text(context.l10n.done),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceAll('Exception:', '').trim();
        final colors = context.colors;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error_outline, color: colors.danger),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  context.l10n.reservationFailed,
                  style: AppText.sectionTitle.copyWith(color: colors.text),
                ),
              ],
            ),
            content: Text(
              errorMsg.isNotEmpty ? errorMsg : context.l10n.reservationFailed,
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.l10n.iUnderstand),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _calculateDurationText() {
    final startParts = _startTime.split(':');
    final endParts = _endTime.split(':');
    if (startParts.length == 2 && endParts.length == 2) {
      final sMin =
          int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      final eMin =
          int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
      final diff = (eMin - sMin) / 60.0;
      if (diff > 0) {
        return diff % 1 == 0 ? '${diff.toInt()}h' : '${diff.toStringAsFixed(1)}h';
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final durationText = _calculateDurationText();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.quickReserve),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.refresh,
            onPressed: () {
              setState(() {
                _matchedSeat = null;
                _matchErrorMessage = null;
              });
              _loadConfig();
            },
          ),
        ],
      ),
      body: _isLoadingConfig
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                // 1. 预约时段选择卡片
                _buildTimePickerCard(colors, durationText),
                const SizedBox(height: AppSpacing.lg),

                // 2. 位置偏好选择卡片
                _buildLocationCard(colors),
                const SizedBox(height: AppSpacing.lg),

                // 3. 预约匹配按钮
                _buildMatchButton(),
                const SizedBox(height: AppSpacing.xl),

                // 4. 匹配结果或未匹配到提示
                if (_matchedSeat != null) ...[
                  _buildMatchedResultCard(colors),
                ] else if (_matchErrorMessage != null) ...[
                  _buildErrorCard(colors),
                ],
              ],
            ),
    );
  }

  Widget _buildTimePickerCard(AppSemanticColors colors, String durationText) {
    final dayLabel =
        LibraryTimeUtils.formatDayLabelLocalized(context, _selectedDay);

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
          onTap: _pickTimeRange,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.card),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      color: colors.brand,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      context.l10n.selectReservationPeriod,
                      style: AppText.sectionTitle
                          .copyWith(color: colors.text, fontSize: 14),
                    ),
                    const Spacer(),
                    Text(
                      dayLabel,
                      style: AppText.caption.copyWith(color: colors.textMuted),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: colors.textMuted,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Text(
                      '$_startTime ~ $_endTime',
                      style: AppText.keyNumber.copyWith(color: colors.text),
                    ),
                    if (durationText.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colors.statusBg(colors.brand),
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          durationText,
                          style: AppText.caption.copyWith(
                            color: colors.brandText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard(AppSemanticColors colors) {
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
              Icon(
                Icons.place_outlined,
                color: colors.brand,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                context.l10n.locationPreference,
                style: AppText.sectionTitle
                    .copyWith(color: colors.text, fontSize: 14),
              ),
              const SizedBox(width: 6),
              Text(
                '(${context.l10n.optionalLabel})',
                style: AppText.caption.copyWith(color: colors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 楼层选项
          Text(
            context.l10n.floorLabel,
            style: AppText.caption.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(context.l10n.allFloors),
                    selected: _selectedSecondLevel == null,
                    selectedColor: colors.statusBg(colors.brand),
                    labelStyle: AppText.caption.copyWith(
                      color: _selectedSecondLevel == null
                          ? colors.brandText
                          : colors.text,
                      fontWeight: _selectedSecondLevel == null
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.controlAll,
                    ),
                    side: BorderSide(
                      color: _selectedSecondLevel == null
                          ? colors.brand
                          : colors.border,
                    ),
                    onSelected: (selected) {
                      if (selected) _onFloorSelected(null);
                    },
                  ),
                ),
                for (final floor in _secondLevels)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(floor),
                      selected: _selectedSecondLevel == floor,
                      selectedColor: colors.statusBg(colors.brand),
                      labelStyle: AppText.caption.copyWith(
                        color: _selectedSecondLevel == floor
                            ? colors.brandText
                            : colors.text,
                        fontWeight: _selectedSecondLevel == floor
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.controlAll,
                      ),
                      side: BorderSide(
                        color: _selectedSecondLevel == floor
                            ? colors.brand
                            : colors.border,
                      ),
                      onSelected: (selected) {
                        _onFloorSelected(selected ? floor : null);
                      },
                    ),
                  ),
              ],
            ),
          ),

          // 阅览室选项（楼层已选时展示）
          if (_selectedSecondLevel != null) ...[
            const SizedBox(height: 14),
            Text(
              context.l10n.roomLabel,
              style: AppText.caption.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_isLoadingRooms)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text(context.l10n.allRooms),
                        selected: _selectedThirdLevel == null,
                        selectedColor: colors.statusBg(colors.brand),
                        labelStyle: AppText.caption.copyWith(
                          color: _selectedThirdLevel == null
                              ? colors.brandText
                              : colors.text,
                          fontWeight: _selectedThirdLevel == null
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.controlAll,
                        ),
                        side: BorderSide(
                          color: _selectedThirdLevel == null
                              ? colors.brand
                              : colors.border,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedThirdLevel = null;
                              _matchedSeat = null;
                            });
                          }
                        },
                      ),
                    ),
                    for (final room in _thirdLevels)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: ChoiceChip(
                          label: Text(room),
                          selected: _selectedThirdLevel == room,
                          selectedColor: colors.statusBg(colors.brand),
                          labelStyle: AppText.caption.copyWith(
                            color: _selectedThirdLevel == room
                                ? colors.brandText
                                : colors.text,
                            fontWeight: _selectedThirdLevel == room
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.controlAll,
                          ),
                          side: BorderSide(
                            color: _selectedThirdLevel == room
                                ? colors.brand
                                : colors.border,
                          ),
                          onSelected: (selected) {
                            setState(() {
                              _selectedThirdLevel = selected ? room : null;
                              _matchedSeat = null;
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildMatchButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(80, 40),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: 10),
        ),
        onPressed: (_isMatching || _isSubmitting)
            ? null
            : () => _handleMatchSeat(isReMatch: false),
        child: _isMatching
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              )
            : Text(context.l10n.reserve),
      ),
    );
  }

  Widget _buildMatchedResultCard(AppSemanticColors colors) {
    final seat = _matchedSeat!;
    final cooldownActive = _cooldownRemaining > 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.card),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(
          color: colors.brand,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 座位号展示
          Text(
            context.l10n.seatNumberLabel(seat.seatNum),
            style: AppText.keyNumber.copyWith(color: colors.text),
          ),
          const SizedBox(height: 6),

          // 阅览室位置
          Row(
            children: [
              Icon(
                Icons.room_rounded,
                size: 16,
                color: colors.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  seat.fullRoomName,
                  style: AppText.bodyDense.copyWith(color: colors.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 时段展示
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 16,
                color: colors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                '$_selectedDay  ${seat.formattedTimeRange} (${seat.duration}h)',
                style: AppText.caption.copyWith(color: colors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 操作按钮组：换一个（灰色文字） + 确认（长度缩短右对齐）
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: colors.textMuted,
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: cooldownActive || _isSubmitting
                    ? null
                    : () => _handleMatchSeat(isReMatch: true),
                child: Text(
                  cooldownActive
                      ? context.l10n
                          .changeAnotherSeatWithCooldown(_cooldownRemaining)
                      : context.l10n.changeAnotherSeat,
                  style: AppText.bodyDense.copyWith(
                    color: cooldownActive
                        ? colors.textMuted.withValues(alpha: 0.5)
                        : colors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(80, 40),
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxl, vertical: 10),
                ),
                onPressed: _isSubmitting ? null : _handleSubmitReservation,
                child: _isSubmitting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : Text(context.l10n.confirmQuickReserve),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(AppSemanticColors colors) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.card),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(
          color: colors.warning,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: colors.warning,
            size: 32,
          ),
          const SizedBox(height: 10),
          Text(
            _matchErrorMessage ?? context.l10n.noMatchedSeatFound,
            textAlign: TextAlign.center,
            style: AppText.bodyDense.copyWith(
              color: colors.text,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () => _handleMatchSeat(isReMatch: false),
            child: Text(
              context.l10n.retry,
              style: AppText.bodyDense.copyWith(
                color: colors.brandText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
