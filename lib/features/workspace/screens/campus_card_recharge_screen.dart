import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/campus_card_service.dart';
import '../providers/campus_card_cache_provider.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/l10n_extension.dart';
import 'campus_card_payment_sheet.dart';
import '../../../core/theme/app_tokens.dart';

class CampusCardRechargeScreen extends ConsumerStatefulWidget {
  const CampusCardRechargeScreen({super.key});

  @override
  ConsumerState<CampusCardRechargeScreen> createState() => _CampusCardRechargeScreenState();
}

class _CampusCardRechargeScreenState extends ConsumerState<CampusCardRechargeScreen> with WidgetsBindingObserver {
  final _logger = AppLogger.instance;
  final TextEditingController _amountController = TextEditingController();
  
  CampusCardInfo? _info;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  
  double? _selectedAmount;
  final List<double> _presetAmounts = [10, 30, 50, 100, 200, 500];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final cached = ref.read(campusCardCacheProvider).valueOrNull ??
        ref.read(campusCardServiceProvider).cachedInfo;
    if (cached != null) {
      _info = cached;
      _isLoading = false;
    }
    _loadInfo(isSilent: cached != null);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _amountController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadInfo(isSilent: true);
    }
  }

  Future<void> _loadInfo({bool isSilent = false, bool forceRefresh = false}) async {
    if (!mounted) return;
    if (_info == null) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      setState(() {
        _isRefreshing = true;
      });
    }

    try {
      final service = ref.read(campusCardServiceProvider);
      final info = await service.fetchRechargeInfo(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _info = info;
          _isLoading = false;
          _isRefreshing = false;
          _error = null;
        });
      }
      ref.read(campusCardCacheProvider.notifier).update(info);
    } catch (e) {
      _logger.e('Failed to load recharge info: $e');
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          if (!isSilent || _info == null) {
            _error = e.toString();
            _isLoading = false;
          }
        });
      }
    }
  }

  void _handlePresetAmountSelect(double amount) {
    setState(() {
      _selectedAmount = amount;
      _amountController.text = amount.toStringAsFixed(0);
    });
  }

  Future<void> _handleRecharge(PaymentMethod method) async {
    final amountText = _amountController.text;
    final amount = int.tryParse(amountText);
    
    if (amount == null || amount < 1 || amount > 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.pleaseEnterValidAmountRange)),
      );
      return;
    }

    if (_info == null) return;

    // 直接显示原生的支付确认卡片，内部处理支付流程
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => CampusCardPaymentSheet(
        amount: amountText,
        merchantName: context.l10n.campusCardRecharge,
        info: _info!,
        paymentMethod: method,
      ),
    ).then((_) {
      if (mounted) _loadInfo(isSilent: true); // 关闭后静默刷新最新余额
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.campusCardRecharge),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!,
                      style:
                          AppText.bodyDense.copyWith(color: colors.text)),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton(
                    onPressed: () => _loadInfo(forceRefresh: true),
                    child: Text(context.l10n.retry),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 卡片信息头
                  Container(
                    width: double.infinity,
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              context.l10n.currentRechargeCard,
                              style: AppText.caption.copyWith(
                                color: colors.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            InkWell(
                              onTap: _isRefreshing ? null : () => _loadInfo(isSilent: true, forceRefresh: true),
                              borderRadius: AppRadius.innerAll,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xs,
                                    vertical: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_isRefreshing)
                                      const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                        ),
                                      )
                                    else
                                      Icon(
                                        Icons.refresh,
                                        size: 14,
                                        color: colors.textMuted,
                                      ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Text(
                                      _isRefreshing ? context.l10n.refreshing : context.l10n.refreshBalance,
                                      style: AppText.caption.copyWith(
                                          color: colors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _info != null
                              ? '${_info!.name} (${_info!.idserial})'
                              : '---',
                          style: AppText.bodyDense.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          context.l10n.campusCardBalance,
                          style: AppText.caption.copyWith(
                            color: colors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _info != null
                              ? context.l10n.amountYuan(_info!.balance)
                              : (_isRefreshing ? context.l10n.checkingPaymentStatus : context.l10n.amountYuan('0.00')),
                          style: AppText.keyNumber.copyWith(color: colors.text),
                        ),
                      ],
                    ),
                  ),

                   const SizedBox(height: AppSpacing.xxl),

                   Text(
                     context.l10n.selectRechargeAmount,
                     style: AppText.bodyDense.copyWith(
                       fontWeight: FontWeight.w600,
                       color: colors.textMuted,
                     ),
                   ),
                   const SizedBox(height: AppSpacing.md),

                   // 金额预设网格
                   GridView.builder(
                     shrinkWrap: true,
                     physics: const NeverScrollableScrollPhysics(),
                     gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                       crossAxisCount: 3,
                       crossAxisSpacing: AppSpacing.md,
                       mainAxisSpacing: AppSpacing.md,
                       childAspectRatio: 2.2,
                     ),
                     itemCount: _presetAmounts.length,
                     itemBuilder: (context, index) {
                       final amount = _presetAmounts[index];
                       final isSelected = _selectedAmount == amount;
                       return InkWell(
                         onTap: () => _handlePresetAmountSelect(amount),
                         borderRadius: AppRadius.controlAll,
                         child: Container(
                           decoration: BoxDecoration(
                             color: isSelected
                                 ? colors.statusBg(colors.brand)
                                 : colors.surface,
                             borderRadius: AppRadius.controlAll,
                             border: Border.all(
                               color: isSelected
                                   ? colors.brand
                                   : colors.border,
                             ),
                           ),
                           alignment: Alignment.center,
                           child: Text(
                             context.l10n.amountYuan(amount.toStringAsFixed(0)),
                             style: AppText.bodyDense.copyWith(
                               color: isSelected
                                   ? colors.brandText
                                   : colors.text,
                               fontWeight: isSelected
                                   ? FontWeight.w600
                                   : FontWeight.w400,
                             ),
                           ),
                         ),
                       );
                     },
                   ),

                   const SizedBox(height: AppSpacing.lg),

                   // 自定义金额输入（标签在输入框上方）
                   Text(
                     context.l10n.customAmount,
                     style: AppText.bodyDense.copyWith(
                       fontWeight: FontWeight.w600,
                       color: colors.textMuted,
                     ),
                   ),
                   const SizedBox(height: AppSpacing.sm),
                   TextField(
                     controller: _amountController,
                     keyboardType: TextInputType.number,
                     inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                     decoration: const InputDecoration(
                       prefixText: '¥ ',
                     ),
                     style: AppText.keyNumber.copyWith(color: colors.text),
                     onChanged: (value) {
                       setState(() {
                         _selectedAmount = double.tryParse(value);
                       });
                     },
                   ),

                   const SizedBox(height: AppSpacing.xxxl),
                  ],
                ),
              ),
      bottomNavigationBar: _error != null || _isLoading
          ? null
          : _buildPaymentBar(),
    );
  }

  /// 固定在底部的支付方式操作区，始终可见，避免随内容滚动被挤到屏幕外。
  Widget _buildPaymentBar() {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md,
              AppSpacing.page, AppSpacing.md),
          child: Row(
            children: [
              // 微信支付
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => _handleRecharge(PaymentMethod.wechat),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF07C160),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.controlAll),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.string(
                          kWechatSvg,
                          width: 16,
                          height: 16,
                          colorFilter: const ColorFilter.mode(
                              Colors.white, BlendMode.srcIn),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            context.l10n.wechatPay,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // 支付宝支付
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => _handleRecharge(PaymentMethod.alipay),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1677FF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.controlAll),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.string(
                          kAlipaySvg,
                          width: 16,
                          height: 16,
                          colorFilter: const ColorFilter.mode(
                              Colors.white, BlendMode.srcIn),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            context.l10n.alipay,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
