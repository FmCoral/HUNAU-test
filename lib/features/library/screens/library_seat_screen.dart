import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_extension.dart';
import '../models/library_models.dart';
import '../providers/library_provider.dart';
import '../utils/library_time_utils.dart';
import '../widgets/library_time_range_picker.dart';

class LibrarySeatScreen extends ConsumerStatefulWidget {
  final LibraryRoomModel room;
  final String day;
  final String? initialStartTime;
  final String? initialEndTime;

  const LibrarySeatScreen({
    super.key,
    required this.room,
    required this.day,
    this.initialStartTime,
    this.initialEndTime,
  });

  @override
  ConsumerState<LibrarySeatScreen> createState() => _LibrarySeatScreenState();
}

class _LibrarySeatScreenState extends ConsumerState<LibrarySeatScreen> {
  bool _isLoadingGrid = true;
  bool _isLoadingUsed = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  LibrarySeatGridData? _gridData;
  Set<String> _usedSeats = {};

  String? _selectedSeatNum;
  String _startTime = '08:00';
  String _endTime = '12:00';

  final TransformationController _transformController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    _initTimeSlots();
    _loadSeatGrid();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _initTimeSlots() {
    final now = DateTime.now();
    final defaultStart =
        LibraryTimeUtils.defaultStartTime(widget.day, now: now);
    final defaultEnd = defaultStart == null
        ? null
        : LibraryTimeUtils.defaultEndTime(defaultStart);

    final requestedStart = widget.initialStartTime ?? defaultStart;
    final requestedEnd = widget.initialEndTime ?? defaultEnd;

    if (requestedStart != null &&
        requestedEnd != null &&
        LibraryTimeUtils.isValidRange(
          widget.day,
          requestedStart,
          requestedEnd,
          now: now,
        )) {
      _startTime = requestedStart;
      _endTime = requestedEnd;
    } else {
      _startTime = defaultStart ?? '08:00';
      _endTime = defaultEnd ?? '12:00';
    }
  }

  Future<void> _loadSeatGrid() async {
    setState(() {
      _isLoadingGrid = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(libraryServiceProvider);
      final grid = await service.fetchSeatGrid(roomId: widget.room.id);
      _gridData = grid;
      await _loadUsedSeats();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isLoadingGrid = false;
        });
      }
    }
  }

  Future<void> _loadUsedSeats() async {
    if (_gridData == null) return;
    setState(() => _isLoadingUsed = true);

    try {
      final service = ref.read(libraryServiceProvider);
      final used = await service.fetchUsedSeats(
        roomId: widget.room.id,
        startTime: _startTime,
        endTime: _endTime,
        day: widget.day,
      );
      if (mounted) {
        setState(() {
          _usedSeats = used;
          if (_selectedSeatNum != null &&
              _usedSeats.contains(_selectedSeatNum)) {
            _selectedSeatNum = null;
          }
          _isLoadingGrid = false;
          _isLoadingUsed = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingGrid = false;
          _isLoadingUsed = false;
        });
      }
    }
  }

  Future<void> _submitReservation() async {
    if (_selectedSeatNum == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.pleaseSelectSeatFirst)),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final service = ref.read(libraryServiceProvider);
      final result = await service.submitReservation(
        roomId: widget.room.id,
        seatNum: _selectedSeatNum!,
        day: widget.day,
        startTime: _startTime,
        endTime: _endTime,
      );

      // 刷新全局状态与本地缓存
      ref
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
              Text(context.l10n.reservationSuccess,
                  style: AppText.sectionTitle.copyWith(color: colors.text)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.readingRoomLabel(widget.room.displayName)),
              const SizedBox(height: 4),
              Text(context.l10n.seatNumberLabel(result.seatNum)),
              const SizedBox(height: 4),
              Text(context.l10n.dateLabel(widget.day)),
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
        final colors = context.colors;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error_outline, color: colors.danger),
                const SizedBox(width: AppSpacing.sm),
                Text(context.l10n.reservationFailed,
                    style: AppText.sectionTitle.copyWith(color: colors.text)),
              ],
            ),
            content: Text(e.toString().replaceAll('Exception:', '').trim()),
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

  Future<void> _showTimeRangePicker() async {
    final result = await showLibraryTimeRangePicker(
      context: context,
      day: widget.day,
      initialStartTime: _startTime,
      initialEndTime: _endTime,
    );
    if (result == null || !mounted) return;

    setState(() {
      _startTime = result.startTime;
      _endTime = result.endTime;
    });
    await _loadUsedSeats();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room.displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.refreshSeatStatus,
            onPressed: _loadUsedSeats,
          ),
        ],
      ),
      body: Column(
        children: [
          // 顶部时段与图例栏
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.page, vertical: AppSpacing.md),
            color: colors.surface,
            child: Column(
              children: [
                // 时段选择卡片
                InkWell(
                  onTap: _showTimeRangePicker,
                  borderRadius: AppRadius.controlAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: colors.statusBg(colors.brand),
                      borderRadius: AppRadius.controlAll,
                      border: Border.all(color: colors.brand),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time_filled_rounded,
                            size: 16, color: colors.brand),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          context.l10n.dateAndPeriod(
                              widget.day, '$_startTime - $_endTime'),
                          style: AppText.caption.copyWith(
                            color: colors.brandText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        if (_isLoadingUsed)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(Icons.arrow_forward_ios_rounded,
                              size: 12, color: colors.brand),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // 图例说明
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildLegendItem(
                      color: colors.statusBg(colors.brand),
                      borderColor: colors.brand,
                      label: context.l10n.seatAvailable,
                      colors: colors,
                    ),
                    _buildLegendItem(
                      color: colors.brand,
                      borderColor: colors.brand,
                      label: context.l10n.seatSelected,
                      colors: colors,
                    ),
                    _buildLegendItem(
                      color: colors.surfaceSubtle,
                      borderColor: colors.border,
                      label: context.l10n.seatOccupied,
                      colors: colors,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),

          // 中间互动座位图
          Expanded(
            child: _buildSeatGridContent(colors),
          ),

          // 底部确认卡片
          _buildBottomActionCard(colors),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required Color borderColor,
    required String label,
    required AppSemanticColors colors,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: borderColor, width: 1),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppText.caption.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }

  Widget _buildSeatGridContent(AppSemanticColors colors) {
    if (_isLoadingGrid) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(context.l10n.loadingSeatMap),
          ],
        ),
      );
    }

    if (_errorMessage != null || _gridData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sentiment_dissatisfied,
                size: 48, color: colors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(_errorMessage ?? context.l10n.loadFailed),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: _loadSeatGrid,
              child: Text(context.l10n.retry),
            ),
          ],
        ),
      );
    }

    final data = _gridData!;
    const double cellSize = 36.0;

    return InteractiveViewer(
      transformationController: _transformController,
      minScale: 0.3,
      maxScale: 3.5,
      boundaryMargin: const EdgeInsets.all(200),
      constrained: false,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        color: colors.bg,
        child: SizedBox(
          width: data.cols * cellSize,
          height: data.rows * cellSize,
          child: Stack(
            children: [
              // 1. 渲染障碍物/桌子
              for (final obs in data.obstacles)
                Positioned(
                  left: (obs.x - 1) * cellSize,
                  top: (obs.y - 1) * cellSize,
                  width: cellSize - 2,
                  height: cellSize - 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.center,
                    child: obs.label.isNotEmpty
                        ? Text(
                            obs.label,
                            style: AppText.caption.copyWith(
                              fontSize: 10,
                              color: colors.textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          )
                        : const SizedBox(),
                  ),
                ),

              // 2. 渲染座位
              for (final seat in data.seats)
                _buildSeatWidget(seat, cellSize, colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeatWidget(
      LibrarySeatItem seat, double cellSize, AppSemanticColors colors) {
    final isOccupied =
        _usedSeats.contains(seat.seatNum) || seat.reserveStatus != 0;
    final isSelected = _selectedSeatNum == seat.seatNum;

    Color bgColor;
    Color borderColor;
    Color textColor;

    if (isOccupied) {
      bgColor = colors.surfaceSubtle;
      borderColor = colors.border;
      textColor = colors.textMuted;
    } else if (isSelected) {
      bgColor = colors.brand;
      borderColor = colors.brand;
      textColor = Theme.of(context).colorScheme.onPrimary;
    } else {
      bgColor = colors.statusBg(colors.brand);
      borderColor = colors.brand;
      textColor = colors.brandText;
    }

    return Positioned(
      left: (seat.x - 1) * cellSize,
      top: (seat.y - 1) * cellSize,
      width: cellSize - 2,
      height: cellSize - 2,
      child: GestureDetector(
        onTap: isOccupied
            ? null
            : () {
                setState(() {
                  if (_selectedSeatNum == seat.seatNum) {
                    _selectedSeatNum = null;
                  } else {
                    _selectedSeatNum = seat.seatNum;
                  }
                });
              },
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: borderColor, width: isSelected ? 1.8 : 1),
          ),
          alignment: Alignment.center,
          child: Text(
            seat.seatNum,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionCard(AppSemanticColors colors) {
    final onBrand = Theme.of(context).colorScheme.onPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.page, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.border),
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(80, 40),
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              ),
              onPressed: (_selectedSeatNum != null && !_isSubmitting)
                  ? _submitReservation
                  : null,
              child: _isSubmitting
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: onBrand),
                    )
                  : Text(context.l10n.reserveNow),
            ),
          ],
        ),
      ),
    );
  }
}
