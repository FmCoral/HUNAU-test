import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/l10n_extension.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';
import '../../../core/theme/app_tokens.dart';

extension TransactionTypeL10n on TransactionType {
  String getLocalizedLabel(BuildContext context) {
    switch (this) {
      case TransactionType.all:
        return context.l10n.all;
      case TransactionType.consume:
        return context.l10n.transactionConsume;
      case TransactionType.recharge:
        return context.l10n.transactionRecharge;
      case TransactionType.subsidy:
        return context.l10n.transactionSubsidy;
      case TransactionType.transfer:
        return context.l10n.transactionTransfer;
    }
  }
}

/// 校园卡账单页
///
/// 入口放在付款码页（余额卡片的「账单」按钮）。
/// 接口与加解密见 [TransactionService]，页面校验对齐
/// `querytrace.js` 的 `queryTrade()`：间隔 ≤ 31 天，截止 ≥ 起始且 ≤ 当天。
///
/// 布局：未查询时条件居中；点击查询后条件上移，下方出现卡片账单。
class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  final _logger = AppLogger.instance;

  DateTime? _beginDate;
  DateTime? _endDate;
  TransactionType _type = TransactionType.all;

  @override
  void initState() {
    super.initState();
    // 默认：上周到今天（含今天共 7 天），不自动查询
    final now = DateTime.now();
    _endDate = DateTime(now.year, now.month, now.day);
    _beginDate = _endDate!.subtract(const Duration(days: 6));
  }

  bool _isLoading = false;
  bool _hasQueried = false;
  String? _error;
  List<TransactionRecord> _records = [];

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// 对齐 querytrace.js 的三段校验，返回 null 表示通过
  String? _validate() {
    if (_beginDate == null) return context.l10n.pleaseSelectStartDate;
    if (_endDate == null) return context.l10n.pleaseSelectEndDate;
    if (_beginDate!.isAfter(_endDate!)) return context.l10n.endDateMustBeAfterStartDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_endDate!.isAfter(today)) return context.l10n.endDateCannotBeInFuture;
    if (_endDate!.difference(_beginDate!).inDays > 31) return context.l10n.dateRangeMaxOneMonth;
    return null;
  }

  Future<void> _pickDate(bool isBegin) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = isBegin
        ? (_beginDate ?? today.subtract(const Duration(days: 6)))
        : (_endDate ?? today);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(today.year - 2),
      lastDate: today,
    );
    if (picked != null && mounted) {
      setState(() {
        if (isBegin) {
          _beginDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _query() async {
    final err = _validate();
    if (err != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err)),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _hasQueried = true;
      _error = null;
    });

    try {
      final records =
          await ref.read(transactionServiceProvider).queryTransactions(
                beginDate: _fmt(_beginDate!),
                endDate: _fmt(_endDate!),
                tradeType: _type.value,
              );
      if (mounted) {
        setState(() {
          _records = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      _logger.e('❌ queryTransactions failed: $e');
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  /// 每条记录的类型：记录自带优先，否则按当前筛选，全部时兜底
  String _recordTypeValue(TransactionRecord r) {
    if (r.tradeType.isNotEmpty) return r.tradeType;
    if (_type != TransactionType.all) return _type.value;
    return '';
  }

  ({IconData icon, Color color}) _typeStyle(AppSemanticColors colors, String value) {
    switch (value) {
      case '1':
        return (icon: Icons.shopping_cart_outlined, color: colors.warning);
      case '2':
        return (
          icon: Icons.account_balance_wallet_outlined,
          color: colors.brand,
        );
      case '3':
        return (icon: Icons.redeem_outlined, color: colors.info);
      case '4':
        return (icon: Icons.swap_horiz, color: colors.info);
      default:
        return (icon: Icons.receipt_long_outlined, color: colors.textMuted);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.bill),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.12),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: _hasQueried
            ? _buildResultLayout()
            : _buildInitialLayout(),
      ),
    );
  }

  /// 未查询：条件居中
  Widget _buildInitialLayout() {
    return Center(
      key: const ValueKey('bill-initial'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildConditionRow(),
            const SizedBox(height: AppSpacing.lg),
            Align(
              alignment: Alignment.centerRight,
              child: _buildQueryButton(),
            ),
          ],
        ),
      ),
    );
  }

  /// 查询后：条件上移，下方卡片账单
  Widget _buildResultLayout() {
    return Column(
      key: const ValueKey('bill-result'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.page, AppSpacing.page, AppSpacing.page, AppSpacing.md),
          child: Column(
            children: [
              _buildConditionRow(),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: _buildQueryButton(),
              ),
            ],
          ),
        ),
        Expanded(child: _buildBillBox()),
      ],
    );
  }

  /// 起始日期 - 截止日期 - 类型（一行，三框固定等高）
  Widget _buildConditionRow() {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: _buildDateBox(
            label: context.l10n.startDate,
            date: _beginDate,
            onTap: () => _pickDate(true),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 4,
          child: _buildDateBox(
            label: context.l10n.endDate,
            date: _endDate,
            onTap: () => _pickDate(false),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 3,
          child: _buildTypeBox(),
        ),
      ],
    );
  }

  Widget _buildDateBox({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    return _md2Box(
      label: label,
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Text(
              date == null ? context.l10n.pleaseSelect : _fmt(date),
              style: AppText.caption.copyWith(
                fontWeight: FontWeight.w500,
                color: date == null ? colors.textMuted : colors.text,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.calendar_today_outlined,
              size: 16, color: colors.textMuted),
        ],
      ),
    );
  }

  /// 描边选择框：label 嵌在描边上 + 56dp 高，边框/填充走全局主题
  Widget _md2Box({
    required String label,
    required Widget child,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.controlAll,
      child: SizedBox(
        height: 56,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          child: child,
        ),
      ),
    );
  }

  /// 类型选择框：描边框 + 底部弹窗选值
  /// （不用 DropdownButton：它的弹出菜单路由在动画首帧会以零尺寸参与
  /// hit test，debug 下刷 `Cannot hit test a render box with no size`）
  Widget _buildTypeBox() {
    final colors = context.colors;
    return _md2Box(
      label: context.l10n.type,
      onTap: _pickType,
      child: Row(
        children: [
          Expanded(
            child: Text(
              _type.getLocalizedLabel(context),
              style: AppText.bodyDense.copyWith(
                fontWeight: FontWeight.w500,
                color: colors.text,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.keyboard_arrow_down,
              size: 18, color: colors.textMuted),
        ],
      ),
    );
  }

  Future<void> _pickType() async {
    final colors = context.colors;
    final selected = await showModalBottomSheet<TransactionType>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ...TransactionType.values.map(
              (t) => ListTile(
                title: Text(t.getLocalizedLabel(sheetContext)),
                trailing: _type == t
                    ? Icon(Icons.check, color: colors.brand)
                    : null,
                onTap: () => Navigator.pop(sheetContext, t),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _type = selected);
    }
  }

  /// 查询按钮：样式交给全局主题
  Widget _buildQueryButton() {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _query,
        icon: _isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.search, size: 18),
        label: Text(context.l10n.query,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    );
  }

  /// 卡片账单容器
  Widget _buildBillBox() {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: AppRadius.cardAll,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.cardAll,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _buildBillContent(),
        ),
      ),
    );
  }

  Widget _buildBillContent() {
    final colors = context.colors;
    if (_isLoading) {
      return const Center(
        key: ValueKey('bill-loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (_error != null) {
      return Center(
        key: const ValueKey('bill-error'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colors.danger),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppText.bodyDense.copyWith(color: colors.text),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: _query,
              child: Text(context.l10n.retry),
            ),
          ],
        ),
      );
    }
    if (_records.isEmpty) {
      return Center(
        key: const ValueKey('bill-empty'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 48, color: colors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(context.l10n.noTransactions,
                style: AppText.bodyDense.copyWith(color: colors.textMuted)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      key: const ValueKey('bill-list'),
      onRefresh: _query,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm, horizontal: AppSpacing.sm),
        itemCount: _records.length,
        itemBuilder: (context, index) {
          final r = _records[index];
          final style = _typeStyle(colors, _recordTypeValue(r));
          final isNegative = r.amount.trim().startsWith('-');
          return Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.statusBg(style.color),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(style.icon, size: 20, color: style.color),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.merchantName,
                          style: AppText.bodyDense.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: colors.text)),
                      const SizedBox(height: 2),
                      Text(r.time,
                          style: AppText.caption.copyWith(
                              fontSize: 12, color: colors.textMuted)),
                    ],
                  ),
                ),
                Text(
                  r.amount,
                  style: AppText.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isNegative ? colors.text : colors.brandText,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
