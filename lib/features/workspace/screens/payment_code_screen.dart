import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/l10n_extension.dart';
import '../services/campus_card_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/route_utils.dart';
import 'payment_result_screen.dart';
import '../../../core/theme/app_tokens.dart';
import 'campus_card_recharge_screen.dart';
import 'transaction_history_screen.dart';

class PaymentCodeScreen extends ConsumerStatefulWidget {
  const PaymentCodeScreen({super.key});

  @override
  ConsumerState<PaymentCodeScreen> createState() => _PaymentCodeScreenState();
}

class _PaymentCodeScreenState extends ConsumerState<PaymentCodeScreen> with WidgetsBindingObserver {
  final _logger = AppLogger.instance;
  
  bool _isLoading = true;
  String? _error;
  String? _qrBase64;
  Uint8List? _qrBytes;
  String? _paycode;
  String? _userInfo;
  
  Timer? _refreshTimer;
  Timer? _statusTimer;

  int _refreshCountdown = 60;
  bool _isPolling = false;
  // HAR 显示空闲轮询约 250-500ms/次，长期 3s 高频浪费电量/服务端压力。
  // 连续空闲后退避到 5s，有状态变化立刻恢复 3s。
  int _idlePollCount = 0;
  int _statusIntervalSec = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 缓存秒开：55s 内的旧码先直接渲染首帧，后台再静默拉新码
    final svc = ref.read(campusCardServiceProvider);
    final cached = svc.getCachedPaymentCode();
    if (cached != null) {
      _qrBase64 = cached['qrBase64'] as String?;
      if (_qrBase64 != null) {
        try {
          _qrBytes = base64Decode(_qrBase64!);
        } catch (_) {
          _qrBytes = null;
        }
      }
      _paycode = cached['paycode'] as String?;
      _userInfo = cached['info'] as String?;
      if (_qrBytes != null && _paycode != null) {
        _isLoading = false;
        _refreshCountdown = svc.paymentCodeRemainingSeconds();
        _loadPaymentCode(isSilent: true);
        return;
      }
    }
    _loadPaymentCode();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _statusTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadPaymentCode();
    } else if (state == AppLifecycleState.paused) {
      _refreshTimer?.cancel();
      _statusTimer?.cancel();
    }
  }

  Future<void> _loadPaymentCode({bool isSilent = false}) async {
    if (!mounted) return;
    
    if (_qrBase64 == null) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final service = ref.read(campusCardServiceProvider);
      // 页面内的刷新（倒计时归零/点码/支付后）一律强制走网络，
      // 秒开只靠 initState 的缓存种子
      final data = await service.fetchPaymentCode(forceRefresh: true);
      
      if (mounted) {
        setState(() {
          _qrBase64 = data['qrBase64'];
          if (_qrBase64 != null) {
            _qrBytes = base64Decode(_qrBase64!);
          }
          _paycode = data['paycode'];
          _userInfo = data['info'];
          _isLoading = false;
          _refreshCountdown = 60;
          _error = null;
        });
        
        _startTimers();
      }
    } catch (e) {
      _logger.e('Failed to load payment code: $e');
      if (mounted) {
        setState(() {
          if (!isSilent || _qrBase64 == null) {
            _error = e.toString();
            _isLoading = false;
          }
        });
      }
    }
  }

  void _startTimers() {
    _refreshTimer?.cancel();
    _statusTimer?.cancel();
    _idlePollCount = 0;
    _statusIntervalSec = 3;

    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_refreshCountdown > 0) {
          _refreshCountdown--;
        } else {
          _loadPaymentCode(isSilent: true);
        }
      });
    });

    _scheduleStatusTimer();
  }

  void _scheduleStatusTimer() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(Duration(seconds: _statusIntervalSec), (timer) {
      _queryStatus();
    });
  }

  Future<void> _queryStatus() async {
    if (_paycode == null || _isPolling || !mounted) return;

    _isPolling = true;
    try {
      final service = ref.read(campusCardServiceProvider);
      final res = await service.queryOrderStatus(_paycode!);

      if (res['success'] == true) {
        final resultData = res['resultData'];
        final status = resultData is Map
            ? resultData['status']?.toString()
            : null;
        if (status == '1') {
          _idlePollCount = 0;
          _handlePaymentSuccess(Map<String, dynamic>.from(resultData as Map));
          return;
        } else if (['2', '4', '6', '7'].contains(status)) {
          // HAR 实测 status=5 是“付款码未使用”的空闲态，必须继续轮询，
          // 不能按失败弹层；只有 2/4/6/7 按失败处理。
          _idlePollCount = 0;
          final msg = resultData is Map
              ? (resultData['message']?.toString() ?? context.l10n.paymentFailed)
              : context.l10n.paymentFailed;
          _handlePaymentError(msg);
          return;
        }
      }
      _markIdleAndMaybeBackoff();
    } catch (e) {
      _logger.w('Query status error: $e');
      _markIdleAndMaybeBackoff();
    } finally {
      _isPolling = false;
    }
  }

  void _markIdleAndMaybeBackoff() {
    _idlePollCount++;
    // 连续 5 次空闲（约 15s 无人付款）后从 3s 退避到 5s + 抖动由 Timer 自然产生
    if (_idlePollCount >= 5 && _statusIntervalSec != 5) {
      _statusIntervalSec = 5;
      if (mounted) _scheduleStatusTimer();
    }
  }

  void _handlePaymentSuccess(Map<String, dynamic> data) {
    _statusTimer?.cancel();
    _refreshTimer?.cancel();
    
    String? amountStr;
    if (data['txamt'] != null) {
      amountStr = (double.parse(data['txamt'].toString()) / 100).toStringAsFixed(2);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => PaymentResultSheet(
        type: PaymentResultType.success,
        merchantName: data['mercname'] ?? data['merchantName'],
        amount: amountStr,
        time: data['paytime'] ?? '',
        journalNo: data['journo'] ?? '',
      ),
    ).then((_) {
      if (mounted) _loadPaymentCode();
    });
  }

  String _getBalance() {
    if (_userInfo == null) return '0.00';
    try {
      // 尝试从 "姓名：xxx 余额：xx.xx" 中提取余额
      if (_userInfo!.contains('余额：')) {
        return _userInfo!.split('余额：').last.replaceAll('元', '').trim();
      }
    } catch (e) {
      _logger.w('Parse balance error: $e');
    }
    return '0.00';
  }

  void _handlePaymentError(String message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => PaymentResultSheet(
        type: PaymentResultType.failure,
        message: message,
      ),
    ).then((_) {
      if (mounted) _loadPaymentCode();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.sm),
                // 付款码主卡片
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: AppRadius.cardAll,
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 卡片顶栏
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.xs),
                              decoration: BoxDecoration(
                                color: colors.statusBg(colors.brand),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.credit_card,
                                  size: 16, color: colors.brand),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Text(
                              context.l10n.campusCard,
                              style: AppText.sectionTitle
                                  .copyWith(color: colors.text),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xxxl),

                      // 二维码区域
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: AppRadius.innerAll,
                            border: Border.all(color: colors.border),
                          ),
                          child: GestureDetector(
                            onTap: _isLoading ? null : () => _loadPaymentCode(),
                            behavior: HitTestBehavior.opaque,
                            child: SizedBox(
                              width: 180,
                              height: 180,
                              child: (_isLoading && _qrBytes == null)
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : _error != null && _qrBytes == null
                                  ? Icon(Icons.error_outline,
                                      color: colors.danger, size: 48)
                                  : _qrBytes != null
                                    ? Image.memory(
                                        _qrBytes!,
                                        width: 180,
                                        height: 180,
                                        fit: BoxFit.contain,
                                      )
                                    : const SizedBox(),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xxxl),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl),

                // 余额展示卡片
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: AppRadius.cardAll,
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.credit_card_outlined,
                        size: 20,
                        color: colors.textMuted,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          context.l10n.balanceAmount(_getBalance()),
                          style: AppText.bodyDense.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(context, createSlideUpRoute(const CampusCardRechargeScreen())).then((_) => _loadPaymentCode()),
                        child: Text(context.l10n.transactionRecharge),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // 独立账单入口
                InkWell(
                  onTap: () => Navigator.push(context, createSlideUpRoute(const TransactionHistoryScreen())),
                  borderRadius: AppRadius.cardAll,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border.all(color: colors.border),
                      borderRadius: AppRadius.cardAll,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 20,
                          color: colors.textMuted,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            context.l10n.bill,
                            style: AppText.bodyDense.copyWith(
                              fontWeight: FontWeight.w500,
                              color: colors.text,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: colors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl),

                // 提示语 (左对齐)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.l10n.tapQrToRefresh,
                    style: AppText.caption.copyWith(color: colors.textMuted),
                  ),
                ),

                const SizedBox(height: AppSpacing.xxxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
