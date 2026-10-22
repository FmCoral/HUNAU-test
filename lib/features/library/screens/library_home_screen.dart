import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/route_utils.dart';
import '../../../core/theme/app_tokens.dart';
import '../models/library_models.dart';
import '../providers/library_provider.dart';
import '../widgets/library_quick_reserve_sheet.dart';
import 'library_room_screen.dart';
import 'library_book_search_screen.dart';
import 'library_quick_reserve_screen.dart';

class LibraryHomeScreen extends ConsumerStatefulWidget {
  const LibraryHomeScreen({super.key});

  @override
  ConsumerState<LibraryHomeScreen> createState() => _LibraryHomeScreenState();
}

class _LibraryHomeScreenState extends ConsumerState<LibraryHomeScreen> {
  bool _isProcessingAction = false;

  Future<void> _handleSignIn(LibraryReserveModel reserve) async {
    setState(() => _isProcessingAction = true);
    try {
      final success = await ref
          .read(libraryIndexProvider.notifier)
          .signInSeat(reserve);
      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: AppSpacing.sm),
                Text(context.l10n.checkInSuccessEnjoy),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.checkInFailedWithReason(_errorMessage(e)))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingAction = false);
      }
    }
  }

  Future<void> _handleSignBack(LibraryReserveModel reserve) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.confirmCheckOutTitle),
        content: Text(
          context.l10n.confirmCheckOutMessage(reserve.thirdLevelName, reserve.seatNum),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.thinkAgain),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.danger,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 36),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.confirmCheckOut),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isProcessingAction = true);
    try {
      final success =
          await ref.read(libraryIndexProvider.notifier).signBackSeat(reserve);
      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.checkOutSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.checkOutFailedWithReason(_errorMessage(e)))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingAction = false);
      }
    }
  }

  String _errorMessage(Object error) {
    final raw = error.toString();
    if (raw.contains('统一认证已过期') ||
        raw.contains('登录会话已过期') ||
        raw.contains('登录已失效')) {
      return context.l10n.ssoExpiredRelogin;
    }
    if (raw.contains('NO_VALID_RESERVATION') ||
        raw.contains('服务器未返回') ||
        raw.contains('未返回有效')) {
      return context.l10n.reservationFailed;
    }
    return raw
        .replaceAll(RegExp(r'^.*?: '), '')
        .replaceAll(RegExp(r'\s*\(code:.*\)$'), '')
        .trim();
  }

  Future<void> _handleCancelReservation(LibraryReserveModel reserve) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.confirmCancelReservationTitle),
        content: Text(
            context.l10n.confirmCancelReservationMessage(reserve.thirdLevelName, reserve.seatNum)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.thinkAgain),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.danger,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 36),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.confirmCancel),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isProcessingAction = true);
      try {
        final success = await ref
            .read(libraryIndexProvider.notifier)
            .cancelReservation(reserve.id);
        if (mounted && success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.reservationCancelledSuccess)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    context.l10n.cancelReservationFailedWithReason(e.toString().replaceAll('Exception:', '').trim()))),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isProcessingAction = false);
        }
      }
    }
  }

  Future<void> _handleQuickReserve(LibraryReserveModel item) async {
    final selection = await showLibraryQuickReserveSheet(
      context: context,
      item: item,
    );
    if (selection == null || !mounted) return;

    setState(() => _isProcessingAction = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: AppSpacing.lg),
              Text(context.l10n.submittingReservation),
            ],
          ),
        ),
      ),
    );

    try {
      final service = ref.read(libraryServiceProvider);
      final result = await service.submitReservation(
        roomId: item.roomId,
        seatNum: item.seatNum,
        day: selection.day,
        startTime: selection.startTime,
        endTime: selection.endTime,
      );

      if (result.id <= 0 && result.seatNum.isEmpty) {
        throw const AppException('NO_VALID_RESERVATION');
      }

      // 刷新全局状态与本地缓存
      await ref
          .read(cachedLibraryReserveProvider.notifier)
          .addOrUpdateReserve(result);
      await ref.read(libraryIndexProvider.notifier).refresh();

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // 关闭 loading 弹窗

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: context.colors.brand),
                const SizedBox(width: AppSpacing.sm),
                Text(context.l10n.reservationSuccess),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.readingRoomLabel(item.fullRoomName)),
                const SizedBox(height: AppSpacing.xs),
                Text(context.l10n.seatNumberLabel(
                    result.seatNum.isNotEmpty ? result.seatNum : item.seatNum)),
                const SizedBox(height: AppSpacing.xs),
                Text(context.l10n.dateLabel(selection.day)),
                const SizedBox(height: AppSpacing.xs),
                Text(context.l10n.timeValueLabel('${selection.startTime} ~ ${selection.endTime}')),
                const SizedBox(height: AppSpacing.md),
                Text(
                  context.l10n.reservationNotice,
                  style: AppText.caption.copyWith(color: context.colors.textMuted),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.l10n.done),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // 关闭 loading 弹窗

        final errorMsg = _errorMessage(e);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error_outline, color: context.colors.danger),
                const SizedBox(width: AppSpacing.sm),
                Text(context.l10n.reservationFailed),
              ],
            ),
            content: Text(
              errorMsg.isNotEmpty ? errorMsg : context.l10n.reservationFailed,
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 36),
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
        setState(() => _isProcessingAction = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final indexDataAsync = ref.watch(libraryIndexProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.library),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.refresh,
            onPressed: () => ref.read(libraryIndexProvider.notifier).refresh(),
          ),
        ],
      ),
      body: indexDataAsync.when(
        data: (data) => _buildContent(data),
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: context.colors.danger),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
                child: Text(
                  err.toString().replaceAll('Exception:', '').trim(),
                  textAlign: TextAlign.center,
                  style: AppText.bodyDense
                      .copyWith(color: context.colors.textMuted),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: () =>
                    ref.read(libraryIndexProvider.notifier).refresh(),
                child: Text(context.l10n.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(LibraryIndexData data) {
    final activeList = data.curReserves;

    return RefreshIndicator(
      onRefresh: () => ref.read(libraryIndexProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          // 1. 当前预约状态看板 (Active Reservation Cards) - 有预约才显示，无预约不显示任何卡片
          if (activeList.isNotEmpty) ...[
            for (int i = 0; i < activeList.length; i++) ...[
              _buildActiveReservationCard(activeList[i]),
              const SizedBox(height: AppSpacing.md),
            ],
          ],

          // 2. 快速预约入口 (单个卡片)
          _buildEntryCard(
            icon: Icons.bolt_rounded,
            label: context.l10n.quickReserve,
            onTap: () {
              Navigator.push(
                  context, createSlideUpRoute(const LibraryQuickReserveScreen()));
            },
          ),
          const SizedBox(height: AppSpacing.md),

          // 3. 预约选座入口 (单个卡片)
          _buildEntryCard(
            icon: Icons.event_seat_rounded,
            label: context.l10n.reserveSeat,
            onTap: () {
              Navigator.push(
                  context, createSlideUpRoute(const LibraryRoomScreen()));
            },
          ),
          const SizedBox(height: AppSpacing.md),

          // 4. 图书馆图书查询入口 (单个卡片)
          _buildEntryCard(
            icon: Icons.menu_book_rounded,
            label: context.l10n.bookSearch,
            onTap: () {
              Navigator.push(
                  context, createSlideUpRoute(const LibraryBookSearchScreen()));
            },
          ),

          const SizedBox(height: AppSpacing.xxl),

          // 5. 历史与近期预约记录 (顶格显示，无分割线)
          _buildRecentReservationsHeader(),
          const SizedBox(height: 6),
          if (data.nearReserves.isEmpty)
            _buildEmptyHistoryCard()
          else
            ...data.nearReserves.map(
              (item) => _buildHistoryReservationItem(
                item,
                showReserveButton: activeList.isEmpty,
              ),
            ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildActiveReservationCard(LibraryReserveModel reserve) {
    final timeFormat = DateFormat('HH:mm');
    final startTimeStr = timeFormat.format(reserve.startTime);
    final endTimeStr = timeFormat.format(reserve.endTime);
    final canSignBack = reserve.reserveStatus.canSignBack;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: context.colors.border),
      ),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.card, AppSpacing.card, AppSpacing.card, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 座位号
          Text(
            context.l10n.seatWithNumber(reserve.seatNum),
            style: AppText.keyNumber.copyWith(color: context.colors.text),
          ),
          const SizedBox(height: AppSpacing.xs),

          // 位置
          Text(
            reserve.fullRoomName,
            style: AppText.bodyDense.copyWith(
              color: context.colors.text,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),

          // 年月日 + 时间（去掉x小时括号）
          Row(
            children: [
              Icon(Icons.access_time_rounded,
                  size: 14, color: context.colors.textMuted),
              const SizedBox(width: 6),
              Text(
                '${reserve.today}  $startTimeStr - $endTimeStr',
                style: AppText.caption.copyWith(color: context.colors.textMuted),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // 操作按钮：待签到时取消/签到，已入座相关状态时仅显示退座
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!canSignBack) ...[
                TextButton(
                  onPressed: _isProcessingAction
                      ? null
                      : () => _handleCancelReservation(reserve),
                  child: Text(context.l10n.cancelReservation),
                ),
                const SizedBox(width: AppSpacing.sm),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                  ),
                  icon: const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                  ),
                  label: Text(context.l10n.checkIn),
                  onPressed: _isProcessingAction
                      ? null
                      : () => _handleSignIn(reserve),
                ),
              ] else
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.danger,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 36),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 16),
                  label: Text(context.l10n.checkOut),
                  onPressed: _isProcessingAction
                      ? null
                      : () => _handleSignBack(reserve),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: context.colors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.cardAll,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.card, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: context.colors.brand, size: 20),
                const SizedBox(width: AppSpacing.md),
                Text(
                  label,
                  style: AppText.sectionTitle.copyWith(
                    fontSize: 15,
                    color: context.colors.text,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: context.colors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentReservationsHeader() {
    return Text(
      context.l10n.recentReservations,
      style: AppText.sectionTitle.copyWith(
        fontSize: 18,
        color: context.colors.text,
      ),
    );
  }

  Widget _buildEmptyHistoryCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          context.l10n.noReservationRecords,
          style: AppText.bodyDense.copyWith(color: context.colors.textMuted),
        ),
      ),
    );
  }

  Widget _buildHistoryReservationItem(
    LibraryReserveModel item, {
    bool showReserveButton = false,
  }) {
    final timeFormat = DateFormat('HH:mm');
    final startTimeStr = timeFormat.format(item.startTime);
    final endTimeStr = timeFormat.format(item.endTime);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. 座位号（字体加大加粗，无 #）
                Text(
                  item.seatNum,
                  style: AppText.sectionTitle.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.colors.text,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),

                // 2. 位置
                Text(
                  item.fullRoomName,
                  style: AppText.bodyDense.copyWith(
                    fontWeight: FontWeight.w500,
                    color: context.colors.text,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),

                // 3. 时间
                Text(
                  '${item.today}  $startTimeStr - $endTimeStr',
                  style: AppText.caption.copyWith(color: context.colors.textMuted),
                ),
              ],
            ),
          ),
          if (showReserveButton) ...[
            const SizedBox(width: AppSpacing.md),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                minimumSize: const Size(60, 32),
              ),
              onPressed: _isProcessingAction
                  ? null
                  : () => _handleQuickReserve(item),
              child: Text(context.l10n.reserve),
            ),
          ],
        ],
      ),
    );
  }
}
